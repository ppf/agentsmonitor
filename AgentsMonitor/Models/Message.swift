import Foundation

struct Message: Identifiable, Hashable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var isStreaming: Bool
    var toolUseId: UUID?

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        toolUseId: UUID? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.toolUseId = toolUseId
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum MessageRole: String, CaseIterable, Codable {
    case user = "User"
    case assistant = "Assistant"
    case system = "System"
    case tool = "Tool"

    var icon: String {
        switch self {
        case .user: return "person.fill"
        case .assistant: return "brain"
        case .system: return "gearshape.fill"
        case .tool: return "wrench.fill"
        }
    }

    var color: String {
        switch self {
        case .user: return "blue"
        case .assistant: return "purple"
        case .system: return "gray"
        case .tool: return "orange"
        }
    }
}
