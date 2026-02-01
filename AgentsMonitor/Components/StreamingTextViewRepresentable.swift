import SwiftUI
import AppKit

/// AppKit-bridged NSTextView for high-performance streaming text rendering.
/// Use this for displaying streaming AI output where performance is critical.
struct StreamingTextViewRepresentable: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    var textColor: NSColor = .textColor
    var isEditable: Bool = false
    var onTextChange: ((String) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = .textBackgroundColor
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        // Optimize for streaming
        textView.layoutManager?.allowsNonContiguousLayout = true

        // Set up text container
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Only update if text actually changed to avoid unnecessary redraws
        if textView.string != text {
            let wasAtBottom = isScrolledToBottom(scrollView)

            // Preserve selection if possible
            let selectedRange = textView.selectedRange()

            // Use efficient text replacement for streaming
            if text.hasPrefix(textView.string) {
                // Append-only optimization
                let newContent = String(text.dropFirst(textView.string.count))
                textView.textStorage?.append(NSAttributedString(
                    string: newContent,
                    attributes: [
                        .font: font,
                        .foregroundColor: textColor
                    ]
                ))
            } else {
                textView.string = text
            }

            // Restore selection or scroll to bottom
            if wasAtBottom {
                textView.scrollToEndOfDocument(nil)
            } else if selectedRange.location < text.count {
                textView.setSelectedRange(selectedRange)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func isScrolledToBottom(_ scrollView: NSScrollView) -> Bool {
        let visibleRect = scrollView.documentVisibleRect
        let documentHeight = scrollView.documentView?.bounds.height ?? 0
        return visibleRect.maxY >= documentHeight - 50
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: StreamingTextViewRepresentable

        init(_ parent: StreamingTextViewRepresentable) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onTextChange?(textView.string)
        }
    }
}

/// A SwiftUI wrapper that provides a cleaner API for the streaming text view
struct HighPerformanceTextView: View {
    let text: String
    var isStreaming: Bool = false

    @State private var mutableText: String = ""

    var body: some View {
        StreamingTextViewRepresentable(
            text: Binding(
                get: { text },
                set: { _ in }
            )
        )
        .overlay(alignment: .bottomTrailing) {
            if isStreaming {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("Streaming...")
                        .font(.caption2)
                }
                .padding(4)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(8)
            }
        }
    }
}

#Preview {
    HighPerformanceTextView(
        text: """
        This is a test of the streaming text view.
        It should handle large amounts of text efficiently.

        ```swift
        func hello() {
            print("Hello, World!")
        }
        ```
        """,
        isStreaming: true
    )
    .frame(width: 400, height: 300)
}
