import SwiftUI

struct StatusBadge: View {
    let status: SessionStatus
    var size: BadgeSize = .regular

    enum BadgeSize {
        case small
        case regular
        case large

        var iconSize: CGFloat {
            switch self {
            case .small: return 12
            case .regular: return 16
            case .large: return 20
            }
        }

        var fontSize: Font {
            switch self {
            case .small: return .caption2
            case .regular: return .caption
            case .large: return .callout
            }
        }

        var padding: CGFloat {
            switch self {
            case .small: return 4
            case .regular: return 6
            case .large: return 8
            }
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if status == .running {
                PulsingDot(color: statusColor)
                    .frame(width: size.iconSize * 0.5, height: size.iconSize * 0.5)
            } else {
                Image(systemName: status.icon)
                    .font(.system(size: size.iconSize * 0.7))
            }

            if size != .small {
                Text(status.rawValue)
                    .font(size.fontSize)
            }
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, size.padding)
        .padding(.vertical, size.padding * 0.5)
        .background(statusColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .running: return .green
        case .paused: return .yellow
        case .completed: return .blue
        case .failed: return .red
        case .waiting: return .orange
        }
    }
}

struct PulsingDot: View {
    let color: Color
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .scaleEffect(isAnimating ? 1.5 : 1)
                .opacity(isAnimating ? 0 : 0.5)

            Circle()
                .fill(color)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1)
                .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            StatusBadge(status: .running, size: .small)
            StatusBadge(status: .running, size: .regular)
            StatusBadge(status: .running, size: .large)
        }

        HStack(spacing: 16) {
            StatusBadge(status: .paused)
            StatusBadge(status: .completed)
            StatusBadge(status: .failed)
            StatusBadge(status: .waiting)
        }
    }
    .padding()
}
