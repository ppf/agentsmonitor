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

    // Claude session fields
    var jsonlPath: String?
    var projectPath: String?
    var gitBranch: String?
    var firstPrompt: String?
    var sessionSummary: String?
    var isSidechain: Bool = false
    var fileMtime: Int64 = 0

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
        exitCode: Int32? = nil,
        jsonlPath: String? = nil,
        projectPath: String? = nil,
        gitBranch: String? = nil,
        firstPrompt: String? = nil,
        sessionSummary: String? = nil,
        isSidechain: Bool = false,
        fileMtime: Int64 = 0
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
        self.jsonlPath = jsonlPath
        self.projectPath = projectPath
        self.gitBranch = gitBranch
        self.firstPrompt = firstPrompt
        self.sessionSummary = sessionSummary
        self.isSidechain = isSidechain
        self.fileMtime = fileMtime
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

    var shortProjectName: String? {
        guard let path = projectPath else { return nil }
        let components = path.split(separator: "/")
        if components.count >= 2 {
            return components.suffix(2).joined(separator: "/")
        }
        return components.last.map(String.init)
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

    var icon: String { "brain" }
    var displayName: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")

        switch normalized {
        case "claudecode", "claude", "anthropicclaude", "claudecli", "claudecodecli", "claudecodeagent":
            self = .claudeCode
        default:
            // Default to claudeCode for unknown types
            self = .claudeCode
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
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
