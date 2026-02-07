import SwiftUI

@main
struct AgentsMonitorApp: App {
    @State private var sessionStore: SessionStore
    private let appEnvironment: AppEnvironment

    init() {
        let environment = AppEnvironment.current
        self.appEnvironment = environment
        _sessionStore = State(initialValue: SessionStore(environment: environment))
    }

    var body: some Scene {
        MenuBarExtra("Agents Monitor", systemImage: "cpu") {
            MenuBarView()
                .environment(sessionStore)
                .environment(\.appEnvironment, appEnvironment)
        }
        .menuBarExtraStyle(.window)
    }
}
