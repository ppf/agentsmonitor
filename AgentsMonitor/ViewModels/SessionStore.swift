import Foundation
import SwiftUI

@Observable
final class SessionStore {
    // MARK: - Published State

    private(set) var sessions: [Session] = []
    var selectedSessionId: UUID? {
        didSet {
            guard let id = selectedSessionId else { return }
            Task { @MainActor in
                await loadSessionDetailsIfNeeded(id)
            }
        }
    }
    var isLoading: Bool = false
    var error: String?

    // MARK: - Pagination

    private let pageSize = 50
    private var currentPage = 0
    private var hasMorePages = true

    // MARK: - Dependencies

    private let agentService: AgentService
    private let persistence: SessionPersistence?
    private let environment: AppEnvironment
    private var loadingSessionIds: Set<UUID> = []

    private var isRunningTests: Bool {
        environment.isTesting
    }

    // MARK: - Initialization

    init(
        agentService: AgentService = AgentService(),
        persistence: SessionPersistence? = SessionPersistence.shared,
        environment: AppEnvironment = .current
    ) {
        self.agentService = agentService
        self.environment = environment
        self.persistence = environment.isUITesting ? nil : persistence

        AgentType.seedSuggestedOverridesIfNeeded()

        Task {
            await loadPersistedSessions()
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

    var waitingSessions: [Session] {
        sessions.filter { $0.status == .waiting }
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
        let total = aggregateTokens
        if total >= 1_000_000 {
            return String(format: "%.1fM", Double(total) / 1_000_000)
        } else if total >= 1_000 {
            return String(format: "%.1fK", Double(total) / 1_000)
        }
        return "\(total)"
    }

    var formattedAggregateCost: String {
        aggregateCost > 0 ? String(format: "$%.2f", aggregateCost) : "--"
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

    // MARK: - Session CRUD

    func createNewSession() {
        let name = "New Session \(sessions.count + 1)"
        createSession(agentType: .claudeCode, name: name)
    }

    func createSession(agentType: AgentType, name: String?) {
        let sessionName = name ?? "\(agentType.displayName) Session \(sessions.count + 1)"
        let session = Session(
            name: sessionName,
            status: .waiting,
            agentType: agentType
        )
        sessions.insert(session, at: 0)
        selectedSessionId = session.id

        AppLogger.logSessionCreated(session)
        persistSession(session)
    }

    func deleteSession(_ session: Session) {
        let sessionId = session.id
        sessions.removeAll { $0.id == sessionId }

        if selectedSessionId == sessionId {
            selectedSessionId = sessions.first?.id
        }

        AppLogger.logSessionDeleted(sessionId)

        Task {
            try? await persistence?.deleteSession(sessionId)
        }
    }

    func clearAllSessions() {
        sessions.removeAll()
        selectedSessionId = nil
        Task {
            do {
                try await persistence?.clearAllSessions()
            } catch {
                AppLogger.logPersistenceError(error, context: "clearing all sessions")
            }
        }
    }

    func clearCompletedSessions() {
        let completedIds = sessions.filter { $0.status == .completed }.map { $0.id }
        sessions.removeAll { $0.status == .completed }

        Task {
            for id in completedIds {
                try? await persistence?.deleteSession(id)
            }
        }
    }

    func updateSession(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            let oldStatus = sessions[index].status
            sessions[index] = session

            if oldStatus != session.status {
                AppLogger.logSessionStatusChanged(session, from: oldStatus)
            }

            persistSession(session)
        }
    }

    // MARK: - Message & Tool Call Management

    func appendMessage(_ message: Message, to sessionId: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].messages.append(message)
            persistSession(sessions[index])
        }
    }

    func appendToolCall(_ toolCall: ToolCall, to sessionId: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].toolCalls.append(toolCall)
            sessions[index].metrics.toolCallCount += 1

