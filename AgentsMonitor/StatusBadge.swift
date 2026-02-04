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
            case .small: return 8
            case .regular: return 12
            case .large: return 16
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
            case .regular: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .large: return EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            }
        }
        
        var fontSize: Font {
            switch self {
            case .small: return .caption2
            case .regular: return .caption
            case .large: return .callout
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: size.iconSize))
            
            Text(status.rawValue)
                .font(size.fontSize)
                .fontWeight(.medium)
        }
        .padding(size.padding)
        .background(statusColor.opacity(0.15))
        .foregroundColor(statusColor)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(status.rawValue)")
    }
    
    private var statusColor: Color {
        AppTheme.statusColors[status] ?? .secondary
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(SessionStatus.allCases, id: \.self) { status in
            HStack {
                StatusBadge(status: status, size: .small)
                StatusBadge(status: status, size: .regular)
                StatusBadge(status: status, size: .large)
            }
        }
    }
    .padding()
}
