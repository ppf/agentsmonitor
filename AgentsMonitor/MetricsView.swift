import SwiftUI

struct MetricsView: View {
    let metrics: SessionMetrics
    let session: Session
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Token Usage
                MetricsSection(title: "Token Usage", icon: "number.circle.fill") {
                    MetricRow(label: "Total Tokens", value: "\(metrics.totalTokens)")
                    MetricRow(label: "Input Tokens", value: "\(metrics.inputTokens)")
                    MetricRow(label: "Output Tokens", value: "\(metrics.outputTokens)")
                    
                    if metrics.cacheReadTokens > 0 {
                        MetricRow(label: "Cache Read", value: "\(metrics.cacheReadTokens)")
                    }
                    if metrics.cacheWriteTokens > 0 {
                        MetricRow(label: "Cache Write", value: "\(metrics.cacheWriteTokens)")
                    }
                }
                
                // Activity Metrics
                MetricsSection(title: "Activity", icon: "chart.bar.fill") {
                    MetricRow(label: "Tool Calls", value: "\(metrics.toolCallCount)")
                    MetricRow(label: "API Calls", value: "\(metrics.apiCalls)")
                    MetricRow(label: "Errors", value: "\(metrics.errorCount)")
                    MetricRow(label: "Messages", value: "\(session.messages.count)")
                }
                
                // Session Info
                MetricsSection(title: "Session Info", icon: "info.circle.fill") {
                    MetricRow(label: "Duration", value: session.formattedDuration)
                    MetricRow(label: "Started", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    
                    if let endedAt = session.endedAt {
                        MetricRow(label: "Ended", value: endedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    
                    if let processId = session.processId {
                        MetricRow(label: "Process ID", value: "\(processId)")
                    }
                    
                    if let workingDir = session.workingDirectory {
                        MetricRow(label: "Working Directory", value: workingDir.path)
                    }
                }
            }
            .padding()
        }
    }
}

struct MetricsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
            
            VStack(spacing: 8) {
                content
            }
            .padding()
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}

#Preview {
    let session = Session(
        name: "Test Session",
        status: .completed,
        agentType: .claudeCode,
        messages: [
            Message(role: .user, content: "Hello"),
            Message(role: .assistant, content: "Hi there!")
        ],
        metrics: SessionMetrics(
            tokenCount: 1500,
            toolCallCount: 5,
            apiCalls: 10,
            errorCount: 0,
            inputTokens: 800,
            outputTokens: 700
        ),
        processId: 12345
    )
    
    return MetricsView(metrics: session.metrics, session: session)
        .frame(width: 400, height: 600)
}
