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
    let hint: String
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
        .accessibilityHint(hint)
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    MenuBarView()
        .environment(SessionStore(environment: .current))
        .environment(\.appEnvironment, .current)
}
