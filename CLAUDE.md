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

**Key principle:** SessionStore is the single source of truth. All session state flows through it, triggering UI updates automatically.

### Data Flow Architecture
```
ClaudeSessionService (actor) -> reads ~/.claude/projects/*/sessions-index.json
    |
SessionStore (@Observable) -> State + TokenCostCalculator + AnthropicUsageService
    |
Views (@Environment) -> Reactive UI with timer-based refresh
```

**SessionStore responsibilities:**
- Session discovery via Claude Code session files
- Token cost calculation and caching (keyed by fileMtime)
- Usage limit fetching via Anthropic OAuth API
- Aggregate stats (tokens, cost, runtime, average duration)

### Dependency Injection Pattern
SessionStore uses constructor injection for testability:

```swift
// Production (in AgentsMonitorApp.swift)
let environment = AppEnvironment.current
let sessionStore = SessionStore(environment: environment)

// Testing (in SessionStoreTests.swift)
let environment = AppEnvironment(
    isUITesting: false,
    isUnitTesting: true,
    mockSessionCount: nil,
    fixedNow: nil
)
let store = SessionStore(environment: environment)
```

**Key insight:** `AppEnvironment` controls test behavior. `isUnitTesting = true` loads mock data and skips disk I/O. `isUITesting = true` loads mock data with a fixed date for deterministic snapshots.

## Testing Patterns

### SessionStore Tests
**Always use `@MainActor`** because SessionStore performs UI-bound mutations:

```swift
@MainActor
final class SessionStoreTests: XCTestCase {
    var store: SessionStore!

    override func setUp() async throws {
        let environment = AppEnvironment(
            isUITesting: false,
            isUnitTesting: true,
            mockSessionCount: nil,
            fixedNow: nil
        )
        store = SessionStore(environment: environment)
        try await Task.sleep(nanoseconds: 200_000_000)  // Allow mock load
    }
}
```

### Test Organization
- **SessionStoreTests**: Selection, computed properties, error handling, loading state
- **SessionStoreAggregateTests**: Aggregate stats (tokens, cost, runtime, averages)
- **SessionStoreClearAllTests**: Clear all + aggregate reset verification
- **Model tests**: SessionModelTests, ToolCallModelTests, MessageModelTests, SessionMetricsTests (incl. cost/modelName/contextWindow)
- **AgentTypeDecodingTests**: Flexible decoding of agent type and session status variants
- **TokenCostCalculatorTests**: JSONL parsing, cost calculation, model name formatting
- **Pattern**: Create minimal fixtures in tests, verify state changes (not implementation)

## Services

### ClaudeSessionService
**Actor-based** session discovery. Reads Claude Code's own session index files:

```swift
actor ClaudeSessionService {
    func discoverSessions(showAll: Bool, showSidechains: Bool) async -> [Session]
}
```

- Scans `~/.claude/projects/*/sessions-index.json` for session entries
- Determines running status via file mtime heuristic: sessions modified within last 120s are "running", otherwise "completed"
- Extracts session name from `summary` field, falling back to `firstPrompt` prefix, then short session ID
- Supports filtering: `showAll` toggles active-only vs all sessions, `showSidechains` includes/excludes sidechain sessions

### TokenCostCalculator
**Synchronous** JSONL parser for cost calculation:

```swift
struct TokenCostCalculator {
    static func calculate(jsonlPath: String) -> SessionTokenSummary?
}
```

- Parses Claude Code JSONL conversation files (`~/.claude/projects/*/sessions/*.jsonl`)
- Extracts `assistant` message entries with `usage` blocks (input, output, cache write, cache read tokens)
- Calculates cost from built-in pricing table (Opus 4, Sonnet 4, Haiku 4), falls back to Sonnet pricing for unknown models
- Returns `SessionTokenSummary` with token counts, cost, model name, API call count

**Cost caching:** SessionStore caches results keyed by `jsonlPath` + `fileMtime`. Only recalculates when file changes.

### AnthropicUsageService
**Actor-based** usage limit fetcher:

```swift
actor AnthropicUsageService {
    func fetchUsage() async throws -> AnthropicUsage
}
```

- Reads OAuth credentials from macOS Keychain via `security` CLI (service: "Claude Code-credentials"), falling back to `~/.claude/.credentials.json`
- Calls `https://api.anthropic.com/api/oauth/usage` with Bearer token
- Returns `AnthropicUsage` with 5-hour window, 7-day window, 7-day Sonnet window, and extra usage data
- Throws `UsageServiceError` (.noCredentials, .authExpired, .networkError, .parseError)

## Data Source

The app is **read-only** against Claude Code's own files. No app-owned persistence layer:

- **Session index:** `~/.claude/projects/{project}/sessions-index.json`
- **Conversation JSONL:** Referenced via `fullPath` in session entries
- **OAuth credentials:** macOS Keychain or `~/.claude/.credentials.json`

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

### Adding a New Model to Pricing
Update `TokenCostCalculator.pricingTable` and `formatModelName()` in `Services/TokenCostCalculator.swift`.

## Logging Strategy

**Use AppLogger, not print():**
```swift
// Structured logging
AppLogger.logWarning("message", context: "ComponentName")
AppLogger.logError(error, context: "ComponentName")

// Performance timing
AppLogger.measure("loadSessions") { ... }
await AppLogger.measureAsync("fetchData") { ... }
```

## Known Limitations

1. **Running detection is heuristic-based:** Uses file mtime (120s threshold) since we can't reliably correlate OS processes to specific sessions
2. **Token costs require JSONL parsing:** First load can be slow for sessions with large conversation files; mitigated by mtime-based caching

## App Architecture

This is a **menu-bar-only** macOS app (no main window, no Dock icon). The entire UI lives in a `MenuBarExtra(.window)` popover.

- `Info.plist` has `LSUIElement = true` (hides from Dock/Cmd-Tab)
- `AgentsMonitorApp.swift` uses only `MenuBarExtra` scene (no `WindowGroup`)
- `MenuBarView` is a page router: main <-> settings
- `MenuBarMainView`: expandable session rows + usage stats (aggregate tokens, cost, runtime)
- `MenuBarSettingsView`: inline settings (General, Appearance, Connection)

## File Navigation Guide

**App entry point:** `App/AgentsMonitorApp.swift` (MenuBarExtra-only, DI setup)
**State management:** `ViewModels/SessionStore.swift` (single source of truth, aggregate stats, cost caching)
**Session discovery:** `Services/ClaudeSessionService.swift` (actor, reads session-index.json files)
**Token costs:** `Services/TokenCostCalculator.swift` (JSONL parser, pricing table)
**Usage API:** `Services/AnthropicUsageService.swift` (actor, OAuth + Keychain)
**Logging:** `Services/Logger.swift` (AppLogger)
**Theme/styling:** `Theme/AppTheme.swift` (all colors, fonts, spacing)
**Models:** `Models/Session.swift`, `Models/Message.swift`, `Models/ToolCall.swift`, `Models/AppEnvironment.swift`
**Menu bar root:** `Views/MainWindow/MenuBarView.swift` (page router + shared components)
**Main popover:** `Views/MenuBar/MenuBarMainView.swift` (sessions + usage stats)
**Inline settings:** `Views/MenuBar/MenuBarSettingsView.swift` (General, Appearance, Connection)
