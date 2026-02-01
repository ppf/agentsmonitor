import XCTest
@testable import AgentsMonitor

// MARK: - SessionStore Tests

/// Tests for SessionStore functionality
/// Note: These tests use nil persistence to avoid disk I/O.
/// The store will load mock data when persistence is nil.
@MainActor
final class SessionStoreTests: XCTestCase {

    // MARK: - Test Properties

    var store: SessionStore!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        // Create store with nil persistence - it will load mock data
        store = SessionStore(agentService: AgentService(), persistence: nil)
        // Wait for initial mock data to load
        try await Task.sleep(nanoseconds: 200_000_000)
    }

    override func tearDown() async throws {
        store = nil
        try await super.tearDown()
    }

    // MARK: - Session Creation Tests

    func testCreateNewSession() async throws {
        // Given initial mock sessions
        let initialCount = store.sessions.count

        // When
        store.createNewSession()

        // Then
        XCTAssertEqual(store.sessions.count, initialCount + 1)
        XCTAssertEqual(store.sessions.first?.status, .waiting)
        XCTAssertTrue(store.sessions.first?.name.contains("New Session") ?? false)
    }

    func testCreateSessionSelectsNewSession() async throws {
        // When
        store.createNewSession()

        // Then
        XCTAssertNotNil(store.selectedSessionId)
        XCTAssertEqual(store.selectedSession?.id, store.sessions.first?.id)
    }

    func testCreateMultipleSessions() async throws {
        // Given
        let initialCount = store.sessions.count

        // When
        store.createNewSession()
        store.createNewSession()
        store.createNewSession()

        // Then
        XCTAssertEqual(store.sessions.count, initialCount + 3)
    }

    // MARK: - Session Deletion Tests

    func testDeleteSession() async throws {
        // Given
        let initialCount = store.sessions.count
        guard let sessionToDelete = store.sessions.first else {
            XCTFail("No sessions to delete")
            return
        }

        // When
        store.deleteSession(sessionToDelete)

        // Then
        XCTAssertEqual(store.sessions.count, initialCount - 1)
        XCTAssertFalse(store.sessions.contains { $0.id == sessionToDelete.id })
    }

    func testDeleteSelectedSessionSelectsNext() async throws {
        // Given - ensure we have at least 2 sessions
        if store.sessions.count < 2 {
            store.createNewSession()
        }
        let firstSession = store.sessions[0]
        store.selectedSessionId = firstSession.id

        // When
        store.deleteSession(firstSession)

        // Then - selection should move to remaining session
        XCTAssertNotNil(store.selectedSessionId)
    }

    func testClearCompletedSessions() async throws {
        // Given - mock data should include completed sessions
        let completedCount = store.completedSessions.count
        let totalCount = store.sessions.count

        // When
        store.clearCompletedSessions()

        // Then
        XCTAssertEqual(store.sessions.count, totalCount - completedCount)
        XCTAssertEqual(store.completedSessions.count, 0)
    }

    // MARK: - Session Update Tests

    func testUpdateSessionName() async throws {
        // Given
        guard var session = store.sessions.first else {
            XCTFail("No sessions available")
            return
        }
        let originalName = session.name

        // When
        session.name = "Updated Name"
        store.updateSession(session)

        // Then
        XCTAssertEqual(store.sessions.first { $0.id == session.id }?.name, "Updated Name")
        XCTAssertNotEqual(store.sessions.first { $0.id == session.id }?.name, originalName)
    }

    func testUpdateSessionStatus() async throws {
        // Given
        guard var session = store.sessions.first else {
            XCTFail("No sessions available")
            return
        }

        // When
        session.status = .paused
        store.updateSession(session)

        // Then
        let updatedSession = store.sessions.first { $0.id == session.id }
        XCTAssertEqual(updatedSession?.status, .paused)
    }

    func testUpdateNonExistentSessionDoesNothing() async throws {
        // Given
        let originalCount = store.sessions.count
        let session = Session(name: "Non-existent")

        // When
        store.updateSession(session)

        // Then
        XCTAssertEqual(store.sessions.count, originalCount)
        XCTAssertFalse(store.sessions.contains { $0.id == session.id })
    }

    // MARK: - Selection Tests

    func testSelectedSessionReturnsCorrectSession() async throws {
        // Given
        guard store.sessions.count >= 2 else {
            store.createNewSession()
            store.createNewSession()
            return
        }
        let targetSession = store.sessions[1]

        // When
        store.selectedSessionId = targetSession.id

        // Then
        XCTAssertEqual(store.selectedSession?.id, targetSession.id)
    }

    func testSelectedSessionReturnsNilWhenNoSelection() async throws {
        // When
        store.selectedSessionId = nil

        // Then
        XCTAssertNil(store.selectedSession)
    }

    func testSetSelectedSession() async throws {
        // Given
        guard store.sessions.count >= 2 else {
            XCTFail("Need at least 2 sessions")
            return
        }
        let targetSession = store.sessions[1]

        // When
        store.selectedSession = targetSession

        // Then
        XCTAssertEqual(store.selectedSessionId, targetSession.id)
    }

    // MARK: - Filtering Tests

    func testFilterBySearchText() async throws {
        // Given - create session with specific name
        store.createNewSession()
        var session = store.sessions[0]
        session.name = "Authentication Bug Fix"
        store.updateSession(session)

        // When
        let (active, other) = store.filteredSessions(
            searchText: "Authentication",
            status: nil,
            sortOrder: .newest
        )

        // Then
        let allFiltered = active + other
        XCTAssertTrue(allFiltered.contains { $0.name.contains("Authentication") })
    }

    func testFilterByStatus() async throws {
        // Given - mock data includes running sessions
        let runningCount = store.runningSessions.count
        XCTAssertGreaterThan(runningCount, 0, "Mock data should have running sessions")

        // When
        let (active, other) = store.filteredSessions(
            searchText: "",
            status: .running,
            sortOrder: .newest
        )

        // Then
        let allFiltered = active + other
        XCTAssertEqual(allFiltered.count, runningCount)
        XCTAssertTrue(allFiltered.allSatisfy { $0.status == .running })
    }

    func testFilterPartitionsActiveAndOther() async throws {
        // When
        let (active, other) = store.filteredSessions(
            searchText: "",
            status: nil,
            sortOrder: .newest
        )

        // Then
        XCTAssertTrue(active.allSatisfy { $0.status == .running || $0.status == .waiting })
        XCTAssertTrue(other.allSatisfy { $0.status != .running && $0.status != .waiting })
    }

    func testSortByNewest() async throws {
        // When
        let (active, other) = store.filteredSessions(
            searchText: "",
            status: nil,
            sortOrder: .newest
        )

        // Then
        let allFiltered = active + other
        guard allFiltered.count >= 2 else { return }
        for i in 0..<(allFiltered.count - 1) {
            XCTAssertGreaterThanOrEqual(allFiltered[i].startedAt, allFiltered[i + 1].startedAt)
        }
    }

    func testSortByOldest() async throws {
        // When
        let (active, other) = store.filteredSessions(
            searchText: "",
            status: nil,
            sortOrder: .oldest
        )

        // Then
        let allFiltered = active + other
        guard allFiltered.count >= 2 else { return }
        for i in 0..<(allFiltered.count - 1) {
            XCTAssertLessThanOrEqual(allFiltered[i].startedAt, allFiltered[i + 1].startedAt)
        }
    }

    func testSortByName() async throws {
        // When
        let (active, other) = store.filteredSessions(
            searchText: "",
            status: nil,
            sortOrder: .name
        )

        // Then
        let allFiltered = active + other
        guard allFiltered.count >= 2 else { return }
        for i in 0..<(allFiltered.count - 1) {
            XCTAssertLessThanOrEqual(allFiltered[i].name, allFiltered[i + 1].name)
        }
    }

    func testFilterCaching() async throws {
        // First call
        let (active1, other1) = store.filteredSessions(
            searchText: "",
            status: nil,
            sortOrder: .newest
        )

        // Second call with same parameters
        let (active2, other2) = store.filteredSessions(
            searchText: "",
            status: nil,
            sortOrder: .newest
        )

        // Then - results should be identical (cached)
        XCTAssertEqual(active1.map(\.id), active2.map(\.id))
        XCTAssertEqual(other1.map(\.id), other2.map(\.id))
    }

    func testFilterCacheInvalidatesOnUpdate() async throws {
        // Given - cache the result
        let _ = store.filteredSessions(searchText: "", status: nil, sortOrder: .newest)

        // Create a new session which invalidates cache
        store.createNewSession()

        // When
        let (active, _) = store.filteredSessions(
            searchText: "",
            status: nil,
            sortOrder: .newest
        )

        // Then - should include the new session
        XCTAssertTrue(active.contains { $0.status == .waiting })
    }

    // MARK: - Computed Properties Tests

    func testRunningSessionsFilter() async throws {
        // The mock data should have at least one running session
        XCTAssertTrue(store.runningSessions.allSatisfy { $0.status == .running })
    }

    func testCompletedSessionsFilter() async throws {
        XCTAssertTrue(store.completedSessions.allSatisfy { $0.status == .completed })
    }

    func testFailedSessionsFilter() async throws {
        XCTAssertTrue(store.failedSessions.allSatisfy { $0.status == .failed })
    }

    func testWaitingSessionsFilter() async throws {
        XCTAssertTrue(store.waitingSessions.allSatisfy { $0.status == .waiting })
    }

    // MARK: - Message & Tool Call Tests

    func testAppendMessage() async throws {
        // Given
        guard let session = store.sessions.first else {
            XCTFail("No sessions available")
            return
        }
        let sessionId = session.id
        let originalMessageCount = session.messages.count
        let message = Message(role: .user, content: "Test message")

        // When
        store.appendMessage(message, to: sessionId)

        // Then
        let updatedSession = store.sessions.first { $0.id == sessionId }
        XCTAssertEqual(updatedSession?.messages.count, originalMessageCount + 1)
        XCTAssertEqual(updatedSession?.messages.last?.content, "Test message")
    }

    func testAppendMessageToNonExistentSession() async throws {
        // Given
        let message = Message(role: .user, content: "Test message")
        let fakeId = UUID()

        // Capture current state
        let sessionCounts = store.sessions.map { $0.messages.count }

        // When
        store.appendMessage(message, to: fakeId)

        // Then - no session should have changed
        for (index, session) in store.sessions.enumerated() {
            XCTAssertEqual(session.messages.count, sessionCounts[index])
        }
    }

    func testAppendToolCall() async throws {
        // Given
        guard let session = store.sessions.first else {
            XCTFail("No sessions available")
            return
        }
        let sessionId = session.id
        let originalToolCallCount = session.toolCalls.count
        let originalMetricCount = session.metrics.toolCallCount
        let toolCall = ToolCall(name: "TestTool", input: "test input")

        // When
        store.appendToolCall(toolCall, to: sessionId)

        // Then
        let updatedSession = store.sessions.first { $0.id == sessionId }
        XCTAssertEqual(updatedSession?.toolCalls.count, originalToolCallCount + 1)
        XCTAssertEqual(updatedSession?.toolCalls.last?.name, "TestTool")
        XCTAssertEqual(updatedSession?.metrics.toolCallCount, originalMetricCount + 1)
    }

    func testUpdateToolCall() async throws {
        // Given
        guard let session = store.sessions.first else {
            XCTFail("No sessions available")
            return
        }
        let sessionId = session.id

        // Add a tool call first
        let toolCall = ToolCall(name: "TestTool", input: "test input", status: .running)
        store.appendToolCall(toolCall, to: sessionId)

        // Get the appended tool call
        guard let appendedToolCall = store.sessions.first(where: { $0.id == sessionId })?.toolCalls.last else {
            XCTFail("Tool call not appended")
            return
        }

        // When - update the tool call
        var updatedToolCall = appendedToolCall
        updatedToolCall.status = .completed
        updatedToolCall.output = "Test output"
        store.updateToolCall(updatedToolCall, in: sessionId)

        // Then
        let finalSession = store.sessions.first { $0.id == sessionId }
        let finalToolCall = finalSession?.toolCalls.first { $0.id == updatedToolCall.id }
        XCTAssertEqual(finalToolCall?.status, .completed)
        XCTAssertEqual(finalToolCall?.output, "Test output")
    }

    // MARK: - Error Handling Tests

    func testClearError() async throws {
        // Given
        store.error = "Some error"

        // When
        store.clearError()

        // Then
        XCTAssertNil(store.error)
    }

    // MARK: - Loading State Tests

    func testInitialLoadingCompletes() async throws {
        // Then - after setup, loading should be complete
        XCTAssertFalse(store.isLoading)
    }
}

