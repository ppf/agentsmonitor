import XCTest
@testable import AgentsMonitor

// MARK: - SessionStore Tests

@MainActor
final class SessionStoreTests: XCTestCase {

    var store: SessionStore!

    override func setUp() async throws {
        try await super.setUp()
        let environment = AppEnvironment(
            isUITesting: false,
            isUnitTesting: true,
            mockSessionCount: nil,
            fixedNow: nil
        )
        store = SessionStore(environment: environment)
        try await Task.sleep(nanoseconds: 200_000_000)
    }

    override func tearDown() async throws {
        store = nil
        try await super.tearDown()
    }

    // MARK: - Selection Tests

    func testSelectedSessionReturnsCorrectSession() async throws {
        guard store.sessions.count >= 2 else {
            XCTFail("Need at least 2 mock sessions")
            return
        }
        let targetSession = store.sessions[1]
        store.selectedSessionId = targetSession.id
        XCTAssertEqual(store.selectedSession?.id, targetSession.id)
    }

    func testSelectedSessionReturnsNilWhenNoSelection() async throws {
        store.selectedSessionId = nil
        XCTAssertNil(store.selectedSession)
    }

    func testSetSelectedSession() async throws {
        guard store.sessions.count >= 2 else {
            XCTFail("Need at least 2 sessions")
            return
        }
        let targetSession = store.sessions[1]
        store.selectedSession = targetSession
        XCTAssertEqual(store.selectedSessionId, targetSession.id)
    }

    // MARK: - Computed Properties Tests

    func testRunningSessionsFilter() async throws {
        XCTAssertTrue(store.runningSessions.allSatisfy { $0.status == .running })
    }

    func testCompletedSessionsFilter() async throws {
        XCTAssertTrue(store.completedSessions.allSatisfy { $0.status == .completed })
    }

    func testFailedSessionsFilter() async throws {
        XCTAssertTrue(store.failedSessions.allSatisfy { $0.status == .failed })
    }

    // MARK: - Error Handling Tests

    func testClearError() async throws {
        store.error = "Some error"
        store.clearError()
        XCTAssertNil(store.error)
    }

    // MARK: - Loading State Tests

    func testInitialLoadingCompletes() async throws {
        XCTAssertFalse(store.isLoading)
    }
}

actor UsageServiceSpy: UsageServiceProviding {
    private var fetchCount = 0
    private let result: Result<AnthropicUsage, Error>

    init(result: Result<AnthropicUsage, Error>) {
        self.result = result
    }

    func fetchUsage() async throws -> AnthropicUsage {
        fetchCount += 1
        return try result.get()
    }

    func currentFetchCount() -> Int {
        fetchCount
    }
}

// MARK: - Usage Refresh Tests

@MainActor
final class SessionStoreUsageRefreshTests: XCTestCase {

    func testRefreshOnlyLoadsSessions() async throws {
        let usage = AnthropicUsage(
            fiveHour: .init(utilization: 0.25, resetsAt: nil),
            sevenDay: .init(utilization: 0.40, resetsAt: nil),
            sevenDaySonnet: nil,
            extraUsage: nil
        )
        let spy = UsageServiceSpy(result: .success(usage))
        let environment = AppEnvironment(
            isUITesting: false,
            isUnitTesting: true,
            mockSessionCount: nil,
            fixedNow: nil
        )
        let store = SessionStore(usageService: spy, environment: environment)
        try await Task.sleep(nanoseconds: 200_000_000)

        await store.refresh()

        let fetchCount = await spy.currentFetchCount()
        XCTAssertEqual(fetchCount, 0)
    }

    func testRefreshAllFetchesUsageData() async throws {
        let usage = AnthropicUsage(
            fiveHour: .init(utilization: 0.25, resetsAt: nil),
            sevenDay: .init(utilization: 0.40, resetsAt: nil),
            sevenDaySonnet: nil,
            extraUsage: nil
        )
        let spy = UsageServiceSpy(result: .success(usage))
        let environment = AppEnvironment(
            isUITesting: false,
            isUnitTesting: true,
            mockSessionCount: nil,
            fixedNow: nil
        )
        let store = SessionStore(usageService: spy, environment: environment)
        try await Task.sleep(nanoseconds: 200_000_000)

        await store.refreshAll()

        let fetchCount = await spy.currentFetchCount()
        XCTAssertEqual(fetchCount, 1)
        let utilization = store.usageData?.fiveHour.utilization
        XCTAssertNotNil(utilization)
        XCTAssertEqual(utilization ?? 0, 0.25, accuracy: 0.0001)
    }
}

// MARK: - Aggregate Stats Tests

@MainActor
final class SessionStoreAggregateTests: XCTestCase {

    var store: SessionStore!

