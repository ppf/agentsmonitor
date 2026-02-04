import SwiftUI

struct MenuBarView: View {
    @Environment(SessionStore.self) private var sessionStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "cpu")
                    .font(.title3)
                Text("Agents Monitor")
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Running Sessions
            if !sessionStore.runningSessions.isEmpty {
                Text("Running Sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ForEach(sessionStore.runningSessions.prefix(5)) { session in
                    MenuBarSessionRow(session: session)
                }
                
                if sessionStore.runningSessions.count > 5 {
                    Text("+\(sessionStore.runningSessions.count - 5) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No running sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Quick Actions
            Button {
                sessionStore.createNewSession()
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("New Session", systemImage: "plus")
            }
            
            Button {
                Task {
                    await sessionStore.refresh()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            
            Divider()
            
            // Open Main Window
            Button {
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Window", systemImage: "macwindow")
            }
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 250)
    }
}

struct MenuBarSessionRow: View {
    let session: Session
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.caption)
                    .lineLimit(1)
                
                Text(session.formattedDuration)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    MenuBarView()
        .environment(SessionStore())
}
