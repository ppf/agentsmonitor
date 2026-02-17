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

    init(
        sessionId: String,
        fullPath: String,
        fileMtime: Int64,
        firstPrompt: String?,
        summary: String?,
        messageCount: Int,
        created: String,
        modified: String,
        gitBranch: String?,
        projectPath: String?,
        isSidechain: Bool
    ) {
        self.sessionId = sessionId
        self.fullPath = fullPath
        self.fileMtime = fileMtime
        self.firstPrompt = firstPrompt
        self.summary = summary
        self.messageCount = messageCount
        self.created = created
        self.modified = modified
        self.gitBranch = gitBranch
        self.projectPath = projectPath
        self.isSidechain = isSidechain
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
        var indexedIds = Set<String>()

        do {
            let projectDirs = try fileManager.contentsOfDirectory(
                at: projectsDir,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            for dir in projectDirs {
                let indexFile = dir.appendingPathComponent("sessions-index.json")
                if fileManager.fileExists(atPath: indexFile.path) {
                    do {
                        let data = try Data(contentsOf: indexFile)
                        let index = try JSONDecoder().decode(ClaudeSessionIndex.self, from: data)
                        allEntries.append(contentsOf: index.entries)
                        for entry in index.entries {
                            indexedIds.insert(entry.sessionId)
                        }
                    } catch {
                        AppLogger.logWarning("Failed to parse \(indexFile.path): \(error.localizedDescription)", context: "ClaudeSessionService")
                    }
                }

                let jsonlEntries = discoverFromJSONL(in: dir, excluding: indexedIds)
                allEntries.append(contentsOf: jsonlEntries)
                for entry in jsonlEntries {
                    indexedIds.insert(entry.sessionId)
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

    // MARK: - JSONL Fallback Discovery

    private func discoverFromJSONL(in projectDir: URL, excluding indexedIds: Set<String>) -> [ClaudeSessionEntry] {
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )
        } catch {
            return []
        }

        let jsonlFiles = contents.filter { $0.pathExtension == "jsonl" }
        var entries: [ClaudeSessionEntry] = []

        for file in jsonlFiles {
            let sessionId = file.deletingPathExtension().lastPathComponent
            guard !indexedIds.contains(sessionId) else { continue }
            guard UUID(uuidString: sessionId) != nil else { continue }

            guard let entry = parseJSONLMetadata(file: file, sessionId: sessionId, projectDir: projectDir) else {
                continue
            }
            entries.append(entry)
        }

        return entries
    }

    private func parseJSONLMetadata(file: URL, sessionId: String, projectDir: URL) -> ClaudeSessionEntry? {
        guard let handle = FileHandle(forReadingAtPath: file.path) else { return nil }
        defer { handle.closeFile() }

        guard let chunk = handle.readData(ofLength: 32_768) as Data?,
              !chunk.isEmpty else { return nil }

        guard let text = String(data: chunk, encoding: .utf8) else { return nil }

        let lines = text.components(separatedBy: "\n").prefix(30)

        var cwd: String?
        var gitBranch: String?
        var isSidechain = false
        var firstTimestamp: String?
        var firstPrompt: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let lineData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            if firstTimestamp == nil, let ts = json["timestamp"] as? String {
                firstTimestamp = ts
            }

            if cwd == nil, let c = json["cwd"] as? String {
                cwd = c
            }

            if gitBranch == nil, let b = json["gitBranch"] as? String {
                gitBranch = b
            }

            if let sc = json["isSidechain"] as? Bool, sc {
                isSidechain = true
            }

            if firstPrompt == nil, let type = json["type"] as? String, type == "user" {
                if let message = json["message"] as? [String: Any] {
                    firstPrompt = extractUserContent(from: message)
                }
            }
        }

        guard let timestamp = firstTimestamp else { return nil }

        // File mtime
        let attrs = try? fileManager.attributesOfItem(atPath: file.path)
        let mtime: Date = (attrs?[.modificationDate] as? Date) ?? Date()
        let fileMtime = Int64(mtime.timeIntervalSince1970 * 1000)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let modifiedString = isoFormatter.string(from: mtime)

        return ClaudeSessionEntry(
            sessionId: sessionId,
            fullPath: file.path,
            fileMtime: fileMtime,
            firstPrompt: firstPrompt,
            summary: nil,
            messageCount: 0,
            created: timestamp,
            modified: modifiedString,
            gitBranch: gitBranch,
            projectPath: cwd,
            isSidechain: isSidechain
        )
    }

    private func extractUserContent(from message: [String: Any]) -> String? {
        if let content = message["content"] as? String {
            return content.hasPrefix("<") ? nil : content
        }

        if let contentArray = message["content"] as? [[String: Any]] {
            for item in contentArray {
                if let text = item["text"] as? String {
                    return text.hasPrefix("<") ? nil : text
                }
            }
        }

        return nil
    }

    // MARK: - Helpers

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
