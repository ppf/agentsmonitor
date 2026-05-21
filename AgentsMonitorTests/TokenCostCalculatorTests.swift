import XCTest
@testable import AgentsMonitor

final class TokenCostCalculatorCodexTests: XCTestCase {

    private func writeTempJSONL(_ lines: [String]) -> String {
        let path = NSTemporaryDirectory() + UUID().uuidString + ".jsonl"
        let content = lines.joined(separator: "\n")
        try! content.write(toFile: path, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(atPath: path) }
        return path
    }

    // MARK: - Basic Parsing

    func testCalculateCodexBasicTokens() {
        let path = writeTempJSONL([
            #"{"type":"turn_context","payload":{"model":"gpt-5.3-codex-20250415"}}"#,
            #"{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":200,"output_tokens":500}}}}"#
        ])

        let result = TokenCostCalculator.calculateCodex(jsonlPath: path)
        XCTAssertNotNil(result)

        let summary = result!.tokenSummary
        XCTAssertEqual(summary.inputTokens, 800)
        XCTAssertEqual(summary.outputTokens, 500)
        XCTAssertEqual(summary.cacheReadTokens, 200)
        XCTAssertEqual(summary.cacheWriteTokens, 0)
        XCTAssertEqual(summary.apiCalls, 1)
        XCTAssertEqual(summary.modelName, "GPT-5.3 Codex")

        // gpt-5.3-codex: $1.75/M input, $0.175/M cache read, $14/M output
        // (800/1M * 1.75) + (200/1M * 0.175) + (500/1M * 14.0)
        let expectedCost = 0.0014 + 0.000035 + 0.007
        XCTAssertEqual(summary.cost, expectedCost, accuracy: 0.0001)
    }

    func testCalculateCodexUsesLastTokenCount() {
        let path = writeTempJSONL([
            #"{"type":"turn_context","payload":{"model":"gpt-5-codex"}}"#,
            #"{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":50}}}}"#,
            #"{"type":"turn_context","payload":{"model":"gpt-5-codex"}}"#,
            #"{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":2000,"cached_input_tokens":500,"output_tokens":1000}}}}"#
        ])

        let result = TokenCostCalculator.calculateCodex(jsonlPath: path)
        XCTAssertNotNil(result)

        let summary = result!.tokenSummary
        XCTAssertEqual(summary.inputTokens, 1500)
        XCTAssertEqual(summary.outputTokens, 1000)
        XCTAssertEqual(summary.cacheReadTokens, 500)
        XCTAssertEqual(summary.apiCalls, 2)
    }

    // MARK: - Rate Limits

    func testCalculateCodexWithRateLimits() {
        let path = writeTempJSONL([
            #"{"type":"turn_context","payload":{"model":"gpt-5.1-codex-mini"}}"#,
            #"{"type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":42.5,"resets_at":1700000000},"secondary":{"used_percent":15.0,"resets_at":1700100000}},"info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":50}}}}"#
        ])

        let result = TokenCostCalculator.calculateCodex(jsonlPath: path)
        XCTAssertNotNil(result)
        XCTAssertNotNil(result!.rateLimits)

        let limits = result!.rateLimits!
        XCTAssertEqual(limits.primary.utilization, 0.425, accuracy: 0.001)
        XCTAssertEqual(limits.secondary.utilization, 0.15, accuracy: 0.001)
        XCTAssertNotNil(limits.primary.resetsAt)
        XCTAssertNotNil(limits.secondary.resetsAt)
    }

    func testRateLimitsWithMissingResetsAt() {
        let path = writeTempJSONL([
            #"{"type":"turn_context","payload":{"model":"gpt-5-codex"}}"#,
            #"{"type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":50.0},"secondary":{"used_percent":20.0}},"info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":50}}}}"#
        ])
        let result = TokenCostCalculator.calculateCodex(jsonlPath: path)
        XCTAssertNotNil(result?.rateLimits)
        XCTAssertNil(result?.rateLimits?.primary.resetsAt)
        XCTAssertEqual(result?.rateLimits?.primary.utilization ?? 0, 0.50, accuracy: 0.001)
    }

    func testRateLimitsReturnsNilWhenPartial() {
        let path = writeTempJSONL([
            #"{"type":"turn_context","payload":{"model":"gpt-5-codex"}}"#,
            #"{"type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":50.0}},"info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":50}}}}"#
        ])
        let result = TokenCostCalculator.calculateCodex(jsonlPath: path)
        XCTAssertNil(result?.rateLimits)
    }

    // MARK: - Nil Returns

    func testCalculateCodexReturnsNilForEmptyFile() {
        let path = writeTempJSONL([""])
        let result = TokenCostCalculator.calculateCodex(jsonlPath: path)
        XCTAssertNil(result)
    }

