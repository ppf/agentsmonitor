import AppKit
import SwiftTerm

enum TerminalThemeSelection: String, CaseIterable {
    case auto = "auto"
    case light = "light"
    case dark = "dark"
    case solarizedLight = "solarizedLight"
    case solarizedDark = "solarizedDark"
}

struct TerminalTheme {
    let background: NSColor
    let foreground: NSColor
    let swiftTermPalette: [NSColor]
}

enum TerminalThemes {
    static func effectiveTheme(for selection: TerminalThemeSelection) -> TerminalTheme {
        switch selection {
        case .auto:
            return NSApp.effectiveAppearance.name == .darkAqua ? darkTheme : lightTheme
        case .light:
            return lightTheme
        case .dark:
            return darkTheme
        case .solarizedLight:
            return solarizedLightTheme
        case .solarizedDark:
            return solarizedDarkTheme
        }
    }
    
    // MARK: - Light Theme
    static let lightTheme = TerminalTheme(
        background: NSColor(white: 1.0, alpha: 1.0),
        foreground: NSColor(white: 0.0, alpha: 1.0),
        swiftTermPalette: [
            // Normal colors (0-7)
            NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),      // Black
            NSColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 1.0),      // Red
            NSColor(red: 0.0, green: 0.8, blue: 0.0, alpha: 1.0),      // Green
            NSColor(red: 0.8, green: 0.8, blue: 0.0, alpha: 1.0),      // Yellow
            NSColor(red: 0.0, green: 0.0, blue: 0.8, alpha: 1.0),      // Blue
            NSColor(red: 0.8, green: 0.0, blue: 0.8, alpha: 1.0),      // Magenta
            NSColor(red: 0.0, green: 0.8, blue: 0.8, alpha: 1.0),      // Cyan
            NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0),      // White
            
            // Bright colors (8-15)
            NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0),      // Bright Black
            NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),      // Bright Red
            NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0),      // Bright Green
            NSColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0),      // Bright Yellow
            NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0),      // Bright Blue
            NSColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0),      // Bright Magenta
            NSColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0),      // Bright Cyan
            NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),      // Bright White
        ]
    )
    
    // MARK: - Dark Theme
    static let darkTheme = TerminalTheme(
        background: NSColor(red: 0.117, green: 0.117, blue: 0.117, alpha: 1.0),
        foreground: NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0),
        swiftTermPalette: [
            // Normal colors (0-7)
            NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0),      // Black
            NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0),      // Red
            NSColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 1.0),      // Green
            NSColor(red: 0.9, green: 0.9, blue: 0.3, alpha: 1.0),      // Yellow
            NSColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0),      // Blue
            NSColor(red: 0.9, green: 0.3, blue: 0.9, alpha: 1.0),      // Magenta
            NSColor(red: 0.3, green: 0.9, blue: 0.9, alpha: 1.0),      // Cyan
            NSColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0),      // White
            
            // Bright colors (8-15)
            NSColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0),      // Bright Black
            NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0),      // Bright Red
            NSColor(red: 0.4, green: 1.0, blue: 0.4, alpha: 1.0),      // Bright Green
            NSColor(red: 1.0, green: 1.0, blue: 0.4, alpha: 1.0),      // Bright Yellow
            NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0),      // Bright Blue
            NSColor(red: 1.0, green: 0.4, blue: 1.0, alpha: 1.0),      // Bright Magenta
            NSColor(red: 0.4, green: 1.0, blue: 1.0, alpha: 1.0),      // Bright Cyan
            NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),      // Bright White
        ]
    )
    
    // MARK: - Solarized Light Theme
    static let solarizedLightTheme = TerminalTheme(
        background: NSColor(red: 0.992, green: 0.965, blue: 0.890, alpha: 1.0),
        foreground: NSColor(red: 0.396, green: 0.482, blue: 0.514, alpha: 1.0),
        swiftTermPalette: [
            NSColor(red: 0.027, green: 0.212, blue: 0.259, alpha: 1.0),
            NSColor(red: 0.863, green: 0.196, blue: 0.184, alpha: 1.0),
            NSColor(red: 0.522, green: 0.600, blue: 0.000, alpha: 1.0),
            NSColor(red: 0.710, green: 0.537, blue: 0.000, alpha: 1.0),
            NSColor(red: 0.149, green: 0.545, blue: 0.824, alpha: 1.0),
            NSColor(red: 0.827, green: 0.212, blue: 0.510, alpha: 1.0),
            NSColor(red: 0.165, green: 0.631, blue: 0.596, alpha: 1.0),
            NSColor(red: 0.933, green: 0.910, blue: 0.835, alpha: 1.0),
            NSColor(red: 0.000, green: 0.169, blue: 0.212, alpha: 1.0),
            NSColor(red: 0.796, green: 0.294, blue: 0.086, alpha: 1.0),
            NSColor(red: 0.345, green: 0.431, blue: 0.459, alpha: 1.0),
            NSColor(red: 0.396, green: 0.482, blue: 0.514, alpha: 1.0),
            NSColor(red: 0.514, green: 0.580, blue: 0.588, alpha: 1.0),
            NSColor(red: 0.424, green: 0.443, blue: 0.769, alpha: 1.0),
            NSColor(red: 0.576, green: 0.631, blue: 0.631, alpha: 1.0),
            NSColor(red: 0.992, green: 0.965, blue: 0.890, alpha: 1.0),
        ]
    )
    
    // MARK: - Solarized Dark Theme
    static let solarizedDarkTheme = TerminalTheme(
        background: NSColor(red: 0.000, green: 0.169, blue: 0.212, alpha: 1.0),
        foreground: NSColor(red: 0.514, green: 0.580, blue: 0.588, alpha: 1.0),
        swiftTermPalette: [
            NSColor(red: 0.027, green: 0.212, blue: 0.259, alpha: 1.0),
            NSColor(red: 0.863, green: 0.196, blue: 0.184, alpha: 1.0),
            NSColor(red: 0.522, green: 0.600, blue: 0.000, alpha: 1.0),
            NSColor(red: 0.710, green: 0.537, blue: 0.000, alpha: 1.0),
            NSColor(red: 0.149, green: 0.545, blue: 0.824, alpha: 1.0),
            NSColor(red: 0.827, green: 0.212, blue: 0.510, alpha: 1.0),
            NSColor(red: 0.165, green: 0.631, blue: 0.596, alpha: 1.0),
            NSColor(red: 0.933, green: 0.910, blue: 0.835, alpha: 1.0),
            NSColor(red: 0.000, green: 0.169, blue: 0.212, alpha: 1.0),
            NSColor(red: 0.796, green: 0.294, blue: 0.086, alpha: 1.0),
            NSColor(red: 0.345, green: 0.431, blue: 0.459, alpha: 1.0),
            NSColor(red: 0.396, green: 0.482, blue: 0.514, alpha: 1.0),
            NSColor(red: 0.514, green: 0.580, blue: 0.588, alpha: 1.0),
            NSColor(red: 0.424, green: 0.443, blue: 0.769, alpha: 1.0),
            NSColor(red: 0.576, green: 0.631, blue: 0.631, alpha: 1.0),
            NSColor(red: 0.992, green: 0.965, blue: 0.890, alpha: 1.0),
        ]
    )
}
