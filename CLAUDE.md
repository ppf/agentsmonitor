# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

### Opening & Running
```bash
# Open Xcode project
open AgentsMonitor/AgentsMonitor.xcodeproj

# Build & run in Xcode: Cmd+R
# Build only: Cmd+B
# Run tests: Cmd+U
```

### Command Line Testing
```bash
# Run all tests (requires full Xcode, not just Command Line Tools)
xcodebuild test -project AgentsMonitor/AgentsMonitor.xcodeproj -scheme AgentsMonitor -destination "platform=macOS"

# Run specific test class
xcodebuild test -project AgentsMonitor/AgentsMonitor.xcodeproj -scheme AgentsMonitor -destination "platform=macOS" -only-testing:AgentsMonitorTests/SessionStoreTests

# Run single test method
xcodebuild test -project AgentsMonitor/AgentsMonitor.xcodeproj -scheme AgentsMonitor -destination "platform=macOS" -only-testing:AgentsMonitorTests/SessionStoreTests/testCreateSession
```

## Architecture Overview

### State Management: @Observable Pattern (Not Redux/TCA)
This app uses Swift 5.9+ `@Observable` macro for state management. **Do not wrap stores in StateObject** - inject directly via `@Environment`:

```swift
// Correct pattern
@Environment(SessionStore.self) private var sessionStore
@Bindable var store = sessionStore  // For two-way binding

// Don't do this (old ObservableObject pattern)
@StateObject var sessionStore = SessionStore()
```

**Key principle:** SessionStore is the single source of truth. All session mutations go through it, triggering UI updates automatically.

### Data Flow Architecture
```
AgentService (actor) → WebSocket events
    ↓
SessionStore (@Observable) → State mutations + persistence
    ↓
Views (@Environment) → Reactive UI updates
```

**SessionStore responsibilities:**
- Session CRUD operations
- Aggregate stats (tokens, cost, runtime, average duration)
- Message/ToolCall appending
- Auto-persistence via SessionPersistence actor

### Dependency Injection Pattern
SessionStore uses constructor injection for testability:

```swift
// Production (in AgentsMonitorApp.swift)
let sessionStore = SessionStore()

// Testing (in SessionStoreTests.swift)
let store = SessionStore(
    agentService: MockAgentService(),
    persistence: nil  // Avoid disk I/O, loads mock data
)
```

**Key insight:** Passing `nil` persistence triggers mock data loading. This is intentional for development/testing.

## Testing Patterns

### SessionStore Tests
**Always use `@MainActor`** because SessionStore performs UI-bound mutations:

```swift
@MainActor
final class SessionStoreTests: XCTestCase {
    var sut: SessionStore!

    override func setUp() async throws {
        sut = SessionStore(persistence: nil)  // Loads mock data
        try await Task.sleep(for: .milliseconds(200))  // Allow mock load
    }
}
```

### Test Organization
- **SessionStoreTests**: CRUD, computed properties, message/toolCall appending
- **SessionStoreAggregateTests**: Aggregate stats (tokens, cost, runtime, averages)
- **SessionStoreClearAllTests**: Clear all + aggregate reset verification
- **SessionStoreMergeRaceTests**: Concurrent append during detail load
- **Model tests**: SessionModelTests, ToolCallModelTests, MessageModelTests, SessionMetricsTests (incl. cost/modelName)
- **Pattern**: Create minimal fixtures in tests, verify state changes (not implementation)

## Performance Optimizations

### Pagination Support
SessionStore has pagination built-in (pageSize=50, hasMorePages flag). Currently unused but ready for large datasets.

## WebSocket Integration

### AgentService Architecture
**Actor-based** for thread safety. Uses `async/await` throughout:

```swift
actor AgentService: AgentServiceProtocol {
    func connect() async throws { ... }
    func send(_ command: AgentCommand) async throws { ... }
    func events() -> AsyncStream<AgentEvent> { ... }
}
```

**Event streaming pattern:**
```swift
// In views/stores
for await event in agentService.events() {
    switch event.data {
    case .sessionStarted(let session): ...
    case .messageReceived(let message): ...
    }
}
```

### Command & Event Protocol
**AgentCommand types:** pause, resume, cancel, retry, sendMessage, subscribe, unsubscribe
**AgentEvent types:** sessionStarted, sessionEnded, messageReceived, messageStreaming, toolCallStarted, toolCallCompleted, toolCallFailed, metricsUpdated, error

Both are `Codable` with custom encoding for flexible JSON structure.

### Connection Management
- Automatic reconnection: 5 attempts, 2s delay, exponential backoff
- Ping/pong keepalive: 30s interval
- Proper cleanup: Cancel receiveTask and pingTask on disconnect

## Theming System

**AppTheme.swift** is the single source of truth for all colors, fonts, spacing. Never hardcode colors in views:

```swift
// Correct
.foregroundColor(AppTheme.statusColor(for: session.status))
.background(AppTheme.roleBackgroundColor(for: message.role))

// Don't do this
.foregroundColor(.blue)
.background(.gray.opacity(0.1))
```

