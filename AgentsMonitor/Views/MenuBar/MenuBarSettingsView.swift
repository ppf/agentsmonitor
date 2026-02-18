import SwiftUI

struct MenuBarSettingsView: View {
    @Environment(SessionStore.self) private var sessionStore
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("refreshInterval") private var refreshInterval: Double = 5.0
    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("activeOnly") private var activeOnly = false
    @AppStorage("showSidechains") private var showSidechains = false

    let navigateBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back header
            HStack {
                Button(action: navigateBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .accessibilityIdentifier("menuBar.settings.back")

                Spacer()

                Text("Settings")
                    .font(.headline)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // General
                    settingsSection("GENERAL") {
                        Toggle("Launch at login", isOn: $launchAtLogin)
                        Toggle("Notifications", isOn: $notificationsEnabled)
                        Toggle("Active only", isOn: $activeOnly)
                        Toggle("Show sidechains", isOn: $showSidechains)

                        HStack {
                            Text("Auto-refresh")
                            Spacer()
                            Picker("", selection: $refreshInterval) {
                                Text("1s").tag(1.0)
                                Text("5s").tag(5.0)
                                Text("10s").tag(10.0)
                                Text("30s").tag(30.0)
                                Text("Manual").tag(0.0)
                            }
                            .labelsHidden()
                            .frame(width: 100)
                        }
                    }

                    // Appearance
                    settingsSection("APPEARANCE") {
                        HStack {
                            Text("Theme")
                            Spacer()
                            Picker("", selection: $appearance) {
                                Text("System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 300)
        .accessibilityIdentifier("menuBar.settings.view")
    }

    private func settingsSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
        }
    }
}
