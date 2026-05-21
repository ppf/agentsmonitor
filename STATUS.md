# AgentsMonitor — Status

> **Note:** Older versions of this file described a full-window app with terminals, persistence, and WebSocket agents. That architecture was removed. This document reflects the **current menu-bar monitor** only. See [README.md](README.md) and [CLAUDE.md](CLAUDE.md) for full guidance.

## Current product

A **read-only** macOS menu-bar app that discovers Claude Code and Codex sessions from on-disk files, shows usage limits, token/cost metrics, and session status. No embedded terminal, no app-owned session database, no process control.

**Stack:** SwiftUI + `@Observable` + Swift actors  
**Target:** macOS 14.0+  
**UI:** `MenuBarExtra` popover only (`LSUIElement`)

## Implemented

| Area | Status |
|------|--------|
| Claude session discovery | Done — `ClaudeSessionService` + `sessions-index.json` |
| Codex session discovery | Done — `CodexSessionService` + `~/.codex/sessions/` |
| Token/cost from JSONL | Done — `TokenCostCalculator` + mtime cache |
| Anthropic usage API | Done — `AnthropicUsageService` (OAuth) |
| Codex rate limits | Done — parsed from session JSONL |
| Menu bar UI | Done — sessions, tabs, usage bars, settings |
| Settings filters | Done — active only, sidechains, source toggles, refresh interval |
| Accessibility | Done — labels/hints on actions; status color + dot |
| Unit tests | Done — `AgentsMonitorTests` (SessionStore, models, services) |
| UI smoke test | Done — `AgentsMonitorUITests` |
| CI | Done — `.github/workflows/macos-tests.yml` |

## Source layout (~16 Swift files)

```
AgentsMonitor/
├── App/AgentsMonitorApp.swift
├── ViewModels/SessionStore.swift
├── Services/ (Claude, Codex, TokenCostCalculator, Anthropic usage, Logger, FileUtilities)
├── Views/MenuBar/ + Views/MainWindow/MenuBarView.swift
├── Theme/AppTheme.swift
└── Models/
```

## Known gaps / limitations

- **Running status:** 30-minute file mtime heuristic (not tied to live processes).
- **Codex cost:** Uses the **last** `token_count` event per session, not a sum across turns (Claude sums all assistant usage blocks).
- **Codex history:** Default discovery scans the last 7 days; `showAll` scans all date directories under `~/.codex/sessions/`.
- **Large JSONL:** First cost parse can be slow; mitigated by background calculation and disk cache.

## Docs map

| File | Purpose |
|------|---------|
| [README.md](README.md) | Overview, build, architecture |
| [CLAUDE.md](CLAUDE.md) | Agent/coding conventions (detailed) |
| [AGENTS.md](AGENTS.md) | Repository guidelines |
| [UI_TESTING.md](UI_TESTING.md) | UI test flags and permissions |