// MARK: - Search Tests

@MainActor
final class SessionStoreSearchTests: XCTestCase {

    var store: SessionStore!

    override func setUp() async throws {
        try await super.setUp()
        store = SessionStore(agentService: AgentService(), persistence: nil)
        try await Task.sleep(nanoseconds: 200_000_000)
    }

    override func tearDown() async throws {
        store = nil
        try await super.tearDown()
    }

    func testSearchFindsMessageContent() async throws {
        // Given
        store.createNewSession()
        let sessionId = store.sessions[0].id
        let message = Message(role: .assistant, content: "The unique_search_term is important")
        store.appendMessage(message, to: sessionId)

        // When
        let (active, other) = store.filteredSessions(
            searchText: "unique_search_term",
            status: nil,
            sortOrder: .newest
        )

        // Then
        let allFiltered = active + other
        XCTAssertTrue(allFiltered.contains { $0.id == sessionId })
    }

    func testSearchIsCaseInsensitive() async throws {
        // Given
        store.createNewSession()
        var session = store.sessions[0]
        session.name = "UPPERCASE_TEST_NAME"
        store.updateSession(session)

        // When
        let (active, other) = store.filteredSessions(
            searchText: "uppercase_test",
            status: nil,
            sortOrder: .newest
        )

        // Then
        let allFiltered = active + other
        XCTAssertTrue(allFiltered.contains { $0.name == "UPPERCASE_TEST_NAME" })
    }

