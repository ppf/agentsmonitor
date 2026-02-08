import SwiftUI

struct MenuBarMainView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.appEnvironment) private var appEnvironment

    let navigateToSettings: () -> Void

    @State private var expandedSessionId: UUID?

    var body: some View {
        let activeSessions = sessionStore.activeSessions
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Agents Monitor")
                    .font(.headline)
                    .accessibilityIdentifier("menuBar.header.title")
                Spacer()
                Text("\(activeSessions.count) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("menuBar.header.activeCount")
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Active Sessions
                    if !activeSessions.isEmpty {
                        Text("ACTIVE SESSIONS")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            .accessibilityIdentifier("menuBar.section.active")

                        ForEach(activeSessions.prefix(5)) { session in
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

                        if activeSessions.count > 5 {
                            Text("+\(activeSessions.count - 5) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                                .accessibilityIdentifier("menuBar.session.more")
                        }

                        Divider()
                            .padding(.vertical, 4)
                    }

                    // Usage Stats
                    VStack(alignment: .leading, spacing: 8) {
                        Text("USAGE")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        HStack(spacing: 24) {
                            MenuBarStat(value: "\(sessionStore.sessions.count)", label: "Total")
                            MenuBarStat(value: "\(sessionStore.completedSessions.count)", label: "Completed")
                            MenuBarStat(value: "\(sessionStore.failedSessions.count)", label: "Failed")
                        }
                        .padding(.horizontal)

                        // Extended stats row
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 2) {
                                Label(sessionStore.formattedAggregateTokens, systemImage: "number")
                                    .font(.caption)
                                Label(sessionStore.formattedTotalRuntime, systemImage: "clock")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Label(sessionStore.formattedAggregateCost, systemImage: "dollarsign.circle")
                                    .font(.caption)
                                Label("Avg: \(sessionStore.formattedAverageDuration)", systemImage: "timer")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    }
                }
            }

            Divider()

            // Actions
            VStack(spacing: 0) {
                MenuBarButton(title: "New Session", icon: "plus", identifier: "menuBar.action.newSession") {
                    sessionStore.createNewSession()
                }

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
        .frame(width: 300)
        .accessibilityIdentifier("menuBar.view")
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
            // Tap target row
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

                        Text(session.formattedDuration(asOf: appEnvironment.now))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("menuBar.session.duration")
                    }

                    Spacer()

                    if session.status == .running || session.status == .waiting {
                        ProgressView()
                            .controlSize(.mini)
                            .accessibilityIdentifier("menuBar.session.spinner")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("menuBar.sessionRow")

            // Expanded metrics
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
        return m.totalTokens > 0 || m.toolCallCount > 0 || m.apiCalls > 0 || m.cost > 0
    }

    @ViewBuilder
    private var expandedMetrics: some View {
        if hasMetrics {
            let m = session.metrics
            let contextPercent = Int(m.contextWindowUsage * 100)
            let contextColor: Color = contextPercent > 80 ? .red : (contextPercent > 50 ? .orange : .green)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    metricItem(icon: "number", text: m.formattedTokens)
                    Spacer()
                    metricItem(icon: "wrench.and.screwdriver", text: "\(m.toolCallCount) tools")
                }
                HStack {
                    metricItem(icon: "arrow.up.arrow.down", text: "\(m.apiCalls) API")
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption2)
                        Text("\(contextPercent)%")
                            .font(.caption)
                            .foregroundStyle(contextColor)
                    }
                }
                HStack {
                    metricItem(icon: "dollarsign.circle", text: m.formattedCost)
                    Spacer()
                    if !m.modelName.isEmpty {
                        metricItem(icon: "cpu", text: m.modelName)
                    }
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
