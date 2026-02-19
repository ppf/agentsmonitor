import Foundation

actor CodexSessionService {
    private let fileManager = FileManager.default
    private let codexDir: URL

    init() {
        let home = FileUtilities.realHomeDirectory()
        self.codexDir = URL(fileURLWithPath: home).appendingPathComponent(".codex")
    }

    func discoverSessions(showAll: Bool, showSidechains: Bool) async -> [Session] {
        let sessionsDir = codexDir.appendingPathComponent("sessions")
        guard fileManager.fileExists(atPath: sessionsDir.path) else { return [] }

        let dateDirs = recentDateDirectories(baseDir: sessionsDir)
        var sessions: [Session] = []

        for dateDir in dateDirs {
            guard fileManager.fileExists(atPath: dateDir.path) else { continue }

            let jsonlFiles: [URL]
            do {
                jsonlFiles = try fileManager.contentsOfDirectory(
                    at: dateDir,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: .skipsHiddenFiles
                ).filter { $0.pathExtension == "jsonl" }
            } catch {
                AppLogger.logWarning("Failed to list \(dateDir.path): \(error.localizedDescription)", context: "CodexSessionService")
                continue
            }

            for file in jsonlFiles {
                guard let session = parseSessionFile(file) else { continue }

                if !showSidechains && session.isSidechain { continue }
                if !showAll && session.status != .running { continue }

                sessions.append(session)
            }
        }

        sessions.sort { $0.startedAt > $1.startedAt }
        return sessions
    }

    private func parseSessionFile(_ fileURL: URL) -> Session? {
        guard let handle = FileHandle(forReadingAtPath: fileURL.path) else { return nil }
        defer { handle.closeFile() }

        let chunkData = handle.readData(ofLength: 16384)
        guard !chunkData.isEmpty, let chunk = String(data: chunkData, encoding: .utf8) else { return nil }

        let lines = chunk.components(separatedBy: "\n").prefix(50)

        var sessionId: String?
        var timestamp: String?
        var cwd: String?
        var gitBranch: String?
        var isSidechain = false
        var model: String?
        var firstPrompt: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { continue }

            let payload = json["payload"] as? [String: Any]

            switch type {
            case "session_meta":
                guard let p = payload else { continue }
                sessionId = p["id"] as? String
                timestamp = p["timestamp"] as? String
                cwd = p["cwd"] as? String
                if let git = p["git"] as? [String: Any] {
                    gitBranch = git["branch"] as? String
                }
                if let source = p["source"] {
                    if source is String {
                        isSidechain = (source as! String) != "cli"
                    } else {
                        isSidechain = true
                    }
                }

            case "turn_context":
                if model == nil, let p = payload {
                    model = p["model"] as? String
                }

            case "response_item":
                if firstPrompt == nil, let p = payload,
                   let role = p["role"] as? String, role == "user",
                   let content = p["content"] as? [[String: Any]] {
                    for item in content {
                        guard let itemType = item["type"] as? String, itemType == "input_text",
                              let text = item["text"] as? String else { continue }
                        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmedText.hasPrefix("<") || trimmedText.hasPrefix("#") || trimmedText.hasPrefix("You are") {
                            continue
                        }
                        firstPrompt = String(trimmedText.prefix(200))
                        break
                    }
                }

            default:
                break
            }
        }

        guard let sid = sessionId else {
            AppLogger.logWarning("No session_meta in \(fileURL.lastPathComponent)", context: "CodexSessionService")
            return nil
        }

        let uuid = UUID(uuidString: sid) ?? UUID(uuidString: normalizeToUUID(sid)) ?? UUID()

        let startDate: Date
        if let ts = timestamp {
            startDate = parseISO8601(ts) ?? Date()
        } else {
            startDate = Date()
        }

        let fileMtime = fileModificationTime(fileURL)
        let mtimeDate = Date(timeIntervalSince1970: TimeInterval(fileMtime) / 1000.0)
        let isRunning = Date().timeIntervalSince(mtimeDate) < 1800
        let status: SessionStatus = isRunning ? .running : .completed

        let shortId = String(sid.prefix(8))
        let name = firstPrompt ?? "Codex session \(shortId)"

        return Session(
            id: uuid,
            name: name,
            status: status,
            agentType: .codex,
            startedAt: startDate,
            endedAt: status == .completed ? mtimeDate : nil,
            metrics: SessionMetrics(modelName: model ?? ""),
            workingDirectory: cwd.map { URL(fileURLWithPath: $0) },
            jsonlPath: fileURL.path,
            projectPath: cwd,
            gitBranch: gitBranch,
            firstPrompt: firstPrompt,
            isSidechain: isSidechain,
            fileMtime: fileMtime
        )
    }

    private var rateLimitCache: (path: String, mtime: Date, limits: CodexRateLimits)?

    func fetchRateLimits() -> CodexRateLimits? {
        let sessionsDir = codexDir.appendingPathComponent("sessions")
        guard fileManager.fileExists(atPath: sessionsDir.path) else { return nil }

        let dateDirs = recentDateDirectories(baseDir: sessionsDir)
        var runningFile: URL?
        var runningMtime: Date = .distantPast
        var fallbackFile: URL?
        var fallbackMtime: Date = .distantPast
        let now = Date()

        for dateDir in dateDirs {
            let files: [URL]
            do {
                files = try fileManager.contentsOfDirectory(
                    at: dateDir,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: .skipsHiddenFiles
                )
            } catch {
                AppLogger.logWarning("Failed to list \(dateDir.path): \(error.localizedDescription)", context: "CodexSessionService")
                continue
            }

            for file in files where file.pathExtension == "jsonl" {
                guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                      let mtime = attrs.contentModificationDate else { continue }
                let isRunning = now.timeIntervalSince(mtime) < 1800
                if isRunning && mtime > runningMtime {
                    runningMtime = mtime
                    runningFile = file
                } else if mtime > fallbackMtime {
                    fallbackMtime = mtime
                    fallbackFile = file
                }
            }
        }

        let file: URL
        let fileMtime: Date
        if let rf = runningFile {
            file = rf; fileMtime = runningMtime
        } else if let ff = fallbackFile {
            file = ff; fileMtime = fallbackMtime
        } else {
            return nil
        }

        // Return cached result if file hasn't changed
        if let cached = rateLimitCache, cached.path == file.path, cached.mtime == fileMtime {
            return cached.limits
        }

        guard let limits = TokenCostCalculator.calculateCodex(jsonlPath: file.path)?.rateLimits else { return nil }
        rateLimitCache = (path: file.path, mtime: fileMtime, limits: limits)
        return limits
    }

    private func recentDateDirectories(baseDir: URL) -> [URL] {
        let calendar = Calendar.current
        let today = Date()
        var dirs: [URL] = []

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = components.year, let month = components.month, let day = components.day else { continue }

            let path = baseDir
                .appendingPathComponent(String(format: "%04d", year))
                .appendingPathComponent(String(format: "%02d", month))
                .appendingPathComponent(String(format: "%02d", day))
            dirs.append(path)
        }

        return dirs
    }

    private func fileModificationTime(_ url: URL) -> Int64 {
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let mtime = attrs[.modificationDate] as? Date else { return 0 }
        return Int64(mtime.timeIntervalSince1970 * 1000)
    }

    private func normalizeToUUID(_ string: String) -> String {
        let hex = string.filter { $0.isHexDigit }
        guard hex.count >= 32 else { return string }
        let chars = Array(hex.prefix(32))
        return "\(String(chars[0..<8]))-\(String(chars[8..<12]))-\(String(chars[12..<16]))-\(String(chars[16..<20]))-\(String(chars[20..<32]))"
    }

    private func parseISO8601(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

}