    func testEmptySearchReturnsAll() async throws {
        // Given
        let totalCount = store.sessions.count

        // When
        let (active, other) = store.filteredSessions(
            searchText: "",
            status: nil,
            sortOrder: .newest
        )

        // Then
        XCTAssertEqual(active.count + other.count, totalCount)
    }
}

// MARK: - Model Tests

final class SessionModelTests: XCTestCase {

    func testSessionDuration() {
        // Given
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3600) // 1 hour later

        let session = Session(
            name: "Test",
            startedAt: startDate,
            endedAt: endDate
        )

        // Then
        XCTAssertEqual(session.duration, 3600, accuracy: 0.1)
    }

    func testSessionFormattedDuration() {
        // Given
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3661) // 1h 1m 1s

        let session = Session(
            name: "Test",
            startedAt: startDate,
            endedAt: endDate
        )

        // Then
        let formatted = session.formattedDuration
        XCTAssertTrue(formatted.contains("1") && formatted.contains("h"))
    }

    func testSessionEquality() {
        // Given
        let id = UUID()
        let session1 = Session(id: id, name: "Test1")
        let session2 = Session(id: id, name: "Test2")
        let session3 = Session(name: "Test1")

        // Then
        XCTAssertEqual(session1, session2) // Same ID = equal
        XCTAssertNotEqual(session1, session3) // Different ID = not equal
    }

    func testSessionStatusProperties() {
        XCTAssertEqual(SessionStatus.running.icon, "play.circle.fill")
        XCTAssertEqual(SessionStatus.paused.icon, "pause.circle.fill")
        XCTAssertEqual(SessionStatus.completed.icon, "checkmark.circle.fill")
        XCTAssertEqual(SessionStatus.failed.icon, "xmark.circle.fill")
        XCTAssertEqual(SessionStatus.waiting.icon, "clock.fill")
    }

    func testAgentTypeProperties() {
        XCTAssertEqual(AgentType.claude.icon, "brain")
        XCTAssertEqual(AgentType.custom.icon, "cpu")
    }
}

