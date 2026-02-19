import Foundation
import SwiftUI

struct MenuBarMainView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.appEnvironment) private var appEnvironment
    @AppStorage("refreshInterval") private var refreshInterval: Double = 5.0
    @AppStorage("codexEnabled") private var codexEnabled = true
    @AppStorage("claudeCodeEnabled") private var claudeCodeEnabled = true

    let navigateToSettings: () -> Void

    @State private var expandedSessionId: UUID?
    @State private var selectedSourceTab: SessionSourceTab = .all
    private let usageRefreshInterval: Double = 60.0

    private var availableSourceTabs: [SessionSourceTab] {
        var tabs: [SessionSourceTab] = [.all]
        if codexEnabled {
            tabs.append(.codex)
        }
        if claudeCodeEnabled {
            tabs.append(.claudeCode)
        }
        return tabs
    }

    private var filteredSessions: [Session] {
        sessionStore.visibleSessions(
            for: selectedSourceTab,
            codexEnabled: codexEnabled,
            claudeCodeEnabled: claudeCodeEnabled
        )
    }

    private var filteredRunningCount: Int {
        filteredSessions.filter { $0.status == .running }.count
    }

    private var sevenDaySessions: [Session] {
        let now = appEnvironment.now
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        return filteredSessions.filter { $0.startedAt >= cutoff }
    }

    private var filteredAggregateTokens: Int {
        sevenDaySessions.reduce(0) { $0 + $1.metrics.totalTokens }
    }

    private var filteredAggregateCost: Double {
        sevenDaySessions.reduce(0) { $0 + $1.metrics.cost }
    }

    private var areAllSourcesDisabled: Bool {
        !codexEnabled && !claudeCodeEnabled
    }

    private var showUsageSection: Bool {
        true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Agents Monitor")
                    .font(.headline)
                    .accessibilityIdentifier("menuBar.header.title")
                Spacer()
                let running = filteredRunningCount
                if running > 0 {
                    Text("\(running) active")
                        .font(.caption)
                        .foregroundStyle(AppTheme.statusColor(for: .running))
                        .accessibilityIdentifier("menuBar.header.activeCount")
                } else {
                    Text("\(filteredSessions.count) sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("menuBar.header.activeCount")
                }
            }
            .padding()

            Divider()

            if availableSourceTabs.count > 1 {
                HStack(spacing: 6) {
                    ForEach(availableSourceTabs) { tab in
                        sourceTabButton(for: tab)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 6)
                .padding(.bottom, 2)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if showUsageSection {
                        // Usage Limits
                        usageLimitsSection

                        Divider()
                            .padding(.vertical, 4)
                    }

                    // Sessions
                    sessionsSection
                }
            }

            Divider()

            // Actions
            VStack(spacing: 0) {
                MenuBarButton(title: "Refresh", icon: "arrow.clockwise", identifier: "menuBar.action.refresh") {
                    Task {
                        await sessionStore.refreshAll()
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
        .task(id: usageRefreshInterval) {
            guard usageRefreshInterval > 0 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(usageRefreshInterval))
                await sessionStore.fetchUsageData()
            }
        }
        .onChange(of: codexEnabled) { _, _ in
            syncSelectedTabWithAvailability()
        }
        .onChange(of: claudeCodeEnabled) { _, _ in
            syncSelectedTabWithAvailability()
        }
        .onChange(of: selectedSourceTab) { _, _ in
            expandedSessionId = nil
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

            VStack(alignment: .leading, spacing: 6) {
                // Claude Code usage
                if selectedSourceTab == .all || selectedSourceTab == .claudeCode {
                    if let usage = sessionStore.usageData {
                        usageBar(label: "5-hour", utilization: usage.fiveHour.utilization, resetsAt: usage.fiveHour.resetsAt)
                        usageBar(label: "7-day", utilization: usage.sevenDay.utilization, resetsAt: usage.sevenDay.resetsAt)
                        if let sonnet = usage.sevenDaySonnet {
                            usageBar(label: "Sonnet 7d", utilization: sonnet.utilization, resetsAt: sonnet.resetsAt)
                        }
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
                    } else {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("Loading usage...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Codex usage
                if selectedSourceTab == .all || selectedSourceTab == .codex {
                    if let codex = sessionStore.codexUsage {
                        usageBar(label: "Codex 5hr", utilization: codex.primary.utilization, resetsAt: codex.primary.resetsAt, tint: AppTheme.agentTypeColor(for: .codex))
                        usageBar(label: "Codex 7d", utilization: codex.secondary.utilization, resetsAt: codex.secondary.resetsAt, tint: AppTheme.agentTypeColor(for: .codex))
                    }
                }
            }
            .padding(.horizontal)

            // 7-day aggregate cost
            HStack(spacing: 4) {
                Text("7d")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                HStack(spacing: 12) {
                    Label(SessionStore.formatCost(filteredAggregateCost), systemImage: "dollarsign.circle")
                        .font(.caption)
                    Label(SessionStore.formatTokenCount(filteredAggregateTokens), systemImage: "number")
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
    }

    private func usageBar(label: String, utilization: Double, resetsAt: String?, tint: Color? = nil) -> some View {
        let clampedUtilization = min(max(utilization, 0), 1)
        let barColor = tint ?? utilizationColor(utilization)
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text("\(Int((utilization * 100).rounded()))%")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(barColor)
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
                        .fill(barColor)
                        .frame(width: geo.size.width * clampedUtilization)
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
        let allSessions = filteredSessions

        if areAllSourcesDisabled {
            VStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text("No agent sources enabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Enable Codex or Claude Code in Settings")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else if allSessions.isEmpty && !sessionStore.isLoading {
            VStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text("No sessions found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(emptyStateSubtitle)
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

    private func sourceTabButton(for tab: SessionSourceTab) -> some View {
        let isSelected = selectedSourceTab == tab
        return Button {
            selectedSourceTab = tab
        } label: {
            Text(tab.title)
                .font(.caption)
                .foregroundStyle(isSelected ? AppTheme.tabSelectedForeground : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? AppTheme.tabSelectedBackground : AppTheme.tabBackground)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityHint("Filters by agent source")
        .accessibilityIdentifier(tab.accessibilityIdentifier)
    }

    private var emptyStateSubtitle: String {
        if codexEnabled && claudeCodeEnabled {
            return "Start Codex or Claude Code to see sessions"
        }
        if codexEnabled {
            return "Start Codex to see sessions"
        }
        return "Start Claude Code to see sessions"
    }

    private func syncSelectedTabWithAvailability() {
        if !availableSourceTabs.contains(selectedSourceTab) {
            selectedSourceTab = .all
        }
    }

}

private extension SessionSourceTab {
    var title: String {
        switch self {
        case .all: "All"
        case .codex: "Codex"
        case .claudeCode: "Claude Code"
        }
    }

    var accessibilityIdentifier: String {
        "menuBar.tab.\(rawValue)"
    }

    var accessibilityLabel: String {
        "\(title) sessions"
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

                    PulsatingStatusDot(status: session.status)
                        .accessibilityIdentifier("menuBar.session.status")

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(session.name)
                                .lineLimit(1)
                                .accessibilityIdentifier("menuBar.session.name")
                            Text(session.agentType == .codex ? "CX" : "CC")
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundStyle(AppTheme.agentTypeColor(for: session.agentType))
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(AppTheme.agentTypeColor(for: session.agentType).opacity(0.12))
                                .cornerRadius(3)
                        }

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

                    Text(session.relativeTimeString)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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

// MARK: - Pulsating Status Dot

struct PulsatingStatusDot: View {
    let status: SessionStatus
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if status == .running && !reduceMotion {
                Circle()
                    .fill(AppTheme.statusColor(for: status).opacity(0.3))
                    .frame(width: 14, height: 14)
                    .scaleEffect(isPulsing ? 1.0 : 0.5)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: isPulsing)
            }
            Circle()
                .fill(AppTheme.statusColor(for: status))
                .frame(width: 8, height: 8)
        }
        .frame(width: 14, height: 14)
        .accessibilityLabel("Session \(status.rawValue)")
        .onAppear {
            if status == .running {
                isPulsing = true
            }
        }
        .onChange(of: status) { _, newStatus in
            isPulsing = newStatus == .running
        }
    }
}
