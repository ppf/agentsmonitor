import Foundation

struct ToolCall: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let input: String
    var output: String?
    let startedAt: Date
    var completedAt: Date?
    var status: ToolCallStatus
    var error: String?

    enum CodingKeys: String, CodingKey {
        case id, name, input, output, startedAt, completedAt, status, error
    }

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        input = try container.decode(String.self, forKey: .input)
        output = try container.decodeIfPresent(String.self, forKey: .output)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        status = try container.decode(ToolCallStatus.self, forKey: .status)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(input, forKey: .input)
        try container.encodeIfPresent(output, forKey: .output)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(error, forKey: .error)
    }

    var duration: TimeInterval? {
        guard let completed = completedAt else { return nil }
        return completed.timeIntervalSince(startedAt)
    }

    var formattedDuration: String {
        guard let duration = duration else { return "..." }
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        }
        return String(format: "%.2fs", duration)
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: startedAt)
    }

    var toolIcon: String {
        switch name.lowercased() {
        case let n where n.contains("read"): return "doc.text"
        case let n where n.contains("write"): return "pencil"
        case let n where n.contains("edit"): return "pencil.line"
        case let n where n.contains("bash"), let n where n.contains("shell"): return "terminal"
        case let n where n.contains("search"), let n where n.contains("grep"): return "magnifyingglass"
        case let n where n.contains("web"), let n where n.contains("fetch"): return "globe"
        case let n where n.contains("git"): return "arrow.triangle.branch"
        case let n where n.contains("task"), let n where n.contains("agent"): return "cpu"
        default: return "wrench"
        }
    }
}

enum ToolCallStatus: String, CaseIterable, Codable {
    case pending = "Pending"
    case running = "Running"
    case completed = "Completed"
    case failed = "Failed"

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .running: return "play.circle"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        }
    }

    var color: String {
        switch self {
        case .pending: return "gray"
        case .running: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        }
    }
}