final class ToolCallModelTests: XCTestCase {

    func testToolCallDuration() {
        // Given
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(1.5)

        let toolCall = ToolCall(
            name: "Test",
            input: "input",
            startedAt: startDate,
            completedAt: endDate,
            status: .completed
        )

        // Then
        XCTAssertEqual(toolCall.duration ?? 0, 1.5, accuracy: 0.01)
    }

    func testToolCallFormattedDurationMilliseconds() {
        // Given
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(0.5)

        let toolCall = ToolCall(
            name: "Test",
            input: "input",
            startedAt: startDate,
            completedAt: endDate,
            status: .completed
        )

        // Then
        XCTAssertTrue(toolCall.formattedDuration.contains("ms"))
    }

    func testToolCallFormattedDurationSeconds() {
        // Given
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(2.5)

        let toolCall = ToolCall(
            name: "Test",
            input: "input",
            startedAt: startDate,
            completedAt: endDate,
            status: .completed
        )

        // Then
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
        // Just verify it returns a non-empty string
        XCTAssertFalse(message.formattedTime.isEmpty)
    }

    func testMessageEquality() {
        let id = UUID()
        let message1 = Message(id: id, role: .user, content: "Test1")
        let message2 = Message(id: id, role: .assistant, content: "Test2")
        let message3 = Message(role: .user, content: "Test1")

        XCTAssertEqual(message1, message2) // Same ID = equal
        XCTAssertNotEqual(message1, message3) // Different ID = not equal
    }
}

final class SessionMetricsTests: XCTestCase {

    func testFormattedTokens() {
        let metrics = SessionMetrics(totalTokens: 1234567)
        let formatted = metrics.formattedTokens

        // Should be formatted with separators
        XCTAssertTrue(formatted.contains(",") || formatted.count >= 7)
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
    }
}
