import Foundation

struct ToolCall: Identifiable, Hashable {
    let id: UUID
    let name: String
    let input: String
    var output: String?
    let startedAt: Date
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
        case let n where n.contains("glob"): return "folder.badge.gearshape"
        case let n where n.contains("web"), let n where n.contains("fetch"): return "globe"
        case let n where n.contains("git"): return "arrow.triangle.branch"
        case let n where n.contains("task"), let n where n.contains("agent"): return "cpu"
        case let n where n.contains("notebook"): return "book"
        case let n where n.contains("todo"): return "checklist"
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
