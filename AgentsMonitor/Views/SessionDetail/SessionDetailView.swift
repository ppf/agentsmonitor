import SwiftUI

struct SessionDetailView: View {
    let session: Session
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            SessionHeaderView(session: session)

            Divider()

            // Custom tab picker to avoid macOS TabView toolbar crash
            Picker("", selection: $state.selectedDetailTab) {
                ForEach(AppState.DetailTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            // Content based on selection
            Group {
                switch state.selectedDetailTab {
                case .terminal:
                    TerminalContainerView(session: session)
                case .toolCalls:
                    ToolCallsView(toolCalls: session.toolCalls)
                case .metrics:
                    MetricsView(metrics: session.metrics, session: session)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(session.name)
    }
}

struct SessionHeaderView: View {
    let session: Session

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    StatusBadge(status: session.status, size: .large)
                    Text(session.name)
                        .font(.headline)
                }

                HStack(spacing: 16) {
                    Label(session.agentType.rawValue, systemImage: session.agentType.icon)
                    Label("Started \(session.startedAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                    Label(session.formattedDuration, systemImage: "timer")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            QuickMetricsView(metrics: session.metrics)
        }
        .padding()
        .background(.bar)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Session \(session.name), status \(session.status.rawValue), duration \(session.formattedDuration)")
    }
}

struct QuickMetricsView: View {
    let metrics: SessionMetrics

    var body: some View {
        HStack(spacing: 24) {
            MetricItem(
                value: metrics.formattedTokens,
                label: "Tokens",
                icon: "number"
            )

            MetricItem(
                value: "\(metrics.toolCallCount)",
                label: "Tools",
                icon: "wrench"
            )

            MetricItem(
                value: "\(metrics.apiCalls)",
                label: "API Calls",
                icon: "arrow.up.arrow.down"
            )

            if metrics.errorCount > 0 {
                MetricItem(
                    value: "\(metrics.errorCount)",
                    label: "Errors",
                    icon: "exclamationmark.triangle",
                    color: .red
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metrics.formattedTokens) tokens, \(metrics.toolCallCount) tool calls, \(metrics.apiCalls) API calls\(metrics.errorCount > 0 ? ", \(metrics.errorCount) errors" : "")")
    }
}

struct MetricItem: View {
    let value: String
    let label: String
    let icon: String
    var color: Color = .secondary

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(value)
                    .fontWeight(.semibold)
            }
            .font(.callout)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct SessionActionButtons: View {
    let session: Session
    @Environment(SessionStore.self) private var sessionStore
    @State private var showingExportPanel = false
    @State private var showingCancelConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var actionError: String?
    @State private var showingError = false

    var body: some View {
        HStack(spacing: 8) {
            if session.status == .running {
                Button {
                    Task {
                        await performAction {
                            try await sessionStore.pauseSession(session)
                        }
                    }
                } label: {
                    Image(systemName: "pause.fill")
                }
                .help("Pause Session")
                .accessibilityLabel("Pause Session")
                .accessibilityHint("Pauses the running session")

                Button {
                    showingCancelConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                }
                .help("Cancel Session")
                .accessibilityLabel("Cancel Session")
                .accessibilityHint("Cancels and stops the session")
            }

            if session.status == .paused {
                Button {
                    Task {
                        await performAction {
                            try await sessionStore.resumeSession(session)
                        }
                    }
                } label: {
                    Image(systemName: "play.fill")
                }
                .help("Resume Session")
                .accessibilityLabel("Resume Session")
                .accessibilityHint("Resumes the paused session")
            }

            if session.status == .failed {
                Button {
                    Task {
                        await performAction {
                            try await sessionStore.retrySession(session)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Retry Session")
                .accessibilityLabel("Retry Session")
                .accessibilityHint("Retries the failed session")
            }

            Button {
                showingExportPanel = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .help("Export Session")
            .accessibilityLabel("Export Session")
            .accessibilityHint("Exports session data to a file")
        }
        .confirmationDialog("Cancel Session?", isPresented: $showingCancelConfirmation) {
            Button("Cancel Session", role: .destructive) {
                Task {
                    await performAction {
                        try await sessionStore.cancelSession(session)
                    }
                }
            }
            Button("Keep Running", role: .cancel) {}
        } message: {
            Text("This will stop the session and mark it as cancelled. This action cannot be undone.")
        }
        .fileExporter(
            isPresented: $showingExportPanel,
            document: SessionDocument(session: session),
            contentType: .json,
            defaultFilename: "\(session.name.replacingOccurrences(of: " ", with: "-")).json"
        ) { result in
            switch result {
            case .success:
                AppLogger.logPersistenceSaved(session.id)
            case .failure(let error):
                actionError = error.localizedDescription
                showingError = true
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("Dismiss") {
                actionError = nil
            }
        } message: {
            Text(actionError ?? "An unknown error occurred")
        }
    }

    private func performAction(_ action: @escaping () async throws -> Void) async {
        do {
            try await action()
        } catch {
            actionError = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Session Document for Export

import UniformTypeIdentifiers

struct SessionDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let session: Session

    init(session: Session) {
        self.session = session
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        session = try JSONDecoder().decode(Session.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    let store = SessionStore()
    return SessionDetailView(session: store.sessions[0])
        .environment(store)
        .environment(AppState())
}
