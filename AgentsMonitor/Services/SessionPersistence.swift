import Foundation

/// Handles persistent storage of sessions to disk
actor SessionPersistence {
    private let fileManager: FileManager
    private let sessionsDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    nonisolated static var shared: SessionPersistence? {
        Shared.instance
    }

    private enum Shared {
        static let instance = try? SessionPersistence()
    }

    init(fileManager: FileManager = .default, sessionsDirectory: URL? = nil) throws {
        self.fileManager = fileManager
        let overrideDirectory = Self.sessionsDirectoryOverrideFromEnvironment()

        if let sessionsDirectory {
            self.sessionsDirectory = sessionsDirectory
        } else if let overrideDirectory {
            self.sessionsDirectory = overrideDirectory
        } else {
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            let appDirectory = appSupport.appendingPathComponent("AgentsMonitor")
            self.sessionsDirectory = appDirectory.appendingPathComponent("Sessions")
        }

        try fileManager.createDirectory(
            at: self.sessionsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = Self.flexibleISO8601DateDecodingStrategy

        // Skip migration when tests intentionally override the sessions directory.
        if sessionsDirectory == nil && overrideDirectory == nil {
            Self.migrateLegacySessionsIfNeeded(using: fileManager, sessionsDirectory: self.sessionsDirectory)
        }
    }

    private static func sessionsDirectoryOverrideFromEnvironment() -> URL? {
        let env = ProcessInfo.processInfo.environment
        guard let rawPath = env["AGENTS_MONITOR_SESSIONS_DIR"] else { return nil }
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: trimmed, isDirectory: true)
    }

    private static let flexibleISO8601DateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()

        if let timestamp = try? container.decode(Double.self) {
            return Date(timeIntervalSince1970: timestamp)
        }
        if let timestamp = try? container.decode(Int.self) {
            return Date(timeIntervalSince1970: TimeInterval(timestamp))
        }

        let value = try container.decode(String.self)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = fractional.date(from: trimmed) {
            return parsed
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let parsed = plain.date(from: trimmed) {
            return parsed
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected ISO8601 date string with or without fractional seconds."
        )
    }

    private func sessionFilename(for sessionId: UUID) -> String {
        "\(sessionId.uuidString.lowercased()).json"
    }

    private func sessionFileURL(for sessionId: UUID) -> URL {
        sessionsDirectory.appendingPathComponent(sessionFilename(for: sessionId))
    }

    private func matchingSessionFileURLs(for sessionId: UUID) throws -> [URL] {
        let target = sessionFilename(for: sessionId)
        let files = try fileManager.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )

        return files
            .filter { $0.pathExtension.lowercased() == "json" }
            .filter { $0.lastPathComponent.lowercased() == target }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func resolveSessionFileURL(for sessionId: UUID, renameToCanonical: Bool) throws -> URL? {
        let canonicalName = sessionFilename(for: sessionId)
        let canonicalURL = sessionsDirectory.appendingPathComponent(canonicalName)
        let matches = try matchingSessionFileURLs(for: sessionId)

        guard !matches.isEmpty else {
            return nil
        }

        if let exactCanonical = matches.first(where: { $0.lastPathComponent == canonicalName }) {
            return exactCanonical
        }

        guard let match = matches.first else {
            return nil
        }

        guard renameToCanonical else {
            return match
        }

        let temporaryURL = sessionsDirectory.appendingPathComponent(".rename-\(UUID().uuidString).json")
        do {
            try fileManager.moveItem(at: match, to: temporaryURL)
            try fileManager.moveItem(at: temporaryURL, to: canonicalURL)
            return canonicalURL
        } catch {
            if fileManager.fileExists(atPath: temporaryURL.path) {
                try? fileManager.moveItem(at: temporaryURL, to: match)
            }

            if let existingCanonical = try? matchingSessionFileURLs(for: sessionId).first(where: { $0.lastPathComponent == canonicalName }) {
                if match.path != existingCanonical.path, fileManager.fileExists(atPath: match.path) {
                    try? fileManager.removeItem(at: match)
                }
                return existingCanonical
            }

            AppLogger.logPersistenceError(error, context: "canonicalizing session filename \(match.lastPathComponent)")
            return fileManager.fileExists(atPath: match.path) ? match : nil
        }
    }

    private static func migrateLegacySessionsIfNeeded(using fileManager: FileManager, sessionsDirectory: URL) {
        let legacyDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("AgentsMonitor")
            .appendingPathComponent("Sessions")

        guard legacyDirectory.path != sessionsDirectory.path else { return }
        guard fileManager.fileExists(atPath: legacyDirectory.path) else { return }

        do {
            let legacyFiles = try fileManager.contentsOfDirectory(
                at: legacyDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            var migratedCount = 0
            for file in legacyFiles where file.pathExtension == "json" {
                let destination = sessionsDirectory.appendingPathComponent(file.lastPathComponent)
                if !fileManager.fileExists(atPath: destination.path) {
                    try fileManager.copyItem(at: file, to: destination)
                    migratedCount += 1
                }
            }

            if migratedCount > 0 {
                AppLogger.logWarning(
                    "Migrated \(migratedCount) legacy session file(s) into sandbox storage",
                    context: "SessionPersistence"
                )
            }
        } catch {
            AppLogger.logPersistenceError(error, context: "migrating legacy sessions")
        }
    }

    // MARK: - Load Sessions

    func loadSessions() async throws -> [Session] {
        let files = try fileManager.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )

        let sessions: [Session] = files
            .filter { $0.pathExtension.lowercased() == "json" }
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

    func loadSessionSummaries() async throws -> [SessionSummary] {
        let files = try fileManager.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )

        let summaries: [SessionSummary] = files
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url -> SessionSummary? in
                do {
                    let data = try Data(contentsOf: url)
                    
                    // First try to decode as SessionSummary
                    if let summary = try? decoder.decode(SessionSummary.self, from: data) {
                        return summary
                    }
                    
                    // If that fails, try to decode as full Session and convert to summary
                    if let session = try? decoder.decode(Session.self, from: data) {
                        AppLogger.logWarning("Loaded full session as summary for \(url.lastPathComponent)", context: "loadSessionSummaries")
                        return SessionSummary(
                            id: session.id,
                            name: session.name,
                            status: session.status,
                            agentType: session.agentType,
                            startedAt: session.startedAt,
                            endedAt: session.endedAt,
                            metrics: session.metrics,
                            workingDirectory: session.workingDirectory,
                            processId: session.processId,
                            errorMessage: session.errorMessage,
                            isExternalProcess: session.isExternalProcess,
                            terminalOutput: session.terminalOutput
                        )
                    }
                    
                    // If both fail, log the error
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: [],
                            debugDescription: "Could not decode as SessionSummary or Session"
                        )
                    )
                } catch {
                    AppLogger.logPersistenceError(error, context: "loading session summary from \(url.lastPathComponent)")
                    return nil
                }
            }
            .sorted { $0.startedAt > $1.startedAt }

        return summaries
    }

    func loadSession(_ sessionId: UUID) async throws -> Session? {
        guard let url = try resolveSessionFileURL(for: sessionId, renameToCanonical: true) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(Session.self, from: data)
    }

    // MARK: - Save Session

    func saveSession(_ session: Session) async throws {
        _ = try resolveSessionFileURL(for: session.id, renameToCanonical: true)
        let url = sessionFileURL(for: session.id)
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
        _ = try resolveSessionFileURL(for: sessionId, renameToCanonical: true)
        let matching = try matchingSessionFileURLs(for: sessionId)
        for url in matching {
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

        for file in files where file.pathExtension.lowercased() == "json" {
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
        case workingDirectory, processId, errorMessage, isExternalProcess
        case terminalOutput, exitCode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(SessionStatus.self, forKey: .status)
        agentType = try container.decode(AgentType.self, forKey: .agentType)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        messages = (try? container.decodeIfPresent([Message].self, forKey: .messages)) ?? []
        toolCalls = (try? container.decodeIfPresent([ToolCall].self, forKey: .toolCalls)) ?? []
        metrics = (try? container.decodeIfPresent(SessionMetrics.self, forKey: .metrics)) ?? SessionMetrics()
        workingDirectory = try decodeWorkingDirectory(from: container, forKey: .workingDirectory)
        processId = try container.decodeIfPresent(Int32.self, forKey: .processId)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        isExternalProcess = try container.decodeIfPresent(Bool.self, forKey: .isExternalProcess) ?? false
        terminalOutput = try container.decodeIfPresent(Data.self, forKey: .terminalOutput)
        exitCode = try container.decodeIfPresent(Int32.self, forKey: .exitCode)
        isFullyLoaded = true
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
        try container.encodeIfPresent(workingDirectory, forKey: .workingDirectory)
        try container.encodeIfPresent(processId, forKey: .processId)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encode(isExternalProcess, forKey: .isExternalProcess)
        try container.encodeIfPresent(terminalOutput, forKey: .terminalOutput)
        try container.encodeIfPresent(exitCode, forKey: .exitCode)
    }
}

private func decodeWorkingDirectory<K: CodingKey>(
    from container: KeyedDecodingContainer<K>,
    forKey key: K
) throws -> URL? {
    if let url = try? container.decodeIfPresent(URL.self, forKey: key) {
        return url
    }
    if let path = try? container.decodeIfPresent(String.self, forKey: key) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(fileURLWithPath: trimmed)
    }
    return nil
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
