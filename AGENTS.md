# Repository Guidelines

## Project Structure & Module Organization
- `AgentsMonitor/` contains the macOS SwiftUI app source.
- `AgentsMonitor/App/` holds the app entry point (`AgentsMonitorApp.swift`).
- `AgentsMonitor/Views/`, `ViewModels/`, `Models/`, `Services/`, `Components/`, `Theme/` hold UI, state, data, and helpers.
- `AgentsMonitor/Resources/Assets.xcassets/` stores images and app assets.
- `AgentsMonitorTests/` contains XCTest unit tests.
- Root utility/docs: `IconGenerator.swift`, `STATUS.md`, `MACOS_STACK_RESEARCH.md`.

## Build, Test, and Development Commands
- Open in Xcode:
  - `open AgentsMonitor/AgentsMonitor.xcodeproj`
- Run locally in Xcode:
  - Select the `AgentsMonitor` scheme and press Cmd+R.
- Run tests in Xcode:
  - Product → Test (Cmd+U).
- Run tests from CLI (requires full Xcode install):
  - `xcodebuild test -project AgentsMonitor/AgentsMonitor.xcodeproj -scheme AgentsMonitor -destination "platform=macOS"`

## Coding Style & Naming Conventions
- Swift 4-space indentation; follow Swift API Design Guidelines.
- Types use `PascalCase`, variables/functions use `camelCase`.
- File names match primary types (e.g., `SessionStore.swift`).
- Keep SwiftUI views small and compose via subviews in `Views/`.

## Testing Guidelines
- XCTest is used (`import XCTest`).
- Test files follow `*Tests.swift`, classes end with `Tests` (e.g., `SessionStoreTests`).
- Test methods use `test...` naming.
- Keep tests deterministic; prefer dependency injection (e.g., pass `persistence: nil`).

## Commit & Pull Request Guidelines
- Recent commits use short, imperative, capitalized subjects without issue IDs.
  - Example: `Add WebSocket support, app icons, and unit tests`
- PRs should include:
  - A clear summary of changes.
  - Testing notes (commands run or “not run” with reason).
  - Screenshots for UI changes (main window and settings).

## Security & Configuration Tips
- Do not hardcode secrets; use environment variables or local config.
- Avoid logging sensitive data (tokens, credentials, PII).
- App entitlements live in `AgentsMonitor/AgentsMonitor.entitlements`.
