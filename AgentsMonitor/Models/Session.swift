import Foundation

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

    init(
        id: UUID = UUID(),
        name: String,
        status: SessionStatus = .running,
        agentType: AgentType = .claude,
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
    case claude = "Claude"
    case custom = "Custom Agent"

    var icon: String {
        switch self {
        case .claude: return "brain"
        case .custom: return "cpu"
        }
    }
}

struct SessionMetrics: Hashable {
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
