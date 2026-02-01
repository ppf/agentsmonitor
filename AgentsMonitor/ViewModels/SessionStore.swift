import Foundation
import SwiftUI

@Observable
final class SessionStore {
    // MARK: - Published State

    private(set) var sessions: [Session] = []
    var selectedSessionId: UUID?
    var isLoading: Bool = false
    var error: String?

    // MARK: - Pagination

    private let pageSize = 50
    private var currentPage = 0
    private var hasMorePages = true

    // MARK: - Cache

    private var filteredCache: FilteredSessionsCache?

    private struct FilteredSessionsCache {
        let searchText: String
        let status: SessionStatus?
        let sortOrder: AppState.SortOrder
        let result: [Session]
        let activeSessions: [Session]
        let otherSessions: [Session]
    }

    // MARK: - Dependencies

    private let agentService: AgentService
    private let persistence: SessionPersistence?

    // MARK: - Initialization

    init(agentService: AgentService = AgentService(), persistence: SessionPersistence? = SessionPersistence.shared) {
        self.agentService = agentService
        self.persistence = persistence

        Task {
            await loadPersistedSessions()
        }
    }

    // MARK: - Computed Properties

    var selectedSession: Session? {
        get {
            guard let id = selectedSessionId else { return nil }
            return sessions.first { $0.id == id }
        }
        set {
            selectedSessionId = newValue?.id
        }
    }

    var runningSessions: [Session] {
        sessions.filter { $0.status == .running }
    }

    var completedSessions: [Session] {
        sessions.filter { $0.status == .completed }
    }

    var failedSessions: [Session] {
        sessions.filter { $0.status == .failed }
    }

    var waitingSessions: [Session] {
        sessions.filter { $0.status == .waiting }
    }

    // MARK: - Filtered Sessions with Caching

    func filteredSessions(searchText: String, status: SessionStatus?, sortOrder: AppState.SortOrder) -> (active: [Session], other: [Session]) {
        // Return cached result if inputs haven't changed
        if let cache = filteredCache,
           cache.searchText == searchText,
           cache.status == status,
           cache.sortOrder == sortOrder {
            return (cache.activeSessions, cache.otherSessions)
        }

        // Compute filtered results
        var result = sessions

        if !searchText.isEmpty {
            result = result.filter { session in
                session.name.localizedCaseInsensitiveContains(searchText) ||
                session.messages.contains { $0.content.localizedCaseInsensitiveContains(searchText) }
            }
        }

        if let status = status {
            result = result.filter { $0.status == status }
        }

        switch sortOrder {
        case .newest:
            result.sort { $0.startedAt > $1.startedAt }
        case .oldest:
            result.sort { $0.startedAt < $1.startedAt }
        case .name:
            result.sort { $0.name < $1.name }
        case .status:
            result.sort { $0.status.rawValue < $1.status.rawValue }
        }

        // Partition into active and other sessions in a single pass
        var activeSessions: [Session] = []
        var otherSessions: [Session] = []

        for session in result {
            if session.status == .running || session.status == .waiting {
                activeSessions.append(session)
            } else {
                otherSessions.append(session)
            }
        }

        // Cache the result
        filteredCache = FilteredSessionsCache(
            searchText: searchText,
            status: status,
            sortOrder: sortOrder,
            result: result,
            activeSessions: activeSessions,
            otherSessions: otherSessions
        )

        return (activeSessions, otherSessions)
    }

    // MARK: - Session CRUD

    func createNewSession() {
        let session = Session(
            name: "New Session \(sessions.count + 1)",
            status: .waiting
        )
        sessions.insert(session, at: 0)
        selectedSessionId = session.id
        invalidateCache()

        AppLogger.logSessionCreated(session)
        persistSession(session)
    }

    func deleteSession(_ session: Session) {
        let sessionId = session.id
        sessions.removeAll { $0.id == sessionId }

        if selectedSessionId == sessionId {
            selectedSessionId = sessions.first?.id
        }
        invalidateCache()

        AppLogger.logSessionDeleted(sessionId)

        Task {
            try? await persistence?.deleteSession(sessionId)
        }
    }

