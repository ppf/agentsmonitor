#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/AgentsMonitor/AgentsMonitor.xcodeproj"
SCHEME="AgentsMonitor"
DESTINATION="platform=macOS"

echo "Running status-item preflight..."
"$ROOT_DIR/scripts/verify_status_item.sh"

echo "Running full test suite..."
xcodebuild test -project "$PROJECT_PATH" -scheme "$SCHEME" -destination "$DESTINATION"
