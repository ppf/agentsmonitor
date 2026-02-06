# AgentsMonitor

A native macOS application for monitoring and managing AI coding agent sessions. Track Claude Code and Codex sessions in real-time with an embedded terminal, tool call timeline, token metrics, and context window usage.

## Features

- **Session Management** -- Launch, pause, resume, and cancel agent sessions from one place
- **Embedded Terminal** -- Full terminal emulation (via SwiftTerm) for each session
- **Tool Call Timeline** -- Searchable split-view showing every tool invocation with inputs, outputs, and timing
- **Token Metrics** -- Per-session dashboards: input/output tokens, cache hits, API calls, context window usage
- **External Process Detection** -- Auto-discovers running `claude` and `codex` processes via `ps`
- **Menu Bar Widget** -- Quick-glance status from the macOS menu bar
- **Session Persistence** -- Sessions saved as JSON to `~/Library/Application Support/AgentsMonitor/Sessions/`
- **Filtering & Search** -- Filter by status, sort by date/name, full-text search across session names and messages
- **Export** -- Export any session as a JSON file
- **Accessibility** -- VoiceOver labels, icon+color status indicators (colorblind-safe), keyboard shortcuts
- **Theming** -- Multiple terminal themes (Dracula, Nord, Tokyo Night, Gruvbox, Solarized, GitHub Light)

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15+ (for building from source)
- Swift 5.9+

## Getting Started

### Build & Run

```bash
# Open in Xcode
open AgentsMonitor/AgentsMonitor.xcodeproj

# Build: Cmd+B
# Run:   Cmd+R
# Test:  Cmd+U
```

### Command Line Build & Test

```bash
# Build
xcodebuild build \
  -project AgentsMonitor/AgentsMonitor.xcodeproj \
  -scheme AgentsMonitor \
  -destination "platform=macOS"

# Run all tests
xcodebuild test \
  -project AgentsMonitor/AgentsMonitor.xcodeproj \
  -scheme AgentsMonitor \
  -destination "platform=macOS"

# Run a specific test class
xcodebuild test \
  -project AgentsMonitor/AgentsMonitor.xcodeproj \
  -scheme AgentsMonitor \
  -destination "platform=macOS" \
  -only-testing:AgentsMonitorTests/SessionStoreTests
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  AgentsMonitorApp (@main)                           │
│  ├── WindowGroup → ContentView                      │
│  ├── Settings    → SettingsView                     │
│  ├── MenuBarExtra → MenuBarView                     │
│  └── Window      → SessionDebugView                 │
└─────────────────────┬───────────────────────────────┘
                      │ @Environment injection
┌─────────────────────▼───────────────────────────────┐
│  SessionStore (@Observable)                         │
│  Single source of truth for all session state       │
│  ├── Session CRUD                                   │
│  ├── Filtered cache with auto-invalidation          │
│  ├── Process lifecycle (spawn/terminate/signal)     │
│  └── Async persistence (non-blocking)               │
└───────┬──────────────────┬──────────────────────────┘
        │                  │
┌───────▼──────┐   ┌───────▼──────────────┐
│ AgentProcess │   │ SessionPersistence   │
│ Manager      │   │ (actor)              │
│ (actor)      │   │ JSON files on disk   │
│ spawn/signal │   └──────────────────────┘
│ /terminate   │
└───────┬──────┘
        │
┌───────▼──────┐
│ Terminal     │
│ Bridge       │
│ SwiftTerm ↔  │
│ LocalProcess │
└──────────────┘
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| `@Observable` (not `ObservableObject`) | Swift 5.9+ macro; finer-grained UI updates, no `@Published` boilerplate |
| Actor-based services | Thread safety without manual locking for `AgentService`, `SessionPersistence`, `AgentProcessManager` |
| Constructor injection | Testability: pass `persistence: nil` to load mock data in tests |
| Single `SessionStore` | Avoids split-brain state; all mutations flow through one object |
| `FilteredSessionsCache` | Avoids re-filtering on every SwiftUI body evaluation |
| Lazy session loading | `SessionSummary` loaded at startup; full `Session` loaded on selection |

## Project Structure

```
AgentsMonitor/
├── App/
│   ├── AgentsMonitorApp.swift          # @main entry, DI setup, scenes
│   ├── AppDelegate.swift               # NSApplicationDelegate
│   └── StatusItemController.swift      # Menu bar NSPopover management
├── Models/
│   ├── Session.swift                   # Session, SessionSummary, SessionMetrics,
│   │                                   # SessionStatus, AgentType enums
│   ├── Message.swift                   # Message struct, MessageRole enum
│   ├── ToolCall.swift                  # ToolCall struct, ToolCallStatus enum
│   ├── AppState.swift                  # UI state: tabs, search, filters, sort
│   └── AppEnvironment.swift            # Testing/UI-test environment config
├── ViewModels/
│   └── SessionStore.swift              # @Observable store, CRUD, filtering,
│                                       # process lifecycle, persistence
├── Services/
│   ├── AgentService.swift              # Actor-based WebSocket client
│   ├── AgentProcessManager.swift       # Process spawn/signal/terminate
│   ├── SessionPersistence.swift        # Actor-based JSON file I/O
│   ├── TerminalBridge.swift            # SwiftTerm ↔ LocalProcess bridge
│   └── Logger.swift                    # OSLog structured logging
├── Views/
│   ├── MainWindow/
│   │   ├── ContentView.swift           # NavigationSplitView root
│   │   └── MenuBarView.swift           # Menu bar popover UI
│   ├── SessionList/
│   │   ├── SessionListView.swift       # Sidebar with sections & context menus
│   │   └── NewSessionSheet.swift       # New session dialog
│   ├── SessionDetail/
│   │   ├── SessionDetailView.swift     # Tabbed detail: terminal/tools/metrics
│   │   ├── TerminalView.swift          # NSViewRepresentable for SwiftTerm
│   │   └── MetricsView.swift           # Token & usage metrics
│   ├── ToolCalls/
│   │   └── ToolCallsView.swift         # Split-view tool call browser
│   └── Settings/
│       ├── SettingsView.swift           # Tab-based preferences
│       └── TerminalSettingsView.swift   # Terminal theme & font settings
├── Components/
│   └── StatusBadge.swift               # Reusable status indicator
├── Theme/
│   ├── AppTheme.swift                  # Colors, fonts, spacing, corner radii
│   └── TerminalThemes.swift            # Terminal color schemes
└── Resources/
    ├── Assets.xcassets/                # App icons, accent color
    ├── Fonts/                          # Custom fonts
    └── Info.plist                      # Bundle metadata