    override func setUp() async throws {
        try await super.setUp()
        let environment = AppEnvironment(
            isUITesting: false,
            isUnitTesting: true,
            mockSessionCount: nil,
            fixedNow: nil
        )
        store = SessionStore(environment: environment)
        try await Task.sleep(nanoseconds: 200_000_000)
    }

    override func tearDown() async throws {
        store = nil
        try await super.tearDown()
    }

    func testAggregateTokensSumsAllSessions() async throws {
        let expected = store.sessions.reduce(0) { $0 + $1.metrics.totalTokens }
        XCTAssertEqual(store.aggregateTokens, expected)
        XCTAssertGreaterThan(store.aggregateTokens, 0)
    }

    func testAggregateCostSumsAllSessions() async throws {
        let expected = store.sessions.reduce(0.0) { $0 + $1.metrics.cost }
        XCTAssertEqual(store.aggregateCost, expected, accuracy: 0.0001)
        XCTAssertGreaterThan(store.aggregateCost, 0)
    }

    func testTotalRuntimeSumsAllDurations() async throws {
        XCTAssertGreaterThan(store.totalRuntime, 0)
    }

    func testAverageDurationComputesCorrectly() async throws {
        let sessionCount = store.sessions.count
        XCTAssertGreaterThan(sessionCount, 0)
        let expectedAvg = store.totalRuntime / Double(sessionCount)
        XCTAssertEqual(store.averageDuration, expectedAvg, accuracy: 0.01)
    }

    func testFormattedAggregateTokensReturnsNonEmpty() async throws {
        XCTAssertFalse(store.formattedAggregateTokens.isEmpty)
    }

    func testFormattedAggregateCostReturnsNonEmpty() async throws {
        XCTAssertFalse(store.formattedAggregateCost.isEmpty)
    }

    func testFormattedTotalRuntimeReturnsNonEmpty() async throws {
        XCTAssertFalse(store.formattedTotalRuntime.isEmpty)
    }

    func testFormattedAverageDurationReturnsNonEmpty() async throws {
        XCTAssertFalse(store.formattedAverageDuration.isEmpty)
    }

    func testAggregateCostUpdatesAfterClearAll() async throws {
        XCTAssertGreaterThan(store.aggregateCost, 0)
        store.clearAllSessions()
        XCTAssertEqual(store.aggregateCost, 0)
    }
}

// MARK: - Clear All Tests

@MainActor
final class SessionStoreClearAllTests: XCTestCase {

    var store: SessionStore!

    override func setUp() async throws {
        try await super.setUp()
        let environment = AppEnvironment(
            isUITesting: false,
            isUnitTesting: true,
            mockSessionCount: nil,
            fixedNow: nil
        )
        store = SessionStore(environment: environment)
        try await Task.sleep(nanoseconds: 200_000_000)
    }

    override func tearDown() async throws {
        store = nil
        try await super.tearDown()
    }

    func testClearAllSessions() async throws {
        XCTAssertFalse(store.sessions.isEmpty)
        store.clearAllSessions()
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertNil(store.selectedSessionId)
    }

    func testClearAllSessionsResetsAggregates() async throws {
        XCTAssertGreaterThan(store.sessions.count, 0)
        store.clearAllSessions()
        XCTAssertEqual(store.aggregateTokens, 0)
        XCTAssertEqual(store.aggregateCost, 0)
        XCTAssertEqual(store.totalRuntime, 0)
    }
}

// MARK: - Session Model Tests

final class SessionModelTests: XCTestCase {

