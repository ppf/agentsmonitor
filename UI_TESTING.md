# UI Testing & Automation

## Deterministic UI Testing Mode
The app supports a deterministic UI test mode for stable automation runs:
- Launch argument: `--ui-testing`
- Environment variable: `AGENTS_MONITOR_UI_TESTING=1`

Optional for CI reliability (forces NSStatusItem + NSPopover instead of MenuBarExtra):
- Launch argument: `--status-item`
- Environment variable: `AGENTS_MONITOR_USE_STATUS_ITEM=1`

Optional for performance profiling:
- `AGENTS_MONITOR_UI_TEST_SESSIONS=5000` (or any integer) to load a large mock list.

## CLI Test Runner
Verify status item + popover before tests (runs the menu-bar UI test in status-item mode):
```bash
./scripts/verify_status_item.sh
```

Run all tests (unit + UI):
```bash
xcodebuild test -project AgentsMonitor/AgentsMonitor.xcodeproj -scheme AgentsMonitor -destination "platform=macOS"
```

Run only UI tests:
```bash
xcodebuild test -project AgentsMonitor/AgentsMonitor.xcodeproj -scheme AgentsMonitor -destination "platform=macOS" -only-testing:AgentsMonitorUITests
```

## Required Permissions (Local macOS)
UI automation requires local macOS permissions:
- Enable Accessibility for `Xcode` and/or `xcodebuild`.
- Allow Automation permissions when prompted (System Settings -> Privacy & Security -> Automation).
