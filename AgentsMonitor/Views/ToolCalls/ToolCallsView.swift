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
                    Text("Select a tool call to view details")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    }
}

struct ToolCallRowView: View {
    let toolCall: ToolCall

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toolCall.toolIcon)
                .font(.title2)
                .foregroundStyle(statusColor)
                .frame(width: 32)

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
    }

    private var statusColor: Color {
        switch toolCall.status {
        case .pending: return .gray
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        }
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
        .background(backgroundColor)
        .foregroundStyle(foregroundColor)
        .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .pending: return .gray.opacity(0.2)
        case .running: return .blue.opacity(0.2)
        case .completed: return .green.opacity(0.2)
        case .failed: return .red.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .pending: return .gray
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

struct ToolCallDetailView: View {
    let toolCall: ToolCall
    @State private var selectedTab = 0

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

            Divider()

            // Content
            TabView(selection: $selectedTab) {
                CodeBlockView(title: "Input", content: toolCall.input)
                    .tabItem { Text("Input") }
                    .tag(0)

                if let output = toolCall.output {
                    CodeBlockView(title: "Output", content: output)
                        .tabItem { Text("Output") }
                        .tag(1)
                }

                if let error = toolCall.error {
                    CodeBlockView(title: "Error", content: error, isError: true)
                        .tabItem { Text("Error") }
                        .tag(2)
                }
            }
            .padding()
        }
    }
}

struct CodeBlockView: View {
    let title: String
    let content: String
    var isError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
            }

            ScrollView {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(isError ? Color.red.opacity(0.1) : Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    ToolCallsView(toolCalls: [
        ToolCall(name: "Read", input: "src/auth/login.ts", output: "// code here", status: .completed),
        ToolCall(name: "Bash", input: "npm test", status: .running)
    ])
}