**Theme enums:**
- `FontSize`: small/medium/large with CGFloat values
- `Spacing`: small/medium/large/extraLarge constants
- `CornerRadius`: small/medium/large values
- `Animation`: fast/normal/slow durations

## Persistence Layer

### SessionPersistence Actor
**Thread-safe disk I/O** to `~/Library/Application Support/AgentsMonitor/Sessions/`:

```swift
actor SessionPersistence {
    static let shared = SessionPersistence()

    func save(_ session: Session) async throws { ... }
    func load(_ id: UUID) async throws -> Session { ... }
    func loadAll() async throws -> [Session] { ... }
}
```

**File format:** One JSON file per session (keyed by UUID)
**Codable extension:** SessionPersistence.swift lines 118-207 extend Session/Message/ToolCall with custom encode/decode

### Auto-Persistence Pattern
SessionStore automatically persists after mutations:

```swift
func createNewSession() {
    let session = Session(...)
    sessions.insert(session, at: 0)

    Task {
        try? await persistence?.saveSession(session)  // Async, doesn't block UI
    }
}
```

## Accessibility Requirements

All icon buttons **must** have labels and hints:

```swift
// Correct
Button { action() } label: {
    Image(systemName: "play.fill")
}
.accessibilityLabel("Resume session")
.accessibilityHint("Resumes the paused agent session")

// Don't ship without labels
Button { action() } label: {
    Image(systemName: "play.fill")
}
```

**Status indicators:** Always pair color with icon (colorblind safe).

## Common Modification Patterns

### Adding a New SessionStatus
1. Update `SessionStatus` enum in `Models/Session.swift`
2. Add computed property in SessionStore (e.g., `var archiveSessions`)
3. Add color mapping in `AppTheme.statusColors`
4. Update `MenuBarMainView` to display new status

### Adding a New AgentType
1. Update `AgentType` enum with icon, displayName, defaultHost/Port/Path, color
2. Add preset config in `AgentService.Config` static methods
3. Update `MenuBarSettingsView` connection section if needed
4. Add test session to `SessionStore.loadMockData()` if desired

### Adding a New Tool Call Icon
Update `ToolCall.icon` computed property in `Models/ToolCall.swift`:
```swift
var icon: String {
    switch name.lowercased() {
    case "newTool": return "wrench.and.screwdriver"
    // ... existing cases
    }
}
```

## Logging Strategy

**Use Logger, not print():**
```swift
import Services

// Structured logging
Logger.log(.sessions, "Created session \(sessionID, privacy: .public)")
Logger.error(.network, "Connection failed", file: #file, line: #line)

// Performance timing
Logger.measure("loadSessions") {
    // ... expensive operation
}

await Logger.measureAsync("fetchData") {
    // ... async operation
}
```

**Categories:** sessions, network, persistence, errors, performance

## Memory Management

### Weak References in Closures
AgentService uses weak self to avoid retain cycles:

```swift
private func startPingTimer() {
    pingTask = Task { [weak self] in
        while !Task.isCancelled {
            try? await self?.ping()
            try? await Task.sleep(for: .seconds(30))
        }
    }
}
```

### Task Cancellation
Always cancel tasks in cleanup:

```swift
func disconnect() async {
    receiveTask?.cancel()
    pingTask?.cancel()
    // ... close WebSocket
}
```

## Known Incomplete Features

1. **WebSocket connection:** AgentService is fully implemented but app loads mock data instead of connecting to real agent
2. **Real event streaming:** SessionStore.refresh() reloads from disk, not from live WebSocket
3. **Export functionality:** Buttons exist but only save JSON to disk (no sharing sheet)

When implementing these, the architecture is ready - just wire up the AgentService connection in SessionStore initialization.

## App Architecture

This is a **menu-bar-only** macOS app (no main window, no Dock icon). The entire UI lives in a `MenuBarExtra(.window)` popover.

- `Info.plist` has `LSUIElement = true` (hides from Dock/Cmd-Tab)
- `AgentsMonitorApp.swift` uses only `MenuBarExtra` scene (no `WindowGroup`)
- `MenuBarView` is a page router: main ↔ settings
- `MenuBarMainView`: expandable session rows + usage stats (aggregate tokens, cost, runtime)
- `MenuBarSettingsView`: inline settings (General, Appearance, Connection)

## File Navigation Guide

**App entry point:** `App/AgentsMonitorApp.swift` (MenuBarExtra-only, DI setup)
**State management:** `ViewModels/SessionStore.swift` (single source of truth, aggregate stats)
**WebSocket logic:** `Services/AgentService.swift` (actor-based, async/await)
**Persistence:** `Services/SessionPersistence.swift` (actor, Codable extensions)
**Theme/styling:** `Theme/AppTheme.swift` (all colors, fonts, spacing)
**Menu bar root:** `Views/MainWindow/MenuBarView.swift` (page router + shared components)
**Main popover:** `Views/MenuBar/MenuBarMainView.swift` (sessions + usage stats)
**Inline settings:** `Views/MenuBar/MenuBarSettingsView.swift` (General, Appearance, Connection)
