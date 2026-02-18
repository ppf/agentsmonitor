import Foundation
import SwiftUI

enum SessionSourceTab: String, CaseIterable, Identifiable {
    case all
    case codex
    case claudeCode

    var id: Self { self }
}

@Observable
final class SessionStore {
    // MARK: - Published State

    private(set) var sessions: [Session] = []
    var selectedSessionId: UUID?
    var isLoading: Bool = false
    var error: String?

    // Usage API
    var usageData: AnthropicUsage?
    var usageError: String?
    var codexUsage: CodexRateLimits?

    // MARK: - Dependencies

    private let sessionService: ClaudeSessionService
    private let codexService: CodexSessionService
    private let usageService: any UsageServiceProviding
    private let environment: AppEnvironment

    // Token cost cache: jsonlPath → (mtime, summary)
    private var costCache: [String: CostCacheEntry] = [:]
    private var costCalculationTask: Task<Void, Never>?

    struct CostCacheEntry: Codable {
        let mtime: Int64
        let summary: SessionTokenSummary
    }

    private static var cacheFileURL: URL {
        URL(fileURLWithPath: FileUtilities.realHomeDirectory())
            .appendingPathComponent(".claude")
            .appendingPathComponent("agents-monitor-cost-cache.json")
    }

    private var isRunningTests: Bool {
        environment.isTesting
    }

    // MARK: - Initialization

    init(
        sessionService: ClaudeSessionService = ClaudeSessionService(),
        codexService: CodexSessionService = CodexSessionService(),
        usageService: any UsageServiceProviding = AnthropicUsageService(),
        environment: AppEnvironment = .current
    ) {
        self.sessionService = sessionService
        self.codexService = codexService
        self.usageService = usageService
        self.environment = environment
        if !environment.isTesting {
            loadCostCache()
        }

        Task {
            await initialLoad()
        }
    }

    // MARK: - Computed Properties

    var selectedSession: Session? {
        get {
            guard let id = selectedSessionId else { return nil }
            return sessions.first { $0.id == id }
        }
        set {
            selectedSessionId = newValue?.id
        }
    }

    var runningSessions: [Session] {
        sessions.filter { $0.status == .running }
    }

    var activeSessions: [Session] {
        sessions.filter { $0.status == .running || $0.status == .waiting }
    }

    var completedSessions: [Session] {
        sessions.filter { $0.status == .completed }
    }

    var failedSessions: [Session] {
        sessions.filter { $0.status == .failed }
    }

    // MARK: - Aggregate Stats

    var aggregateTokens: Int {
        sessions.reduce(0) { $0 + $1.metrics.totalTokens }
    }

    var aggregateCost: Double {
        sessions.reduce(0) { $0 + $1.metrics.cost }
    }

    var totalRuntime: TimeInterval {
        let now = environment.now
        return sessions.reduce(0) { $0 + $1.duration(asOf: now) }
    }

    var averageDuration: TimeInterval {
        guard !sessions.isEmpty else { return 0 }
        return totalRuntime / Double(sessions.count)
    }

    var formattedAggregateTokens: String {
        Self.formatTokenCount(aggregateTokens)
    }

    var formattedAggregateCost: String {
        Self.formatCost(aggregateCost)
    }

    static func formatTokenCount(_ total: Int) -> String {
        if total >= 1_000_000 {
            return String(format: "%.1fM", Double(total) / 1_000_000)
        } else if total >= 1_000 {
            return String(format: "%.1fK", Double(total) / 1_000)
        }
        return "\(total)"
    }

    static func formatCost(_ total: Double) -> String {
        total > 0 ? String(format: "$%.2f", total) : "--"
    }

    var formattedTotalRuntime: String {
        Self.formatDuration(totalRuntime)
    }

    var formattedAverageDuration: String {
        Self.formatDuration(averageDuration)
    }

