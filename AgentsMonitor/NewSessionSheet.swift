import SwiftUI

struct NewSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var sessionStore
    
    @State private var sessionName = ""
    @State private var selectedAgentType: AgentType = .claudeCode
    @State private var workingDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    @State private var showingDirectoryPicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Session")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                Section("Session Details") {
                    LabeledContent("Name") {
                        TextField("Session Name", text: $sessionName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 300)
                    }
                    
                    LabeledContent("Agent Type") {
                        Picker("Agent Type", selection: $selectedAgentType) {
                            ForEach(AgentType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 300)
                    }
                }
                
                Section("Working Directory") {
                    HStack {
                        Text(workingDirectory.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button("Choose...") {
                            showingDirectoryPicker = true
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Create") {
                    createSession()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(sessionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 500)
        .fileImporter(
            isPresented: $showingDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                workingDirectory = url
            }
        }
        .onAppear {
            if sessionName.isEmpty {
                sessionName = "New Session \(sessionStore.sessions.count + 1)"
            }
        }
    }
    
    private func createSession() {
        sessionStore.createSession(
            agentType: selectedAgentType,
            workingDirectory: workingDirectory,
            name: sessionName
        )
        dismiss()
    }
}

#Preview {
    NewSessionSheet()
        .environment(SessionStore())
}
