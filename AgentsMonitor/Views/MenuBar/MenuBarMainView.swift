import SwiftUI

struct MenuBarMainView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.appEnvironment) private var appEnvironment
    @AppStorage("refreshInterval") private var refreshInterval: Double = 5.0

    let navigateToSettings: () -> Void

    @State private var expandedSessionId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Agents Monitor")
                    .font(.headline)
                    .accessibilityIdentifier("menuBar.header.title")
                Spacer()
                let running = sessionStore.runningSessions.count
                if running > 0 {
                    Text("\(running) active")
                        .font(.caption)
                        .foregroundStyle(AppTheme.statusColor(for: .running))
                        .accessibilityIdentifier("menuBar.header.activeCount")
                } else {
                    Text("\(sessionStore.sessions.count) sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("menuBar.header.activeCount")
                }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Usage Limits
                    usageLimitsSection

                    Divider()
                        .padding(.vertical, 4)

                    // Sessions
                    sessionsSection
                }
            }

            Divider()

            // Actions
            VStack(spacing: 0) {
                MenuBarButton(title: "Refresh", icon: "arrow.clockwise", identifier: "menuBar.action.refresh") {
                    Task {
                        await sessionStore.refresh()
                    }
                }

                Divider()

                MenuBarButton(title: "Settings...", icon: "gearshape", identifier: "menuBar.action.settings") {
                    navigateToSettings()
                }

                MenuBarButton(title: "Quit", icon: "power", identifier: "menuBar.action.quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .frame(width: 320)
        .task(id: refreshInterval) {
            guard refreshInterval > 0 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(refreshInterval))
                await sessionStore.refresh()
            }
        }
        .accessibilityIdentifier("menuBar.view")
    }

    // MARK: - Usage Limits Section

    @ViewBuilder
    private var usageLimitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("USAGE LIMITS")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)

            if let usage = sessionStore.usageData {
                VStack(alignment: .leading, spacing: 6) {
                    usageBar(label: "5-hour", utilization: usage.fiveHour.utilization, resetsAt: usage.fiveHour.resetsAt)
                    usageBar(label: "7-day", utilization: usage.sevenDay.utilization, resetsAt: usage.sevenDay.resetsAt)
                    if let sonnet = usage.sevenDaySonnet {
                        usageBar(label: "Sonnet 7d", utilization: sonnet.utilization, resetsAt: sonnet.resetsAt)
                    }
                }
                .padding(.horizontal)
            } else if let usageError = sessionStore.usageError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(usageError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal)
            } else {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Loading usage...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }

            // Aggregate cost
            HStack(spacing: 16) {
                Label(sessionStore.formattedAggregateCost, systemImage: "dollarsign.circle")
                    .font(.caption)
                Label(sessionStore.formattedAggregateTokens, systemImage: "number")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
    }

    private func usageBar(label: String, utilization: Double, resetsAt: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text("\(Int(utilization * 100))%")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(utilizationColor(utilization))
                if let resetsAt {
                    Text("resets \(formatResetTime(resetsAt))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(utilizationColor(utilization))
                        .frame(width: max(geo.size.width * utilization, 0))
                }
            }
            .frame(height: 4)
        }
    }

    private func utilizationColor(_ value: Double) -> Color {
        if value > 0.9 { return .red }
        if value > 0.7 { return .orange }
        return .green
    }

    private func formatResetTime(_ iso: String) -> String {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        guard let date = fractional.date(from: iso) ?? plain.date(from: iso) else {
            return iso
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Sessions Section

    @ViewBuilder
    private var sessionsSection: some View {
        let allSessions = sessionStore.sessions

        if allSessions.isEmpty && !sessionStore.isLoading {
            VStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text("No sessions found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Start Claude Code to see sessions")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else {
            Text("SESSIONS")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 4)

            ForEach(allSessions.prefix(20)) { session in
                MenuBarExpandableSessionRow(
                    session: session,
                    isExpanded: expandedSessionId == session.id,
                    onToggle: {
                        withAnimation(.easeInOut(duration: AppTheme.Animation.fast)) {
                            expandedSessionId = expandedSessionId == session.id ? nil : session.id
                        }
                    }
                )
            }

            if allSessions.count > 20 {
                Text("+\(allSessions.count - 20) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            }
        }
    }

}

// MARK: - Expandable Session Row

struct MenuBarExpandableSessionRow: View {
    let session: Session
    let isExpanded: Bool
    let onToggle: () -> Void
    @Environment(\.appEnvironment) private var appEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12)

                    Circle()
                        .fill(AppTheme.statusColor(for: session.status))
                        .frame(width: 8, height: 8)
                        .accessibilityIdentifier("menuBar.session.status")

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.name)
                            .lineLimit(1)
                            .accessibilityIdentifier("menuBar.session.name")

                        HStack(spacing: 4) {
                            if let project = session.shortProjectName {
                                Text(project)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            if let branch = session.gitBranch {
                                Text(branch)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(AppTheme.roleColor(for: .assistant).opacity(0.15))
                                    .cornerRadius(3)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    if session.status == .running {
                        ProgressView()
                            .controlSize(.mini)
                            .accessibilityIdentifier("menuBar.session.spinner")
                    } else {
                        Text(session.relativeTimeString)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("menuBar.sessionRow")

            if isExpanded {
                expandedMetrics
                    .padding(.leading, 32)
                    .padding(.trailing)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityIdentifier("menuBar.session.expandedMetrics")
            }
        }
    }

    private var hasMetrics: Bool {
        let m = session.metrics
        return m.totalTokens > 0 || m.apiCalls > 0 || m.cost > 0
    }

    @ViewBuilder
    private var expandedMetrics: some View {
        if hasMetrics {
            let m = session.metrics

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    metricItem(icon: "number", text: m.formattedTokens)
                    Spacer()
                    metricItem(icon: "arrow.up.arrow.down", text: "\(m.apiCalls) calls")
                }
                HStack {
                    metricItem(icon: "dollarsign.circle", text: m.formattedCost)
                    Spacer()
                    if !m.modelName.isEmpty {
                        metricItem(icon: "cpu", text: m.modelName)
                    }
                }
                if let prompt = session.firstPrompt, !prompt.isEmpty {
                    Text(prompt)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
            Text("No metrics available")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func metricItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .lineLimit(1)
        }
    }
}
