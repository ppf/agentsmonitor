import AppKit
import SwiftTerm

enum TerminalThemeSelection: String, CaseIterable, Codable {
    case auto = "auto"
    case dracula = "dracula"
    case oneDark = "oneDark"
    case nord = "nord"
    case tokyoNight = "tokyoNight"
    case gruvboxDark = "gruvboxDark"
    case solarizedLight = "solarizedLight"
    case githubLight = "githubLight"

    var displayName: String {
        switch self {
        case .auto: return "Auto (follow system)"
        case .dracula: return "Dracula"
        case .oneDark: return "One Dark"
        case .nord: return "Nord"
        case .tokyoNight: return "Tokyo Night"
        case .gruvboxDark: return "Gruvbox Dark"
        case .solarizedLight: return "Solarized Light"
        case .githubLight: return "GitHub Light"
        }
    }

    var isDark: Bool {
        switch self {
        case .auto: return true
        case .dracula, .oneDark, .nord, .tokyoNight, .gruvboxDark: return true
        case .solarizedLight, .githubLight: return false
        }
    }
}

struct TerminalTheme {
    let id: TerminalThemeSelection
    let name: String
    let isDark: Bool
    let palette: [NSColor]
    let foreground: NSColor
    let background: NSColor
    let cursor: NSColor
    let selection: NSColor

    var swiftTermPalette: [SwiftTerm.Color] {
        palette.map { color in
            let srgb = color.usingColorSpace(.sRGB) ?? color
            let red = UInt16(max(0.0, min(1.0, srgb.redComponent)) * 65535.0)
            let green = UInt16(max(0.0, min(1.0, srgb.greenComponent)) * 65535.0)
            let blue = UInt16(max(0.0, min(1.0, srgb.blueComponent)) * 65535.0)
            return SwiftTerm.Color(red: red, green: green, blue: blue)
        }
    }
}

enum TerminalThemes {
    // MARK: - Theme Definitions

    static let dracula = TerminalTheme(
        id: .dracula,
        name: "Dracula",
        isDark: true,
        palette: [
            NSColor(hex: 0x21222C), // 0: black
            NSColor(hex: 0xFF5555), // 1: red
            NSColor(hex: 0x50FA7B), // 2: green
            NSColor(hex: 0xF1FA8C), // 3: yellow
            NSColor(hex: 0xBD93F9), // 4: blue
            NSColor(hex: 0xFF79C6), // 5: magenta
            NSColor(hex: 0x8BE9FD), // 6: cyan
            NSColor(hex: 0xF8F8F2), // 7: white
            NSColor(hex: 0x6272A4), // 8: bright black
            NSColor(hex: 0xFF6E6E), // 9: bright red
            NSColor(hex: 0x69FF94), // 10: bright green
            NSColor(hex: 0xFFFFA5), // 11: bright yellow
            NSColor(hex: 0xD6ACFF), // 12: bright blue
            NSColor(hex: 0xFF92DF), // 13: bright magenta
            NSColor(hex: 0xA4FFFF), // 14: bright cyan
            NSColor(hex: 0xFFFFFF), // 15: bright white
        ],
        foreground: NSColor(hex: 0xF8F8F2),
        background: NSColor(hex: 0x282A36),
        cursor: NSColor(hex: 0xF8F8F2),
        selection: NSColor(hex: 0x44475A)
    )

    static let oneDark = TerminalTheme(
        id: .oneDark,
        name: "One Dark",
        isDark: true,
        palette: [
            NSColor(hex: 0x1E2127), // 0: black
            NSColor(hex: 0xE06C75), // 1: red
            NSColor(hex: 0x98C379), // 2: green
            NSColor(hex: 0xE5C07B), // 3: yellow
            NSColor(hex: 0x61AFEF), // 4: blue
            NSColor(hex: 0xC678DD), // 5: magenta
            NSColor(hex: 0x56B6C2), // 6: cyan
            NSColor(hex: 0xABB2BF), // 7: white
            NSColor(hex: 0x5C6370), // 8: bright black
            NSColor(hex: 0xE06C75), // 9: bright red
            NSColor(hex: 0x98C379), // 10: bright green
            NSColor(hex: 0xE5C07B), // 11: bright yellow
            NSColor(hex: 0x61AFEF), // 12: bright blue
            NSColor(hex: 0xC678DD), // 13: bright magenta
            NSColor(hex: 0x56B6C2), // 14: bright cyan
            NSColor(hex: 0xFFFFFF), // 15: bright white
        ],
        foreground: NSColor(hex: 0xABB2BF),
        background: NSColor(hex: 0x282C34),
        cursor: NSColor(hex: 0x528BFF),
        selection: NSColor(hex: 0x3E4451)
    )

