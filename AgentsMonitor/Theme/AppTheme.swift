import SwiftUI
import AppKit

typealias AppColor = SwiftUI.Color

enum AppTheme {
    // MARK: - Session Status Colors

    static let statusColors: [SessionStatus: AppColor] = [
        .running: .green,
        .paused: .yellow,
        .completed: .blue,
        .failed: .red,
        .waiting: .orange,
        .cancelled: .gray
    ]

    // MARK: - Message Role Colors

    static let roleColors: [MessageRole: AppColor] = [
        .user: .blue,
        .assistant: .purple,
        .system: .gray,
        .tool: .orange
    ]

    static let roleBackgroundColors: [MessageRole: AppColor] = [
        .user: AppColor.blue.opacity(0.1),
        .assistant: AppColor.purple.opacity(0.1),
        .system: AppColor.gray.opacity(0.1),
        .tool: AppColor.orange.opacity(0.1)
    ]

    // MARK: - Tool Call Status Colors

    static let toolCallStatusColors: [ToolCallStatus: AppColor] = [
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

    static func statusColor(for status: SessionStatus) -> AppColor {
        statusColors[status] ?? .gray
    }

    static func roleColor(for role: MessageRole) -> AppColor {
        roleColors[role] ?? .gray
    }

    static func roleBackgroundColor(for role: MessageRole) -> AppColor {
        roleBackgroundColors[role] ?? AppColor.gray.opacity(0.1)
    }

    static func toolCallStatusColor(for status: ToolCallStatus) -> AppColor {
        toolCallStatusColors[status] ?? .gray
    }

    static func agentTypeColor(for agentType: AgentType) -> AppColor {
        switch agentType {
        case .codex: return .orange
        case .claudeCode: return .blue
        }
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
