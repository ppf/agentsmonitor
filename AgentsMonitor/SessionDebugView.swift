import SwiftUI

/// Debug view to help understand session loading and persistence
struct SessionDebugView: View {
    @Environment(SessionStore.self) private var sessionStore
    @State private var persistenceInfo: PersistenceInfo?
    @State private var isRefreshing = false
    
    struct PersistenceInfo {
        var directory: String
        var fileCount: Int
        var files: [String]
        var error: String?
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Debug Info")
                .font(.title2)
                .fontWeight(.semibold)
            
            Divider()
            
            // Current Sessions
            GroupBox("Current Sessions") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total: \(sessionStore.sessions.count)")
                    Text("External: \(sessionStore.sessions.filter { $0.isExternalProcess }.count)")
                    Text("Persisted: \(sessionStore.sessions.filter { !$0.isExternalProcess }.count)")
                    
                    Divider()
                    
                    ForEach(sessionStore.sessions.prefix(5)) { session in
                        HStack {
                            Image(systemName: session.isExternalProcess ? "bolt.horizontal.circle" : "doc")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.name)
                                    .font(.caption)
                                if let dir = session.workingDirectory {
                                    Text(dir.path)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("No working directory")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Persistence Info
            GroupBox("Persistence Storage") {
                VStack(alignment: .leading, spacing: 8) {
                    if let info = persistenceInfo {
                        if let error = info.error {
                            Text("Error: \(error)")
                                .foregroundStyle(.red)
                        } else {
                            Text("Directory: \(info.directory)")
                                .font(.caption)
                                .textSelection(.enabled)
                            Text("Files: \(info.fileCount)")
                            
                            if !info.files.isEmpty {
                                Text("Recent files:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(info.files.prefix(5), id: \.self) { file in
                                    Text("• \(file)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        Text("Loading...")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Actions
            HStack {
                Button("Refresh Info") {
                    Task {
                        await refreshInfo()
                    }
                }
                .disabled(isRefreshing)
                
                Button("Open Storage Directory") {
                    if let info = persistenceInfo {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: info.directory)
                    }
                }
                .disabled(persistenceInfo == nil)
                
                Button("Clear All Saved Sessions") {
                    Task {
                        await clearAllSessions()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 600, height: 500)
        .task {
            await refreshInfo()
        }
    }
    
    private func refreshInfo() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        guard let persistence = SessionPersistence.shared else {
            persistenceInfo = PersistenceInfo(
                directory: "N/A",
                fileCount: 0,
                files: [],
                error: "Persistence not initialized"
            )
            return
        }
        
        do {
            // Get the storage directory
            let fm = FileManager.default
            let appSupport = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let appDirectory = appSupport.appendingPathComponent("AgentsMonitor")
            let sessionsDirectory = appDirectory.appendingPathComponent("Sessions")
            
            // List files
            let files = try fm.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)
            let jsonFiles = files.filter { $0.pathExtension == "json" }
            
            persistenceInfo = PersistenceInfo(
                directory: sessionsDirectory.path,
                fileCount: jsonFiles.count,
                files: jsonFiles.map { $0.lastPathComponent },
                error: nil
            )
        } catch {
            persistenceInfo = PersistenceInfo(
                directory: "N/A",
                fileCount: 0,
                files: [],
                error: error.localizedDescription
            )
        }
    }
    
    private func clearAllSessions() async {
        guard let persistence = SessionPersistence.shared else { return }
        
        do {
            try await persistence.clearAllSessions()
            await refreshInfo()
        } catch {
            persistenceInfo?.error = "Failed to clear: \(error.localizedDescription)"
        }
    }
}

#Preview {
    SessionDebugView()
        .environment(SessionStore())
}
