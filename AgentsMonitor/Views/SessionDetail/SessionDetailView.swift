import SwiftUI

struct SessionDetailView: View {
    let session: Session
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            SessionHeaderView(session: session)

            Divider()

            TabView(selection: $state.selectedDetailTab) {
                ConversationView(messages: session.messages)
                    .tabItem {
                        Label("Conversation", systemImage: "bubble.left.and.bubble.right")
                    }
                    .tag(AppState.DetailTab.conversation)

                ToolCallsView(toolCalls: session.toolCalls)
                    .tabItem {
                        Label("Tool Calls", systemImage: "wrench.and.screwdriver")
                    }
                    .tag(AppState.DetailTab.toolCalls)

                MetricsView(metrics: session.metrics, session: session)
                    .tabItem {
                        Label("Metrics", systemImage: "chart.bar")
                    }
                    .tag(AppState.DetailTab.metrics)
            }
            .padding(.top, 8)
        }
        .navigationTitle(session.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                SessionActionButtons(session: session)
            }
        }
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

    var body: some View {
        HStack(spacing: 8) {
            if session.status == .running {
                Button {
                    // Pause action
                } label: {
                    Image(systemName: "pause.fill")
                }
                .help("Pause Session")

                Button(role: .destructive) {
                    // Cancel action
                } label: {
                    Image(systemName: "xmark")
                }
                .help("Cancel Session")
            }

            if session.status == .paused {
                Button {
                    // Resume action
                } label: {
                    Image(systemName: "play.fill")
                }
                .help("Resume Session")
            }

            if session.status == .failed {
                Button {
                    // Retry action
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Retry Session")
            }

            Button {
                // Export action
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .help("Export Session")
        }
    }
}

#Preview {
    let store = SessionStore()
    return SessionDetailView(session: store.sessions[0])
        .environment(store)
        .environment(AppState())
}
