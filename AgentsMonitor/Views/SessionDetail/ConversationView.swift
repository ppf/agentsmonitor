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
                    .foregroundStyle(roleColor)

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
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

    private var roleColor: Color {
        switch message.role {
        case .user: return .blue
        case .assistant: return .purple
        case .system: return .gray
        case .tool: return .orange
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user: return Color.blue.opacity(0.1)
        case .assistant: return Color.purple.opacity(0.1)
        case .system: return Color.gray.opacity(0.1)
        case .tool: return Color.orange.opacity(0.1)
        }
    }
}

struct StreamingTextView: View {
    let text: String
    @State private var displayedText = ""
    @State private var cursorVisible = true

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(text)
                .textSelection(.enabled)
                .font(.body)

            if cursorVisible {
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 2, height: 16)
                    .opacity(cursorVisible ? 1 : 0)
            }
        }
        .onAppear {
            startCursorAnimation()
        }
    }

    private func startCursorAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            cursorVisible.toggle()
        }
    }
}

#Preview {
    ConversationView(messages: [
        Message(role: .user, content: "Fix the authentication bug"),
        Message(role: .assistant, content: "I'll analyze the code and find the issue.", isStreaming: true)
    ])
}
