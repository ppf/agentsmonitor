import SwiftUI

@main
struct AgentsMonitorApp: App {
    @State private var sessionStore = SessionStore()
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sessionStore)
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Session") {
                    sessionStore.createNewSession()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    appState.isSidebarVisible.toggle()
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }

            CommandMenu("Sessions") {
                Button("Clear Completed") {
                    sessionStore.clearCompletedSessions()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Divider()

                Button("Refresh") {
                    Task {
                        await sessionStore.refresh()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }

        MenuBarExtra("Agents Monitor", systemImage: "cpu") {
            MenuBarView()
                .environment(sessionStore)
        }
        .menuBarExtraStyle(.window)
    }
}
