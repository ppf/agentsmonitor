import SwiftUI

struct SessionListView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(AppState.self) private var appState
    @State private var showNewSessionSheet = false

    var body: some View {
        @Bindable var store = sessionStore

        let filtered = sessionStore.filteredSessions(
            searchText: appState.searchText,
            status: appState.filterStatus,
            sortOrder: appState.sortOrder
        )
        let activeSessions = filtered.active
        let otherSessions = filtered.other
        let isEmpty = activeSessions.isEmpty && otherSessions.isEmpty

        List(selection: $store.selectedSessionId) {
            if !activeSessions.isEmpty {
                Section("Active") {
                    ForEach(activeSessions) { session in
                        SessionRowView(session: session)
                            .tag(session.id)
                    }
                }
            }

            if !otherSessions.isEmpty {
                Section("Sessions") {
                    ForEach(otherSessions) { session in
                        SessionRowView(session: session)
                            .tag(session.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("session.list")
        .overlay {
            if isEmpty {
                ContentUnavailableView {
                    Label("No Sessions", systemImage: "tray")
                } description: {
                    Text("Create a new session to get started")
                }
            }
        }
        .contextMenu(forSelectionType: UUID.self) { selection in
            if let sessionId = selection.first,
               let session = sessionStore.sessions.first(where: { $0.id == sessionId }) {
                SessionContextMenu(session: session)
            }
        }
        .accessibilityLabel("Sessions list")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewSessionSheet = true
                } label: {
                    Label("New Session", systemImage: "plus")
                }
                .help("Create a new agent session")
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $showNewSessionSheet) {
            NewSessionSheet()
        }
    }
}

struct SessionRowView: View {
    let session: Session
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        HStack(spacing: 12) {
            StatusBadge(status: session.status)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .accessibilityIdentifier("session.list.name")

                HStack(spacing: 8) {
                    Label(session.relativeTimeString, systemImage: "clock")

                    if session.metrics.toolCallCount > 0 {
                        Label("\(session.metrics.toolCallCount)", systemImage: "wrench")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if session.status == .running {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 16, height: 16)
                    .accessibilityLabel("Session in progress")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityIdentifier("session.list.row")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.name), \(session.status.rawValue), \(session.relativeTimeString)")
        .accessibilityHint("Double-tap to view session details")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                sessionStore.deleteSession(session)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct SessionContextMenu: View {
    let session: Session
    @Environment(SessionStore.self) private var sessionStore
    @State private var actionError: String?

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(session.id.uuidString, forType: .string)
        } label: {
            Label("Copy Session ID", systemImage: "doc.on.doc")
        }

        Divider()

        if session.status == .running {
            Button {
                Task {
                    do {
                        try await sessionStore.pauseSession(session)
                    } catch {
                        actionError = error.localizedDescription
                    }
                }
            } label: {
                Label("Pause", systemImage: "pause")
            }
        }

        if session.status == .paused {
            Button {
                Task {
                    do {
                        try await sessionStore.resumeSession(session)
                    } catch {
                        actionError = error.localizedDescription
                    }
                }
            } label: {
                Label("Resume", systemImage: "play")
            }
        }

        if session.status == .failed {
            Button {
                Task {
                    do {
                        try await sessionStore.retrySession(session)
                    } catch {
                        actionError = error.localizedDescription
                    }
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
        }

        Divider()

        Button(role: .destructive) {
            sessionStore.deleteSession(session)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

#Preview {
    SessionListView()
        .environment(SessionStore())
        .environment(AppState())
        .frame(width: 300)
}
