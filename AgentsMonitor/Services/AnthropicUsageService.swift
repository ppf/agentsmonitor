import Foundation

struct AnthropicUsage {
    let fiveHour: UsageWindow
    let sevenDay: UsageWindow
    let sevenDaySonnet: UsageWindow?
    let extraUsage: ExtraUsage?

    struct UsageWindow {
        let utilization: Double
        let resetsAt: String?
    }

    struct ExtraUsage {
        let usedCredits: Int?
        let monthlyLimit: Int?
    }
}

enum UsageServiceError: LocalizedError {
    case noCredentials
    case authExpired
    case networkError(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .noCredentials: return "No OAuth credentials found"
        case .authExpired: return "Re-auth in Claude Code"
        case .networkError(let msg): return "Network error: \(msg)"
        case .parseError(let msg): return "Parse error: \(msg)"
        }
    }
}

actor AnthropicUsageService {
    private struct OAuthCredentials {
        let accessToken: String
        let expiresAt: Int64
    }

    func fetchUsage() async throws -> AnthropicUsage {
        let credentials = try loadCredentials()

        // Check expiry (expiresAt is milliseconds since epoch)
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        if credentials.expiresAt > 0 && credentials.expiresAt < nowMs {
            throw UsageServiceError.authExpired
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageServiceError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw UsageServiceError.authExpired
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw UsageServiceError.networkError("HTTP \(httpResponse.statusCode): \(body)")
        }

        return try parseUsageResponse(data)
    }

    private func loadCredentials() throws -> OAuthCredentials {
        if let creds = loadFromKeychain() {
            return creds
        }

        if let creds = loadFromFile() {
            return creds
        }

        throw UsageServiceError.noCredentials
    }

    private func loadFromKeychain() -> OAuthCredentials? {
        // Use security CLI to avoid Keychain access dialog blocking the app
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let exitCode = process.terminationStatus
            // 44 = item not found (expected when no credential stored)
            if exitCode != 44 {
                let stderrData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
                AppLogger.logWarning("security CLI exited with code \(exitCode): \(stderrText)", context: "AnthropicUsageService")
            }
            return nil
        }

        guard let jsonString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let jsonData = jsonString.data(using: .utf8) else { return nil }

        return parseCredentialData(jsonData)
    }

    private func loadFromFile() -> OAuthCredentials? {
        let home = Self.realHomeDirectory()
        let path = (home as NSString).appendingPathComponent(".claude/.credentials.json")
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return parseCredentialData(data)
    }

    private func parseCredentialData(_ data: Data) -> OAuthCredentials? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            AppLogger.logWarning("Credential data is not valid JSON", context: "AnthropicUsageService")
            return nil
        }

        guard let oauth = json["claudeAiOauth"] as? [String: Any] else {
            AppLogger.logWarning("Credential JSON missing claudeAiOauth key", context: "AnthropicUsageService")
            return nil
        }

        guard let accessToken = oauth["accessToken"] as? String else {
            AppLogger.logWarning("OAuth data missing accessToken", context: "AnthropicUsageService")
            return nil
        }

        let expiresAt = oauth["expiresAt"] as? Int64 ?? 0
        return OAuthCredentials(accessToken: accessToken, expiresAt: expiresAt)
    }

    private func parseUsageResponse(_ data: Data) throws -> AnthropicUsage {
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw UsageServiceError.parseError("Invalid JSON: \(error.localizedDescription)")
        }

        guard let json = parsed as? [String: Any] else {
            throw UsageServiceError.parseError("JSON root is not a dictionary")
        }

        func parseWindow(_ key: String) -> AnthropicUsage.UsageWindow? {
            guard let window = json[key] as? [String: Any] else { return nil }
            let utilization = window["utilization"] as? Double ?? 0
            let resetsAt = window["resetsAt"] as? String ?? window["resets_at"] as? String
            return AnthropicUsage.UsageWindow(utilization: utilization, resetsAt: resetsAt)
        }

        func parseExtra() -> AnthropicUsage.ExtraUsage? {
            guard let extra = (json["extraUsage"] ?? json["extra_usage"]) as? [String: Any] else { return nil }
            let used = (extra["usedCredits"] ?? extra["used_credits"]) as? Int
            let limit = (extra["monthlyLimit"] ?? extra["monthly_limit"]) as? Int
            return AnthropicUsage.ExtraUsage(usedCredits: used, monthlyLimit: limit)
        }

        let fiveHour = parseWindow("fiveHour") ?? parseWindow("five_hour")
        let sevenDay = parseWindow("sevenDay") ?? parseWindow("seven_day")

        if fiveHour == nil && sevenDay == nil {
            AppLogger.logWarning("Usage response missing both fiveHour and sevenDay keys", context: "AnthropicUsageService")
        }

        let resolvedFiveHour = fiveHour ?? AnthropicUsage.UsageWindow(utilization: 0, resetsAt: nil)
        let resolvedSevenDay = sevenDay ?? AnthropicUsage.UsageWindow(utilization: 0, resetsAt: nil)
        let sevenDaySonnet = parseWindow("sevenDaySonnet") ?? parseWindow("seven_day_sonnet")

        return AnthropicUsage(
            fiveHour: resolvedFiveHour,
            sevenDay: resolvedSevenDay,
            sevenDaySonnet: sevenDaySonnet,
            extraUsage: parseExtra()
        )
    }

    private static func realHomeDirectory() -> String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }
}
