import Foundation
import Darwin

struct Session: Identifiable, Hashable {
    let id: UUID
    var name: String
    var status: SessionStatus
    var agentType: AgentType
    var startedAt: Date
    var endedAt: Date?
    var messages: [Message]
    var toolCalls: [ToolCall]
    var metrics: SessionMetrics
    var workingDirectory: URL?
    var processId: Int32?
    var errorMessage: String?
    var isExternalProcess: Bool
    var isFullyLoaded: Bool
    var terminalOutput: Data?
    var exitCode: Int32?

    init(
        id: UUID = UUID(),
        name: String,
        status: SessionStatus = .running,
        agentType: AgentType = .claudeCode,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        messages: [Message] = [],
        toolCalls: [ToolCall] = [],
        metrics: SessionMetrics = SessionMetrics(),
        workingDirectory: URL? = nil,
        processId: Int32? = nil,
        errorMessage: String? = nil,
        isExternalProcess: Bool = false,
        isFullyLoaded: Bool = true,
        terminalOutput: Data? = nil,
        exitCode: Int32? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.agentType = agentType
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.messages = messages
        self.toolCalls = toolCalls
        self.metrics = metrics
        self.workingDirectory = workingDirectory
        self.processId = processId
        self.errorMessage = errorMessage
        self.isExternalProcess = isExternalProcess
        self.isFullyLoaded = isFullyLoaded
        self.terminalOutput = terminalOutput
        self.exitCode = exitCode
    }

    func duration(asOf date: Date) -> TimeInterval {
        let end = endedAt ?? date
        return end.timeIntervalSince(startedAt)
    }

    func formattedDuration(asOf date: Date) -> String {
        let interval = duration(asOf: date)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        if interval < 60 {
            formatter.allowedUnits = [.second]
        } else {
            formatter.allowedUnits = [.day, .hour, .minute]
        }
        return formatter.string(from: interval) ?? "0s"
    }

    var relativeTimeString: String {
        let interval = Date().timeIntervalSince(startedAt)
        if interval < 60 { return "just now" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        if interval < 3600 {
            formatter.allowedUnits = [.minute]
        } else if interval < 86400 {
            formatter.allowedUnits = [.hour, .minute]
        } else {
            formatter.allowedUnits = [.day, .hour]
        }
        guard let formatted = formatter.string(from: interval) else { return "just now" }
        return "\(formatted) ago"
    }

    var duration: TimeInterval {
        duration(asOf: Date())
    }

    var formattedDuration: String {
        formattedDuration(asOf: Date())
    }

    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct SessionSummary: Identifiable, Hashable, Decodable {
    let id: UUID
    let name: String
    let status: SessionStatus
    let agentType: AgentType
    let startedAt: Date
    let endedAt: Date?
    let metrics: SessionMetrics
    let workingDirectory: URL?
    let processId: Int32?
    let errorMessage: String?
    let isExternalProcess: Bool
    let terminalOutput: Data?
    let exitCode: Int32?

    // Memberwise initializer
    init(
        id: UUID,
        name: String,
        status: SessionStatus,
        agentType: AgentType,
        startedAt: Date,
        endedAt: Date? = nil,
        metrics: SessionMetrics,
        workingDirectory: URL? = nil,
        processId: Int32? = nil,
        errorMessage: String? = nil,
        isExternalProcess: Bool = false,
        terminalOutput: Data? = nil,
        exitCode: Int32? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.agentType = agentType
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.metrics = metrics
        self.workingDirectory = workingDirectory
        self.processId = processId
        self.errorMessage = errorMessage
        self.isExternalProcess = isExternalProcess
        self.terminalOutput = terminalOutput
        self.exitCode = exitCode
    }

    enum CodingKeys: String, CodingKey {
        case id, name, status, agentType, startedAt, endedAt
        case metrics, workingDirectory, processId, errorMessage, isExternalProcess
        case terminalOutput, exitCode
        // Ignored keys from full Session
        case messages, toolCalls
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(SessionStatus.self, forKey: .status)
        agentType = try container.decode(AgentType.self, forKey: .agentType)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)

        // Try to decode metrics, if it fails use default
        metrics = (try? container.decode(SessionMetrics.self, forKey: .metrics)) ?? SessionMetrics()

        workingDirectory = try decodeWorkingDirectory(from: container, forKey: .workingDirectory)
        processId = try container.decodeIfPresent(Int32.self, forKey: .processId)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        isExternalProcess = (try? container.decodeIfPresent(Bool.self, forKey: .isExternalProcess)) ?? false
        terminalOutput = try container.decodeIfPresent(Data.self, forKey: .terminalOutput)
        exitCode = try container.decodeIfPresent(Int32.self, forKey: .exitCode)

        // messages and toolCalls are ignored for summary
    }

    func toSession() -> Session {
        Session(
            id: id,
            name: name,
            status: status,
            agentType: agentType,
            startedAt: startedAt,
            endedAt: endedAt,
            messages: [],
            toolCalls: [],
            metrics: metrics,
            workingDirectory: workingDirectory,
            processId: processId,
            errorMessage: errorMessage,
            isExternalProcess: isExternalProcess,
            isFullyLoaded: false,
            terminalOutput: terminalOutput,
            exitCode: exitCode
        )
    }
}

enum SessionStatus: String, CaseIterable, Codable {
    case running = "Running"
    case paused = "Paused"
    case completed = "Completed"
    case failed = "Failed"
    case waiting = "Waiting"
    case cancelled = "Cancelled"

