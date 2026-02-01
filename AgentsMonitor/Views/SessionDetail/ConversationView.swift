import SwiftUI

struct ConversationView: View {
    let messages: [Message]
    @State private var scrollToBottom = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                if scrollToBottom, let lastMessage = messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastMessage = messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(alignment: .topTrailing) {
            Button {
                scrollToBottom.toggle()
            } label: {
                Image(systemName: scrollToBottom ? "arrow.down.circle.fill" : "arrow.down.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(scrollToBottom ? "Auto-scroll enabled" : "Auto-scroll disabled")
            .accessibilityHint("Toggle automatic scrolling to new messages")
            .padding()
        }
    }
}

struct MessageBubbleView: View {
    let message: Message
    @State private var isExpanded = true
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: message.role.icon)
                    .foregroundStyle(AppTheme.roleColors[message.role] ?? .secondary)

                Text(message.role.rawValue)
                    .fontWeight(.medium)

                Spacer()

                Text(message.formattedTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isExpanded ? "Collapse message" : "Expand message")
            }
            .font(.callout)

            if isExpanded {
                if message.isStreaming {
                    StreamingTextView(text: message.content)
                } else {
                    Text(message.content)
                        .textSelection(.enabled)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(AppTheme.roleBackgroundColors[message.role] ?? Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role.rawValue) message: \(message.content)")
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.content, forType: .string)
                isCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isCopied = false
                }
            } label: {
                Label(isCopied ? "Copied!" : "Copy", systemImage: "doc.on.doc")
            }
        }
    }
}

struct StreamingTextView: View {
    let text: String
    @State private var cursorVisible = true
    @State private var cursorTimer: Timer?

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(text)
                .textSelection(.enabled)
                .font(.body)

            Rectangle()
                .fill(Color.primary)
                .frame(width: 2, height: 16)
                .opacity(cursorVisible ? 1 : 0)
        }
        .onAppear {
            startCursorAnimation()
        }
        .onDisappear {
            stopCursorAnimation()
        }
        .accessibilityLabel("Streaming message: \(text)")
        .accessibilityHint("Message is still being generated")
    }

    private func startCursorAnimation() {
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            cursorVisible.toggle()
        }
    }

    private func stopCursorAnimation() {
        cursorTimer?.invalidate()
        cursorTimer = nil
    }
}

#Preview {
    ConversationView(messages: [
        Message(role: .user, content: "Fix the authentication bug"),
        Message(role: .assistant, content: "I'll analyze the code and find the issue.", isStreaming: true)
    ])
}
