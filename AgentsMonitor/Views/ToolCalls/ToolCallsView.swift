import SwiftUI

struct ToolCallsView: View {
    let toolCalls: [ToolCall]
    @State private var selectedToolCall: ToolCall?
    @State private var filterText = ""

    var filteredToolCalls: [ToolCall] {
        if filterText.isEmpty {
            return toolCalls
        }
        return toolCalls.filter {
            $0.name.localizedCaseInsensitiveContains(filterText) ||
            $0.input.localizedCaseInsensitiveContains(filterText)
        }
    }

    var body: some View {
        HSplitView {
            ToolCallListView(
                toolCalls: filteredToolCalls,
                selectedToolCall: $selectedToolCall
            )
            .frame(minWidth: 300)

            if let toolCall = selectedToolCall {
                ToolCallDetailView(toolCall: toolCall)
                    .frame(minWidth: 400)
            } else {
                VStack {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("Select a tool call to view details")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("No tool call selected")
            }
        }
        .searchable(text: $filterText, prompt: "Filter tool calls...")
    }
}

struct ToolCallListView: View {
    let toolCalls: [ToolCall]
    @Binding var selectedToolCall: ToolCall?

    var body: some View {
        List(toolCalls, selection: $selectedToolCall) { toolCall in
            ToolCallRowView(toolCall: toolCall)
                .tag(toolCall)
        }
        .listStyle(.inset)
        .overlay {
            if toolCalls.isEmpty {
                ContentUnavailableView {
                    Label("No Tool Calls", systemImage: "wrench")
                } description: {
                    Text("This session hasn't made any tool calls yet")
                }
            }
        }
        .accessibilityLabel("Tool calls list")
    }
}

struct ToolCallRowView: View {
    let toolCall: ToolCall

    var body: some View {
        HStack(spacing: 12) {
            // Icon with status indicator for accessibility
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: toolCall.toolIcon)
                    .font(.title2)
                    .foregroundStyle(AppTheme.toolCallStatusColors[toolCall.status] ?? .secondary)
                    .frame(width: 32)

                // Small status icon for color-blind accessibility
                Image(systemName: toolCall.status.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.toolCallStatusColors[toolCall.status] ?? .secondary)
                    .background(
                        Circle()
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .frame(width: 14, height: 14)
                    )
                    .offset(x: 4, y: 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(toolCall.name)
                        .fontWeight(.medium)

                    Spacer()

                    StatusPill(status: toolCall.status)
                }

                Text(toolCall.input)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack {
                    Text(toolCall.formattedTime)
                    if toolCall.status == .completed || toolCall.status == .failed {
                        Text("•")
                        Text(toolCall.formattedDuration)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(toolCall.name), \(toolCall.status.rawValue), input: \(toolCall.input)")
        .accessibilityHint("Double-tap to view details")
    }
}

struct StatusPill: View {
    let status: ToolCallStatus

    var body: some View {
        HStack(spacing: 4) {
            if status == .running {
                ProgressView()
                    .scaleEffect(0.5)
            } else {
                Image(systemName: status.icon)
            }
            Text(status.rawValue)
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.toolCallStatusColors[status]?.opacity(0.2) ?? Color.gray.opacity(0.2))
        .foregroundStyle(AppTheme.toolCallStatusColors[status] ?? .gray)
        .clipShape(Capsule())
        .accessibilityLabel("Status: \(status.rawValue)")
    }
}

// MARK: - Type-Safe Tab Enum

enum ToolDetailTab: String, CaseIterable {
    case input = "Input"
    case output = "Output"
    case error = "Error"
}

struct ToolCallDetailView: View {
    let toolCall: ToolCall
    @State private var selectedTab: ToolDetailTab = .input
    @Environment(\.codeFontSize) private var codeFontSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: toolCall.toolIcon)
                        .font(.title)
                    Text(toolCall.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                    StatusPill(status: toolCall.status)
                }

                HStack(spacing: 16) {
                    Label(toolCall.formattedTime, systemImage: "clock")
                    if let _ = toolCall.duration {
                        Label(toolCall.formattedDuration, systemImage: "timer")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(.bar)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Tool call \(toolCall.name), status \(toolCall.status.rawValue)")

            Divider()

            // Content with type-safe tabs
            TabView(selection: $selectedTab) {
                CodeBlockView(title: "Input", content: toolCall.input, fontSize: codeFontSize)
                    .tabItem { Text("Input") }
                    .tag(ToolDetailTab.input)

                if let output = toolCall.output {
                    CodeBlockView(title: "Output", content: output, fontSize: codeFontSize)
                        .tabItem { Text("Output") }
                        .tag(ToolDetailTab.output)
                }

                if let error = toolCall.error {
                    CodeBlockView(title: "Error", content: error, fontSize: codeFontSize, isError: true)
                        .tabItem { Text("Error") }
                        .tag(ToolDetailTab.error)
                }
            }
            .padding()
        }
        .onAppear {
            // Auto-select appropriate tab based on status
            if toolCall.error != nil {
                selectedTab = .error
            } else if toolCall.output != nil {
                selectedTab = .output
            } else {
                selectedTab = .input
            }
        }
    }
}

struct CodeBlockView: View {
    let title: String
    let content: String
    var fontSize: Int = 12
    var isError: Bool = false
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isCopied = false
                    }
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isCopied ? "Copied" : "Copy to clipboard")
                .accessibilityHint("Copies the \(title.lowercased()) content to clipboard")
            }

            ScrollView {
                Text(content)
                    .font(.system(size: CGFloat(fontSize), design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(isError ? Color.red.opacity(0.1) : Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            .accessibilityLabel("\(title): \(content)")
        }
    }
}

#Preview {
    ToolCallsView(toolCalls: [
        ToolCall(name: "Read", input: "src/auth/login.ts", output: "// code here", status: .completed),
        ToolCall(name: "Bash", input: "npm test", status: .running)
    ])
}