    static let nord = TerminalTheme(
        id: .nord,
        name: "Nord",
        isDark: true,
        palette: [
            NSColor(hex: 0x3B4252), // 0: black (nord1)
            NSColor(hex: 0xBF616A), // 1: red (nord11)
            NSColor(hex: 0xA3BE8C), // 2: green (nord14)
            NSColor(hex: 0xEBCB8B), // 3: yellow (nord13)
            NSColor(hex: 0x81A1C1), // 4: blue (nord9)
            NSColor(hex: 0xB48EAD), // 5: magenta (nord15)
            NSColor(hex: 0x88C0D0), // 6: cyan (nord8)
            NSColor(hex: 0xE5E9F0), // 7: white (nord5)
            NSColor(hex: 0x4C566A), // 8: bright black (nord3)
            NSColor(hex: 0xBF616A), // 9: bright red
            NSColor(hex: 0xA3BE8C), // 10: bright green
            NSColor(hex: 0xEBCB8B), // 11: bright yellow
            NSColor(hex: 0x81A1C1), // 12: bright blue
            NSColor(hex: 0xB48EAD), // 13: bright magenta
            NSColor(hex: 0x8FBCBB), // 14: bright cyan (nord7)
            NSColor(hex: 0xECEFF4), // 15: bright white (nord6)
        ],
        foreground: NSColor(hex: 0xD8DEE9),
        background: NSColor(hex: 0x2E3440),
        cursor: NSColor(hex: 0xD8DEE9),
        selection: NSColor(hex: 0x434C5E)
    )

    static let tokyoNight = TerminalTheme(
        id: .tokyoNight,
        name: "Tokyo Night",
        isDark: true,
        palette: [
            NSColor(hex: 0x15161E), // 0: black
            NSColor(hex: 0xF7768E), // 1: red
            NSColor(hex: 0x9ECE6A), // 2: green
            NSColor(hex: 0xE0AF68), // 3: yellow
            NSColor(hex: 0x7AA2F7), // 4: blue
            NSColor(hex: 0xBB9AF7), // 5: magenta
            NSColor(hex: 0x7DCFFF), // 6: cyan
            NSColor(hex: 0xA9B1D6), // 7: white
            NSColor(hex: 0x414868), // 8: bright black
            NSColor(hex: 0xF7768E), // 9: bright red
            NSColor(hex: 0x9ECE6A), // 10: bright green
            NSColor(hex: 0xE0AF68), // 11: bright yellow
            NSColor(hex: 0x7AA2F7), // 12: bright blue
            NSColor(hex: 0xBB9AF7), // 13: bright magenta
            NSColor(hex: 0x7DCFFF), // 14: bright cyan
            NSColor(hex: 0xC0CAF5), // 15: bright white
        ],
        foreground: NSColor(hex: 0xA9B1D6),
        background: NSColor(hex: 0x1A1B26),
        cursor: NSColor(hex: 0xC0CAF5),
        selection: NSColor(hex: 0x33467C)
    )

    static let gruvboxDark = TerminalTheme(
        id: .gruvboxDark,
        name: "Gruvbox Dark",
        isDark: true,
        palette: [
            NSColor(hex: 0x282828), // 0: black (bg0)
            NSColor(hex: 0xCC241D), // 1: red
            NSColor(hex: 0x98971A), // 2: green
            NSColor(hex: 0xD79921), // 3: yellow
            NSColor(hex: 0x458588), // 4: blue
            NSColor(hex: 0xB16286), // 5: magenta
            NSColor(hex: 0x689D6A), // 6: cyan
            NSColor(hex: 0xA89984), // 7: white (fg4)
            NSColor(hex: 0x928374), // 8: bright black (gray)
            NSColor(hex: 0xFB4934), // 9: bright red
            NSColor(hex: 0xB8BB26), // 10: bright green
            NSColor(hex: 0xFABD2F), // 11: bright yellow
            NSColor(hex: 0x83A598), // 12: bright blue
            NSColor(hex: 0xD3869B), // 13: bright magenta
            NSColor(hex: 0x8EC07C), // 14: bright cyan
            NSColor(hex: 0xEBDBB2), // 15: bright white (fg1)
        ],
        foreground: NSColor(hex: 0xEBDBB2),
        background: NSColor(hex: 0x282828),
        cursor: NSColor(hex: 0xEBDBB2),
        selection: NSColor(hex: 0x504945)
    )

