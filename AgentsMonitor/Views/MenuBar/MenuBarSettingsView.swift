import SwiftUI
import UniformTypeIdentifiers

struct MenuBarSettingsView: View {
    @Environment(SessionStore.self) private var sessionStore
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("refreshInterval") private var refreshInterval: Double = 5.0
    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("agentHost") private var agentHost = "localhost"
    @AppStorage("agentPort") private var agentPort = "8080"

    let navigateBack: () -> Void

    @State private var isConnected = false
    @State private var isConnecting = false
    @State private var showingClearConfirmation = false
    @State private var showingExportPanel = false

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

                        HStack(spacing: 8) {
                            Button("Clear History") {
                                showingClearConfirmation = true
                            }
                            .accessibilityIdentifier("menuBar.settings.clearHistory")

                            Button("Export Sessions") {
                                showingExportPanel = true
                            }
                            .accessibilityIdentifier("menuBar.settings.export")
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

                    // Connection
                    settingsSection("CONNECTION") {
                        HStack {
                            Text("Host")
                            Spacer()
                            TextField("localhost", text: $agentHost)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)
                        }
                        HStack {
                            Text("Port")
                            Spacer()
                            TextField("8080", text: $agentPort)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        HStack {
                            Circle()
                                .fill(isConnected ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(isConnected ? "Connected" : "Disconnected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button(isConnected ? "Disconnect" : "Connect") {
                                if isConnected {
                                    isConnected = false
                                } else {
                                    isConnecting = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        isConnecting = false
                                        isConnected = true
                                    }
                                }
                            }
                            .disabled(isConnecting)
                            .accessibilityIdentifier("menuBar.settings.connect")

                            if isConnecting {
                                ProgressView()
                                    .controlSize(.mini)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 300)
        .confirmationDialog("Clear Session History?", isPresented: $showingClearConfirmation) {
            Button("Clear All", role: .destructive) {
                sessionStore.clearAllSessions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all session history.")
        }
        .fileExporter(
            isPresented: $showingExportPanel,
            document: AllSessionsDocument(sessions: sessionStore.sessions),
            contentType: .json,
            defaultFilename: "sessions-export-\(Date().ISO8601Format()).json"
        ) { _ in }
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

struct AllSessionsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let sessions: [Session]

    init(sessions: [Session]) { self.sessions = sessions }

    init(configuration: ReadConfiguration) throws { sessions = [] }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(sessions)
        return FileWrapper(regularFileWithContents: data)
    }
}
