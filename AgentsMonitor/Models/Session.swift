import Foundation

struct Session: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var status: SessionStatus
    var agentType: AgentType
    var startedAt: Date
    var endedAt: Date?
    var messages: [Message]
    var toolCalls: [ToolCall]
    var metrics: SessionMetrics

    enum CodingKeys: String, CodingKey {
        case id, name, status, agentType, startedAt, endedAt
        case messages, toolCalls, metrics
    }

    init(
        id: UUID = UUID(),
        name: String,
        status: SessionStatus = .running,
        agentType: AgentType = .claudeCode,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        messages: [Message] = [],
        toolCalls: [ToolCall] = [],
        metrics: SessionMetrics = SessionMetrics()
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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(SessionStatus.self, forKey: .status)
        agentType = try container.decode(AgentType.self, forKey: .agentType)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        messages = try container.decode([Message].self, forKey: .messages)
        toolCalls = try container.decode([ToolCall].self, forKey: .toolCalls)
        metrics = try container.decode(SessionMetrics.self, forKey: .metrics)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(status, forKey: .status)
        try container.encode(agentType, forKey: .agentType)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encode(messages, forKey: .messages)
        try container.encode(toolCalls, forKey: .toolCalls)
        try container.encode(metrics, forKey: .metrics)
    }

    var duration: TimeInterval {
        let end = endedAt ?? Date()
        return end.timeIntervalSince(startedAt)
    }

    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
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

    var color: String {
        switch self {
        case .running: return "green"
        case .paused: return "yellow"
        case .completed: return "blue"
        case .failed: return "red"
        case .waiting: return "orange"
        }
    }

    var icon: String {
        switch self {
        case .running: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .waiting: return "clock.fill"
        }
    }
}

enum AgentType: String, CaseIterable, Codable {
    case claudeCode = "Claude Code"
    case codex = "Codex"
    case gemini = "Gemini CLI"
    case custom = "Custom Agent"

    var icon: String {
        switch self {
        case .claudeCode: return "brain"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .gemini: return "sparkles"
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
        case .gemini: return "localhost"
        case .custom: return "localhost"
        }
    }

    var defaultPort: Int {
        switch self {
        case .claudeCode: return 8080
        case .codex: return 8081
        case .gemini: return 8082
        case .custom: return 9000
        }
    }

    var defaultPath: String {
        switch self {
        case .claudeCode: return "/ws/claude"
        case .codex: return "/ws/codex"
        case .gemini: return "/ws/gemini"
        case .custom: return "/ws"
        }
    }

    var color: String {
        switch self {
        case .claudeCode: return "purple"
        case .codex: return "green"
        case .gemini: return "indigo"
        case .custom: return "blue"
        }
    }
}

struct SessionMetrics: Hashable, Codable {
    var totalTokens: Int
    var inputTokens: Int
    var outputTokens: Int
    var toolCallCount: Int
    var errorCount: Int
    var apiCalls: Int

    init(
        totalTokens: Int = 0,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        toolCallCount: Int = 0,
        errorCount: Int = 0,
        apiCalls: Int = 0
    ) {
        self.totalTokens = totalTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.toolCallCount = toolCallCount
        self.errorCount = errorCount
        self.apiCalls = apiCalls
    }

    var formattedTokens: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: totalTokens)) ?? "\(totalTokens)"
    }
}