    func testCalculateCodexReturnsNilForNoTokenEvents() {
        let path = writeTempJSONL([
            #"{"type":"turn_context","payload":{"model":"gpt-5-codex"}}"#,
            #"{"type":"event_msg","payload":{"type":"something_else"}}"#
        ])
        let result = TokenCostCalculator.calculateCodex(jsonlPath: path)
        XCTAssertNil(result)
    }

    // MARK: - Model Names

    func testCalculateCodexModelName() {
        let path = writeTempJSONL([
            #"{"type":"turn_context","payload":{"model":"gpt-5.1-codex-mini-2025"}}"#,
            #"{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":50}}}}"#
        ])
        let result = TokenCostCalculator.calculateCodex(jsonlPath: path)
        XCTAssertEqual(result?.tokenSummary.modelName, "GPT-5.1 Mini")
    }

    // MARK: - Pricing Per Tier

    func testGPT5CodexPricingMatchesCorrectTier() {
        // gpt-5.3-codex: $1.75/M input
        let path53 = writeTempJSONL([
            #"{"type":"turn_context","payload":{"model":"gpt-5.3-codex-20250415"}}"#,
            #"{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000000,"cached_input_tokens":0,"output_tokens":0}}}}"#
        ])
        let result53 = TokenCostCalculator.calculateCodex(jsonlPath: path53)
        XCTAssertEqual(result53?.tokenSummary.cost ?? 0, 1.75, accuracy: 0.001)

        // gpt-5.1-codex-mini: $0.25/M input
        let path51 = writeTempJSONL([
            #"{"type":"turn_context","payload":{"model":"gpt-5.1-codex-mini-20250415"}}"#,
            #"{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000000,"cached_input_tokens":0,"output_tokens":0}}}}"#
        ])
        let result51 = TokenCostCalculator.calculateCodex(jsonlPath: path51)
        XCTAssertEqual(result51?.tokenSummary.cost ?? 0, 0.25, accuracy: 0.001)

        // gpt-5-codex: $1.25/M input (must NOT match gpt-5.3 or gpt-5.1)
        let path5 = writeTempJSONL([
            #"{"type":"turn_context","payload":{"model":"gpt-5-codex-20250415"}}"#,
            #"{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000000,"cached_input_tokens":0,"output_tokens":0}}}}"#
        ])
        let result5 = TokenCostCalculator.calculateCodex(jsonlPath: path5)
        XCTAssertEqual(result5?.tokenSummary.cost ?? 0, 1.25, accuracy: 0.001)
    }

    // MARK: - Codable Roundtrip

    func testSessionTokenSummaryCodableRoundtrip() throws {
        let original = SessionTokenSummary(
            inputTokens: 800,
            outputTokens: 500,
            cacheWriteTokens: 100,
            cacheReadTokens: 200,
            cost: 1.234,
            modelName: "GPT-5.3 Codex",
            apiCalls: 3
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SessionTokenSummary.self, from: data)
        XCTAssertEqual(decoded.inputTokens, original.inputTokens)
        XCTAssertEqual(decoded.outputTokens, original.outputTokens)
        XCTAssertEqual(decoded.cacheWriteTokens, original.cacheWriteTokens)
        XCTAssertEqual(decoded.cacheReadTokens, original.cacheReadTokens)
        XCTAssertEqual(decoded.cost, original.cost, accuracy: 0.0001)
        XCTAssertEqual(decoded.modelName, original.modelName)
        XCTAssertEqual(decoded.apiCalls, original.apiCalls)
    }

    func testCostCacheEntryCodableRoundtrip() throws {
        let entry = SessionStore.CostCacheEntry(
            mtime: 1708000000000,
            summary: SessionTokenSummary(
                inputTokens: 100, outputTokens: 50,
                cacheWriteTokens: 0, cacheReadTokens: 0,
                cost: 0.05, modelName: "Sonnet 4", apiCalls: 1
            )
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(SessionStore.CostCacheEntry.self, from: data)
        XCTAssertEqual(decoded.mtime, entry.mtime)
        XCTAssertEqual(decoded.summary.cost, entry.summary.cost, accuracy: 0.0001)
        XCTAssertEqual(decoded.summary.modelName, entry.summary.modelName)
    }
}

final class CodexSessionServiceTests: XCTestCase {
    private func makeCodexFixture() throws -> (service: CodexSessionService, dateDir: URL, tempRoot: URL) {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex_fixture_\(UUID().uuidString)", isDirectory: true)
        let codexDir = tempRoot.appendingPathComponent(".codex", isDirectory: true)
        let sessionsDir = codexDir.appendingPathComponent("sessions", isDirectory: true)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        let dateDir = sessionsDir
            .appendingPathComponent(String(format: "%04d", components.year ?? 2026), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", components.month ?? 1), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", components.day ?? 1), isDirectory: true)

