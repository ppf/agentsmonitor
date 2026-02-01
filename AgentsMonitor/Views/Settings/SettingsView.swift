import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            ConnectionSettingsView()
                .tabItem {
                    Label("Connection", systemImage: "network")
                }

            KeyboardShortcutsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval: Double = 5.0
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra: Bool = true
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true

    @State private var showingClearConfirmation = false
    @State private var showingExportPanel = false
    @State private var clearError: String?
    @State private var showingError = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .accessibilityHint("Automatically start AgentsMonitor when you log in")
                Toggle("Show in menu bar", isOn: $showMenuBarExtra)
                    .accessibilityHint("Show quick access widget in the menu bar")
                Toggle("Enable notifications", isOn: $notificationsEnabled)
                    .accessibilityHint("Receive notifications for session events")
            }

            Section("Refresh") {
                Picker("Auto-refresh interval", selection: $refreshInterval) {
                    Text("1 second").tag(1.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                    Text("Manual only").tag(0.0)
                }
                .accessibilityHint("How often to automatically refresh session data")
            }

            Section("Data") {
                Button("Clear Session History") {
                    showingClearConfirmation = true
                }
                .accessibilityHint("Removes all completed sessions from history")

                Button("Export All Sessions...") {
                    showingExportPanel = true
                }
                .accessibilityHint("Exports all sessions to a JSON file")
            }
        }
        .formStyle(.grouped)
        .padding()
        .confirmationDialog("Clear Session History?", isPresented: $showingClearConfirmation) {
            Button("Clear All", role: .destructive) {
                Task {
                    do {
                        try await SessionPersistence.shared?.clearAllSessions()
                    } catch {
                        clearError = error.localizedDescription
                        showingError = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all session history. This action cannot be undone.")
        }
        .fileExporter(
            isPresented: $showingExportPanel,
            document: AllSessionsDocument(),
            contentType: .json,
            defaultFilename: "sessions-export-\(Date().ISO8601Format()).json"
        ) { result in
            if case .failure(let error) = result {
                clearError = error.localizedDescription
                showingError = true
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("Dismiss") {
                clearError = nil
            }
        } message: {
            Text(clearError ?? "An unknown error occurred")
        }
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("compactMode") private var compactMode: Bool = false
    @AppStorage("showTimestamps") private var showTimestamps: Bool = true
    @AppStorage("syntaxHighlighting") private var syntaxHighlighting: Bool = true
    @AppStorage("codeFontSize") private var codeFontSize: Int = 12

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Color theme")
            }

            Section("Display") {
                Toggle("Compact mode", isOn: $compactMode)
                    .accessibilityHint("Uses smaller spacing and fonts")
                Toggle("Show timestamps", isOn: $showTimestamps)
                    .accessibilityHint("Shows time for each message")
                Toggle("Syntax highlighting", isOn: $syntaxHighlighting)
                    .accessibilityHint("Highlights code syntax in messages")
            }

            Section("Font") {
                Picker("Code font size", selection: $codeFontSize) {
                    ForEach(AppTheme.FontSize.allCases, id: \.rawValue) { size in
                        Text(size.label).tag(size.rawValue)
                    }
                }
                .accessibilityHint("Font size for code blocks and tool outputs")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ConnectionSettingsView: View {
    @AppStorage("agentHost") private var agentHost: String = "localhost"
    @AppStorage("agentPort") private var agentPort: String = "8080"
    @AppStorage("watchDirectory") private var watchDirectory: String = ""
    @State private var isConnected = false
    @State private var isConnecting = false
    @State private var connectionError: String?

    var body: some View {
        Form {
            Section("Agent Service") {
                TextField("Host", text: $agentHost)
                    .accessibilityLabel("Host address")
                TextField("Port", text: $agentPort)
                    .accessibilityLabel("Port number")

                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isConnected ? .green : .red)
                            .frame(width: 8, height: 8)
                        // Add icon for colorblind accessibility
                        Image(systemName: isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(isConnected ? .green : .red)
                        Text(isConnected ? "Connected" : "Disconnected")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(isConnected ? "Connection status: Connected" : "Connection status: Disconnected")

                    Spacer()

                    Button(isConnected ? "Disconnect" : "Connect") {
                        if isConnected {
                            isConnected = false
                            AppLogger.logDisconnection(reason: "User initiated")
                        } else {
                            isConnecting = true
                            AppLogger.logConnectionAttempt(host: agentHost, port: agentPort)
                            // Simulate connection
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                isConnecting = false
                                isConnected = true
                                AppLogger.logConnectionSuccess()
                            }
                        }
                    }
                    .disabled(isConnecting)

                    if isConnecting {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }

                if let error = connectionError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("File Watcher") {
                HStack {
                    TextField("Watch Directory", text: $watchDirectory)
                        .accessibilityLabel("Directory to watch for session files")
                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.message = "Select a directory to monitor for agent session files"

                        if panel.runModal() == .OK {
                            if let url = panel.url {
                                watchDirectory = url.path
                            }
                        }
                    }
                    .accessibilityHint("Opens a file browser to select a directory")
                }

                Text("Monitor a directory for agent session files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct KeyboardShortcutsView: View {
    var body: some View {
        Form {
            Section("Navigation") {
                ShortcutRow(action: "New Session", shortcut: "⌘N")
                ShortcutRow(action: "Toggle Sidebar", shortcut: "⌃⌘S")
                ShortcutRow(action: "Search", shortcut: "⌘F")
                ShortcutRow(action: "Refresh", shortcut: "⌘R")
            }

            Section("Sessions") {
                ShortcutRow(action: "Clear Completed", shortcut: "⇧⌘K")
                ShortcutRow(action: "Delete Session", shortcut: "⌘⌫")
                ShortcutRow(action: "Export Session", shortcut: "⇧⌘E")
            }

            Section("View") {
                ShortcutRow(action: "Conversation Tab", shortcut: "⌘1")
                ShortcutRow(action: "Tool Calls Tab", shortcut: "⌘2")
                ShortcutRow(action: "Metrics Tab", shortcut: "⌘3")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ShortcutRow: View {
    let action: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(action): \(shortcut)")
    }
}

// MARK: - All Sessions Document for Export

import UniformTypeIdentifiers

struct AllSessionsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    init() {}

    init(configuration: ReadConfiguration) throws {
        // Not used for export-only
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // This would need access to SessionStore - in production,
        // this should be handled differently
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        // Export empty array as placeholder - actual implementation
        // should pass sessions from SessionStore
        let data = try encoder.encode([String]())
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    SettingsView()
}
