import SwiftUI

struct ContentView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(AppState.self) private var appState
    @State private var showingError = false

    var body: some View {
        @Bindable var store = sessionStore
        @Bindable var state = appState

        NavigationSplitView(
            columnVisibility: Binding(
                get: { state.isSidebarVisible ? .all : .detailOnly },
                set: { state.isSidebarVisible = ($0 != .detailOnly) }
            )
        ) {
            SessionListView()
                .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
        } detail: {
            if let session = sessionStore.selectedSession {
                SessionDetailView(session: session)
            } else {
                EmptyStateView()
            }
        }
        .searchable(text: $state.searchText, prompt: "Search sessions...")
        .overlay {
            if sessionStore.isLoading {
                LoadingOverlay()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                FilterMenu()

                Menu {
                    Button {
                        sessionStore.createNewSession(agentType: .claudeCode)
                    } label: {
                        Label("New Claude Code Session", systemImage: AgentType.claudeCode.icon)
                    }

                    Button {
                        sessionStore.createNewSession(agentType: .codex)
                    } label: {
                        Label("New Codex Session", systemImage: AgentType.codex.icon)
                    }

                    Button {
                        sessionStore.createNewSession(agentType: .gemini)
                    } label: {
                        Label("New Gemini Session", systemImage: AgentType.gemini.icon)
                    }

                    Divider()

                    Button {
                        sessionStore.createNewSession(agentType: .custom)
                    } label: {
                        Label("New Custom Session", systemImage: AgentType.custom.icon)
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Session")
                .accessibilityLabel("New Session")
                .accessibilityHint("Creates a new agent session")

                Button {
                    Task {
                        await sessionStore.refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                .accessibilityLabel("Refresh")
                .accessibilityHint("Refreshes the session list")
                .disabled(sessionStore.isLoading)
            }

            ToolbarItem(placement: .status) {
                StatusBarView()
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("Dismiss") {
                sessionStore.clearError()
            }
        } message: {
            Text(sessionStore.error ?? "An unknown error occurred")
        }
        .onChange(of: sessionStore.error) { _, newError in
            showingError = newError != nil
        }
    }
}

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
        }
        .accessibilityLabel("Loading sessions")
    }
}

struct EmptyStateView: View {
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("No Session Selected")
                .font(.title2)
                .fontWeight(.medium)

            Text("Select a session from the sidebar or create a new one")
                .foregroundStyle(.secondary)

            Button("New Session") {
                sessionStore.createNewSession()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Creates a new agent session")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct FilterMenu: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        Menu {
            Section("Status") {
                Button {
                    state.filterStatus = nil
                } label: {
                    Label("All", systemImage: state.filterStatus == nil ? "checkmark" : "")
                }

                ForEach(SessionStatus.allCases, id: \.self) { status in
                    Button {
                        state.filterStatus = status
                    } label: {
                        Label(status.rawValue, systemImage: state.filterStatus == status ? "checkmark" : "")
                    }
                }
            }

            Divider()

            Section("Sort") {
                ForEach(AppState.SortOrder.allCases, id: \.self) { order in
                    Button {
                        state.sortOrder = order
                    } label: {
                        Label(order.rawValue, systemImage: state.sortOrder == order ? "checkmark" : "")
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .help("Filter & Sort")
        .accessibilityLabel("Filter and Sort")
        .accessibilityHint("Opens filter and sort options for sessions")
    }
}

struct StatusBarView: View {
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        HStack(spacing: 12) {
            StatusIndicator(
                count: sessionStore.runningSessions.count,
                label: "Running",
                color: AppTheme.statusColors[.running] ?? .green
            )

            StatusIndicator(
                count: sessionStore.sessions.count,
                label: "Total",
                color: .secondary
            )
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sessionStore.runningSessions.count) running sessions, \(sessionStore.sessions.count) total")
    }
}

struct StatusIndicator: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(count) \(label)")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .environment(SessionStore())
        .environment(AppState())
}
