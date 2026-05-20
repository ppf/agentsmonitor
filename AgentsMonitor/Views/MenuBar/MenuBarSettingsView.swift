import SwiftUI

struct MenuBarSettingsView: View {
    @Environment(SessionStore.self) private var sessionStore
    @AppStorage("refreshInterval") private var refreshInterval: Double = 5.0
    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("activeOnly") private var activeOnly = false
    @AppStorage("showSidechains") private var showSidechains = false
    @AppStorage("codexEnabled") private var codexEnabled = true
    @AppStorage("claudeCodeEnabled") private var claudeCodeEnabled = true

    let navigateBack: () -> Void
    var isActive: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: navigateBack) {
                    HStack(spacing: AppTheme.Spacing.small) {
                        Image(systemName: "chevron.left")
                            .accessibilityHidden(true)
                        Text("Back")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.secondaryAction)
                .accessibilityLabel("Back")
                .accessibilityHint("Returns to the sessions list")
                .accessibilityIdentifier("menuBar.settings.back")

                Spacer()

                Text("Settings")
                    .font(.headline)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    settingsSection("GENERAL") {
                        Toggle("Active only", isOn: $activeOnly)
                            .accessibilityHint("Shows only running sessions when enabled")
                        Toggle("Show sidechains", isOn: $showSidechains)
                            .accessibilityHint("Includes sidechain sessions in the list when enabled")
                        Toggle("Enable Codex", isOn: $codexEnabled)
                            .accessibilityLabel("Enable Codex")
                            .accessibilityHint("Shows Codex sessions and refreshes Codex data when enabled")
                            .accessibilityIdentifier("menuBar.settings.enableCodex")
                        Toggle("Enable Claude Code", isOn: $claudeCodeEnabled)
                            .accessibilityLabel("Enable Claude Code")
                            .accessibilityHint("Shows Claude Code sessions and refreshes Claude data when enabled")
                            .accessibilityIdentifier("menuBar.settings.enableClaudeCode")

                        HStack {
                            Text("Auto-refresh")
                            Spacer()
                            Picker("Auto-refresh interval", selection: $refreshInterval) {
                                Text("1s").tag(1.0)
                                Text("5s").tag(5.0)
                                Text("10s").tag(10.0)
                                Text("30s").tag(30.0)
                                Text("Manual").tag(0.0)
                            }
                            .labelsHidden()
                            .frame(width: 100)
                            .accessibilityLabel("Auto-refresh interval")
                        }
                    }

                    settingsSection("APPEARANCE") {
                        HStack {
                            Text("Theme")
                            Spacer()
                            Picker("Theme", selection: $appearance) {
                                Text("System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                            .accessibilityLabel("Appearance theme")
                        }
                    }
                }
                .padding()
            }
        }
        .onChange(of: refreshTrigger) { _, _ in
            refreshSessions()
        }
        .accessibilityIdentifier("menuBar.settings.view")
    }

    private var refreshTrigger: String {
        "\(activeOnly)-\(showSidechains)-\(codexEnabled)-\(claudeCodeEnabled)"
    }

    private func settingsSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
        }
    }

    private func refreshSessions() {
        Task {
            await sessionStore.refresh()
        }
    }
}
