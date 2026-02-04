import SwiftUI

enum AppTheme {
    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let extraLarge: CGFloat = 16
    }
    
    enum Spacing {
        static let tiny: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
    }
    
    static let statusColors: [SessionStatus: Color] = [
        .running: .green,
        .paused: .yellow,
        .completed: .blue,
        .failed: .red,
        .waiting: .orange,
        .cancelled: .gray
    ]
    
    static let toolCallStatusColors: [ToolCallStatus: Color] = [
        .running: .blue,
        .completed: .green,
        .failed: .red
    ]
    
    enum FontSize: Int, CaseIterable {
        case extraSmall = 10
        case small = 11
        case regular = 12
        case medium = 13
        case large = 14
        case extraLarge = 16
        
        var label: String {
            switch self {
            case .extraSmall: return "Extra Small"
            case .small: return "Small"
            case .regular: return "Regular"
            case .medium: return "Medium"
            case .large: return "Large"
            case .extraLarge: return "Extra Large"
            }
        }
    }
}
// MARK: - Environment Values

private struct CodeFontSizeKey: EnvironmentKey {
    static let defaultValue: Int = 12
}

extension EnvironmentValues {
    var codeFontSize: Int {
        get { self[CodeFontSizeKey.self] }
        set { self[CodeFontSizeKey.self] = newValue }
    }
}