        try FileManager.default.createDirectory(at: dateDir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: tempRoot) }

        return (CodexSessionService(codexDir: codexDir), dateDir, tempRoot)
    }

    func testDiscoverSessionsTreatsCodexDesktopSourceAsMainSession() async throws {
        let (service, dateDir, _) = try makeCodexFixture()

        let sessionId = "550e8400-e29b-41d4-a716-446655440000"
        let jsonl = [
            #"{"type":"session_meta","payload":{"id":"\#(sessionId)","timestamp":"2026-04-11T10:00:00.000Z","cwd":"/Users/test/project","source":"vscode","git":{"branch":"main"}}}"#,
            #"{"type":"turn_context","payload":{"model":"gpt-5.4"}}"#,
            #"{"type":"response_item","payload":{"role":"user","content":[{"type":"input_text","text":"Build the thing"}]}}"#
        ].joined(separator: "\n")
        let fileURL = dateDir.appendingPathComponent("rollout-\(sessionId).jsonl")
        try jsonl.write(to: fileURL, atomically: true, encoding: .utf8)

        let sessions = await service.discoverSessions(showAll: true, showSidechains: false)

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.agentType, .codex)
        XCTAssertFalse(sessions.first?.isSidechain ?? true)
    }

    func testDiscoverSessionsParsesLargeSessionMetaLine() async throws {
        let (service, dateDir, _) = try makeCodexFixture()

        let sessionId = "550e8400-e29b-41d4-a716-446655440010"
        let largeInstructions = String(repeating: "Codex metadata can be long. ", count: 900)
        let jsonl = [
            #"{"type":"session_meta","payload":{"id":"\#(sessionId)","timestamp":"2026-04-11T10:00:00.000Z","cwd":"/Users/test/project","source":"cli","base_instructions":{"text":"\#(largeInstructions)"}}}"#,
            #"{"type":"turn_context","payload":{"model":"gpt-5.4"}}"#,
            #"{"type":"response_item","payload":{"role":"user","content":[{"type":"input_text","text":"Measure usage"}]}}"#
        ].joined(separator: "\n")
        let fileURL = dateDir.appendingPathComponent("rollout-\(sessionId).jsonl")
        try jsonl.write(to: fileURL, atomically: true, encoding: .utf8)

        let sessions = await service.discoverSessions(showAll: true, showSidechains: false)

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.projectPath, "/Users/test/project")
        XCTAssertEqual(sessions.first?.firstPrompt, "Measure usage")
    }

    func testFetchRateLimitsIgnoresSidechainFilesWhenSidechainsAreHidden() async throws {
        let (service, dateDir, _) = try makeCodexFixture()

        let mainFile = try writeCodexSession(
            in: dateDir,
            sessionId: "550e8400-e29b-41d4-a716-446655440001",
            sourceJSON: #""vscode""#,
            usedPercent: 10,
            modifiedAt: Date().addingTimeInterval(-60)
        )
        _ = mainFile
        let sidechainFile = try writeCodexSession(
            in: dateDir,
            sessionId: "550e8400-e29b-41d4-a716-446655440002",
            sourceJSON: #"{"kind":"subagent"}"#,
            usedPercent: 90,
            modifiedAt: Date()
        )
        _ = sidechainFile

        let limits = await service.fetchRateLimits(showSidechains: false)

        XCTAssertEqual(limits?.primary.utilization ?? 0, 0.10, accuracy: 0.001)
    }

    private func writeCodexSession(
        in dateDir: URL,
        sessionId: String,
        sourceJSON: String,
        usedPercent: Int,
        modifiedAt: Date
    ) throws -> URL {
        let jsonl = [
            #"{"type":"session_meta","payload":{"id":"\#(sessionId)","timestamp":"2026-04-11T10:00:00.000Z","cwd":"/Users/test/project","source":\#(sourceJSON),"git":{"branch":"main"}}}"#,
            #"{"type":"turn_context","payload":{"model":"gpt-5.4"}}"#,
            #"{"type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":\#(usedPercent),"resets_at":1700000000},"secondary":{"used_percent":5,"resets_at":1700100000}},"info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":50}}}}"#
        ].joined(separator: "\n")
        let fileURL = dateDir.appendingPathComponent("rollout-\(sessionId).jsonl")
        try jsonl.write(to: fileURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: fileURL.path)
        return fileURL
    }
}

// MARK: - Claude Session Discovery Tests

