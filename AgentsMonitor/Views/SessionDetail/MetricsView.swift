import SwiftUI

struct MetricsView: View {
    let metrics: SessionMetrics
    let session: Session

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Token Usage
                MetricsSectionView(title: "Token Usage", icon: "number") {
                    HStack(spacing: 32) {
                        CircularProgressView(
                            value: Double(metrics.inputTokens),
                            total: Double(metrics.totalTokens),
                            label: "Input",
                            color: .blue
                        )

                        CircularProgressView(
                            value: Double(metrics.outputTokens),
                            total: Double(metrics.totalTokens),
                            label: "Output",
                            color: .purple
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            MetricRow(label: "Total Tokens", value: metrics.formattedTokens)
                            MetricRow(label: "Input Tokens", value: "\(metrics.inputTokens)")
                            MetricRow(label: "Output Tokens", value: "\(metrics.outputTokens)")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // API Stats
                MetricsSectionView(title: "API Statistics", icon: "arrow.up.arrow.down") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(title: "API Calls", value: "\(metrics.apiCalls)", icon: "network", color: .blue)
                        StatCard(title: "Tool Calls", value: "\(metrics.toolCallCount)", icon: "wrench", color: .orange)
                        StatCard(title: "Errors", value: "\(metrics.errorCount)", icon: "exclamationmark.triangle", color: metrics.errorCount > 0 ? .red : .green)
                    }
                }

                // Session Timeline
                MetricsSectionView(title: "Session Timeline", icon: "clock") {
                    VStack(alignment: .leading, spacing: 12) {
                        TimelineRow(label: "Started", time: session.startedAt)

                        if let endedAt = session.endedAt {
                            TimelineRow(label: "Ended", time: endedAt)
                        }

                        HStack {
                            Text("Duration")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(session.formattedDuration)
                                .fontWeight(.medium)
                        }
                    }
                }

                // Tool Call Breakdown
                if !session.toolCalls.isEmpty {
                    MetricsSectionView(title: "Tool Call Breakdown", icon: "chart.pie") {
                        ToolCallBreakdownChart(toolCalls: session.toolCalls)
                    }
                }
            }
            .padding()
        }
    }
}

struct MetricsSectionView<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .font(.headline)
            }

            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CircularProgressView: View {
    let value: Double
    let total: Double
    let label: String
    let color: Color

    var progress: Double {
        guard total > 0 else { return 0 }
        return value / total
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .frame(width: 60, height: 60)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
                .monospacedDigit()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TimelineRow: View {
    let label: String
    let time: Date

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(time.formatted(date: .abbreviated, time: .standard))
                .fontWeight(.medium)
        }
    }
}

struct ToolCallBreakdownChart: View {
    let toolCalls: [ToolCall]

    var toolCounts: [(name: String, count: Int, color: Color)] {
        let grouped = Dictionary(grouping: toolCalls, by: { $0.name })
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .cyan]

        return grouped.enumerated().map { index, item in
            (name: item.key, count: item.value.count, color: colors[index % colors.count])
        }.sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(toolCounts, id: \.name) { tool in
                HStack {
                    Text(tool.name)
                        .frame(width: 100, alignment: .leading)

                    GeometryReader { geometry in
                        let width = geometry.size.width * CGFloat(tool.count) / CGFloat(toolCalls.count)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(tool.color)
                            .frame(width: max(width, 20))
                    }
                    .frame(height: 20)

                    Text("\(tool.count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
    }
}

#Preview {
    let store = SessionStore()
    return MetricsView(metrics: store.sessions[0].metrics, session: store.sessions[0])
}