    func testSessionDuration() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3600)
        let session = Session(name: "Test", startedAt: startDate, endedAt: endDate)
        XCTAssertEqual(session.duration, 3600, accuracy: 0.1)
    }

    func testSessionFormattedDuration() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3661)
        let session = Session(name: "Test", startedAt: startDate, endedAt: endDate)
        let formatted = session.formattedDuration
        XCTAssertTrue(formatted.contains("1") && formatted.contains("h"))
    }

    func testFormattedDurationShowsSecondsUnderOneMinute() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(45)
        let session = Session(name: "Test", startedAt: startDate, endedAt: endDate)
        let formatted = session.formattedDuration
        XCTAssertTrue(formatted.contains("s"))
        XCTAssertFalse(formatted.contains("m"))
    }

    func testFormattedDurationDropsSecondsOverOneMinute() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(90)
        let session = Session(name: "Test", startedAt: startDate, endedAt: endDate)
        let formatted = session.formattedDuration
        XCTAssertTrue(formatted.contains("m"))
        XCTAssertFalse(formatted.contains("s"))
    }

    func testFormattedDurationShowsDays() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(90_000)
        let session = Session(name: "Test", startedAt: startDate, endedAt: endDate)
        let formatted = session.formattedDuration
        XCTAssertTrue(formatted.contains("d"))
    }

    func testRelativeTimeString() {
        let session = Session(name: "Test", startedAt: Date().addingTimeInterval(-7200))
        let relative = session.relativeTimeString
        XCTAssertTrue(relative.contains("ago"))
    }

    func testRelativeTimeStringJustNow() {
        let session = Session(name: "Test", startedAt: Date())
        XCTAssertEqual(session.relativeTimeString, "just now")
    }

    func testSessionEquality() {
        let id = UUID()
        let session1 = Session(id: id, name: "Test1")
        let session2 = Session(id: id, name: "Test2")
        let session3 = Session(name: "Test1")

        XCTAssertEqual(session1, session2)
        XCTAssertNotEqual(session1, session3)
    }

    func testSessionStatusProperties() {
        XCTAssertEqual(SessionStatus.running.icon, "play.circle.fill")
        XCTAssertEqual(SessionStatus.paused.icon, "pause.circle.fill")
        XCTAssertEqual(SessionStatus.completed.icon, "checkmark.circle.fill")
        XCTAssertEqual(SessionStatus.failed.icon, "xmark.circle.fill")
        XCTAssertEqual(SessionStatus.waiting.icon, "clock.fill")
    }

    func testAgentTypeProperties() {
        XCTAssertEqual(AgentType.claudeCode.icon, "brain")
        XCTAssertEqual(AgentType.claudeCode.displayName, "Claude Code")
    }

    func testShortProjectName() {
        let session = Session(name: "Test", projectPath: "/Users/storm/Projects/myapp")
        XCTAssertEqual(session.shortProjectName, "Projects/myapp")
    }

    func testShortProjectNameNil() {
        let session = Session(name: "Test")
        XCTAssertNil(session.shortProjectName)
    }

    func testShortProjectNameSingleComponent() {
        let session = Session(name: "Test", projectPath: "/myapp")
        XCTAssertEqual(session.shortProjectName, "myapp")
    }
}

// MARK: - ToolCall Model Tests

final class ToolCallModelTests: XCTestCase {

    func testToolCallDuration() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(1.5)
        let toolCall = ToolCall(name: "Test", input: "input", startedAt: startDate, completedAt: endDate, status: .completed)
        XCTAssertEqual(toolCall.duration ?? 0, 1.5, accuracy: 0.01)
    }

    func testToolCallFormattedDurationMilliseconds() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(0.5)
        let toolCall = ToolCall(name: "Test", input: "input", startedAt: startDate, completedAt: endDate, status: .completed)
        XCTAssertTrue(toolCall.formattedDuration.contains("ms"))
    }

    func testToolCallFormattedDurationSeconds() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(2.5)
        let toolCall = ToolCall(name: "Test", input: "input", startedAt: startDate, completedAt: endDate, status: .completed)
        XCTAssertTrue(toolCall.formattedDuration.contains("s"))
        XCTAssertFalse(toolCall.formattedDuration.contains("ms"))
    }

    func testToolCallIconForReadTool() {
        let toolCall = ToolCall(name: "Read", input: "file.txt")
        XCTAssertEqual(toolCall.toolIcon, "doc.text")
    }

    func testToolCallIconForBashTool() {
        let toolCall = ToolCall(name: "Bash", input: "ls -la")
        XCTAssertEqual(toolCall.toolIcon, "terminal")
    }

    func testToolCallIconForSearchTool() {
        let toolCall = ToolCall(name: "Search", input: "query")
        XCTAssertEqual(toolCall.toolIcon, "magnifyingglass")
    }

    func testToolCallIconForWebTool() {
        let toolCall = ToolCall(name: "WebFetch", input: "https://example.com")
        XCTAssertEqual(toolCall.toolIcon, "globe")
    }

    func testToolCallIconForUnknownTool() {
        let toolCall = ToolCall(name: "CustomTool", input: "input")
        XCTAssertEqual(toolCall.toolIcon, "wrench")
    }

    func testToolCallStatusProperties() {
        XCTAssertEqual(ToolCallStatus.pending.icon, "clock")
        XCTAssertEqual(ToolCallStatus.running.icon, "play.circle")
        XCTAssertEqual(ToolCallStatus.completed.icon, "checkmark.circle")
        XCTAssertEqual(ToolCallStatus.failed.icon, "xmark.circle")
    }
}

// MARK: - Message Model Tests

final class MessageModelTests: XCTestCase {

    func testMessageRoleIcons() {
        XCTAssertEqual(MessageRole.user.icon, "person.fill")
        XCTAssertEqual(MessageRole.assistant.icon, "brain")
        XCTAssertEqual(MessageRole.system.icon, "gearshape.fill")
        XCTAssertEqual(MessageRole.tool.icon, "wrench.fill")
    }

    func testMessageRoleColors() {
        XCTAssertEqual(MessageRole.user.color, "blue")
        XCTAssertEqual(MessageRole.assistant.color, "purple")
        XCTAssertEqual(MessageRole.system.color, "gray")
        XCTAssertEqual(MessageRole.tool.color, "orange")
    }

