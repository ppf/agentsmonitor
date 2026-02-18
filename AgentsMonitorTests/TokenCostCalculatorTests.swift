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
