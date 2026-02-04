import Foundation

struct Message: Identifiable, Hashable {
    let id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
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
}

enum MessageRole: String, Codable, Hashable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    case tool = "tool"
}

struct ToolCall: Identifiable, Hashable {
    let id: UUID
    var name: String
    var input: String
    var output: String?
    var startedAt: Date
    var completedAt: Date?
    var status: ToolCallStatus
    var error: String?
    
    init(
        id: UUID = UUID(),
        name: String,
        input: String,
        output: String? = nil,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        status: ToolCallStatus = .running,
        error: String? = nil
    ) {
        self.id = id
        self.name = name
        self.input = input
        self.output = output
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
        self.error = error
    }
    
    var duration: TimeInterval? {
        guard let completedAt = completedAt else { return nil }
        return completedAt.timeIntervalSince(startedAt)
    }
    
    var formattedDuration: String {
        guard let duration = duration else { return "In progress..." }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "\(Int(duration))s"
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startedAt)
    }
    
    var toolIcon: String {
        switch name.lowercased() {
        case "read": return "doc.text"
        case "write": return "square.and.pencil"
        case "edit": return "pencil"
        case "bash", "shell": return "terminal"
        case "grep", "search": return "magnifyingglass"
        case "glob": return "folder"
        default: return "wrench"
        }
    }
}

enum ToolCallStatus: String, Codable, Hashable, CaseIterable {
    case running = "Running"
    case completed = "Completed"
    case failed = "Failed"
    
    var icon: String {
        switch self {
        case .running: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .running: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        }
    }
}
