import SwiftUI
import AppKit
import SwiftTerm

typealias AppColor = SwiftUI.Color

/// Centralized theme configuration for consistent styling across the app
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

    // MARK: - Terminal Colors (Catppuccin Mocha)

    static let terminalBackground = AppColor(nsColor: terminalBackgroundNS)
    static let terminalForeground = AppColor(nsColor: terminalForegroundNS)

    static let terminalBackgroundNS = NSColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0)  // #1e1e2e
    static let terminalForegroundNS = NSColor(red: 0.80, green: 0.84, blue: 0.96, alpha: 1.0)  // #cdd6f4

    static let terminalColors: [NSColor] = [
        // Standard colors (0-7)
        NSColor(red: 0.27, green: 0.28, blue: 0.35, alpha: 1.0),  // 0: black #45475a
        NSColor(red: 0.95, green: 0.55, blue: 0.66, alpha: 1.0),  // 1: red #f38ba8
        NSColor(red: 0.65, green: 0.89, blue: 0.63, alpha: 1.0),  // 2: green #a6e3a1
        NSColor(red: 0.98, green: 0.90, blue: 0.59, alpha: 1.0),  // 3: yellow #f9e2af
        NSColor(red: 0.54, green: 0.71, blue: 0.98, alpha: 1.0),  // 4: blue #89b4fa
        NSColor(red: 0.80, green: 0.62, blue: 0.93, alpha: 1.0),  // 5: magenta #cba6f7
        NSColor(red: 0.58, green: 0.89, blue: 0.88, alpha: 1.0),  // 6: cyan #94e2d5
        NSColor(red: 0.73, green: 0.74, blue: 0.80, alpha: 1.0),  // 7: white #bac2de

        // Bright colors (8-15)
        NSColor(red: 0.36, green: 0.36, blue: 0.44, alpha: 1.0),  // 8: bright black #585b70
        NSColor(red: 0.95, green: 0.55, blue: 0.66, alpha: 1.0),  // 9: bright red #f38ba8
        NSColor(red: 0.65, green: 0.89, blue: 0.63, alpha: 1.0),  // 10: bright green #a6e3a1
        NSColor(red: 0.98, green: 0.90, blue: 0.59, alpha: 1.0),  // 11: bright yellow #f9e2af
        NSColor(red: 0.54, green: 0.71, blue: 0.98, alpha: 1.0),  // 12: bright blue #89b4fa
        NSColor(red: 0.80, green: 0.62, blue: 0.93, alpha: 1.0),  // 13: bright magenta #cba6f7
        NSColor(red: 0.58, green: 0.89, blue: 0.88, alpha: 1.0),  // 14: bright cyan #94e2d5
        NSColor(red: 0.65, green: 0.66, blue: 0.72, alpha: 1.0),  // 15: bright white #a6adc8
    ]

    static var terminalPalette: [SwiftTerm.Color] {
        terminalColors.map { color in
            let srgb = color.usingColorSpace(.sRGB) ?? color
            let red = UInt16(max(0.0, min(1.0, srgb.redComponent)) * 65535.0)
            let green = UInt16(max(0.0, min(1.0, srgb.greenComponent)) * 65535.0)
            let blue = UInt16(max(0.0, min(1.0, srgb.blueComponent)) * 65535.0)
            return SwiftTerm.Color(red: red, green: green, blue: blue)
        }
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