    static let solarizedLight = TerminalTheme(
        id: .solarizedLight,
        name: "Solarized Light",
        isDark: false,
        palette: [
            NSColor(hex: 0x073642), // 0: black (base02)
            NSColor(hex: 0xDC322F), // 1: red
            NSColor(hex: 0x859900), // 2: green
            NSColor(hex: 0xB58900), // 3: yellow
            NSColor(hex: 0x268BD2), // 4: blue
            NSColor(hex: 0xD33682), // 5: magenta
            NSColor(hex: 0x2AA198), // 6: cyan
            NSColor(hex: 0xEEE8D5), // 7: white (base2)
            NSColor(hex: 0x002B36), // 8: bright black (base03)
            NSColor(hex: 0xCB4B16), // 9: bright red (orange)
            NSColor(hex: 0x586E75), // 10: bright green (base01)
            NSColor(hex: 0x657B83), // 11: bright yellow (base00)
            NSColor(hex: 0x839496), // 12: bright blue (base0)
            NSColor(hex: 0x6C71C4), // 13: bright magenta (violet)
            NSColor(hex: 0x93A1A1), // 14: bright cyan (base1)
            NSColor(hex: 0xFDF6E3), // 15: bright white (base3)
        ],
        foreground: NSColor(hex: 0x657B83),
        background: NSColor(hex: 0xFDF6E3),
        cursor: NSColor(hex: 0x657B83),
        selection: NSColor(hex: 0xEEE8D5)
    )

    static let githubLight = TerminalTheme(
        id: .githubLight,
        name: "GitHub Light",
        isDark: false,
        palette: [
            NSColor(hex: 0x24292E), // 0: black
            NSColor(hex: 0xD73A49), // 1: red
            NSColor(hex: 0x28A745), // 2: green
            NSColor(hex: 0xDBAB09), // 3: yellow
            NSColor(hex: 0x0366D6), // 4: blue
            NSColor(hex: 0x6F42C1), // 5: magenta
            NSColor(hex: 0x1B7C83), // 6: cyan
            NSColor(hex: 0x6A737D), // 7: white
            NSColor(hex: 0x959DA5), // 8: bright black
            NSColor(hex: 0xCB2431), // 9: bright red
            NSColor(hex: 0x22863A), // 10: bright green
            NSColor(hex: 0xB08800), // 11: bright yellow
            NSColor(hex: 0x005CC5), // 12: bright blue
            NSColor(hex: 0x5A32A3), // 13: bright magenta
            NSColor(hex: 0x3192AA), // 14: bright cyan
            NSColor(hex: 0x24292E), // 15: bright white
        ],
        foreground: NSColor(hex: 0x24292E),
        background: NSColor(hex: 0xFFFFFF),
        cursor: NSColor(hex: 0x24292E),
        selection: NSColor(hex: 0xC8C8FA)
    )

    // MARK: - Theme Access

    static func get(_ selection: TerminalThemeSelection) -> TerminalTheme {
        switch selection {
        case .auto, .dracula: return dracula
        case .oneDark: return oneDark
        case .nord: return nord
        case .tokyoNight: return tokyoNight
        case .gruvboxDark: return gruvboxDark
        case .solarizedLight: return solarizedLight
        case .githubLight: return githubLight
        }
    }

    static var defaultDark: TerminalTheme { dracula }
    static var defaultLight: TerminalTheme { solarizedLight }

    static func effectiveTheme(for selection: TerminalThemeSelection) -> TerminalTheme {
        if selection != .auto {
            return get(selection)
        }
        // Auto mode - follow system appearance
        // Check both NSApp and UserDefaults for more reliable detection
        let appearance = NSApp.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? defaultDark : defaultLight
    }

    /// Check if system is in dark mode
    static var systemIsDarkMode: Bool {
        if let appearance = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
            return appearance == .darkAqua
        }
        // Fallback: check UserDefaults
        let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
        return style?.lowercased() == "dark"
    }

    static var allThemes: [TerminalTheme] {
        [dracula, oneDark, nord, tokyoNight, gruvboxDark, solarizedLight, githubLight]
    }
}

// MARK: - NSColor Hex Extension

private extension NSColor {
    convenience init(hex: Int) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