    func testMessageFormattedTime() {
        let message = Message(role: .user, content: "Test")
        XCTAssertFalse(message.formattedTime.isEmpty)
    }

    func testMessageEquality() {
        let id = UUID()
        let message1 = Message(id: id, role: .user, content: "Test1")
        let message2 = Message(id: id, role: .assistant, content: "Test2")
        let message3 = Message(role: .user, content: "Test1")

        XCTAssertEqual(message1, message2)
        XCTAssertNotEqual(message1, message3)
    }
}

// MARK: - SessionMetrics Tests

final class SessionMetricsTests: XCTestCase {

    func testFormattedTokens() {
        let metrics = SessionMetrics(totalTokens: 1234567)
        XCTAssertEqual(metrics.formattedTokens, "1.2M")
    }

    func testMetricsEquality() {
        let metrics1 = SessionMetrics(totalTokens: 100, inputTokens: 50, outputTokens: 50)
        let metrics2 = SessionMetrics(totalTokens: 100, inputTokens: 50, outputTokens: 50)
        let metrics3 = SessionMetrics(totalTokens: 200, inputTokens: 100, outputTokens: 100)

        XCTAssertEqual(metrics1, metrics2)
        XCTAssertNotEqual(metrics1, metrics3)
    }

    func testDefaultMetrics() {
        let metrics = SessionMetrics()
        XCTAssertEqual(metrics.totalTokens, 0)
        XCTAssertEqual(metrics.inputTokens, 0)
        XCTAssertEqual(metrics.outputTokens, 0)
        XCTAssertEqual(metrics.toolCallCount, 0)
        XCTAssertEqual(metrics.errorCount, 0)
        XCTAssertEqual(metrics.apiCalls, 0)
        XCTAssertEqual(metrics.cost, 0.0)
        XCTAssertEqual(metrics.modelName, "")
    }

    func testCostAndModelName() {
        let metrics = SessionMetrics(totalTokens: 1000, cost: 0.0542, modelName: "claude-3-opus")
        XCTAssertEqual(metrics.cost, 0.0542, accuracy: 0.0001)
        XCTAssertEqual(metrics.modelName, "claude-3-opus")
    }

    func testFormattedCostPositive() {
        let metrics = SessionMetrics(cost: 0.0542)
        XCTAssertEqual(metrics.formattedCost, "$0.0542")
    }

    func testFormattedCostZero() {
        let metrics = SessionMetrics(cost: 0.0)
        XCTAssertEqual(metrics.formattedCost, "--")
    }

    func testCostDecodesFromJSON() throws {
        let json = """
        {"totalTokens":100,"inputTokens":50,"outputTokens":50,"toolCallCount":1,"errorCount":0,"apiCalls":1,"cost":0.123,"modelName":"gpt-4"}
        """
        let data = Data(json.utf8)
        let metrics = try JSONDecoder().decode(SessionMetrics.self, from: data)
        XCTAssertEqual(metrics.cost, 0.123, accuracy: 0.0001)
        XCTAssertEqual(metrics.modelName, "gpt-4")
    }

    func testCostDefaultsWhenMissingFromJSON() throws {
        let json = """
        {"totalTokens":100,"inputTokens":50,"outputTokens":50,"toolCallCount":1,"errorCount":0,"apiCalls":1}
        """
        let data = Data(json.utf8)
        let metrics = try JSONDecoder().decode(SessionMetrics.self, from: data)
        XCTAssertEqual(metrics.cost, 0.0)
        XCTAssertEqual(metrics.modelName, "")
    }

    func testContextWindowDefaults() {
        let metrics = SessionMetrics()
        XCTAssertEqual(metrics.contextWindowMax, SessionMetrics.defaultContextWindowMax)
        XCTAssertEqual(metrics.contextWindowUsage, 0)
    }

    func testContextWindowUsage() {
        let metrics = SessionMetrics(totalTokens: 100_000, contextWindowMax: 200_000)
        XCTAssertEqual(metrics.contextWindowUsage, 0.5, accuracy: 0.001)
    }

    func testContextWindowUsageZeroMax() {
        let metrics = SessionMetrics(totalTokens: 100, contextWindowMax: 0)
        XCTAssertEqual(metrics.contextWindowUsage, 0)
    }

    func testContextWindowUsageClampedToOne() {
        let metrics = SessionMetrics(totalTokens: 300_000, contextWindowMax: 200_000)
        XCTAssertEqual(metrics.contextWindowUsage, 1.0)
    }

    func testFormattedContextWindow() {
        let metrics = SessionMetrics(totalTokens: 50_000, contextWindowMax: 200_000)
        XCTAssertEqual(metrics.formattedContextWindow, "50.0K / 200K")
    }

