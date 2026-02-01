import SwiftUI

struct SessionListView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var store = sessionStore

        let filteredSessions = sessionStore.filteredSessions(
            searchText: appState.searchText,
            status: appState.filterStatus,
            sortOrder: appState.sortOrder
        )

        List(selection: $store.selectedSessionId) {
            if !sessionStore.runningSessions.isEmpty {
                Section("Active") {
                    ForEach(filteredSessions.filter { $0.status == .running || $0.status == .waiting }) { session in
                        SessionRowView(session: session)
                            .tag(session.id)
                    }
                }
            }

            Section("Sessions") {
                ForEach(filteredSessions.filter { $0.status != .running && $0.status != .waiting }) { session in
                    SessionRowView(session: session)
                        .tag(session.id)
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if filteredSessions.isEmpty {
                ContentUnavailableView {
                    Label("No Sessions", systemImage: "tray")
                } description: {
                    Text("No sessions match your search criteria")
                }
            }
        }
        .contextMenu(forSelectionType: UUID.self) { selection in
            if let sessionId = selection.first,
               let session = sessionStore.sessions.first(where: { $0.id == sessionId }) {
                SessionContextMenu(session: session)
            }
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

                HStack(spacing: 8) {
                    Label(session.formattedDuration, systemImage: "clock")

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
                    .scaleEffect(0.6)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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

    var body: some View {
        Button {
            // Copy session ID
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(session.id.uuidString, forType: .string)
        } label: {
            Label("Copy Session ID", systemImage: "doc.on.doc")
        }

        Divider()

        if session.status == .running {
            Button {
                // Pause session
            } label: {
                Label("Pause", systemImage: "pause")
            }
        }

        if session.status == .paused {
            Button {
                // Resume session
            } label: {
                Label("Resume", systemImage: "play")
            }
        }

        if session.status == .failed {
            Button {
                // Retry session
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