    static func formatDuration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        if interval < 60 {
            formatter.allowedUnits = [.second]
        } else if interval < 3600 {
            formatter.allowedUnits = [.minute]
        } else {
            formatter.allowedUnits = [.hour, .minute]
        }
        return formatter.string(from: interval) ?? "0s"
    }

    static func boolPreference(forKey key: String, defaultValue: Bool, defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    func visibleSessions(
        for tab: SessionSourceTab,
        codexEnabled: Bool,
        claudeCodeEnabled: Bool
    ) -> [Session] {
        let enabledSessions = sessions.filter { session in
            switch session.agentType {
            case .codex:
                codexEnabled
            case .claudeCode:
                claudeCodeEnabled
            }
        }

        switch tab {
        case .all:
            return enabledSessions
        case .codex:
            return enabledSessions.filter { $0.agentType == .codex }
        case .claudeCode:
            return enabledSessions.filter { $0.agentType == .claudeCode }
        }
    }

    // MARK: - Session Management

    func clearAllSessions() {
        sessions.removeAll()
        selectedSessionId = nil
        costCache.removeAll()
        do {
            try FileManager.default.removeItem(at: Self.cacheFileURL)
        } catch let error as NSError where !(error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError) {
            AppLogger.logWarning("Failed to delete cost cache: \(error.localizedDescription)", context: "SessionStore")
        } catch {}
    }

    // MARK: - Refresh & Loading

    @MainActor
    func refresh() async {
        await loadSessions()
    }

    @MainActor
    func refreshAll() async {
        async let sessionsTask: () = loadSessions()
        async let usageTask: () = fetchUsageData()
        _ = await (sessionsTask, usageTask)
    }

    @MainActor
    func loadSessions() async {
        if isRunningTests && environment.isUITesting {
            loadMockData(referenceDate: environment.now, sessionCount: environment.mockSessionCount)
            return
        }
        if isRunningTests {
            return
        }

        isLoading = true
        error = nil

        await AppLogger.measureAsync("load sessions") {
            let defaults = UserDefaults.standard
            let showAll = !defaults.bool(forKey: "activeOnly")
            let showSidechains = defaults.bool(forKey: "showSidechains")
            let codexEnabled = Self.boolPreference(forKey: "codexEnabled", defaultValue: true, defaults: defaults)
            let claudeCodeEnabled = Self.boolPreference(forKey: "claudeCodeEnabled", defaultValue: true, defaults: defaults)

            if !codexEnabled { codexUsage = nil }

            async let claudeSessionsTask: [Session] = claudeCodeEnabled
                ? sessionService.discoverSessions(showAll: showAll, showSidechains: showSidechains)
                : []
            async let codexSessionsTask: [Session] = codexEnabled
                ? codexService.discoverSessions(showAll: showAll, showSidechains: showSidechains)
                : []
            async let codexLimitsTask: CodexRateLimits? = codexEnabled
                ? codexService.fetchRateLimits()
                : nil

            var discovered = await claudeSessionsTask + codexSessionsTask
            codexUsage = await codexLimitsTask
            discovered.sort { $0.startedAt > $1.startedAt }

            // Apply cached costs immediately
            for i in discovered.indices {
                guard let jsonlPath = discovered[i].jsonlPath else { continue }
                let mtime = discovered[i].fileMtime
                if let cached = costCache[jsonlPath], cached.mtime == mtime {
                    applyTokenSummary(cached.summary, to: &discovered[i])
                }
            }

            sessions = discovered

            if let current = selectedSessionId, sessions.contains(where: { $0.id == current }) {
                // Keep selection
            } else {
                selectedSessionId = sessions.first?.id
            }
        }

        isLoading = false

        // Calculate uncached costs in background, update sessions incrementally
        costCalculationTask?.cancel()
        guard !sessions.isEmpty else {
            costCalculationTask = nil
            return
        }
        costCalculationTask = Task.detached(priority: .utility) {
            let sessionMeta: [(id: UUID, jsonlPath: String, mtime: Int64, agentType: AgentType)] = await MainActor.run {
                self.sessions.compactMap { session in
                    guard let path = session.jsonlPath else { return nil }
                    let cached = self.costCache[path]?.mtime == session.fileMtime
                    guard !cached else { return nil }
                    return (id: session.id, jsonlPath: path, mtime: session.fileMtime, agentType: session.agentType)
                }
            }

            for entry in sessionMeta {
                guard !Task.isCancelled else { break }

                let summary: SessionTokenSummary?
                if entry.agentType == .codex {
                    summary = TokenCostCalculator.calculateCodex(jsonlPath: entry.jsonlPath)?.tokenSummary
                } else {
                    summary = TokenCostCalculator.calculate(jsonlPath: entry.jsonlPath)
                }

                if let summary {
                    await MainActor.run {
                        self.costCache[entry.jsonlPath] = CostCacheEntry(mtime: entry.mtime, summary: summary)
                        if let idx = self.sessions.firstIndex(where: { $0.id == entry.id }) {
                            self.applyTokenSummary(summary, to: &self.sessions[idx])
                        }
                    }
                }
            }

            await MainActor.run {
                self.saveCostCache()
            }
        }
    }

    @MainActor
    func fetchUsageData() async {
        do {
            usageData = try await usageService.fetchUsage()
            usageError = nil
        } catch {
            usageError = error.localizedDescription
            AppLogger.logWarning("Usage API: \(error.localizedDescription)", context: "fetchUsageData")
        }
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }

    // MARK: - Private Helpers

    private func applyTokenSummary(_ summary: SessionTokenSummary, to session: inout Session) {
        session.metrics.inputTokens = summary.inputTokens
        session.metrics.outputTokens = summary.outputTokens
        session.metrics.totalTokens = summary.inputTokens + summary.outputTokens + summary.cacheWriteTokens + summary.cacheReadTokens
        session.metrics.cacheWriteTokens = summary.cacheWriteTokens
        session.metrics.cacheReadTokens = summary.cacheReadTokens
        session.metrics.cost = summary.cost
        session.metrics.modelName = summary.modelName
        session.metrics.apiCalls = summary.apiCalls
    }

    private func loadCostCache() {
        let url = Self.cacheFileURL
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return
        } catch {
            AppLogger.logWarning("Failed to read cost cache: \(error.localizedDescription)", context: "SessionStore")
            return
        }
        guard let decoded = try? JSONDecoder().decode([String: CostCacheEntry].self, from: data) else {
            AppLogger.logWarning("Corrupt cost cache, starting fresh", context: "SessionStore")
            return
        }
        costCache = decoded
    }

    private func saveCostCache() {
        guard !isRunningTests else { return }
        let url = Self.cacheFileURL
        let data: Data
        do {
            data = try JSONEncoder().encode(costCache)
        } catch {
            AppLogger.logWarning("Failed to encode cost cache: \(error.localizedDescription)", context: "SessionStore")
            return
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            AppLogger.logWarning("Failed to save cost cache: \(error.localizedDescription)", context: "SessionStore")
        }
    }

    @MainActor
    private func initialLoad() async {
        if environment.isUITesting {
            loadMockData(referenceDate: environment.now, sessionCount: environment.mockSessionCount)
            return
        }

        if environment.isUnitTesting {
            loadMockData()
            return
        }

        await refreshAll()
    }

    #if DEBUG
    private func loadMockData(referenceDate: Date = Date(), sessionCount: Int? = nil) {
        let now = referenceDate
        let session1 = Session(
            name: "Fix authentication bug",
            status: .waiting,
            agentType: .claudeCode,
            startedAt: now.addingTimeInterval(-3600),
            metrics: SessionMetrics(totalTokens: 15420, inputTokens: 8200, outputTokens: 7220, toolCallCount: 3, errorCount: 0, apiCalls: 5, cost: 0.0312, modelName: "claude-sonnet-4-5-20250929")
        )

        let session2 = Session(
            name: "Generate unit tests",
            status: .completed,
            agentType: .claudeCode,
            startedAt: now.addingTimeInterval(-7200),
            endedAt: now.addingTimeInterval(-5400),
            metrics: SessionMetrics(totalTokens: 32150, inputTokens: 14200, outputTokens: 17950, toolCallCount: 5, errorCount: 0, apiCalls: 8, cost: 0.1845, modelName: "claude-sonnet-4-5-20250929")
        )

        let session3 = Session(
            name: "Code review PR #142",
            status: .running,
            agentType: .claudeCode,
            startedAt: now.addingTimeInterval(-300),
            metrics: SessionMetrics(totalTokens: 0, inputTokens: 0, outputTokens: 0, toolCallCount: 0, errorCount: 0, apiCalls: 0)
        )

        let session4 = Session(
            name: "Refactor API endpoints",
            status: .completed,
            agentType: .codex,
            startedAt: now.addingTimeInterval(-1800),
            endedAt: now.addingTimeInterval(-900),
            metrics: SessionMetrics(modelName: "gpt-5.3-codex")
        )

        var baseSessions = [session1, session2, session3, session4]

        if let sessionCount, sessionCount > baseSessions.count {
            let extraCount = sessionCount - baseSessions.count
            for index in 0..<extraCount {
                let sequence = baseSessions.count + index + 1
                let extra = Session(
                    name: "Mock Session \(sequence)",
                    status: .completed,
                    agentType: .claudeCode,
                    startedAt: now.addingTimeInterval(-Double(12000 + (index * 60))),
                    endedAt: now.addingTimeInterval(-Double(9000 + (index * 60))),
                    metrics: SessionMetrics(totalTokens: 1200, inputTokens: 600, outputTokens: 600, toolCallCount: 1, errorCount: 0, apiCalls: 1)
                )
                baseSessions.append(extra)
            }
        }

        sessions = baseSessions
        selectedSessionId = session1.id
    }
    #endif
}
