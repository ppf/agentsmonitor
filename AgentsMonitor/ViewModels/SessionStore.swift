import Foundation
import SwiftUI

@Observable
final class SessionStore {
    var sessions: [Session] = []
    var selectedSessionId: UUID?
    var isLoading: Bool = false
    var error: String?

    private let agentService = AgentService()

    init() {
        loadMockData()
    }

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

    func filteredSessions(searchText: String, status: SessionStatus?, sortOrder: AppState.SortOrder) -> [Session] {
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

        return result
    }

    func createNewSession() {
        let session = Session(
            name: "New Session \(sessions.count + 1)",
            status: .waiting
        )
        sessions.insert(session, at: 0)
        selectedSessionId = session.id
    }

    func deleteSession(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
        if selectedSessionId == session.id {
            selectedSessionId = sessions.first?.id
        }
    }

    func clearCompletedSessions() {
        sessions.removeAll { $0.status == .completed }
    }

    @MainActor
    func refresh() async {
        isLoading = true
        error = nil

        do {
            try await Task.sleep(nanoseconds: 500_000_000)
            // In production, fetch from actual agent service
            // sessions = try await agentService.fetchSessions()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func updateSession(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
    }

    func appendMessage(_ message: Message, to sessionId: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].messages.append(message)
        }
    }

    func appendToolCall(_ toolCall: ToolCall, to sessionId: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].toolCalls.append(toolCall)
            sessions[index].metrics.toolCallCount += 1
        }
    }

    private func loadMockData() {
        let session1 = Session(
            name: "Fix authentication bug",
            status: .running,
            agentType: .claude,
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

        let session2 = Session(
            name: "Add dark mode support",
            status: .completed,
            agentType: .claude,
            startedAt: Date().addingTimeInterval(-7200),
            endedAt: Date().addingTimeInterval(-5400),
            messages: [
                Message(role: .user, content: "Add dark mode support to the settings page", timestamp: Date().addingTimeInterval(-7200)),
                Message(role: .assistant, content: "I'll implement dark mode support for the settings page. This will involve adding a theme toggle and updating the CSS variables.", timestamp: Date().addingTimeInterval(-7190)),
                Message(role: .assistant, content: "Dark mode has been successfully implemented. The theme toggle is now available in settings and persists across sessions.", timestamp: Date().addingTimeInterval(-5400))
            ],
            toolCalls: [
                ToolCall(name: "Read", input: "src/settings/Settings.tsx", output: "// Settings component", startedAt: Date().addingTimeInterval(-7180), completedAt: Date().addingTimeInterval(-7175), status: .completed),
                ToolCall(name: "Edit", input: "src/settings/Settings.tsx", output: "Added theme toggle", startedAt: Date().addingTimeInterval(-7100), completedAt: Date().addingTimeInterval(-7050), status: .completed),
                ToolCall(name: "Write", input: "src/styles/dark-theme.css", output: "Created dark theme styles", startedAt: Date().addingTimeInterval(-6800), completedAt: Date().addingTimeInterval(-6750), status: .completed)
            ],
            metrics: SessionMetrics(totalTokens: 28450, inputTokens: 12300, outputTokens: 16150, toolCallCount: 8, errorCount: 0, apiCalls: 12)
        )

        let session3 = Session(
            name: "Database migration failed",
            status: .failed,
            agentType: .claude,
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

        let session4 = Session(
            name: "Code review PR #142",
            status: .waiting,
            agentType: .claude,
            startedAt: Date().addingTimeInterval(-300),
            messages: [
                Message(role: .user, content: "Review PR #142 and provide feedback", timestamp: Date().addingTimeInterval(-300))
            ],
            toolCalls: [],
            metrics: SessionMetrics(totalTokens: 0, inputTokens: 0, outputTokens: 0, toolCallCount: 0, errorCount: 0, apiCalls: 0)
        )

        sessions = [session1, session2, session3, session4]
        selectedSessionId = session1.id
    }
}
