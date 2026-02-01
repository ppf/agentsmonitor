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

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Show in menu bar", isOn: $showMenuBarExtra)
                Toggle("Enable notifications", isOn: $notificationsEnabled)
            }

            Section("Refresh") {
                Picker("Auto-refresh interval", selection: $refreshInterval) {
                    Text("1 second").tag(1.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                    Text("Manual only").tag(0.0)
                }
            }

            Section("Data") {
                Button("Clear Session History") {
                    // Clear history action
                }

                Button("Export All Sessions...") {
                    // Export action
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("compactMode") private var compactMode: Bool = false
    @AppStorage("showTimestamps") private var showTimestamps: Bool = true
    @AppStorage("syntaxHighlighting") private var syntaxHighlighting: Bool = true

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Section("Display") {
                Toggle("Compact mode", isOn: $compactMode)
                Toggle("Show timestamps", isOn: $showTimestamps)
                Toggle("Syntax highlighting", isOn: $syntaxHighlighting)
            }

            Section("Font") {
                Picker("Code font size", selection: .constant(12)) {
                    Text("Small (11pt)").tag(11)
                    Text("Medium (12pt)").tag(12)
                    Text("Large (14pt)").tag(14)
                }
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

    var body: some View {
        Form {
            Section("Agent Service") {
                TextField("Host", text: $agentHost)
                TextField("Port", text: $agentPort)

                HStack {
                    Circle()
                        .fill(isConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(isConnected ? "Connected" : "Disconnected")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(isConnected ? "Disconnect" : "Connect") {
                        isConnected.toggle()
                    }
                }
            }

            Section("File Watcher") {
                HStack {
                    TextField("Watch Directory", text: $watchDirectory)
                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        if panel.runModal() == .OK {
                            watchDirectory = panel.url?.path ?? ""
                        }
                    }
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
    }
}

#Preview {
    SettingsView()
}
