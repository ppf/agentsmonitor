import SwiftUI

struct MenuBarView: View {
    @State private var currentPage: MenuBarPage = .main

    enum MenuBarPage {
        case main
        case settings
    }

    var body: some View {
        ZStack {
            page(.main) {
                MenuBarMainView(
                    navigateToSettings: { currentPage = .settings },
                    isActive: currentPage == .main
                )
            }

            page(.settings) {
                MenuBarSettingsView(
                    navigateBack: { currentPage = .main },
                    isActive: currentPage == .settings
                )
            }
        }
        .frame(width: AppTheme.popoverWidth)
    }

    @ViewBuilder
    private func page<Content: View>(_ page: MenuBarPage, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(currentPage == page ? 1 : 0)
            .allowsHitTesting(currentPage == page)
            .accessibilityHidden(currentPage != page)
    }
}

// MARK: - Shared Components

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
                    .accessibilityHidden(true)
                Text(title)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, AppTheme.Spacing.medium)
            .background(isHovered ? AppTheme.hoverBackground : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel(title)
        .accessibilityHint(hint)
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    MenuBarView()
        .environment(SessionStore(environment: .current))
        .environment(\.appEnvironment, .current)
}