    func testSessionMetricsDecodesWithoutContextWindowMax() throws {
        let json = """
        {"totalTokens":100,"inputTokens":50,"outputTokens":50,"toolCallCount":1,"errorCount":0,"apiCalls":1}
        """
        let data = Data(json.utf8)
        let metrics = try JSONDecoder().decode(SessionMetrics.self, from: data)
        XCTAssertEqual(metrics.contextWindowMax, SessionMetrics.defaultContextWindowMax)
    }
}

// MARK: - AgentType Decoding Tests

final class AgentTypeDecodingTests: XCTestCase {
    private struct AgentTypeContainer: Decodable {
        let agentType: AgentType
    }

    private struct SessionStatusContainer: Decodable {
        let status: SessionStatus
    }

    func testAgentTypeDecodingVariants() throws {
        let cases: [(String, AgentType)] = [
            ("ClaudeCode", .claudeCode),
            ("claudeCode", .claudeCode),
            ("Claude Code", .claudeCode),
            ("claude_code", .claudeCode),
            ("claude-code", .claudeCode),
            ("claude", .claudeCode),
        ]

        let decoder = JSONDecoder()
        for (rawValue, expected) in cases {
            let data = Data(#"{"agentType":"\#(rawValue)"}"#.utf8)
            let decoded = try decoder.decode(AgentTypeContainer.self, from: data)
            XCTAssertEqual(decoded.agentType, expected, "Expected \(rawValue) to decode as \(expected)")
        }
    }

    func testSessionStatusVariantDecodingVariants() throws {
        let cases: [(String, SessionStatus)] = [
            ("running", .running),
            ("paused", .paused),
            ("completed", .completed),
            ("failed", .failed),
            ("waiting", .waiting),
            ("cancelled", .cancelled),
            ("canceled", .cancelled)
        ]

        let decoder = JSONDecoder()
        for (rawValue, expected) in cases {
            let data = Data(#"{"status":"\#(rawValue)"}"#.utf8)
            let decoded = try decoder.decode(SessionStatusContainer.self, from: data)
            XCTAssertEqual(decoded.status, expected, "Expected \(rawValue) to decode as \(expected)")
        }
    }
}

// MARK: - TokenCostCalculator Tests

final class TokenCostCalculatorTests: XCTestCase {

    func testFormatModelName() {
        // Test via calculate with known model patterns
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_calc_\(UUID().uuidString).jsonl")

        let jsonl = """
        {"type":"assistant","message":{"model":"claude-sonnet-4-5-20250929","usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
        """

        try? jsonl.data(using: .utf8)?.write(to: testFile)
        defer { try? FileManager.default.removeItem(at: testFile) }

        let summary = TokenCostCalculator.calculate(jsonlPath: testFile.path)
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.modelName, "Sonnet 4")
        XCTAssertEqual(summary?.inputTokens, 100)
        XCTAssertEqual(summary?.outputTokens, 50)
        XCTAssertEqual(summary?.apiCalls, 1)
    }

    func testCostCalculation() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_cost_\(UUID().uuidString).jsonl")

        // 1M input tokens at sonnet pricing = $3
        let jsonl = """
        {"type":"assistant","message":{"model":"claude-sonnet-4-5-20250929","usage":{"input_tokens":1000000,"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
        """

        try? jsonl.data(using: .utf8)?.write(to: testFile)
        defer { try? FileManager.default.removeItem(at: testFile) }

        let summary = TokenCostCalculator.calculate(jsonlPath: testFile.path)
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.cost ?? 0, 3.0, accuracy: 0.001)
    }

    func testNonExistentFileReturnsNil() {
        let summary = TokenCostCalculator.calculate(jsonlPath: "/nonexistent/path.jsonl")
        XCTAssertNil(summary)
    }

    func testMultipleAssistantMessages() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_multi_\(UUID().uuidString).jsonl")

        let jsonl = [
            #"{"type":"assistant","message":{"model":"claude-sonnet-4-5-20250929","usage":{"input_tokens":200,"output_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}"#,
            #"{"type":"assistant","message":{"model":"claude-sonnet-4-5-20250929","usage":{"input_tokens":300,"output_tokens":150,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}"#,
            #"{"type":"assistant","message":{"model":"claude-sonnet-4-5-20250929","usage":{"input_tokens":500,"output_tokens":250,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}"#,
        ].joined(separator: "\n")

        try? jsonl.data(using: .utf8)?.write(to: testFile)
        defer { try? FileManager.default.removeItem(at: testFile) }

        let summary = TokenCostCalculator.calculate(jsonlPath: testFile.path)
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.inputTokens, 1000)
        XCTAssertEqual(summary?.outputTokens, 500)
        XCTAssertEqual(summary?.apiCalls, 3)
    }

    func testMixedModelsArePricedPerModel() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_mixed_\(UUID().uuidString).jsonl")

        let jsonl = [
            #"{"type":"assistant","message":{"model":"claude-sonnet-4-5-20250929","usage":{"input_tokens":1000000,"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}"#,
            #"{"type":"assistant","message":{"model":"claude-opus-4-20250929","usage":{"input_tokens":1000000,"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}"#,
            #"{"type":"assistant","message":{"model":"claude-sonnet-4-5-20250929","usage":{"input_tokens":0,"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}"#,
        ].joined(separator: "\n")

        try? jsonl.data(using: .utf8)?.write(to: testFile)
        defer { try? FileManager.default.removeItem(at: testFile) }

        let summary = TokenCostCalculator.calculate(jsonlPath: testFile.path)
        XCTAssertNotNil(summary)
        // Sonnet 1M input ($3) + Opus 1M input ($15) = $18
        XCTAssertEqual(summary?.cost ?? 0, 18.0, accuracy: 0.001)
    }

    func testUnknownModelFallsBackToSonnetPricing() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_unknown_\(UUID().uuidString).jsonl")

        // 1M input tokens with unknown model → fallback to Sonnet pricing = $3
        let jsonl = """
        {"type":"assistant","message":{"model":"some-future-model-2026","usage":{"input_tokens":1000000,"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
        """

        try? jsonl.data(using: .utf8)?.write(to: testFile)
        defer { try? FileManager.default.removeItem(at: testFile) }

        let summary = TokenCostCalculator.calculate(jsonlPath: testFile.path)
        XCTAssertNotNil(summary)
        // Unknown model name returned as-is
        XCTAssertEqual(summary?.modelName, "some-future-model-2026")
        // Fallback to Sonnet pricing: 1M input * $3/M = $3
        XCTAssertEqual(summary?.cost ?? 0, 3.0, accuracy: 0.001)
    }

    func testEmptyFileReturnsNil() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_empty_\(UUID().uuidString).jsonl")

        // File with content but no valid assistant messages
        let jsonl = [
            #"{"type":"user","message":{"content":"hello"}}"#,
            #"{"type":"system","message":{"content":"system prompt"}}"#,
        ].joined(separator: "\n")

        try? jsonl.data(using: .utf8)?.write(to: testFile)
        defer { try? FileManager.default.removeItem(at: testFile) }

        let summary = TokenCostCalculator.calculate(jsonlPath: testFile.path)
        // Returns a summary with zero tokens/cost since file exists but no assistant messages
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.inputTokens, 0)
        XCTAssertEqual(summary?.outputTokens, 0)
        XCTAssertEqual(summary?.apiCalls, 0)
        XCTAssertEqual(summary?.cost ?? 0, 0, accuracy: 0.0001)
    }

    func testCacheTokensInCostCalculation() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_cache_\(UUID().uuidString).jsonl")

        // Opus pricing: cache_write=$18.75/M, cache_read=$1.50/M
        let jsonl = """
        {"type":"assistant","message":{"model":"claude-opus-4-20250929","usage":{"input_tokens":0,"output_tokens":0,"cache_creation_input_tokens":1000000,"cache_read_input_tokens":1000000}}}
        """

        try? jsonl.data(using: .utf8)?.write(to: testFile)
        defer { try? FileManager.default.removeItem(at: testFile) }

        let summary = TokenCostCalculator.calculate(jsonlPath: testFile.path)
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.cacheWriteTokens, 1_000_000)
        XCTAssertEqual(summary?.cacheReadTokens, 1_000_000)
        // Cost: 1M cache_write * $18.75/M + 1M cache_read * $1.50/M = $20.25
        XCTAssertEqual(summary?.cost ?? 0, 20.25, accuracy: 0.001)
    }
}

