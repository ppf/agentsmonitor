import SwiftUI
import SwiftTerm

struct TerminalContainerView: View {
    let session: Session
    @Environment(SessionStore.self) private var sessionStore
    @AppStorage("terminalTheme") private var terminalTheme: String = "auto"

    private var effectiveBackground: SwiftUI.Color {
        let themeSelection = TerminalThemeSelection(rawValue: terminalTheme) ?? .auto
        let theme = TerminalThemes.effectiveTheme(for: themeSelection)
        return SwiftUI.Color(nsColor: theme.background)
    }

    var body: some View {
        Group {
            if session.agentType.isTerminalBased {
                VStack(spacing: 0) {
                    if session.isExternalProcess {
                        ExternalProcessBanner(session: session)
                    }
                    if session.status == .waiting {
                        StatusBanner(text: "Starting session...")
                    }
                    if session.status == .failed, let errorMessage = session.errorMessage {
                        StatusBanner(text: errorMessage, isError: true)
                    }
                    TerminalViewRepresentable(session: session)
                        .background(effectiveBackground)
                        .id(session.id)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "terminal")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Terminal not available for \(session.agentType.displayName)")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct ExternalProcessBanner: View {
    let session: Session

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.horizontal.circle")
            Text("External process detected (PID \(session.processId.map(String.init) ?? "unknown")). Not attached.")
                .font(.callout)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SwiftUI.Color.yellow.opacity(0.2))
        .foregroundStyle(.primary)
    }
}

private struct StatusBanner: View {
    let text: String
    var isError: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle" : "clock")
            Text(text)
                .font(.callout)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isError ? SwiftUI.Color.red : SwiftUI.Color.blue).opacity(0.15))
        .foregroundStyle(.primary)
    }
}

/// Container view that wraps TerminalView with paste menu support
final class TerminalContainerNSView: NSView, NSMenuItemValidation {
    let terminal: SwiftTerm.TerminalView

    override init(frame: NSRect) {
        terminal = SwiftTerm.TerminalView(frame: frame)
        super.init(frame: frame)
        addSubview(terminal)
        terminal.autoresizingMask = [.width, .height]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // NSMenuItemValidation protocol - enable Paste menu item
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(paste(_:)) {
            return NSPasteboard.general.string(forType: .string) != nil
        }
        return true
    }

    // Handle Edit > Paste menu action
    @objc func paste(_ sender: Any?) {
        if let text = NSPasteboard.general.string(forType: .string) {
            terminal.send(txt: text)
        }
    }

    // Allow this view to become first responder to receive menu actions
    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        return terminal.becomeFirstResponder()
    }
}

struct TerminalViewRepresentable: NSViewRepresentable {
    typealias NSViewType = TerminalContainerNSView

    let session: Session
    @Environment(SessionStore.self) private var sessionStore

    // Terminal settings from user defaults
    @AppStorage("terminalTheme") private var terminalTheme: String = "auto"
    @AppStorage("terminalFontFamily") private var terminalFontFamily: String = "SF Mono"
    @AppStorage("terminalFontSize") private var terminalFontSize: Int = 13
    @AppStorage("terminalScrollback") private var terminalScrollback: Int = 1000

    func makeNSView(context: Context) -> TerminalContainerNSView {
        // Use a reasonable initial frame to avoid zero-size issues
        let container = TerminalContainerNSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let terminal = container.terminal

        // Note: Scrollback is configured via TerminalOptions at Terminal init time in SwiftTerm
        // The macOS TerminalView currently uses a default of 10000 lines
        // Custom scrollback would require modifying SwiftTerm or using a custom Terminal instance

        // Apply theme
        let themeSelection = TerminalThemeSelection(rawValue: terminalTheme) ?? .auto
        let theme = TerminalThemes.effectiveTheme(for: themeSelection)
        terminal.nativeBackgroundColor = theme.background
        terminal.nativeForegroundColor = theme.foreground
        terminal.installColors(theme.swiftTermPalette)

        // Apply font
        terminal.font = resolvedFont()

        // Restore history if available
        if let output = session.terminalOutput {
            terminal.feed(byteArray: Array(output)[...])
        }

        let bridge = sessionStore.getOrCreateBridge(for: session.id)
        terminal.terminalDelegate = bridge
        // Attach terminal (preserves existing callbacks if nil passed)
        bridge.attachTerminal(terminal)

        // Start session if waiting (error display handled by updateNSView after state changes)
        if session.status == .waiting {
            Task {
                await sessionStore.startSession(session.id, terminal: terminal)
            }
        }

        return container
    }

    private func resolvedFont() -> NSFont {
        let size = CGFloat(terminalFontSize)
        let fontName: String
        switch terminalFontFamily {
        case "SF Mono":
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case "Menlo":
            fontName = "Menlo-Regular"
        case "Monaco":
            fontName = "Monaco"
        case "JetBrains Mono":
            fontName = "JetBrainsMono-Regular"
        case "Fira Code":
            fontName = "FiraCode-Regular"
        default:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
        return NSFont(name: fontName, size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    func updateNSView(_ nsView: TerminalContainerNSView, context: Context) {
        let terminal = nsView.terminal

        // Start session if it transitions to waiting
        if session.status == .waiting {
            Task { @MainActor in
                await sessionStore.startSession(session.id, terminal: terminal)
            }
        }

        // Show error message if session failed (only once via coordinator)
        if session.status == .failed, let errorMessage = session.errorMessage {
            if !context.coordinator.hasShownError {
                context.coordinator.hasShownError = true
                terminal.feed(text: "\u{001B}[31m❌ Error: \(errorMessage)\u{001B}[0m\r\n")
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var hasShownError = false
    }

    static func dismantleNSView(_ nsView: TerminalContainerNSView, coordinator: ()) {
        // Cleanup handled by SessionStore
    }
}

#Preview {
    let store = SessionStore(persistence: nil)
    return TerminalContainerView(session: store.sessions.first ?? Session(name: "Preview", status: .waiting))
        .environment(store)
        .frame(width: 800, height: 600)
}
