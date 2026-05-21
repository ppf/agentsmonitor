# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

**Requires full Xcode** (not Command Line Tools only):

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

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

# Unit tests only (CI default)
xcodebuild test -project AgentsMonitor/AgentsMonitor.xcodeproj -scheme AgentsMonitor -destination "platform=macOS" -only-testing:AgentsMonitorTests

# Run specific test class
xcodebuild test -project AgentsMonitor/AgentsMonitor.xcodeproj -scheme AgentsMonitor -destination "platform=macOS" -only-testing:AgentsMonitorTests/SessionStoreTests

# Run single test method
xcodebuild test -project AgentsMonitor/AgentsMonitor.xcodeproj -scheme AgentsMonitor -destination "platform=macOS" -only-testing:AgentsMonitorTests/SessionStoreTests/testSelectedSessionReturnsCorrectSession
```

### CI
- **GitHub Actions:** `.github/workflows/macos-tests.yml` — unit tests on `macos-latest`
- **Local full suite:** `./scripts/ci.sh` (UI preflight + all tests). See [UI_TESTING.md](UI_TESTING.md)

## Architecture Overview

### State Management: @Observable Pattern (Not Redux/TCA)
This app uses Swift 5.9+ `@Observable` on a `@MainActor` store. **Do not wrap stores in StateObject** — inject via `@Environment`:

```swift
@Environment(SessionStore.self) private var sessionStore
@Bindable var store = sessionStore  // For two-way binding
```

**Key principle:** `SessionStore` is the single source of truth for session list, selection, usage data, and aggregates.

### Data Flow Architecture
```
ClaudeSessionService (actor)  ──┐
CodexSessionService (actor)   ──┼──> SessionStore (@MainActor @Observable)
AnthropicUsageService (actor) ──┘         │
TokenCostCalculator (sync)    ────────────┘ (background cost tasks)
    |
MenuBarMainView / MenuBarSettingsView (@Environment, timer refresh when active)
```

**SessionStore responsibilities:**
- Parallel discovery from Claude + Codex (UserDefaults: `activeOnly`, `showSidechains`, source toggles)
- Serialized loads via `loadTask` (cancel superseded refresh)
- Token cost calculation and caching (keyed by `jsonlPath` + `fileMtime`)
- Usage limits (Anthropic OAuth) and Codex rate limits
- Aggregate stats (7-day tokens/cost per tab, runtime, averages)

### Dependency Injection Pattern
```swift
// Production (AgentsMonitorApp.swift)
let sessionStore = SessionStore(environment: AppEnvironment.current)

// Testing
let store = SessionStore(environment: SessionStoreTestSupport.unitTestEnvironment())
// or with usage spy:
let store = SessionStoreTestSupport.makeStore(usageService: spy)
try await SessionStoreTestSupport.waitForMockSessions(in: store)
```

**AppEnvironment:** `isUnitTesting` loads `#if DEBUG` mock data and skips disk I/O; `isUITesting` uses fixed clock + optional large mock list (see UI_TESTING.md).

## Testing Patterns

### SessionStore Tests
**Always use `@MainActor`** — the store is main-actor isolated:

```swift
@MainActor
final class SessionStoreTests: XCTestCase {
    var store: SessionStore!

    override func setUp() async throws {
        store = SessionStore(environment: SessionStoreTestSupport.unitTestEnvironment())
        try await SessionStoreTestSupport.waitForMockSessions(in: store)
    }
}
```

### Test Organization (in `AgentsMonitorTests/`)
- **SessionStoreTests** — selection, filters, usage refresh/cancellation, visible sessions
- **SessionStoreAggregateTests** — aggregates, formatting
- **SessionStoreClearAllTests** — clear all + cache file removal
- **Model tests** — Session, ToolCall, Message, SessionMetrics, decoding
- **TokenCostCalculatorTests** — Claude + Codex JSONL pricing
- **CodexSessionServiceTests** — temp-dir discovery fixtures
- **ClaudeSessionServiceTests** — temp-dir `sessions-index.json` fixtures
- **AnthropicUsageParsingTests** — error strings, utilization helper

**Pattern:** Minimal fixtures, assert behavior; prefer `SessionStoreTestSupport` and service temp directories over fixed `Task.sleep`.

## Services

### ClaudeSessionService
```swift
actor ClaudeSessionService {
    init(claudeDir: URL? = nil)  // inject for tests
    func discoverSessions(showAll: Bool, showSidechains: Bool) async -> [Session]
}
```

- Scans `~/.claude/projects/*/sessions-index.json` (+ JSONL fallback in project dirs)
- **Running heuristic:** `fileMtime` within last **30 minutes** (1800s) → `.running`, else `.completed`
- Name from `summary` → `firstPrompt` prefix → short session ID

### CodexSessionService
```swift
actor CodexSessionService {
    init(codexDir: URL? = nil)  // inject for tests
    func discoverSessions(showAll: Bool, showSidechains: Bool) async -> [Session]
    func fetchRateLimits(showSidechains: Bool) async -> CodexRateLimits?
}
```