// MARK: - ClaudeSessionEntry Tests

final class ClaudeSessionEntryTests: XCTestCase {

    private func makeEntryJSON(
        sessionId: String = "550e8400-e29b-41d4-a716-446655440000",
        fullPath: String = "/tmp/test.jsonl",
        fileMtime: Int64 = 1708000000000,
        firstPrompt: String? = "Fix the bug",
        summary: String? = "Bug fix session",
        messageCount: Int = 10,
        created: String = "2024-02-15T10:00:00.000Z",
        modified: String = "2024-02-15T11:00:00.000Z",
        gitBranch: String? = "main",
        projectPath: String? = "/Users/test/project",
        isSidechain: Bool = false
    ) -> Data {
        var dict: [String: Any] = [
            "sessionId": sessionId,
            "fullPath": fullPath,
            "fileMtime": fileMtime,
            "messageCount": messageCount,
            "created": created,
            "modified": modified,
            "isSidechain": isSidechain,
        ]
        if let firstPrompt { dict["firstPrompt"] = firstPrompt }
        if let summary { dict["summary"] = summary }
        if let gitBranch { dict["gitBranch"] = gitBranch }
        if let projectPath { dict["projectPath"] = projectPath }
        return try! JSONSerialization.data(withJSONObject: dict)
    }

