import SwiftUI

@main
struct AgentsMonitorApp: App {
    @State private var sessionStore: SessionStore
    @State private var appState = AppState()
    @State private var showDebugWindow = false
    @State private var statusItemController: StatusItemController?
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra: Bool = true
    private let appEnvironment: AppEnvironment
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let environment = AppEnvironment.current
        self.appEnvironment = environment
        let store = SessionStore(environment: environment)
        _sessionStore = State(initialValue: store)
        _statusItemController = State(
            initialValue: environment.useStatusItemPopover
                ? StatusItemController(sessionStore: store, environment: environment)
                : nil
        )
    }

    private var menuBarInsertion: Binding<Bool> {
        Binding(
            get: {
                if appEnvironment.useStatusItemPopover {
                    return false
                }
                return showMenuBarExtra || appEnvironment.forceMenuBarExtraVisible
            },
            set: { newValue in
                if !appEnvironment.forceMenuBarExtraVisible && !appEnvironment.useStatusItemPopover {
                    showMenuBarExtra = newValue
                }
            }
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sessionStore)
                .environment(appState)
                .environment(\.appEnvironment, appEnvironment)
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
                
                Divider()
                
                Button("Debug Info...") {
                    showDebugWindow = true
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
                .environment(\.appEnvironment, appEnvironment)
        }

        MenuBarExtra(isInserted: menuBarInsertion) {
            MenuBarView()
                .environment(sessionStore)
                .environment(\.appEnvironment, appEnvironment)
        } label: {
            Label("Agents Monitor", systemImage: "cpu")
                .accessibilityIdentifier("menuBar.statusItem")
        }
        .menuBarExtraStyle(.window)
        
        // Debug Window
        Window("Session Debug Info", id: "debug") {
            SessionDebugView()
                .environment(sessionStore)
                .environment(\.appEnvironment, appEnvironment)
        }
        .keyboardShortcut("d", modifiers: [.command, .shift])
        .defaultPosition(.center)
    }
}
