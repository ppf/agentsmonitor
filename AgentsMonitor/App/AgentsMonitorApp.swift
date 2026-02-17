import SwiftUI

@main
struct AgentsMonitorApp: App {
    @State private var sessionStore: SessionStore
    @AppStorage("appearance") private var appearance: String = "system"
    private let appEnvironment: AppEnvironment

    init() {
        UserDefaults.standard.register(defaults: [
            "showAllSessions": true,
            "showSidechains": false,
            "refreshInterval": 5.0,
            "appearance": "system"
        ])
        let environment = AppEnvironment.current
        self.appEnvironment = environment
        _sessionStore = State(initialValue: SessionStore(environment: environment))
    }

    var body: some Scene {
        MenuBarExtra("Agents Monitor", systemImage: "cpu") {
            MenuBarView()
                .environment(sessionStore)
                .environment(\.appEnvironment, appEnvironment)
                .onChange(of: appearance) { _, newValue in
                    applyAppearance(newValue)
                }
                .onAppear {
                    applyAppearance(appearance)
                }
        }
        .menuBarExtraStyle(.window)
    }

    private func applyAppearance(_ value: String) {
        guard let app = NSApp else { return }
        switch value {
        case "light":
            app.appearance = NSAppearance(named: .aqua)
        case "dark":
            app.appearance = NSAppearance(named: .darkAqua)
        default:
            app.appearance = nil
        }
    }
}
