import SwiftUI

struct MenuBarView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Agents Monitor")
                    .font(.headline)
                Spacer()
                Text("\(sessionStore.runningSessions.count) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            // Active Sessions
            if !sessionStore.runningSessions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("ACTIVE SESSIONS")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    ForEach(sessionStore.runningSessions.prefix(5)) { session in
                        MenuBarSessionRow(session: session)
                    }

                    if sessionStore.runningSessions.count > 5 {
                        Text("+\(sessionStore.runningSessions.count - 5) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.vertical, 4)
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
                MenuBarButton(title: "New Session", icon: "plus") {
                    sessionStore.createNewSession()
                }

                MenuBarButton(title: "Open Window", icon: "macwindow") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    if let window = NSApplication.shared.windows.first(where: { $0.title.contains("Agents") }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }

                MenuBarButton(title: "Refresh", icon: "arrow.clockwise") {
                    Task {
                        await sessionStore.refresh()
                    }
                }

                Divider()

                MenuBarButton(title: "Settings...", icon: "gearshape") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }

                MenuBarButton(title: "Quit", icon: "power") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .frame(width: 280)
    }
}

struct MenuBarSessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .lineLimit(1)

                Text(session.formattedDuration)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ProgressView()
                .scaleEffect(0.5)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { isHovered in
            // Hover effect handled by system
        }
    }
}

struct MenuBarStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct MenuBarButton: View {
    let title: String
    let icon: String
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
    }
}

#Preview {
    MenuBarView()
        .environment(SessionStore())
}