final class ClaudeSessionServiceTests: XCTestCase {
    private func makeClaudeFixture(projectName: String = "my-project") throws -> (service: ClaudeSessionService, projectDir: URL, tempRoot: URL) {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude_fixture_\(UUID().uuidString)", isDirectory: true)
        let claudeDir = tempRoot.appendingPathComponent(".claude", isDirectory: true)
        let projectDir = claudeDir
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent(projectName, isDirectory: true)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: tempRoot) }
        return (ClaudeSessionService(claudeDir: claudeDir), projectDir, tempRoot)
    }

    func testDiscoverSessionsReadsSessionsIndex() async throws {
        let (service, projectDir, _) = try makeClaudeFixture()

        let sessionId = "12345678-1234-1234-1234-123456789abc"
        let jsonlURL = projectDir.appendingPathComponent("\(sessionId).jsonl")
        try "{}".write(to: jsonlURL, atomically: true, encoding: .utf8)
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let indexJSON = """
        {
          "version": 1,
          "entries": [{
            "sessionId": "\(sessionId)",
            "fullPath": "\(jsonlURL.path)",
            "fileMtime": \(nowMs),
            "firstPrompt": "Fix the auth bug",
            "summary": "Auth fix",
            "messageCount": 3,
            "created": "2026-04-11T10:00:00.000Z",
            "modified": "2026-04-11T10:05:00.000Z",
            "gitBranch": "main",
            "projectPath": "/Users/test/project",
            "isSidechain": false
          }]
        }
        """
        try indexJSON.write(to: projectDir.appendingPathComponent("sessions-index.json"), atomically: true, encoding: .utf8)

        let sessions = await service.discoverSessions(showAll: true, showSidechains: false)

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.name, "Auth fix")
        XCTAssertEqual(sessions.first?.agentType, .claudeCode)
        XCTAssertEqual(sessions.first?.status, .running)
        XCTAssertFalse(sessions.first?.isSidechain ?? true)
    }

    func testDiscoverSessionsExcludesSidechainsWhenDisabled() async throws {
        let (service, projectDir, _) = try makeClaudeFixture()

        let mainId = "12345678-1234-1234-1234-123456789001"
        let sideId = "12345678-1234-1234-1234-123456789002"
        let mainPath = projectDir.appendingPathComponent("\(mainId).jsonl")
        let sidePath = projectDir.appendingPathComponent("\(sideId).jsonl")
        try "{}".write(to: mainPath, atomically: true, encoding: .utf8)
        try "{}".write(to: sidePath, atomically: true, encoding: .utf8)
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let indexJSON = """
        {
          "version": 1,
          "entries": [
            {
              "sessionId": "\(mainId)",
              "fullPath": "\(mainPath.path)",
              "fileMtime": \(nowMs),
              "firstPrompt": "Main",
              "summary": "Main session",
              "messageCount": 1,
              "created": "2026-04-11T10:00:00.000Z",
              "modified": "2026-04-11T10:05:00.000Z",
              "gitBranch": null,
              "projectPath": "/Users/test",
              "isSidechain": false
            },
            {
              "sessionId": "\(sideId)",
              "fullPath": "\(sidePath.path)",
              "fileMtime": \(nowMs),
              "firstPrompt": "Side",
              "summary": "Side session",
              "messageCount": 1,
              "created": "2026-04-11T10:00:00.000Z",
              "modified": "2026-04-11T10:05:00.000Z",
              "gitBranch": null,
              "projectPath": "/Users/test",
              "isSidechain": true
            }
          ]
        }
        """
        try indexJSON.write(to: projectDir.appendingPathComponent("sessions-index.json"), atomically: true, encoding: .utf8)

        let sessions = await service.discoverSessions(showAll: true, showSidechains: false)

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.name, "Main session")
    }

    func testDiscoverSessionsRejectsPathsOutsideProjectsTree() async throws {
        let (service, projectDir, _) = try makeClaudeFixture()

        let sessionId = "12345678-1234-1234-1234-123456789099"
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let indexJSON = """
        {
          "version": 1,
          "entries": [{
            "sessionId": "\(sessionId)",
            "fullPath": "/etc/passwd",
            "fileMtime": \(nowMs),
            "firstPrompt": "Evil",
            "summary": "Should be skipped",
            "messageCount": 1,
            "created": "2026-04-11T10:00:00.000Z",
            "modified": "2026-04-11T10:05:00.000Z",
            "gitBranch": null,
            "projectPath": "/Users/test",
            "isSidechain": false
          }]
        }
        """
        try indexJSON.write(to: projectDir.appendingPathComponent("sessions-index.json"), atomically: true, encoding: .utf8)

        let sessions = await service.discoverSessions(showAll: true, showSidechains: false)

        XCTAssertTrue(sessions.isEmpty)
    }
}
