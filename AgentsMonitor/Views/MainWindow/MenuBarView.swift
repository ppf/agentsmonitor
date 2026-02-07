import SwiftUI

struct MenuBarView: View {
    @State private var currentPage: MenuBarPage = .main

    enum MenuBarPage {
        case main
        case settings
    }

    var body: some View {
        switch currentPage {
        case .main:
            MenuBarMainView(navigateToSettings: { currentPage = .settings })
        case .settings:
            MenuBarSettingsView(navigateBack: { currentPage = .main })
        }
    }
}

// MARK: - Shared Components

struct MenuBarSessionRow: View {
    let session: Session
    @Environment(\.appEnvironment) private var appEnvironment

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.green)
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

            ProgressView()
                .controlSize(.mini)
                .accessibilityIdentifier("menuBar.session.spinner")
        }
        .accessibilityElement(children: .contain)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityIdentifier("menuBar.sessionRow")
    }
}

struct MenuBarStat: View {
    let value: String
    let label: String

    var body: some View {
        let normalized = label.lowercased().replacingOccurrences(of: " ", with: "-")
        VStack(spacing: 2) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
                .accessibilityIdentifier("menuBar.stat.value.\(normalized)")

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("menuBar.stat.label.\(normalized)")
        }
    }
}

struct MenuBarButton: View {
    let title: String
    let icon: String
    let identifier: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isHovered ? Color.accentColor.opacity(0.1) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    MenuBarView()
        .environment(SessionStore(environment: .current))
        .environment(\.appEnvironment, .current)
}
