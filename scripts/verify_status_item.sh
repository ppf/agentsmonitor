#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/AgentsMonitor/AgentsMonitor.xcodeproj"
SCHEME="AgentsMonitor"
DESTINATION="platform=macOS"

echo "Preflighting status item + popover..."
xcodebuild test \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:AgentsMonitorUITests/AgentsMonitorMenuBarTests/testMenuBarExtraContents