- Scans `~/.codex/sessions/YYYY/MM/DD/*.jsonl`
- **Last 7 days** when `showAll == false`; **all date directories** when `showAll == true`
- Rate limits from most recent running (or fallback) session JSONL

### TokenCostCalculator
```swift
struct TokenCostCalculator {
    static func calculate(jsonlPath: String) -> SessionTokenSummary?       // Claude: sum assistant usage
    static func calculateCodex(jsonlPath: String) -> CodexSessionSummary?  // Codex: last token_count event
}
```

**Cost caching:** `SessionStore` caches by `jsonlPath` + `fileMtime`; persists to `~/.claude/agents-monitor-cost-cache.json`.

### AnthropicUsageService
Implements `UsageServiceProviding` for tests. OAuth via Keychain (`Claude Code-credentials`) or `~/.claude/.credentials.json` → `https://api.anthropic.com/api/oauth/usage`.

**Usage refresh cancellation:** `fetchUsageData()` ignores `CancellationError`, `URLError.cancelled`, and `NSURLErrorCancelled` — keeps stale usage, clears no error.

## Data Sources (read-only)

| Data | Location |
|------|----------|
| Claude session index | `~/.claude/projects/{project}/sessions-index.json` |
| Claude/Codex JSONL | Paths from index or Codex rollout files |
| Codex sessions | `~/.codex/sessions/YYYY/MM/DD/*.jsonl` |
| Cost cache | `~/.claude/agents-monitor-cost-cache.json` |
| OAuth credentials | Keychain or `~/.claude/.credentials.json` |

No app-owned session persistence or terminal I/O.

## Theming System

**AppTheme.swift** — colors, spacing, `popoverWidth`, `utilizationColor(for:)`, status/agent colors. Prefer theme tokens over raw `.blue` / `.green` in views.

```swift
.foregroundStyle(AppTheme.statusColor(for: session.status))
.frame(width: AppTheme.popoverWidth)
```

Enums: `Spacing`, `CornerRadius`, `FontSize`, `Animation` — used in menu bar views.

## Accessibility Requirements

All icon/action buttons **must** have `.accessibilityLabel()` and `.accessibilityHint()` (see `MenuBarButton`, settings back button, session expand rows, pickers).

**Status:** Color + `PulsatingStatusDot` (not color alone).

## Important Conventions When Modifying Code

- **Serialized refresh:** `performLoadSessions()` cancels the previous `loadTask` before starting a new load.
- **Settings → refresh:** Changes to `activeOnly`, `showSidechains`, `codexEnabled`, or `claudeCodeEnabled` must call `sessionStore.refresh()` (see `MenuBarSettingsView`).
- **Cost cache:** Background `costCalculationTask` updates sessions incrementally; `saveCostCache()` after batch.
- **Navigation:** `MenuBarView` uses a `ZStack` with `isActive` so main view state and timers pause on the settings page.
- **New `SessionStatus`:** Update enum, `AppTheme.statusColors`, and `MenuBarMainView` / `PulsatingStatusDot`.

## Common Modification Patterns

### Adding a New Model to Pricing
Update `TokenCostCalculator.pricingTable` and `formatModelName()` in `Services/TokenCostCalculator.swift`.

### Adding a Tool Call Icon (reserved model fields)
Update `ToolCall.icon` in `Models/ToolCall.swift` if a future detail UI uses tool calls.

## Logging Strategy

Use **AppLogger** only (`logWarning`, `logError`, `measure`, `measureAsync`) — no `print()`.

## Known Limitations

1. **Running detection:** File mtime heuristic (30 min), not process-linked.
2. **JSONL parse cost:** Large files can slow first load; mtime cache + `Task.detached` background work help.
3. **Codex token totals:** Last `token_count` event only — multi-turn sessions may under-report vs Claude’s summed usage.

## App Architecture

**Menu-bar-only** — no `WindowGroup`, no Dock icon (`LSUIElement`).

- `AgentsMonitorApp.swift` — `MenuBarExtra` + environment injection
- `MenuBarView` — `ZStack` toggles main vs settings (`isActive` gates refresh timers)
- `MenuBarMainView` — sessions, usage bars, source tabs, 7-day aggregates
- `MenuBarSettingsView` — General (filters, sources, refresh), Appearance (theme)

## File Navigation Guide

| Area | Path |
|------|------|
| App entry | `App/AgentsMonitorApp.swift` |
| State | `ViewModels/SessionStore.swift` |
| Claude discovery | `Services/ClaudeSessionService.swift` |
| Codex discovery | `Services/CodexSessionService.swift` |
| Token costs | `Services/TokenCostCalculator.swift` |
| Usage API | `Services/AnthropicUsageService.swift` |
| Logging | `Services/Logger.swift` |
| Theme | `Theme/AppTheme.swift` |
| Models | `Models/Session.swift`, `Message.swift`, `ToolCall.swift`, `AppEnvironment.swift` |
| Menu shell | `Views/MainWindow/MenuBarView.swift` |
| Main UI | `Views/MenuBar/MenuBarMainView.swift` |
| Settings | `Views/MenuBar/MenuBarSettingsView.swift` |
