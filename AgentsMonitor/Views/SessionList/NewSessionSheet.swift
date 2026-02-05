import SwiftUI

struct NewSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var sessionStore

    @State private var agentType: AgentType = .claudeCode
    @State private var workingDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    @State private var sessionName: String = ""
    @State private var showDirectoryPicker = false
    @State private var validationError: String?
    @State private var validationWarning: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Session")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section {
                    Picker("Agent Type", selection: $agentType) {
                        ForEach(AgentType.allCases.filter { $0.isTerminalBased }, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Working Directory")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(workingDirectory.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(workingDirectory.path)
                        }
                        Spacer()
                        Button("Browse...") {
                            showDirectoryPicker = true
                        }
                    }
                }

                Section {
                    TextField("Session Name (optional)", text: $sessionName)
                        .textFieldStyle(.roundedBorder)
                }

                if let error = validationError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                if let warning = validationWarning {
                    Section {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Create Session") {
                    createSession()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 450, height: 350)
        .fileImporter(
            isPresented: $showDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    workingDirectory = url
                    validationError = nil
                }
            case .failure(let error):
                validationError = error.localizedDescription
            }
        }
        .onChange(of: agentType) { _, _ in
            validateExecutable()
        }
        .onAppear {
            if workingDirectory == FileManager.default.homeDirectoryForCurrentUser {
                workingDirectory = sessionStore.defaultWorkingDirectory
            }
            validateExecutable()
        }
    }

    private var isValid: Bool {
        validationError == nil
    }

    private func validateExecutable() {
        validationError = nil
        validationWarning = nil

        if let override = agentType.overrideExecutablePath {
            if FileManager.default.isExecutableFile(atPath: override) {
                return
            }
            if isLikelyPermissionIssue(for: override) {
                validationWarning = "Permission required — click Grant Access in Settings."
                return
            }
            validationError = "Override path not executable: \(override)"
            return
        }

        if agentType.detectedExecutablePath() != nil {
            return
        }

        let names = agentType.executableNames.joined(separator: " or ")
        validationError = "\(agentType.displayName) not found. Ensure \(names) is on PATH or set an override in Settings."
    }

    private func isLikelyPermissionIssue(for path: String) -> Bool {
        if let suggested = agentType.suggestedDefaultPath, suggested == path {
            return true
        }
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && !isDir.boolValue
    }

    private func createSession() {
        let name = sessionName.isEmpty ? nil : sessionName
        sessionStore.createSession(agentType: agentType, workingDirectory: workingDirectory, name: name)
        dismiss()
    }
}

#Preview {
    NewSessionSheet()
        .environment(SessionStore())
}