    // MARK: - sessionName fallback

    func testSessionNameReturnsSummaryWhenPresent() throws {
        let data = makeEntryJSON(firstPrompt: "My prompt", summary: "My summary")
        let entry = try JSONDecoder().decode(ClaudeSessionEntry.self, from: data)
        XCTAssertEqual(entry.sessionName, "My summary")
    }

    func testSessionNameFallsBackToFirstPrompt() throws {
        let data = makeEntryJSON(firstPrompt: "My prompt", summary: nil)
        let entry = try JSONDecoder().decode(ClaudeSessionEntry.self, from: data)
        XCTAssertEqual(entry.sessionName, "My prompt")
    }

    func testSessionNameTruncatesFirstPromptAt80Chars() throws {
        let longPrompt = String(repeating: "a", count: 120)
        let data = makeEntryJSON(firstPrompt: longPrompt, summary: nil)
        let entry = try JSONDecoder().decode(ClaudeSessionEntry.self, from: data)
        XCTAssertEqual(entry.sessionName.count, 80)
        XCTAssertEqual(entry.sessionName, String(repeating: "a", count: 80))
    }

    func testSessionNameFallsBackToShortId() throws {
        let data = makeEntryJSON(
            sessionId: "550e8400-e29b-41d4-a716-446655440000",
            firstPrompt: nil,
            summary: nil
        )
        let entry = try JSONDecoder().decode(ClaudeSessionEntry.self, from: data)
        XCTAssertEqual(entry.sessionName, "Session 550e8400")
    }

    func testSessionNameSkipsEmptySummary() throws {
        let data = makeEntryJSON(firstPrompt: "Fallback prompt", summary: "")
        let entry = try JSONDecoder().decode(ClaudeSessionEntry.self, from: data)
        XCTAssertEqual(entry.sessionName, "Fallback prompt")
    }

    func testSessionNameSkipsEmptyFirstPrompt() throws {
        let data = makeEntryJSON(
            sessionId: "abcdef01-0000-0000-0000-000000000000",
            firstPrompt: "",
            summary: ""
        )
        let entry = try JSONDecoder().decode(ClaudeSessionEntry.self, from: data)
        XCTAssertEqual(entry.sessionName, "Session abcdef01")
    }

    // MARK: - Date parsing

    func testStartDateParsingWithFractionalSeconds() throws {
        let data = makeEntryJSON(created: "2024-02-15T10:30:45.123Z")
        let entry = try JSONDecoder().decode(ClaudeSessionEntry.self, from: data)
        XCTAssertNotNil(entry.startDate)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: entry.startDate!)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 30)
        XCTAssertEqual(components.second, 45)
    }

    func testStartDateParsingWithoutFractionalSeconds() throws {
        let data = makeEntryJSON(created: "2024-02-15T10:30:45Z")
        let entry = try JSONDecoder().decode(ClaudeSessionEntry.self, from: data)
        XCTAssertNotNil(entry.startDate)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: entry.startDate!)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 10)
    }

    func testStartDateReturnsNilForInvalidString() throws {
        let data = makeEntryJSON(created: "not-a-date")
        let entry = try JSONDecoder().decode(ClaudeSessionEntry.self, from: data)
        XCTAssertNil(entry.startDate)
    }

    func testModifiedDateParsing() throws {
        let data = makeEntryJSON(modified: "2024-06-20T14:00:00.500Z")
        let entry = try JSONDecoder().decode(ClaudeSessionEntry.self, from: data)
        XCTAssertNotNil(entry.modifiedDate)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: entry.modifiedDate!)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 20)
    }

    // MARK: - Decodable

    func testDecodableFromValidJSON() throws {
        let data = makeEntryJSON(
            sessionId: "12345678-1234-1234-1234-123456789abc",
            fullPath: "/home/user/.claude/sessions/test.jsonl",
            fileMtime: 1700000000000,
            firstPrompt: "Write tests",
            summary: "Testing session",
            messageCount: 42,
            created: "2024-01-01T00:00:00.000Z",
            modified: "2024-01-01T01:00:00.000Z",
            gitBranch: "feature/tests",
            projectPath: "/Users/dev/myproject",
            isSidechain: false
        )
        let entry = try JSONDecoder().decode(ClaudeSessionEntry.self, from: data)

        XCTAssertEqual(entry.sessionId, "12345678-1234-1234-1234-123456789abc")
        XCTAssertEqual(entry.fullPath, "/home/user/.claude/sessions/test.jsonl")
        XCTAssertEqual(entry.fileMtime, 1700000000000)
        XCTAssertEqual(entry.firstPrompt, "Write tests")
        XCTAssertEqual(entry.summary, "Testing session")
        XCTAssertEqual(entry.messageCount, 42)
        XCTAssertEqual(entry.created, "2024-01-01T00:00:00.000Z")
        XCTAssertEqual(entry.modified, "2024-01-01T01:00:00.000Z")
        XCTAssertEqual(entry.gitBranch, "feature/tests")
        XCTAssertEqual(entry.projectPath, "/Users/dev/myproject")
        XCTAssertEqual(entry.isSidechain, false)
    }

    // MARK: - isSidechain

    func testIsSidechainTrue() throws {
        let data = makeEntryJSON(isSidechain: true)
        let entry = try JSONDecoder().decode(ClaudeSessionEntry.self, from: data)
        XCTAssertTrue(entry.isSidechain)
    }

    func testIsSidechainFalse() throws {
        let data = makeEntryJSON(isSidechain: false)
        let entry = try JSONDecoder().decode(ClaudeSessionEntry.self, from: data)
        XCTAssertFalse(entry.isSidechain)
    }
}

