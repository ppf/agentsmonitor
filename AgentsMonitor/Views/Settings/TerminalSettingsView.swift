import SwiftUI
import SwiftUI

struct TerminalSettingsView: View {
    @AppStorage("terminalTheme") private var terminalTheme: String = "auto"
    @AppStorage("terminalFontFamily") private var terminalFontFamily: String = "SF Mono"
    @AppStorage("terminalFontSize") private var terminalFontSize: Int = 13
    @AppStorage("terminalScrollback") private var terminalScrollback: Int = 1000

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Color scheme", selection: $terminalTheme) {
                    ForEach(TerminalThemeSelection.allCases, id: \.rawValue) { theme in
                        HStack {
                            ThemePreviewSwatch(theme: theme)
                            Text(theme.displayName)
                        }
                        .tag(theme.rawValue)
                    }
                }
                .accessibilityLabel("Terminal color scheme")

                if terminalTheme == "auto" {
                    let effective = TerminalThemes.effectiveTheme(for: .auto)
                    Text("Currently using: \(effective.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Theme changes apply when starting a new session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Font") {
                Picker("Font family", selection: $terminalFontFamily) {
                    Text("SF Mono").tag("SF Mono")
                    Text("Menlo").tag("Menlo")
                    Text("Monaco").tag("Monaco")
                    Text("JetBrains Mono").tag("JetBrains Mono")
                    Text("Fira Code").tag("Fira Code")
                }
                .accessibilityLabel("Terminal font family")

                HStack {
                    Text("Font size")
                    Spacer()
                    Stepper("\(terminalFontSize) pt", value: $terminalFontSize, in: 10...24)
                        .frame(width: 120)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Font size: \(terminalFontSize) points")

                FontPreview(fontFamily: terminalFontFamily, fontSize: CGFloat(terminalFontSize))
            }

            Section("Scrollback") {
                Picker("Buffer size", selection: $terminalScrollback) {
                    Text("500 lines").tag(500)
                    Text("1,000 lines").tag(1000)
                    Text("2,000 lines").tag(2000)
                    Text("5,000 lines").tag(5000)
                    Text("10,000 lines").tag(10000)
                }
                .accessibilityLabel("Scrollback buffer size")

                Text("Larger buffers use more memory")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct ThemePreviewSwatch: View {
    let theme: TerminalThemeSelection

    var body: some View {
        let themeData = TerminalThemes.get(theme)
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(Color(nsColor: themeData.palette[index + 1]))
                    .frame(width: 8, height: 12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5)
        )
    }
}

private struct FontPreview: View {
    let fontFamily: String
    let fontSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("user@mac ~ % echo \"Hello, World!\"")
                .font(.custom(resolvedFontName, size: fontSize))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: TerminalThemes.dracula.background))
                .foregroundColor(Color(nsColor: TerminalThemes.dracula.foreground))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var resolvedFontName: String {
        switch fontFamily {
        case "SF Mono": return "SFMono-Regular"
        case "Menlo": return "Menlo-Regular"
        case "Monaco": return "Monaco"
        case "JetBrains Mono": return "JetBrainsMono-Regular"
        case "Fira Code": return "FiraCode-Regular"
        default: return "SFMono-Regular"
        }
    }
}

#Preview {
    TerminalSettingsView()
        .frame(width: 500)
}
