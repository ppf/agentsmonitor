import SwiftUI

struct ContentView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(AppState.self) private var appState

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
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                FilterMenu()

                Button {
                    sessionStore.createNewSession()
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Session")

                Button {
                    Task {
                        await sessionStore.refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }

            ToolbarItem(placement: .status) {
                StatusBarView()
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Session Selected")
                .font(.title2)
                .fontWeight(.medium)

            Text("Select a session from the sidebar or create a new one")
                .foregroundStyle(.secondary)

            Button("New Session") {
                // Will be connected to sessionStore
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    }
}

struct StatusBarView: View {
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        HStack(spacing: 12) {
            StatusIndicator(
                count: sessionStore.runningSessions.count,
                label: "Running",
                color: .green
            )

            StatusIndicator(
                count: sessionStore.sessions.count,
                label: "Total",
                color: .secondary
            )
        }
        .font(.caption)
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