// MARK: - AnthropicUsage Parsing Tests

final class AnthropicUsageParsingTests: XCTestCase {

    func testErrorDescriptionNoCredentials() {
        let error = UsageServiceError.noCredentials
        XCTAssertEqual(error.errorDescription, "No OAuth credentials found")
    }

    func testErrorDescriptionAuthExpired() {
        let error = UsageServiceError.authExpired
        XCTAssertEqual(error.errorDescription, "Re-auth in Claude Code")
    }

    func testErrorDescriptionNetworkError() {
        let error = UsageServiceError.networkError("timeout")
        XCTAssertEqual(error.errorDescription, "Network error: timeout")
    }

    func testErrorDescriptionParseError() {
        let error = UsageServiceError.parseError("invalid JSON")
        XCTAssertEqual(error.errorDescription, "Parse error: invalid JSON")
    }

    func testUsageWindowConstruction() {
        let usage = AnthropicUsage(
            fiveHour: .init(utilization: 0.5, resetsAt: "2024-01-01T00:00:00Z"),
            sevenDay: .init(utilization: 0.8, resetsAt: nil),
            sevenDaySonnet: nil,
            extraUsage: nil
        )
        XCTAssertEqual(usage.fiveHour.utilization, 0.5)
        XCTAssertEqual(usage.fiveHour.resetsAt, "2024-01-01T00:00:00Z")
        XCTAssertEqual(usage.sevenDay.utilization, 0.8)
        XCTAssertNil(usage.sevenDay.resetsAt)
        XCTAssertNil(usage.sevenDaySonnet)
        XCTAssertNil(usage.extraUsage)
    }

    func testUsageWindowWithAllFields() {
        let usage = AnthropicUsage(
            fiveHour: .init(utilization: 0.25, resetsAt: "2024-06-01T12:00:00Z"),
            sevenDay: .init(utilization: 0.6, resetsAt: "2024-06-07T00:00:00Z"),
            sevenDaySonnet: .init(utilization: 0.3, resetsAt: "2024-06-07T00:00:00Z"),
            extraUsage: .init(usedCredits: 50, monthlyLimit: 100)
        )
        XCTAssertEqual(usage.fiveHour.utilization, 0.25)
        XCTAssertEqual(usage.sevenDay.utilization, 0.6)
        XCTAssertNotNil(usage.sevenDaySonnet)
        XCTAssertEqual(usage.sevenDaySonnet?.utilization, 0.3)
        XCTAssertNotNil(usage.extraUsage)
        XCTAssertEqual(usage.extraUsage?.usedCredits, 50)
        XCTAssertEqual(usage.extraUsage?.monthlyLimit, 100)
    }

    func testExtraUsageWithNilFields() {
        let extra = AnthropicUsage.ExtraUsage(usedCredits: nil, monthlyLimit: nil)
        XCTAssertNil(extra.usedCredits)
        XCTAssertNil(extra.monthlyLimit)
    }

    func testUsageWindowZeroUtilization() {
        let window = AnthropicUsage.UsageWindow(utilization: 0.0, resetsAt: nil)
        XCTAssertEqual(window.utilization, 0.0)
    }

    func testUsageWindowFullUtilization() {
        let window = AnthropicUsage.UsageWindow(utilization: 1.0, resetsAt: "2024-12-31T23:59:59Z")
        XCTAssertEqual(window.utilization, 1.0)
        XCTAssertEqual(window.resetsAt, "2024-12-31T23:59:59Z")
    }

    func testNormalizeUtilizationConvertsPercentToFraction() {
        XCTAssertEqual(AnthropicUsageService.normalizedUtilization(10.0), 0.10, accuracy: 0.0001)
    }

    func testNormalizeUtilizationKeepsFractionValue() {
        XCTAssertEqual(AnthropicUsageService.normalizedUtilization(0.42), 0.42, accuracy: 0.0001)
    }
}
