import SwiftUI

struct MenuBarView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.appEnvironment) private var appEnvironment

    var body: some View {
        let activeSessions = sessionStore.activeSessions
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Agents Monitor")
                    .font(.headline)
                    .accessibilityIdentifier("menuBar.header.title")
                Spacer()
                Text("\(activeSessions.count) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("menuBar.header.activeCount")
            }
            .accessibilityElement(children: .contain)
            .padding()

            Divider()

            // Active Sessions
            if !activeSessions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("ACTIVE SESSIONS")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .accessibilityIdentifier("menuBar.section.active")

                    ForEach(activeSessions.prefix(5)) { session in
                        MenuBarSessionRow(session: session)
                    }

                    if activeSessions.count > 5 {
                        Text("+\(activeSessions.count - 5) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .accessibilityIdentifier("menuBar.session.more")
                    }
                }

                Divider()
            }

            // Quick Stats
            HStack(spacing: 24) {
                MenuBarStat(value: "\(sessionStore.sessions.count)", label: "Total")
                MenuBarStat(value: "\(sessionStore.completedSessions.count)", label: "Completed")
                MenuBarStat(value: "\(sessionStore.failedSessions.count)", label: "Failed")
            }
            .padding()

            Divider()

            // Actions
            VStack(spacing: 0) {
                MenuBarButton(title: "New Session", icon: "plus", identifier: "menuBar.action.newSession") {
                    sessionStore.createNewSession()
                }

                MenuBarButton(title: "Open Window", icon: "macwindow", identifier: "menuBar.action.openWindow") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    if let window = NSApplication.shared.windows.first(where: { $0.title.contains("Agents") }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }

                MenuBarButton(title: "Refresh", icon: "arrow.clockwise", identifier: "menuBar.action.refresh") {
                    Task {
                        await sessionStore.refresh()
                    }
                }

                Divider()

                MenuBarButton(title: "Settings...", icon: "gearshape", identifier: "menuBar.action.settings") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }

                MenuBarButton(title: "Quit", icon: "power", identifier: "menuBar.action.quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .frame(width: 280)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("menuBar.view")
    }
}

struct MenuBarSessionRow: View {
    let session: Session
    @Environment(\.appEnvironment) private var appEnvironment

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
                .accessibilityIdentifier("menuBar.session.status")

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .lineLimit(1)
                    .accessibilityIdentifier("menuBar.session.name")

                Text(session.formattedDuration(asOf: appEnvironment.now))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("menuBar.session.duration")
            }

            Spacer()

            ProgressView()
                .controlSize(.mini)
                .accessibilityIdentifier("menuBar.session.spinner")
        }
        .accessibilityElement(children: .contain)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { isHovered in
            // Hover effect handled by system
        }
        .accessibilityIdentifier("menuBar.sessionRow")
    }
}

struct MenuBarStat: View {
    let value: String
    let label: String

    var body: some View {
        let normalized = label.lowercased().replacingOccurrences(of: " ", with: "-")
        VStack(spacing: 2) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
                .accessibilityIdentifier("menuBar.stat.value.\(normalized)")

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("menuBar.stat.label.\(normalized)")
        }
    }
}

struct MenuBarButton: View {
    let title: String
    let icon: String
    let identifier: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isHovered ? Color.accentColor.opacity(0.1) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    MenuBarView()
        .environment(SessionStore(environment: .current))
        .environment(\.appEnvironment, .current)
}
