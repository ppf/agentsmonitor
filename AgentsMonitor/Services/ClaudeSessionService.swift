import Foundation

struct ClaudeSessionIndex: Decodable {
    let version: Int
    let entries: [ClaudeSessionEntry]
}

struct ClaudeSessionEntry: Decodable {
    let sessionId: String
    let fullPath: String
    let fileMtime: Int64
    let firstPrompt: String?
    let summary: String?
    let messageCount: Int
    let created: String
    let modified: String
    let gitBranch: String?
    let projectPath: String?
    let isSidechain: Bool

    var startDate: Date? {
        Self.parseISO8601(created)
    }

    var modifiedDate: Date? {
        Self.parseISO8601(modified)
    }

    var sessionName: String {
        if let summary, !summary.isEmpty {
            return summary
        }
        if let firstPrompt, !firstPrompt.isEmpty {
            return String(firstPrompt.prefix(80))
        }
        let shortId = String(sessionId.prefix(8))
        return "Session \(shortId)"
    }

    private static func parseISO8601(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}

actor ClaudeSessionService {
    private let fileManager = FileManager.default
    private let claudeDir: URL

    init() {
        let home = Self.realHomeDirectory()
        self.claudeDir = URL(fileURLWithPath: home).appendingPathComponent(".claude")
    }

    func discoverSessions(showAll: Bool, showSidechains: Bool) async -> [Session] {
        let projectsDir = claudeDir.appendingPathComponent("projects")
        guard fileManager.fileExists(atPath: projectsDir.path) else { return [] }

        var allEntries: [ClaudeSessionEntry] = []

        do {
            let projectDirs = try fileManager.contentsOfDirectory(
                at: projectsDir,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            for dir in projectDirs {
                let indexFile = dir.appendingPathComponent("sessions-index.json")
                guard fileManager.fileExists(atPath: indexFile.path) else { continue }

                do {
                    let data = try Data(contentsOf: indexFile)
                    let index = try JSONDecoder().decode(ClaudeSessionIndex.self, from: data)
                    allEntries.append(contentsOf: index.entries)
                } catch {
                    AppLogger.logWarning("Failed to parse \(indexFile.path): \(error.localizedDescription)", context: "ClaudeSessionService")
                }
            }
        } catch {
            AppLogger.logError(error, context: "enumerating Claude projects")
            return []
        }

        // Filter sidechains
        if !showSidechains {
            allEntries = allEntries.filter { !$0.isSidechain }
        }

        // Convert to sessions with status detection.
        // Heuristic: sessions modified within last 120s are considered active/running,
        // since we can't reliably correlate OS processes to specific sessions.
        var sessions = allEntries.compactMap { entry -> Session? in
            guard let startDate = entry.startDate else {
                AppLogger.logWarning("Skipping session \(entry.sessionId): unparseable date", context: "ClaudeSessionService")
                return nil
            }
            guard let sessionUUID = UUID(uuidString: entry.sessionId) else {
                AppLogger.logWarning("Skipping session \(entry.sessionId): invalid UUID", context: "ClaudeSessionService")
                return nil
            }

            let isRecent = isRecentlyModified(entry: entry)
            let status: SessionStatus = isRecent ? .running : .completed

            return Session(
                id: sessionUUID,
                name: entry.sessionName,
                status: status,
                agentType: .claudeCode,
                startedAt: startDate,
                endedAt: status == .completed ? entry.modifiedDate : nil,
                metrics: SessionMetrics(apiCalls: entry.messageCount),
                workingDirectory: entry.projectPath.map { URL(fileURLWithPath: $0) },
                jsonlPath: entry.fullPath,
                projectPath: entry.projectPath,
                gitBranch: entry.gitBranch,
                firstPrompt: entry.firstPrompt,
                sessionSummary: entry.summary,
                isSidechain: entry.isSidechain,
                fileMtime: entry.fileMtime
            )
        }

        // Filter: active-only unless showAll
        if !showAll {
            sessions = sessions.filter { $0.status == .running }
        }

        // Sort by most recent first
        sessions.sort { $0.startedAt > $1.startedAt }

        return sessions
    }

    private func isRecentlyModified(entry: ClaudeSessionEntry) -> Bool {
        // fileMtime is milliseconds since epoch
        let mtimeSeconds = TimeInterval(entry.fileMtime) / 1000.0
        let mtimeDate = Date(timeIntervalSince1970: mtimeSeconds)
        return Date().timeIntervalSince(mtimeDate) < 120
    }

    private static func realHomeDirectory() -> String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }
}
