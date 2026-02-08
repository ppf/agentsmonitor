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
