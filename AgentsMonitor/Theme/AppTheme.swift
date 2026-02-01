import SwiftUI

/// Centralized theme configuration for consistent styling across the app
enum AppTheme {
    // MARK: - Session Status Colors

    static let statusColors: [SessionStatus: Color] = [
        .running: .green,
        .paused: .yellow,
        .completed: .blue,
        .failed: .red,
        .waiting: .orange
    ]

    // MARK: - Message Role Colors

    static let roleColors: [MessageRole: Color] = [
        .user: .blue,
        .assistant: .purple,
        .system: .gray,
        .tool: .orange
    ]

    static let roleBackgroundColors: [MessageRole: Color] = [
        .user: Color.blue.opacity(0.1),
        .assistant: Color.purple.opacity(0.1),
        .system: Color.gray.opacity(0.1),
        .tool: Color.orange.opacity(0.1)
    ]

    // MARK: - Tool Call Status Colors

    static let toolCallStatusColors: [ToolCallStatus: Color] = [
        .pending: .gray,
        .running: .blue,
        .completed: .green,
        .failed: .red
    ]

    // MARK: - Font Sizes

    enum FontSize: Int, CaseIterable {
        case small = 11
        case medium = 12
        case large = 14

        var label: String {
            switch self {
            case .small: return "Small (11pt)"
            case .medium: return "Medium (12pt)"
            case .large: return "Large (14pt)"
            }
        }

        var cgFloat: CGFloat {
            CGFloat(rawValue)
        }
    }

    // MARK: - Spacing

    enum Spacing {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
    }

    // MARK: - Animation Durations

    enum Animation {
        static let fast: Double = 0.15
        static let normal: Double = 0.25
        static let slow: Double = 0.4
    }
}

// MARK: - Environment Key for Code Font Size

private struct CodeFontSizeKey: EnvironmentKey {
    static let defaultValue: Int = 12
}

extension EnvironmentValues {
    var codeFontSize: Int {
        get { self[CodeFontSizeKey.self] }
        set { self[CodeFontSizeKey.self] = newValue }
    }
}
