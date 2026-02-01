import Foundation

// MARK: - Protocol for Dependency Injection

protocol AgentServiceProtocol: Sendable {
    func connect() async throws
    func disconnect() async
    func sendCommand(_ command: AgentCommand) async throws
    var eventStream: AsyncStream<AgentEvent> { get async }
    var connectionState: ConnectionState { get async }
}

enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(Error)

    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected): return true
        case (.connecting, .connecting): return true
        case (.connected, .connected): return true
        case (.reconnecting(let a), .reconnecting(let b)): return a == b
        case (.failed, .failed): return true
        default: return false
        }
    }
}

// MARK: - Agent Service Implementation

actor AgentService: AgentServiceProtocol {
    // MARK: - Configuration

    struct Config: Sendable {
        var host: String
        var port: Int
        var path: String
        var useTLS: Bool
        var apiKey: String?
        var reconnectAttempts: Int
        var reconnectDelay: TimeInterval
        var pingInterval: TimeInterval

        static var `default`: Config {
            Config(
                host: "localhost",
                port: 8080,
                path: "/ws",
                useTLS: false,
                apiKey: nil,
                reconnectAttempts: 5,
                reconnectDelay: 2.0,
                pingInterval: 30.0
            )
        }

        var url: URL? {
            let scheme = useTLS ? "wss" : "ws"
            return URL(string: "\(scheme)://\(host):\(port)\(path)")
        }
    }

    // MARK: - Properties

    private var config: Config
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private var eventContinuation: AsyncStream<AgentEvent>.Continuation?
    private var _connectionState: ConnectionState = .disconnected
    private var pingTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var shouldReconnect = true

    var connectionState: ConnectionState {
        _connectionState
    }

    var eventStream: AsyncStream<AgentEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }

    // MARK: - Initialization

    init(config: Config = .default, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    // MARK: - Configuration

    func configure(_ config: Config) {
        self.config = config
    }

    func updateHost(_ host: String, port: Int) {
        config.host = host
        config.port = port
    }

    // MARK: - Connection Management

    func connect() async throws {
        guard _connectionState != .connected && _connectionState != .connecting else {
            return
        }

        shouldReconnect = true
        try await performConnect()
    }

    private func performConnect() async throws {
        guard let url = config.url else {
            throw AgentServiceError.invalidURL
        }

        _connectionState = .connecting
        AppLogger.logConnectionAttempt(host: config.host, port: String(config.port))

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        if let apiKey = config.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        // Wait for connection to establish
        do {
            try await sendPing()
            _connectionState = .connected
            AppLogger.logConnectionSuccess()

            startReceiving()
            startPingTimer()
        } catch {
            _connectionState = .failed(error)
            AppLogger.logConnectionFailed(error)
            throw AgentServiceError.connectionFailed(error.localizedDescription)
        }
    }

    func disconnect() async {
        shouldReconnect = false
        cleanup()
        _connectionState = .disconnected
        AppLogger.logDisconnection(reason: "User initiated")
    }

    private func cleanup() {
        pingTask?.cancel()
        pingTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    // MARK: - Reconnection

    private func attemptReconnect() async {
        guard shouldReconnect else { return }

        for attempt in 1...config.reconnectAttempts {
            _connectionState = .reconnecting(attempt: attempt)
            AppLogger.logWarning("Reconnection attempt \(attempt)/\(config.reconnectAttempts)", context: "WebSocket")

            let delay = config.reconnectDelay * Double(attempt)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard shouldReconnect else { return }

            do {
                try await performConnect()
                return
            } catch {
                if attempt == config.reconnectAttempts {
                    _connectionState = .failed(error)
                    eventContinuation?.yield(AgentEvent(
                        type: .error,
                        sessionId: UUID(),
                        timestamp: Date(),
                        data: .error(message: "Connection failed after \(attempt) attempts")
                    ))
                }
            }
        }
    }

    // MARK: - Receiving Messages

    private func startReceiving() {
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    private func receiveLoop() async {
        guard let task = webSocketTask else { return }

        while !Task.isCancelled && task.state == .running {
            do {
                let message = try await task.receive()
                try await handleReceivedMessage(message)
            } catch {
                if !Task.isCancelled {
                    AppLogger.logError(error, context: "WebSocket receive")
                    await attemptReconnect()
                }
                break
            }
        }
    }

    private func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message) async throws {
        let data: Data

        switch message {
        case .string(let text):
            guard let textData = text.data(using: .utf8) else { return }
            data = textData
        case .data(let messageData):
            data = messageData
        @unknown default:
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let event = try decoder.decode(AgentEvent.self, from: data)
            eventContinuation?.yield(event)
            logEvent(event)
        } catch {
            AppLogger.logError(error, context: "JSON decode")
        }
    }

    private func logEvent(_ event: AgentEvent) {
        switch event.type {
        case .sessionStarted:
            AppLogger.logSessionCreated(Session(name: "Session", status: .running))
        case .toolCallStarted:
            if case .toolCall(let name, let input, _) = event.data {
                let toolCall = ToolCall(name: name, input: input, status: .running)
                AppLogger.logToolCallStarted(toolCall, sessionId: event.sessionId)
            }
        case .error:
            if case .error(let message) = event.data {
                AppLogger.logWarning(message, context: "Agent")
            }
        default:
            break
        }
    }

    // MARK: - Sending Commands

    func sendCommand(_ command: AgentCommand) async throws {
        guard let task = webSocketTask, task.state == .running else {
            throw AgentServiceError.notConnected
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(command)
        guard let text = String(data: data, encoding: .utf8) else {
            throw AgentServiceError.encodingFailed
        }

        try await task.send(.string(text))
    }

    // MARK: - Ping/Pong

    private func startPingTimer() {
        pingTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.config.pingInterval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                do {
                    try await self.sendPing()
                } catch {
                    break
                }
            }
        }
    }

    private func sendPing() async throws {
        guard let task = webSocketTask else {
            throw AgentServiceError.notConnected
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.sendPing { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Errors

enum AgentServiceError: LocalizedError {
    case invalidURL
    case notConnected
    case encodingFailed
    case connectionFailed(String)
    case timeout

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
        case .timeout:
            return "Connection timed out"
        }
    }
}

// MARK: - Commands and Events

struct AgentCommand: Codable, Sendable {
    let type: CommandType
    let sessionId: UUID?
    let payload: String?

    enum CommandType: String, Codable, Sendable {
        case pause
        case resume
        case cancel
        case retry
        case sendMessage
        case subscribe
        case unsubscribe
    }
}

struct AgentEvent: Codable, Sendable {
    let type: EventType
    let sessionId: UUID
    let timestamp: Date
    let data: EventData

    enum EventType: String, Codable, Sendable {
        case sessionStarted
        case sessionEnded
        case sessionUpdated
        case messageReceived
        case messageStreaming
        case toolCallStarted
        case toolCallCompleted
        case toolCallFailed
        case metricsUpdated
        case error
    }

    enum EventData: Codable, Sendable {
        case session(SessionEventData)
        case message(MessageEventData)
        case toolCall(ToolCallEventData)
        case metrics(MetricsEventData)
        case status(String)
        case error(message: String)

        enum CodingKeys: String, CodingKey {
            case type, session, message, toolCall, metrics, status, error
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "session":
                self = .session(try container.decode(SessionEventData.self, forKey: .session))
            case "message":
                self = .message(try container.decode(MessageEventData.self, forKey: .message))
            case "toolCall":
                self = .toolCall(try container.decode(ToolCallEventData.self, forKey: .toolCall))
            case "metrics":
                self = .metrics(try container.decode(MetricsEventData.self, forKey: .metrics))
            case "status":
                self = .status(try container.decode(String.self, forKey: .status))
            case "error":
                self = .error(message: try container.decode(String.self, forKey: .error))
            default:
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unknown type: \(type)"))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .session(let data):
                try container.encode("session", forKey: .type)
                try container.encode(data, forKey: .session)
            case .message(let data):
                try container.encode("message", forKey: .type)
                try container.encode(data, forKey: .message)
            case .toolCall(let data):
                try container.encode("toolCall", forKey: .type)
                try container.encode(data, forKey: .toolCall)
            case .metrics(let data):
                try container.encode("metrics", forKey: .type)
                try container.encode(data, forKey: .metrics)
            case .status(let status):
                try container.encode("status", forKey: .type)
                try container.encode(status, forKey: .status)
            case .error(let message):
                try container.encode("error", forKey: .type)
                try container.encode(message, forKey: .error)
            }
        }
    }
}

// MARK: - Event Data Types

struct SessionEventData: Codable, Sendable {
    let id: UUID
    let name: String
    let status: String
    let agentType: String?
}

struct MessageEventData: Codable, Sendable {
    let id: UUID
    let role: String
    let content: String
    let isStreaming: Bool?
}

struct ToolCallEventData: Codable, Sendable {
    let id: UUID
    let name: String
    let input: String
    let output: String?
    let status: String
    let error: String?
    let duration: TimeInterval?
}

struct MetricsEventData: Codable, Sendable {
    let totalTokens: Int
    let inputTokens: Int
    let outputTokens: Int
    let toolCallCount: Int
    let apiCalls: Int
}

// MARK: - Mock Service for Testing

actor MockAgentService: AgentServiceProtocol {
    private var _connectionState: ConnectionState = .disconnected
    private var eventContinuation: AsyncStream<AgentEvent>.Continuation?
    var sentCommands: [AgentCommand] = []

    var connectionState: ConnectionState {
        _connectionState
    }

    var eventStream: AsyncStream<AgentEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }

    func connect() async throws {
        _connectionState = .connected
    }

    func disconnect() async {
        _connectionState = .disconnected
    }

    func sendCommand(_ command: AgentCommand) async throws {
        sentCommands.append(command)
    }

    func simulateEvent(_ event: AgentEvent) {
        eventContinuation?.yield(event)
    }
}
