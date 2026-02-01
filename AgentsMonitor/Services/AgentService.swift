import Foundation

actor AgentService {
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession.shared

    struct AgentConfig {
        var baseURL: URL
        var apiKey: String?
        var watchDirectory: String?

        static var `default`: AgentConfig {
            AgentConfig(
                baseURL: URL(string: "ws://localhost:8080")!,
                apiKey: nil,
                watchDirectory: nil
            )
        }
    }

    private var config: AgentConfig = .default

    func configure(_ config: AgentConfig) {
        self.config = config
    }

    func fetchSessions() async throws -> [Session] {
        // In production, this would fetch from the agent API
        // For now, return empty array - mock data is in SessionStore
        return []
    }

    func connect() async throws {
        guard let url = URL(string: "\(config.baseURL)/ws") else {
            throw AgentServiceError.invalidURL
        }

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        try await receiveMessages()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    private func receiveMessages() async throws {
        guard let task = webSocketTask else { return }

        while task.state == .running {
            let message = try await task.receive()
            switch message {
            case .string(let text):
                try await handleMessage(text)
            case .data(let data):
                if let text = String(data: data, encoding: .utf8) {
                    try await handleMessage(text)
                }
            @unknown default:
                break
            }
        }
    }

    private func handleMessage(_ text: String) async throws {
        // Parse incoming agent messages and emit events
        // This would integrate with the SessionStore via delegation or async streams
    }

    func sendCommand(_ command: AgentCommand) async throws {
        guard let task = webSocketTask else {
            throw AgentServiceError.notConnected
        }

        let data = try JSONEncoder().encode(command)
        guard let text = String(data: data, encoding: .utf8) else {
            throw AgentServiceError.encodingFailed
        }

        try await task.send(.string(text))
    }
}

enum AgentServiceError: LocalizedError {
    case invalidURL
    case notConnected
    case encodingFailed
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .notConnected:
            return "Not connected to agent service"
        case .encodingFailed:
            return "Failed to encode command"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        }
    }
}

struct AgentCommand: Codable {
    let type: CommandType
    let sessionId: UUID?
    let payload: String?

    enum CommandType: String, Codable {
        case pause
        case resume
        case cancel
        case retry
        case sendMessage
    }
}

struct AgentEvent: Codable {
    let type: EventType
    let sessionId: UUID
    let timestamp: Date
    let data: EventData

    enum EventType: String, Codable {
        case sessionStarted
        case sessionEnded
        case messageReceived
        case toolCallStarted
        case toolCallCompleted
        case error
    }

    enum EventData: Codable {
        case message(content: String, role: String)
        case toolCall(name: String, input: String, output: String?)
        case status(SessionStatus)
        case error(message: String)
    }
}
