# AgentsMonitor

A native macOS **menu-bar** application for monitoring Claude Code and Codex agent sessions. Read-only discovery from agent session files on disk, with token/cost metrics, usage limits, and session status at a glance.

## Features

- **Session discovery** — Claude Code (`~/.claude/projects/*/sessions-index.json`) and Codex (`~/.codex/sessions/`)
- **Token metrics** — Per-session cost, tokens, model name (JSONL parsing with mtime-based cache)
- **Usage limits** — Anthropic OAuth usage API (5-hour / 7-day windows) and Codex rate limits from session files
- **Menu bar UI** — Expandable session rows, source tabs (All / Codex / Claude Code), auto-refresh
- **Settings** — Active-only filter, sidechains, source toggles, refresh interval, appearance
- **Accessibility** — VoiceOver labels on actions; status uses color + icon (colorblind-safe)

## Requirements

- macOS 14.0+ (Sonoma)
- **Full Xcode** 15+ (not Command Line Tools alone — required for `xcodebuild`, SDK, and running the app)
- Swift 5.9+

## Getting Started

### Build & Run

```bash
open AgentsMonitor/AgentsMonitor.xcodeproj
# Build: Cmd+B  |  Run: Cmd+R  |  Test: Cmd+U
```

### Command Line Build & Test

```bash
xcodebuild build \
  -project AgentsMonitor/AgentsMonitor.xcodeproj \
  -scheme AgentsMonitor \
  -destination "platform=macOS"

xcodebuild test \
  -project AgentsMonitor/AgentsMonitor.xcodeproj \
  -scheme AgentsMonitor \
  -destination "platform=macOS"

# Specific test class
xcodebuild test \
  -project AgentsMonitor/AgentsMonitor.xcodeproj \
  -scheme AgentsMonitor \
  -destination "platform=macOS" \
  -only-testing:AgentsMonitorTests/SessionStoreTests
```

## Architecture

```
MenuBarExtra (AgentsMonitorApp)
    └── MenuBarView (main ↔ settings)
            └── SessionStore (@MainActor @Observable)
                    ├── ClaudeSessionService (actor)
                    ├── CodexSessionService (actor)
                    ├── AnthropicUsageService (actor)
                    └── TokenCostCalculator (sync JSONL)
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| `@Observable` + `@MainActor` store | Swift 5.9+ observation with safe UI-bound mutations |
| Actor-based discovery | Thread-safe file enumeration without manual locking |
| Read-only data source | No app-owned persistence; monitors agents' own files |
| mtime cost cache | Avoid re-parsing large JSONL until files change |
| Serialized `loadTask` | Prevents overlapping refreshes from racing |

## Project Structure

```
AgentsMonitor/
├── App/AgentsMonitorApp.swift
├── Models/Session.swift, Message.swift, ToolCall.swift, AppEnvironment.swift
├── ViewModels/SessionStore.swift
├── Services/
│   ├── ClaudeSessionService.swift
│   ├── CodexSessionService.swift
│   ├── TokenCostCalculator.swift
│   ├── AnthropicUsageService.swift
│   ├── FileUtilities.swift
│   └── Logger.swift
├── Views/
│   ├── MainWindow/MenuBarView.swift
│   └── MenuBar/MenuBarMainView.swift, MenuBarSettingsView.swift
└── Theme/AppTheme.swift
```

## Data Sources

| Data | Location |
|------|----------|
| Claude session index | `~/.claude/projects/{project}/sessions-index.json` |
| Conversation JSONL | Paths in index `fullPath` |
| Codex sessions | `~/.codex/sessions/YYYY/MM/DD/*.jsonl` |
| Cost cache | `~/.claude/agents-monitor-cost-cache.json` |
| OAuth credentials | Keychain or `~/.claude/.credentials.json` |

## CI

- **GitHub Actions:** `.github/workflows/macos-tests.yml` runs unit tests on `macos-latest`.
- **Local:** `./scripts/ci.sh` runs UI preflight (`verify_status_item.sh`) then the full test suite. See [UI_TESTING.md](UI_TESTING.md) for UI automation flags.

## License

See repository license file if present.
