# Repository Guidelines

## Project Overview

AgentsMonitor is a native macOS **menu-bar-only** SwiftUI application for monitoring Claude Code and Codex sessions. It reads agent session files on disk (read-only), shows token/cost metrics, usage limits, and session status — no embedded terminal or process management.

**Platform:** macOS 14.0+ (Sonoma)
**Language:** Swift 5.9+
**UI Framework:** SwiftUI with AppKit bridges
**Architecture:** MVVM with `@Observable`

## Project Structure & Module Organization

- `AgentsMonitor/` contains the macOS SwiftUI app source.
- `AgentsMonitor/App/` holds the app entry point (`AgentsMonitorApp.swift`).
- `AgentsMonitor/Models/` holds data types: `Session`, `Message`, `ToolCall`, `AppEnvironment`.
- `AgentsMonitor/ViewModels/SessionStore.swift` is the single source of truth for all session state.
- `AgentsMonitor/Services/` holds actor-based services: `ClaudeSessionService`, `CodexSessionService`, `TokenCostCalculator`, `AnthropicUsageService`, `Logger`.
- `AgentsMonitor/Views/` holds SwiftUI views (`MenuBarView`, `MenuBarMainView`, `MenuBarSettingsView`).
- `AgentsMonitor/Theme/` holds `AppTheme.swift` (colors, fonts, spacing).
- `AgentsMonitor/Resources/` holds `Assets.xcassets` and `Info.plist`.
- `AgentsMonitorTests/` contains XCTest unit tests (100+ tests).
- `AgentsMonitorUITests/` contains UI integration tests.

## Build, Test, and Development Commands

```bash
# Open in Xcode
open AgentsMonitor/AgentsMonitor.xcodeproj

# Build from CLI
xcodebuild build -project AgentsMonitor/AgentsMonitor.xcodeproj -scheme AgentsMonitor -destination "platform=macOS"

# Run all tests from CLI (requires full Xcode install)
xcodebuild test -project AgentsMonitor/AgentsMonitor.xcodeproj -scheme AgentsMonitor -destination "platform=macOS"

# Run a specific test class
xcodebuild test -project AgentsMonitor/AgentsMonitor.xcodeproj -scheme AgentsMonitor -destination "platform=macOS" -only-testing:AgentsMonitorTests/SessionStoreTests

# Run a single test method
xcodebuild test -project AgentsMonitor/AgentsMonitor.xcodeproj -scheme AgentsMonitor -destination "platform=macOS" -only-testing:AgentsMonitorTests/SessionStoreTests/testSelectedSessionReturnsCorrectSession
```

In Xcode: Build (Cmd+B), Run (Cmd+R), Test (Cmd+U).

## Key Architecture Patterns

### State Management
- `SessionStore` is an `@MainActor @Observable` class — the single source of truth.
- Views inject it via `@Environment(SessionStore.self)`.
- Use `@Bindable var store = sessionStore` for two-way binding.
- **Do NOT** use `@StateObject` or `ObservableObject` — this project uses Swift 5.9+ `@Observable`.

### Actor-Based Concurrency
- `ClaudeSessionService`, `CodexSessionService`, and `AnthropicUsageService` are Swift actors.
- Disk and network I/O are isolated; UI mutations happen on the main actor via `SessionStore`.

### Dependency Injection
```swift
// Production (in AgentsMonitorApp.swift)
let environment = AppEnvironment.current
let sessionStore = SessionStore(environment: environment)

// Tests (in SessionStoreTests.swift)
let environment = AppEnvironment(
    isUITesting: false,
    isUnitTesting: true,
    mockSessionCount: nil,
    fixedNow: nil
)
let store = SessionStore(environment: environment)
```

### Data Flow
```
ClaudeSessionService / CodexSessionService (actors) -> read session index / JSONL on disk
    |
SessionStore (@MainActor @Observable) -> cost cache, usage API, aggregates
    |
MenuBarMainView / MenuBarSettingsView -> timer-based refresh
```

## Coding Style & Naming Conventions

- Swift 4-space indentation; follow Swift API Design Guidelines.
- Types use `PascalCase`, variables/functions use `camelCase`.
- File names match primary types (e.g., `SessionStore.swift`).
- Keep SwiftUI views small; compose via subviews.
- Use `AppTheme` for all colors, fonts, spacing — never hardcode colors in views.
- Use `AppLogger` for logging — never use `print()`.
- All icon buttons must have `.accessibilityLabel()` and `.accessibilityHint()`.

## Testing Guidelines

- XCTest is used (`import XCTest`, `@testable import AgentsMonitor`).
- Test files follow `*Tests.swift`, classes end with `Tests`.
- Test methods use `test...` naming.
- `SessionStore` tests must use `@MainActor` since the store is main-actor isolated.
- Use `AppEnvironment(isUnitTesting: true)` to load deterministic mock data and skip disk I/O.
- Prefer `try await SessionStoreTestSupport.waitForMockSessions(in: store)` over fixed `Task.sleep`; use `SessionStoreTestSupport.makeStore()` / `unitTestEnvironment()` for custom spies.
- Keep tests deterministic; prefer dependency injection and temp-dir fixtures for services.

## Important Conventions When Modifying Code

- Session loads are serialized via `loadTask` — cancel superseded loads before starting a new one.
- Cost cache is keyed by `jsonlPath` + `fileMtime`; call `saveCostCache()` after background recalculation.
- When adding a new `SessionStatus`, update: the enum, `AppTheme.statusColors`, and status UI in menu bar views.
- Settings toggles that affect discovery (`activeOnly`, `showSidechains`, source enables) should trigger `sessionStore.refresh()`.

## Commit & Pull Request Guidelines

- Use short, imperative, capitalized commit subjects.
  - Example: `Fix filter settings not refreshing sessions immediately`
- PRs should include:
  - A clear summary of changes.
  - Testing notes (commands run or "not run" with reason).
  - Screenshots for UI changes.

## Security & Configuration

- Do not hardcode secrets; credentials come from macOS Keychain or `~/.claude/.credentials.json`.
- Avoid logging sensitive data (tokens, credentials, PII).
- App entitlements live in `AgentsMonitor/AgentsMonitor.entitlements`.

## CI

- Local: `scripts/ci.sh` (UI preflight + full test suite on macOS with Xcode).
- GitHub Actions: `.github/workflows/macos-tests.yml` runs unit tests on `macos-latest`.
