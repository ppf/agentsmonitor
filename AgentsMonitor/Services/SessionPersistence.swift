import Foundation

/// Handles persistent storage of sessions to disk
actor SessionPersistence {
    private let fileManager = FileManager.default
    private let sessionsDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    static let shared = try? SessionPersistence()

    init() throws {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let appDirectory = appSupport.appendingPathComponent("AgentsMonitor")
        sessionsDirectory = appDirectory.appendingPathComponent("Sessions")

        try fileManager.createDirectory(
            at: sessionsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Load Sessions

    func loadSessions() async throws -> [Session] {
        let files = try fileManager.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )

        let sessions: [Session] = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> Session? in
                do {
                    let data = try Data(contentsOf: url)
                    return try decoder.decode(Session.self, from: data)
                } catch {
                    AppLogger.logPersistenceError(error, context: "loading session from \(url.lastPathComponent)")
                    return nil
                }
            }
            .sorted { $0.startedAt > $1.startedAt }

        AppLogger.logPersistenceLoaded(count: sessions.count)
        return sessions
    }

    // MARK: - Save Session

    func saveSession(_ session: Session) async throws {
        let url = sessionsDirectory.appendingPathComponent("\(session.id.uuidString).json")
        let data = try encoder.encode(session)
        try data.write(to: url, options: .atomic)
        AppLogger.logPersistenceSaved(session.id)
    }

    func saveSessions(_ sessions: [Session]) async throws {
        for session in sessions {
            try await saveSession(session)
        }
    }

    // MARK: - Delete Session

    func deleteSession(_ sessionId: UUID) async throws {
        let url = sessionsDirectory.appendingPathComponent("\(sessionId.uuidString).json")
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
            AppLogger.logPersistenceDeleted(sessionId)
        }
    }

    // MARK: - Clear All Sessions

    func clearAllSessions() async throws {
        let files = try fileManager.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )

        for file in files where file.pathExtension == "json" {
            try fileManager.removeItem(at: file)
        }
    }

    // MARK: - Export

    func exportSession(_ session: Session, to url: URL) async throws {
        let data = try encoder.encode(session)
        try data.write(to: url, options: .atomic)
    }

    func exportAllSessions(to url: URL) async throws -> URL {
        let sessions = try await loadSessions()
        let data = try encoder.encode(sessions)

        let exportURL = url.appendingPathComponent("sessions-export-\(Date().ISO8601Format()).json")
        try data.write(to: exportURL, options: .atomic)
        return exportURL
    }
}

// MARK: - Session Codable Conformance

extension Session: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, status, agentType, startedAt, endedAt
        case messages, toolCalls, metrics
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
}

extension Message: Codable {
    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp, isStreaming, toolUseId
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
}

extension ToolCall: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, input, output, startedAt, completedAt, status, error
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
}

extension SessionMetrics: Codable {}
