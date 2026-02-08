import Foundation

struct Message: Identifiable, Hashable, Codable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var isStreaming: Bool
    var toolUseId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp, isStreaming, toolUseId
    }

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(MessageRole.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isStreaming = try container.decodeIfPresent(Bool.self, forKey: .isStreaming) ?? false
        toolUseId = try container.decodeIfPresent(UUID.self, forKey: .toolUseId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isStreaming, forKey: .isStreaming)
        try container.encodeIfPresent(toolUseId, forKey: .toolUseId)
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
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