            AppLogger.logToolCallStarted(toolCall, sessionId: sessionId)
            persistSession(sessions[index])
        }
    }

    func updateToolCall(_ toolCall: ToolCall, in sessionId: UUID) {
        if let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
           let toolIndex = sessions[sessionIndex].toolCalls.firstIndex(where: { $0.id == toolCall.id }) {
            sessions[sessionIndex].toolCalls[toolIndex] = toolCall

            if toolCall.status == .completed || toolCall.status == .failed {
                AppLogger.logToolCallCompleted(toolCall, sessionId: sessionId)
            }

            persistSession(sessions[sessionIndex])
        }
    }

    // MARK: - Refresh & Loading

    @MainActor
    func refresh() async {
        isLoading = true
        error = nil

        do {
            try await AppLogger.measureAsync("refresh sessions") {
                if let persistence = persistence {
                    let summaries = try await persistence.loadSessionSummaries()
                    await applySessionSummaries(summaries)
                }
            }
            await detectRunningAgents()
        } catch {
            self.error = error.localizedDescription
            AppLogger.logError(error, context: "refresh")
        }

        isLoading = false
    }

    @MainActor
    func refreshExternalProcesses() async {
        if isLoading { return }
        isLoading = true
        await detectRunningAgents()
        isLoading = false
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }

    // MARK: - Export

    func exportSession(_ session: Session, to url: URL) async throws {
        try await persistence?.exportSession(session, to: url)
    }

    // MARK: - Private Helpers

    private func persistSession(_ session: Session) {
        Task {
            do {
                try await persistence?.saveSession(session)
            } catch {
                AppLogger.logPersistenceError(error, context: "saving session \(session.id)")
            }
        }
    }

    @MainActor
    private func loadPersistedSessions() async {
        if environment.isUITesting {
            AppLogger.logWarning("UI testing mode active, loading deterministic mock data", context: "loadPersistedSessions")
            loadMockData(referenceDate: environment.now, sessionCount: environment.mockSessionCount)
            return
        }

        guard let persistence = persistence else {
            AppLogger.logWarning("No persistence available, loading mock data", context: "loadPersistedSessions")
            loadMockData()
            await detectRunningAgents()
            return
        }

        isLoading = true

        do {
            let summaries = try await persistence.loadSessionSummaries()
            AppLogger.logPersistenceLoaded(count: summaries.count)

            if summaries.isEmpty {
                await detectRunningAgents()

                if sessions.isEmpty {
                    AppLogger.logWarning("No persisted or running sessions found, loading mock data", context: "loadPersistedSessions")
                    loadMockData()
                } else {
                    AppLogger.logWarning("No persisted sessions found, but detected \(sessions.count) running agent(s)", context: "loadPersistedSessions")
                }
            } else {
                await applySessionSummaries(summaries)
                await detectRunningAgents()
            }
        } catch {
            AppLogger.logPersistenceError(error, context: "loading sessions")
            AppLogger.logWarning("Failed to load persisted sessions, trying to detect running agents", context: "loadPersistedSessions")
            await detectRunningAgents()

            if sessions.isEmpty {
                loadMockData()
            }
        }

        isLoading = false
    }

    @MainActor
    private func applySessionSummaries(_ summaries: [SessionSummary]) async {
        let sorted = summaries.sorted { $0.startedAt > $1.startedAt }
        sessions = sorted.map { $0.toSession() }
        if let current = selectedSessionId, sessions.contains(where: { $0.id == current }) {
            // Keep current selection
        } else {
            selectedSessionId = sessions.first?.id
        }
        if let selected = selectedSessionId {
            await loadSessionDetailsIfNeeded(selected)
        }
    }

    @MainActor
    private func loadSessionDetailsIfNeeded(_ sessionId: UUID) async {
        guard let persistence = persistence else { return }
        guard let initialIndex = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        guard !sessions[initialIndex].isExternalProcess else { return }
        guard !sessions[initialIndex].isFullyLoaded else { return }
        guard !loadingSessionIds.contains(sessionId) else { return }
        let initialSession = sessions[initialIndex]

        loadingSessionIds.insert(sessionId)
        defer { loadingSessionIds.remove(sessionId) }

        do {
            if let loaded = try await persistence.loadSession(sessionId) {
                guard let currentIndex = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
                guard !sessions[currentIndex].isExternalProcess else { return }
                let merged = mergeLoadedSession(initial: initialSession, current: sessions[currentIndex], loaded: loaded)
                sessions[currentIndex] = merged
            }
        } catch {
            AppLogger.logPersistenceError(error, context: "loading session details \(sessionId)")
        }
    }

    @MainActor
    private func detectRunningAgents() async {
        guard !isRunningTests else { return }
        let detected = await AgentProcessDiscovery().detect()
        let existingPids = Set(sessions.compactMap { $0.processId })
        let newProcesses = detected.filter { !existingPids.contains($0.pid) }
        guard !newProcesses.isEmpty else { return }

        let workingDirs = await Self.lookupWorkingDirectories(for: newProcesses.map(\.pid))

        for process in newProcesses {
            let startedAt = Date().addingTimeInterval(-TimeInterval(process.elapsedSeconds))
            let workingDir = workingDirs[process.pid] ?? nil

            let session = Session(
                name: "\(process.agentType.displayName) - PID \(process.pid)",
                status: .running,
                agentType: process.agentType,
                startedAt: startedAt,
                workingDirectory: workingDir,
                processId: process.pid,
                isExternalProcess: true
            )
            sessions.insert(session, at: 0)

            AppLogger.logSessionCreated(session)
        }
    }

    private static func lookupWorkingDirectories(for pids: [Int32]) async -> [Int32: URL?] {
        await withTaskGroup(of: (Int32, URL?).self) { group in
            for pid in pids {
                group.addTask {
                    let directory = await getWorkingDirectory(for: pid)
                    return (pid, directory)
                }
            }

            var results: [Int32: URL?] = [:]
            for await (pid, directory) in group {
                results[pid] = directory
            }
            return results
        }
    }

    private static func getWorkingDirectory(for pid: Int32) async -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lsof")
        process.arguments = ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            AppLogger.logError(error, context: "Getting working directory for PID \(pid)")
            return nil
        }

        let deadline = Date().addingTimeInterval(1.0)
        while process.isRunning {
            if Date() >= deadline {
                process.terminate()
                return nil
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        for line in output.split(separator: "\n") {
            if line.starts(with: "n") {
                let path = String(line.dropFirst())
                return URL(fileURLWithPath: path)
            }
        }

        return nil
    }

    var detectedExternalCount: Int {
        sessions.filter { $0.isExternalProcess }.count
    }

    private func loadMockData(referenceDate: Date = Date(), sessionCount: Int? = nil) {
        let now = referenceDate
        // Claude Code session - waiting
        let session1 = Session(
            name: "Fix authentication bug",
            status: .waiting,
            agentType: .claudeCode,
            startedAt: now.addingTimeInterval(-3600),
            messages: [
                Message(role: .user, content: "Fix the authentication bug in the login flow", timestamp: now.addingTimeInterval(-3600)),
                Message(role: .assistant, content: "I'll analyze the authentication code and identify the bug. Let me start by reading the relevant files.", timestamp: now.addingTimeInterval(-3590)),
                Message(role: .assistant, content: "I found the issue. The token validation is not checking for expiration properly. Let me fix this.", timestamp: now.addingTimeInterval(-3500), isStreaming: true)
            ],
            toolCalls: [
                ToolCall(name: "Read", input: "src/auth/login.ts", output: "// Login code...", startedAt: now.addingTimeInterval(-3580), completedAt: now.addingTimeInterval(-3578), status: .completed),
                ToolCall(name: "Grep", input: "validateToken", output: "Found 3 matches", startedAt: now.addingTimeInterval(-3570), completedAt: now.addingTimeInterval(-3565), status: .completed),
                ToolCall(name: "Edit", input: "src/auth/validate.ts", startedAt: now.addingTimeInterval(-3520), status: .running)
            ],
            metrics: SessionMetrics(totalTokens: 15420, inputTokens: 8200, outputTokens: 7220, toolCallCount: 3, errorCount: 0, apiCalls: 5, cost: 0.0312, modelName: "claude-sonnet-4-5-20250929")
        )

        // Codex session - completed
        let session2 = Session(
            name: "Generate unit tests",
            status: .completed,
            agentType: .codex,
            startedAt: now.addingTimeInterval(-7200),
            endedAt: now.addingTimeInterval(-5400),
            messages: [
                Message(role: .user, content: "Generate comprehensive unit tests for the UserService class", timestamp: now.addingTimeInterval(-7200)),
                Message(role: .assistant, content: "I'll analyze the UserService class and generate unit tests covering all public methods and edge cases.", timestamp: now.addingTimeInterval(-7190)),
                Message(role: .assistant, content: "Successfully generated 24 unit tests for UserService with 100% coverage of public methods.", timestamp: now.addingTimeInterval(-5400))
            ],
            toolCalls: [
                ToolCall(name: "Read", input: "src/services/UserService.ts", output: "// UserService implementation", startedAt: now.addingTimeInterval(-7180), completedAt: now.addingTimeInterval(-7175), status: .completed),
                ToolCall(name: "Write", input: "tests/UserService.test.ts", output: "Created test file", startedAt: now.addingTimeInterval(-6800), completedAt: now.addingTimeInterval(-6750), status: .completed),
                ToolCall(name: "Bash", input: "npm test -- UserService", output: "All 24 tests passed", startedAt: now.addingTimeInterval(-6700), completedAt: now.addingTimeInterval(-6650), status: .completed)
            ],
            metrics: SessionMetrics(totalTokens: 32150, inputTokens: 14200, outputTokens: 17950, toolCallCount: 5, errorCount: 0, apiCalls: 8, cost: 0.1845, modelName: "codex-mini-latest")
        )

        // Claude Code session - completed
        let session3 = Session(
            name: "Add dark mode support",
            status: .completed,
            agentType: .claudeCode,
            startedAt: now.addingTimeInterval(-10800),
            endedAt: now.addingTimeInterval(-9000),
            messages: [
                Message(role: .user, content: "Add dark mode support to the settings page", timestamp: now.addingTimeInterval(-10800)),
                Message(role: .assistant, content: "I'll implement dark mode support for the settings page. This will involve adding a theme toggle and updating the CSS variables.", timestamp: now.addingTimeInterval(-10790)),
                Message(role: .assistant, content: "Dark mode has been successfully implemented. The theme toggle is now available in settings and persists across sessions.", timestamp: now.addingTimeInterval(-9000))
            ],
            toolCalls: [
                ToolCall(name: "Read", input: "src/settings/Settings.tsx", output: "// Settings component", startedAt: now.addingTimeInterval(-10780), completedAt: now.addingTimeInterval(-10775), status: .completed),
                ToolCall(name: "Edit", input: "src/settings/Settings.tsx", output: "Added theme toggle", startedAt: now.addingTimeInterval(-10500), completedAt: now.addingTimeInterval(-10450), status: .completed),
                ToolCall(name: "Write", input: "src/styles/dark-theme.css", output: "Created dark theme styles", startedAt: now.addingTimeInterval(-10000), completedAt: now.addingTimeInterval(-9950), status: .completed)
            ],
            metrics: SessionMetrics(totalTokens: 28450, inputTokens: 12300, outputTokens: 16150, toolCallCount: 8, errorCount: 0, apiCalls: 12, cost: 0.0923, modelName: "claude-sonnet-4-5-20250929")
        )

        // Codex session - failed
        let session4 = Session(
            name: "Database migration failed",
            status: .failed,
            agentType: .codex,
            startedAt: now.addingTimeInterval(-1800),
            endedAt: now.addingTimeInterval(-1200),
            messages: [
                Message(role: .user, content: "Run the database migration for the new user schema", timestamp: now.addingTimeInterval(-1800)),
                Message(role: .assistant, content: "I'll execute the database migration. Let me first check the migration files.", timestamp: now.addingTimeInterval(-1790)),
                Message(role: .system, content: "Error: Migration failed - Foreign key constraint violation on users table", timestamp: now.addingTimeInterval(-1200))
            ],
            toolCalls: [
                ToolCall(name: "Bash", input: "npm run migrate", output: nil, startedAt: now.addingTimeInterval(-1750), completedAt: now.addingTimeInterval(-1200), status: .failed, error: "Foreign key constraint violation")
            ],
            metrics: SessionMetrics(totalTokens: 5200, inputTokens: 2100, outputTokens: 3100, toolCallCount: 1, errorCount: 1, apiCalls: 3, cost: 0.0089, modelName: "codex-mini-latest")
        )

        // Claude Code session - running
        let session5 = Session(
            name: "Code review PR #142",
            status: .running,
            agentType: .claudeCode,
            startedAt: now.addingTimeInterval(-300),
            messages: [
                Message(role: .user, content: "Review PR #142 and provide feedback", timestamp: now.addingTimeInterval(-300))
            ],
            toolCalls: [],
            metrics: SessionMetrics(totalTokens: 0, inputTokens: 0, outputTokens: 0, toolCallCount: 0, errorCount: 0, apiCalls: 0)
        )

        // Codex session - running
        let session6 = Session(
            name: "Refactor API endpoints",
            status: .running,
            agentType: .codex,
            startedAt: now.addingTimeInterval(-900),
            messages: [
                Message(role: .user, content: "Refactor the REST API endpoints to follow OpenAPI 3.0 spec", timestamp: now.addingTimeInterval(-900)),
                Message(role: .assistant, content: "I'll refactor the API endpoints to comply with OpenAPI 3.0 specification. Starting with route analysis.", timestamp: now.addingTimeInterval(-890))
            ],
            toolCalls: [
                ToolCall(name: "Glob", input: "src/routes/**/*.ts", output: "Found 12 route files", startedAt: now.addingTimeInterval(-880), completedAt: now.addingTimeInterval(-875), status: .completed),
                ToolCall(name: "Read", input: "src/routes/users.ts", startedAt: now.addingTimeInterval(-870), status: .running)
            ],
            metrics: SessionMetrics(totalTokens: 8500, inputTokens: 4200, outputTokens: 4300, toolCallCount: 2, errorCount: 0, apiCalls: 4, cost: 0.1050, modelName: "codex-mini-latest")
        )

        var baseSessions = [session1, session2, session3, session4, session5, session6]

        if let sessionCount, sessionCount > baseSessions.count {
            let extraCount = sessionCount - baseSessions.count
            for index in 0..<extraCount {
                let sequence = baseSessions.count + index + 1
                let startedAt = now.addingTimeInterval(-Double(12000 + (index * 60)))
                let endedAt = now.addingTimeInterval(-Double(9000 + (index * 60)))
                let extra = Session(
                    name: "Mock Session \(sequence)",
                    status: .completed,
                    agentType: .custom,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    messages: [],
                    toolCalls: [],
                    metrics: SessionMetrics(totalTokens: 1200, inputTokens: 600, outputTokens: 600, toolCallCount: 1, errorCount: 0, apiCalls: 1)
                )
                baseSessions.append(extra)
            }
        }

        sessions = baseSessions
        selectedSessionId = session1.id
    }

    private func mergeLoadedSession(initial: Session, current: Session, loaded: Session) -> Session {
        var merged = loaded
        merged.name = current.name
        merged.agentType = current.agentType
        merged.startedAt = current.startedAt

        let statusUpdatedInMemory = current.status != initial.status
        let processUpdatedInMemory = current.processId != initial.processId
        let endedAtUpdatedInMemory = current.endedAt != initial.endedAt
        let errorUpdatedInMemory = current.errorMessage != initial.errorMessage

        merged.status = statusUpdatedInMemory ? current.status : loaded.status
        merged.messages = mergeMessages(loaded: loaded.messages, current: current.messages)
        merged.toolCalls = mergeToolCalls(loaded: loaded.toolCalls, current: current.toolCalls)
        merged.terminalOutput = mergeTerminalOutput(loaded: loaded.terminalOutput, current: current.terminalOutput)
        merged.workingDirectory = current.workingDirectory ?? loaded.workingDirectory
        merged.processId = processUpdatedInMemory ? current.processId : loaded.processId
        merged.errorMessage = errorUpdatedInMemory ? current.errorMessage : loaded.errorMessage
        merged.endedAt = endedAtUpdatedInMemory ? current.endedAt : loaded.endedAt
        merged.metrics = current.metrics != initial.metrics ? current.metrics : loaded.metrics
        merged.isExternalProcess = current.isExternalProcess || loaded.isExternalProcess
        merged.isFullyLoaded = true
        return merged
    }

    private func mergeMessages(loaded: [Message], current: [Message]) -> [Message] {
        var mergedById = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        for message in current {
            mergedById[message.id] = message
        }
        return mergedById.values.sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp < rhs.timestamp
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func mergeToolCalls(loaded: [ToolCall], current: [ToolCall]) -> [ToolCall] {
        var mergedById = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        for toolCall in current {
            mergedById[toolCall.id] = toolCall
        }
        return mergedById.values.sorted { lhs, rhs in
            if lhs.startedAt != rhs.startedAt {
                return lhs.startedAt < rhs.startedAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func mergeTerminalOutput(loaded: Data?, current: Data?) -> Data? {
        switch (loaded, current) {
        case (nil, nil):
            return nil
        case let (loaded?, nil):
            return loaded
        case let (nil, current?):
            return current
        case let (loaded?, current?):
            if current.starts(with: loaded) {
                return current
            }
            if loaded.starts(with: current) {
                return loaded
            }
            return current
        }
    }
}

private struct DetectedAgentProcess: Hashable {
    let pid: Int32
    let agentType: AgentType
    let elapsedSeconds: Int
    let command: String
}

struct AgentProcessClassifier {
    static func detectAgentType(comm: String, args: String) -> AgentType? {
        let commHaystack = comm.lowercased()
        let fullHaystack = (comm + " " + args).lowercased()

        if matchesAgent(.codex, in: commHaystack) {
            return .codex
        }
        if matchesAgent(.claudeCode, in: commHaystack) {
            return .claudeCode
        }

        if matchesAgent(.codex, in: fullHaystack) {
            return .codex
        }
        if matchesAgent(.claudeCode, in: fullHaystack) {
            return .claudeCode
        }

        return nil
    }

    private static func matchesAgent(_ agentType: AgentType, in haystack: String) -> Bool {
        let base = URL(fileURLWithPath: agentType.executablePath).lastPathComponent.lowercased()
        let tokens = tokenize(haystack)
        var aliases = agentType.executableNames.map { $0.lowercased() }
        if !aliases.contains(base) {
            aliases.append(base)
        }

        if tokens.contains(where: { aliases.contains($0) }) {
            return true
        }
        if aliases.contains(where: { haystack.contains("/\($0)") }) {
            return true
        }
        return false
    }

    private static func tokenize(_ text: String) -> Set<String> {
        let tokens = text.lowercased().split { !$0.isLetter && !$0.isNumber }
        return Set(tokens.map(String.init))
    }
}

private final class AgentProcessDiscovery {
    func detect() async -> [DetectedAgentProcess] {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/ps")
            process.arguments = ["-axo", "pid=,etimes=,comm=,args="]

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            do {
                try process.run()
            } catch {
                return []
            }

            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                return []
            }

            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            return self.parseOutput(data)
        }.value
    }

    private func parseOutput(_ data: Data) -> [DetectedAgentProcess] {
        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }

        return output
            .split(separator: "\n")
            .compactMap { parseLine(String($0)) }
    }

    private func parseLine(_ line: String) -> DetectedAgentProcess? {
        let parts = line.split(maxSplits: 3, omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
        guard parts.count >= 3 else { return nil }

        guard let pid = Int32(parts[0]) else { return nil }
        let elapsedSeconds = Int(parts[1]) ?? 0
        let comm = String(parts[2])
        let args = parts.count > 3 ? String(parts[3]) : comm

        if let agentType = AgentProcessClassifier.detectAgentType(comm: comm, args: args) {
            return DetectedAgentProcess(pid: pid, agentType: agentType, elapsedSeconds: elapsedSeconds, command: args)
        }

        return nil
    }
}