AgentsMonitorTests/
├── SessionStoreTests.swift             # 80+ unit tests
└── Fixtures/
    ├── legacy_swift_session.json       # Backward-compat test data
    └── legacy_tauri_session.json       # Cross-platform test data

AgentsMonitorUITests/
└── AgentsMonitorMenuBarTests.swift     # Menu bar integration tests
```

## Supported Agent Types

| Agent | Executable | Detection |
|-------|-----------|-----------|
| Claude Code | `claude`, `claude-code` | Process name or args matching |
| Codex | `codex`, `openai-codex` | Process name or args matching |
| Custom | Configurable | User-defined path in Settings |

Executable paths are auto-resolved from `~/.local/bin`, Homebrew, nvm, fnm, volta, and `$PATH`. Override paths can be configured per-agent in Settings.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+N` | New session |
| `Cmd+R` | Refresh sessions |
| `Cmd+Shift+K` | Clear completed sessions |
| `Cmd+Ctrl+S` | Toggle sidebar |
| `Cmd+Shift+D` | Debug info window |
| `Cmd+,` | Settings |

## Testing

The test suite covers:

- **SessionStore**: CRUD, filtering, sorting, caching, cache invalidation, message/tool-call appending, merge-during-load race conditions
- **Models**: Session duration formatting, equality, status properties, agent type properties, metrics calculations, context window usage
- **Persistence**: Legacy filename resolution, backward-compatible decoding, fractional-second timestamps
- **Classification**: Agent process detection from `ps` output, executable name vs args priority

All `SessionStore` tests use `@MainActor` and `persistence: nil` to avoid disk I/O and load deterministic mock data.

## Data Storage

Sessions are persisted as individual JSON files:

```
~/Library/Application Support/AgentsMonitor/Sessions/
├── <uuid>.json
├── <uuid>.json
└── ...
```

The persistence layer handles:
- Atomic writes (`.atomic` option)
- Flexible ISO 8601 date decoding (with/without fractional seconds, Unix timestamps)
- Legacy filename migration (uppercase UUID -> lowercase canonical)
- Backward-compatible decoding of older session formats

## Configuration

The app stores preferences in `UserDefaults`:

| Key | Description |
|-----|-------------|
| `showMenuBarExtra` | Show/hide menu bar widget |
| `agentExecutableOverride.<type>` | Custom executable path per agent type |
| `agentExecutableBookmark.<type>` | Security-scoped bookmark for sandboxed access |
| `lastWorkingDirectory` | Most recently used working directory |

Override the sessions directory with the environment variable:
```bash
AGENTS_MONITOR_SESSIONS_DIR=/path/to/sessions
```

## Contributing

See [CLAUDE.md](CLAUDE.md) for development guidelines, architecture details, and coding patterns. See [AGENTS.md](AGENTS.md) for repository conventions compatible with AI coding agents.

## License

This project is proprietary software. All rights reserved.
