#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="AgentsMonitor"
PROJECT_PATH="AgentsMonitor/AgentsMonitor.xcodeproj"
SCHEME="AgentsMonitor"
CONFIGURATION="Debug"
DESTINATION="platform=macOS"
BUNDLE_ID="com.agentsmonitor.app"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

build_app() {
  xcodebuild build \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION"
}

build_setting() {
  local key="$1"
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -showBuildSettings |
    awk -F' = ' -v key="$key" '$1 ~ key { print $2; exit }'
}

app_bundle_path() {
  local built_products_dir
  local full_product_name
  built_products_dir="$(build_setting 'BUILT_PRODUCTS_DIR')"
  full_product_name="$(build_setting 'FULL_PRODUCT_NAME')"
  printf '%s/%s\n' "$built_products_dir" "$full_product_name"
}

stop_running_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

launch_app() {
  local bundle_path="$1"
  /usr/bin/open -n "$bundle_path"
}

stop_running_app
build_app
APP_BUNDLE="$(app_bundle_path)"

case "$MODE" in
  run)
    launch_app "$APP_BUNDLE"
    ;;
  --verify|verify)
    launch_app "$APP_BUNDLE"
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    printf '%s is running from %s\n' "$APP_NAME" "$APP_BUNDLE"
    ;;
  --logs|logs)
    launch_app "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    launch_app "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --debug|debug)
    exec lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  *)
    printf 'Unknown mode: %s\n' "$MODE" >&2
    printf 'Usage: %s [run|--verify|--logs|--telemetry|--debug]\n' "$0" >&2
    exit 64
    ;;
esac