    func clearCompletedSessions() {
        let completedIds = sessions.filter { $0.status == .completed }.map { $0.id }
        sessions.removeAll { $0.status == .completed }
        invalidateCache()

        Task {
            for id in completedIds {
                try? await persistence?.deleteSession(id)
            }
        }
    }

    func updateSession(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            let oldStatus = sessions[index].status
            sessions[index] = session
            invalidateCache()

            if oldStatus != session.status {
                AppLogger.logSessionStatusChanged(session, from: oldStatus)
            }

            persistSession(session)
        }
    }

    // MARK: - Session Actions

    @MainActor
    func pauseSession(_ session: Session) async throws {
        guard session.status == .running else { return }

        var updated = session
        updated.status = .paused
        updateSession(updated)

        try await agentService.sendCommand(
            AgentCommand(type: .pause, sessionId: session.id, payload: nil)
        )
    }

    @MainActor
    func resumeSession(_ session: Session) async throws {
        guard session.status == .paused else { return }

        var updated = session
        updated.status = .running
        updateSession(updated)

        try await agentService.sendCommand(
            AgentCommand(type: .resume, sessionId: session.id, payload: nil)
        )
    }

    @MainActor
    func cancelSession(_ session: Session) async throws {
        guard session.status == .running || session.status == .paused else { return }

        var updated = session
        updated.status = .failed
        updated.endedAt = Date()
        updateSession(updated)

        try await agentService.sendCommand(
            AgentCommand(type: .cancel, sessionId: session.id, payload: nil)
        )
    }

    @MainActor
    func retrySession(_ session: Session) async throws {
        guard session.status == .failed else { return }

        var updated = session
        updated.status = .running
        updated.endedAt = nil
        updated.metrics.errorCount = 0
        updateSession(updated)

        try await agentService.sendCommand(
            AgentCommand(type: .retry, sessionId: session.id, payload: nil)
        )
    }

    // MARK: - Message & Tool Call Management

    func appendMessage(_ message: Message, to sessionId: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].messages.append(message)
            invalidateCache()
            persistSession(sessions[index])
        }
    }

    func appendToolCall(_ toolCall: ToolCall, to sessionId: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].toolCalls.append(toolCall)
            sessions[index].metrics.toolCallCount += 1
            invalidateCache()

            AppLogger.logToolCallStarted(toolCall, sessionId: sessionId)
            persistSession(sessions[index])
        }
    }

    func updateToolCall(_ toolCall: ToolCall, in sessionId: UUID) {
        if let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
           let toolIndex = sessions[sessionIndex].toolCalls.firstIndex(where: { $0.id == toolCall.id }) {
            sessions[sessionIndex].toolCalls[toolIndex] = toolCall
            invalidateCache()

            if toolCall.status == .completed || toolCall.status == .failed {
                AppLogger.logToolCallCompleted(toolCall, sessionId: sessionId)
            }

            persistSession(sessions[sessionIndex])
        }
    }

    // MARK: - Refresh & Loading

    @MainActor
    func refresh() async {
        isLoading = true
        error = nil

        do {
            try await AppLogger.measureAsync("refresh sessions") {
                // In production, fetch from actual agent service
                // let fetchedSessions = try await agentService.fetchSessions()
                // sessions = fetchedSessions

                // For now, just reload from persistence
                if let persistence = persistence {
                    let persisted = try await persistence.loadSessions()
                    if !persisted.isEmpty {
                        sessions = persisted
                        invalidateCache()
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
            AppLogger.logError(error, context: "refresh")
        }

        isLoading = false
    }

    @MainActor
    func loadNextPage() async {
        guard hasMorePages, !isLoading else { return }

        isLoading = true

        do {
            // In production, this would fetch the next page from the API
            // let newSessions = try await agentService.fetchSessions(page: currentPage, limit: pageSize)
            // sessions.append(contentsOf: newSessions)
            // hasMorePages = newSessions.count == pageSize
            // currentPage += 1

            try await Task.sleep(nanoseconds: 300_000_000)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }

    // MARK: - Export

    func exportSession(_ session: Session, to url: URL) async throws {
        try await persistence?.exportSession(session, to: url)
    }

    // MARK: - Private Helpers

    private func invalidateCache() {
        filteredCache = nil
    }

    private func persistSession(_ session: Session) {
        Task {
            do {
                try await persistence?.saveSession(session)
            } catch {
                AppLogger.logPersistenceError(error, context: "saving session \(session.id)")
            }
        }
    }

    @MainActor
    private func loadPersistedSessions() async {
        guard let persistence = persistence else {
            loadMockData()
            return
        }

        isLoading = true

        do {
            let persisted = try await persistence.loadSessions()
            if persisted.isEmpty {
                loadMockData()
            } else {
                sessions = persisted
                selectedSessionId = sessions.first?.id
            }
        } catch {
            AppLogger.logPersistenceError(error, context: "loading sessions")
            loadMockData()
        }

        isLoading = false
    }

    private func loadMockData() {
        // Claude Code session - running
        let session1 = Session(
            name: "Fix authentication bug",
            status: .running,
            agentType: .claudeCode,
            startedAt: Date().addingTimeInterval(-3600),
            messages: [
                Message(role: .user, content: "Fix the authentication bug in the login flow", timestamp: Date().addingTimeInterval(-3600)),
                Message(role: .assistant, content: "I'll analyze the authentication code and identify the bug. Let me start by reading the relevant files.", timestamp: Date().addingTimeInterval(-3590)),
                Message(role: .assistant, content: "I found the issue. The token validation is not checking for expiration properly. Let me fix this.", timestamp: Date().addingTimeInterval(-3500), isStreaming: true)
            ],
            toolCalls: [
                ToolCall(name: "Read", input: "src/auth/login.ts", output: "// Login code...", startedAt: Date().addingTimeInterval(-3580), completedAt: Date().addingTimeInterval(-3578), status: .completed),
                ToolCall(name: "Grep", input: "validateToken", output: "Found 3 matches", startedAt: Date().addingTimeInterval(-3570), completedAt: Date().addingTimeInterval(-3565), status: .completed),
                ToolCall(name: "Edit", input: "src/auth/validate.ts", startedAt: Date().addingTimeInterval(-3520), status: .running)
            ],
            metrics: SessionMetrics(totalTokens: 15420, inputTokens: 8200, outputTokens: 7220, toolCallCount: 3, errorCount: 0, apiCalls: 5)
        )

        // Codex session - completed
        let session2 = Session(
            name: "Generate unit tests",
            status: .completed,
            agentType: .codex,
            startedAt: Date().addingTimeInterval(-7200),
            endedAt: Date().addingTimeInterval(-5400),
            messages: [
                Message(role: .user, content: "Generate comprehensive unit tests for the UserService class", timestamp: Date().addingTimeInterval(-7200)),
                Message(role: .assistant, content: "I'll analyze the UserService class and generate unit tests covering all public methods and edge cases.", timestamp: Date().addingTimeInterval(-7190)),
                Message(role: .assistant, content: "Successfully generated 24 unit tests for UserService with 100% coverage of public methods.", timestamp: Date().addingTimeInterval(-5400))
            ],
            toolCalls: [
                ToolCall(name: "Read", input: "src/services/UserService.ts", output: "// UserService implementation", startedAt: Date().addingTimeInterval(-7180), completedAt: Date().addingTimeInterval(-7175), status: .completed),
                ToolCall(name: "Write", input: "tests/UserService.test.ts", output: "Created test file", startedAt: Date().addingTimeInterval(-6800), completedAt: Date().addingTimeInterval(-6750), status: .completed),
                ToolCall(name: "Bash", input: "npm test -- UserService", output: "All 24 tests passed", startedAt: Date().addingTimeInterval(-6700), completedAt: Date().addingTimeInterval(-6650), status: .completed)
            ],
            metrics: SessionMetrics(totalTokens: 32150, inputTokens: 14200, outputTokens: 17950, toolCallCount: 5, errorCount: 0, apiCalls: 8)
        )

        // Claude Code session - completed
        let session3 = Session(
            name: "Add dark mode support",
            status: .completed,
            agentType: .claudeCode,
            startedAt: Date().addingTimeInterval(-10800),
            endedAt: Date().addingTimeInterval(-9000),
            messages: [
                Message(role: .user, content: "Add dark mode support to the settings page", timestamp: Date().addingTimeInterval(-10800)),
                Message(role: .assistant, content: "I'll implement dark mode support for the settings page. This will involve adding a theme toggle and updating the CSS variables.", timestamp: Date().addingTimeInterval(-10790)),
                Message(role: .assistant, content: "Dark mode has been successfully implemented. The theme toggle is now available in settings and persists across sessions.", timestamp: Date().addingTimeInterval(-9000))
            ],
            toolCalls: [
                ToolCall(name: "Read", input: "src/settings/Settings.tsx", output: "// Settings component", startedAt: Date().addingTimeInterval(-10780), completedAt: Date().addingTimeInterval(-10775), status: .completed),
                ToolCall(name: "Edit", input: "src/settings/Settings.tsx", output: "Added theme toggle", startedAt: Date().addingTimeInterval(-10500), completedAt: Date().addingTimeInterval(-10450), status: .completed),
                ToolCall(name: "Write", input: "src/styles/dark-theme.css", output: "Created dark theme styles", startedAt: Date().addingTimeInterval(-10000), completedAt: Date().addingTimeInterval(-9950), status: .completed)
            ],
            metrics: SessionMetrics(totalTokens: 28450, inputTokens: 12300, outputTokens: 16150, toolCallCount: 8, errorCount: 0, apiCalls: 12)
        )

        // Codex session - failed
        let session4 = Session(
            name: "Database migration failed",
            status: .failed,
            agentType: .codex,
            startedAt: Date().addingTimeInterval(-1800),
            endedAt: Date().addingTimeInterval(-1200),
            messages: [
                Message(role: .user, content: "Run the database migration for the new user schema", timestamp: Date().addingTimeInterval(-1800)),
                Message(role: .assistant, content: "I'll execute the database migration. Let me first check the migration files.", timestamp: Date().addingTimeInterval(-1790)),
                Message(role: .system, content: "Error: Migration failed - Foreign key constraint violation on users table", timestamp: Date().addingTimeInterval(-1200))
            ],
            toolCalls: [
                ToolCall(name: "Bash", input: "npm run migrate", output: nil, startedAt: Date().addingTimeInterval(-1750), completedAt: Date().addingTimeInterval(-1200), status: .failed, error: "Foreign key constraint violation")
            ],
            metrics: SessionMetrics(totalTokens: 5200, inputTokens: 2100, outputTokens: 3100, toolCallCount: 1, errorCount: 1, apiCalls: 3)
        )

        // Claude Code session - waiting
        let session5 = Session(
            name: "Code review PR #142",
            status: .waiting,
            agentType: .claudeCode,
            startedAt: Date().addingTimeInterval(-300),
            messages: [
                Message(role: .user, content: "Review PR #142 and provide feedback", timestamp: Date().addingTimeInterval(-300))
            ],
            toolCalls: [],
            metrics: SessionMetrics(totalTokens: 0, inputTokens: 0, outputTokens: 0, toolCallCount: 0, errorCount: 0, apiCalls: 0)
        )

        // Codex session - running
        let session6 = Session(
            name: "Refactor API endpoints",
            status: .running,
            agentType: .codex,
            startedAt: Date().addingTimeInterval(-900),
            messages: [
                Message(role: .user, content: "Refactor the REST API endpoints to follow OpenAPI 3.0 spec", timestamp: Date().addingTimeInterval(-900)),
                Message(role: .assistant, content: "I'll refactor the API endpoints to comply with OpenAPI 3.0 specification. Starting with route analysis.", timestamp: Date().addingTimeInterval(-890))
            ],
            toolCalls: [
                ToolCall(name: "Glob", input: "src/routes/**/*.ts", output: "Found 12 route files", startedAt: Date().addingTimeInterval(-880), completedAt: Date().addingTimeInterval(-875), status: .completed),
                ToolCall(name: "Read", input: "src/routes/users.ts", startedAt: Date().addingTimeInterval(-870), status: .running)
            ],
            metrics: SessionMetrics(totalTokens: 8500, inputTokens: 4200, outputTokens: 4300, toolCallCount: 2, errorCount: 0, apiCalls: 4)
        )

        sessions = [session1, session2, session3, session4, session5, session6]
        selectedSessionId = session1.id
    }
}