    var color: String {
        switch self {
        case .running: return "green"
        case .paused: return "yellow"
        case .completed: return "blue"
        case .failed: return "red"
        case .waiting: return "orange"
        case .cancelled: return "gray"
        }
    }

    var icon: String {
        switch self {
        case .running: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .waiting: return "clock.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        let normalized = Self.normalizedDecodeValue(raw)

        switch normalized {
        case "running":
            self = .running
        case "paused":
            self = .paused
        case "completed":
            self = .completed
        case "failed":
            self = .failed
        case "waiting":
            self = .waiting
        case "cancelled", "canceled":
            self = .cancelled
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid SessionStatus value: \(raw)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func normalizedDecodeValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
}

enum AgentType: String, CaseIterable, Codable {
    case claudeCode = "Claude Code"
    case codex = "Codex"
    case custom = "Custom Agent"

    var icon: String {
        switch self {
        case .claudeCode: return "brain"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .custom: return "cpu"
        }
    }

    var displayName: String {
        rawValue
    }

    var defaultHost: String {
        switch self {
        case .claudeCode: return "localhost"
        case .codex: return "localhost"
        case .custom: return "localhost"
        }
    }

    var defaultPort: Int {
        switch self {
        case .claudeCode: return 8080
        case .codex: return 8081
        case .custom: return 9000
        }
    }

    var defaultPath: String {
        switch self {
        case .claudeCode: return "/ws/claude"
        case .codex: return "/ws/codex"
        case .custom: return "/ws"
        }
    }

    var color: String {
        switch self {
        case .claudeCode: return "purple"
        case .codex: return "green"
        case .custom: return "blue"
        }
    }

    var executablePath: String {
        switch self {
        case .claudeCode: return "/usr/local/bin/claude"
        case .codex: return "/usr/local/bin/codex"
        case .custom: return "/usr/local/bin/agent"
        }
    }

    var suggestedDefaultPath: String? {
        let home = Self.realHomeDirectoryPath()
        switch self {
        case .claudeCode:
            return (home as NSString).appendingPathComponent(".local/bin/claude")
        case .codex:
            return "/opt/homebrew/bin/codex"
        case .custom:
            return nil
        }
    }

    static func seedSuggestedOverridesIfNeeded() {
        for agentType in AgentType.allCases {
            guard let suggested = agentType.suggestedDefaultPath else { continue }
            let seedKey = "agentExecutableOverrideSeeded.\(agentType.storageKey)"
            let overrideKey = "agentExecutableOverride.\(agentType.storageKey)"
            let current = UserDefaults.standard.string(forKey: overrideKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if shouldMigrateContainerOverride(current: current, suggested: suggested) {
                UserDefaults.standard.set(suggested, forKey: overrideKey)
                UserDefaults.standard.removeObject(forKey: "agentExecutableBookmark.\(agentType.storageKey)")
                UserDefaults.standard.set(true, forKey: seedKey)
                continue
            }

            if UserDefaults.standard.bool(forKey: seedKey) {
                continue
            }

            if current.isEmpty {
                UserDefaults.standard.set(suggested, forKey: overrideKey)
                UserDefaults.standard.set(true, forKey: seedKey)
            }
        }
    }

    private static func shouldMigrateContainerOverride(current: String, suggested: String) -> Bool {
        guard !current.isEmpty, current != suggested else { return false }
        if current.contains("/Library/Containers/") {
            return true
        }
        return false
    }

    private static func realHomeDirectoryPath() -> String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }

    var storageKey: String {
        switch self {
        case .claudeCode: return "claudeCode"
        case .codex: return "codex"
        case .custom: return "custom"
        }
    }

    static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    var overrideExecutablePath: String? {
        let key = "agentExecutableOverride.\(storageKey)"
        guard let value = UserDefaults.standard.string(forKey: key) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var overrideExecutableBookmarkData: Data? {
        UserDefaults.standard.data(forKey: "agentExecutableBookmark.\(storageKey)")
    }

    var executableNames: [String] {
        switch self {
        case .claudeCode:
            return ["claude", "claude-code", "claude_code"]
        case .codex:
            return ["codex", "openai-codex"]
        case .custom:
            return ["agent"]
        }
    }

    func resolvedExecutablePath() -> String? {
        if let url = overrideExecutableURL(),
           isExecutable(url: url, useSecurityScope: overrideExecutableBookmarkData != nil) {
            return url.path
        }
        return detectedExecutablePath()
    }

    func detectedExecutablePath() -> String? {
        // First, check candidate paths directly
        for path in candidateExecutablePaths() where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        // Fallback: use `which` command to find in shell PATH
        for name in executableNames {
            if let path = Self.whichExecutable(name), FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    func overrideExecutableURL() -> URL? {
        if let data = overrideExecutableBookmarkData {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                return url
            }
        }
        if let override = overrideExecutablePath {
            return URL(fileURLWithPath: override)
        }
        return nil
    }

    private func isExecutable(url: URL, useSecurityScope: Bool) -> Bool {
        if useSecurityScope && Self.isSandboxed {
            let ok = url.startAccessingSecurityScopedResource()
            defer {
                if ok {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            guard ok else { return false }
        }
        return FileManager.default.isExecutableFile(atPath: url.path)
    }

    /// Use `which` command to locate executable in shell PATH
    private static func whichExecutable(_ name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else { return nil }
            return output
        } catch {
            return nil
        }
    }

    private func candidateExecutablePaths() -> [String] {
        var paths: [String] = [executablePath]
        let envPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let envDirs = envPath.split(separator: ":").map(String.init)
        let home = FileManager.default.homeDirectoryForCurrentUser

        // Common installation directories
        let commonDirs = [
            // User local
            home.appendingPathComponent(".local/bin").path,
            home.appendingPathComponent("bin").path,
            // npm global (default and custom prefix)
            home.appendingPathComponent(".npm-global/bin").path,
            home.appendingPathComponent(".npm/bin").path,
            "/usr/local/lib/node_modules/.bin",
            // nvm (Node Version Manager)
            home.appendingPathComponent(".nvm/versions/node").path + "/*/bin",
            // fnm (Fast Node Manager)
            home.appendingPathComponent(".fnm/node-versions").path + "/*/installation/bin",
            home.appendingPathComponent("Library/Application Support/fnm/node-versions").path + "/*/installation/bin",
            // volta
            home.appendingPathComponent(".volta/bin").path,
            // Homebrew
            "/opt/homebrew/bin",
            "/usr/local/bin",
            // System
            "/usr/bin",
            "/bin",
            "/opt/local/bin",
            "/opt/homebrew/sbin",
            "/usr/local/sbin",
            "/opt/local/sbin"
        ]

        var seen = Set<String>()
        let searchDirs = (envDirs + commonDirs).filter { dir in
            guard !dir.isEmpty else { return false }
            if seen.contains(dir) { return false }
            seen.insert(dir)
            return true
        }

        for dir in searchDirs {
            // Handle glob patterns for version managers
            if dir.contains("*") {
                let expanded = Self.expandGlobPath(dir)
                for expandedDir in expanded {
                    for name in executableNames {
                        let url = URL(fileURLWithPath: expandedDir).appendingPathComponent(name)
                        paths.append(url.path)
                    }
                }
            } else {
                for name in executableNames {
                    let url = URL(fileURLWithPath: dir).appendingPathComponent(name)
                    paths.append(url.path)
                }
            }
        }
        return paths
    }

    /// Expand glob patterns like ~/.nvm/versions/node/*/bin
    private static func expandGlobPath(_ pattern: String) -> [String] {
        let parts = pattern.split(separator: "*", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return [] }

        let baseDir = String(parts[0])
        let suffix = String(parts[1])

        guard FileManager.default.fileExists(atPath: baseDir) else { return [] }

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: baseDir)
            return contents.compactMap { item -> String? in
                let full = (baseDir as NSString).appendingPathComponent(item) + suffix
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else {
                    return nil
                }
                return full
            }
        } catch {
            return []
        }
    }

    var defaultArgs: [String] {
        switch self {
        case .claudeCode: return []
        case .codex: return ["--no-alt-screen"]
        case .custom: return []
        }
    }

    var isTerminalBased: Bool {
        switch self {
        case .claudeCode, .codex: return true
        case .custom: return false
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        let normalized = Self.normalizedDecodeValue(raw)

        if let mapped = Self.decodeAliases[normalized] {
            self = mapped
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Invalid AgentType value: \(raw)"
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static let decodeAliases: [String: AgentType] = [
        "claudecode": .claudeCode,
        "claude": .claudeCode,
        "anthropicclaude": .claudeCode,
        "claudecli": .claudeCode,
        "claudecodecli": .claudeCode,
        "claudecodeagent": .claudeCode,
        "codex": .codex,
        "openaicodex": .codex,
        "openaicodexcli": .codex,
        "codexcli": .codex,
        "openaicodexagent": .codex,
        "custom": .custom,
        "customagent": .custom,
        "agent": .custom
    ]

    private static func normalizedDecodeValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
}

private func decodeWorkingDirectory<K: CodingKey>(
    from container: KeyedDecodingContainer<K>,
    forKey key: K
) throws -> URL? {
    if let url = try? container.decodeIfPresent(URL.self, forKey: key) {
        return url
    }
    if let path = try? container.decodeIfPresent(String.self, forKey: key) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(fileURLWithPath: trimmed)
    }
    return nil
}

struct SessionMetrics: Hashable, Codable {
    static let defaultContextWindowMax = 200_000

    var totalTokens: Int
    var inputTokens: Int
    var outputTokens: Int
    var toolCallCount: Int
    var errorCount: Int
    var apiCalls: Int
    var cacheReadTokens: Int
    var cacheWriteTokens: Int
    var contextWindowMax: Int
    var cost: Double
    var modelName: String

    init(
        totalTokens: Int = 0,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        toolCallCount: Int = 0,
        errorCount: Int = 0,
        apiCalls: Int = 0,
        cacheReadTokens: Int = 0,
        cacheWriteTokens: Int = 0,
        contextWindowMax: Int = defaultContextWindowMax,
        cost: Double = 0.0,
        modelName: String = ""
    ) {
        self.totalTokens = totalTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.toolCallCount = toolCallCount
        self.errorCount = errorCount
        self.apiCalls = apiCalls
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.contextWindowMax = contextWindowMax
        self.cost = cost
        self.modelName = modelName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        totalTokens = try container.decode(Int.self, forKey: .totalTokens)
        inputTokens = try container.decode(Int.self, forKey: .inputTokens)
        outputTokens = try container.decode(Int.self, forKey: .outputTokens)
        toolCallCount = try container.decode(Int.self, forKey: .toolCallCount)
        errorCount = try container.decode(Int.self, forKey: .errorCount)
        apiCalls = try container.decode(Int.self, forKey: .apiCalls)
        cacheReadTokens = (try? container.decodeIfPresent(Int.self, forKey: .cacheReadTokens)) ?? 0
        cacheWriteTokens = (try? container.decodeIfPresent(Int.self, forKey: .cacheWriteTokens)) ?? 0
        contextWindowMax = (try? container.decodeIfPresent(Int.self, forKey: .contextWindowMax)) ?? Self.defaultContextWindowMax
        cost = (try? container.decodeIfPresent(Double.self, forKey: .cost)) ?? 0.0
        modelName = (try? container.decodeIfPresent(String.self, forKey: .modelName)) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case totalTokens, inputTokens, outputTokens
        case toolCallCount, errorCount, apiCalls
        case cacheReadTokens, cacheWriteTokens
        case contextWindowMax, cost, modelName
    }

    var contextWindowUsage: Double {
        guard contextWindowMax > 0 else { return 0 }
        return min(max(Double(totalTokens) / Double(contextWindowMax), 0), 1.0)
    }

    var formattedWindowMax: String {
        contextWindowMax >= 1_000 ? "\(contextWindowMax / 1_000)K" : "\(contextWindowMax)"
    }

    var formattedRemaining: String {
        let remaining = max(contextWindowMax - totalTokens, 0)
        if remaining >= 1_000 {
            return String(format: "%.1fK", Double(remaining) / 1_000)
        }
        return "\(remaining)"
    }

    var formattedContextWindow: String {
        "\(formattedTokens) / \(formattedWindowMax)"
    }

    var formattedTokens: String {
        let total = totalTokens
        if total >= 1_000_000 {
            return String(format: "%.1fM", Double(total) / 1_000_000)
        } else if total >= 1_000 {
            return String(format: "%.1fK", Double(total) / 1_000)
        } else {
            return "\(total)"
        }
    }

    var formattedCost: String {
        cost > 0 ? String(format: "$%.4f", cost) : "--"
    }
}
