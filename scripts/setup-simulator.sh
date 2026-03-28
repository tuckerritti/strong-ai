#!/bin/bash
set -euo pipefail

# Creates (or reuses) a per-worktree iOS simulator, builds the app, and installs it.
# The simulator UDID is saved to .context/simulator-udid.txt for use with MCP tools.

WORKTREE_NAME=$(basename "$PWD")
SIM_NAME="light-weight-${WORKTREE_NAME}"
CONTEXT_DIR=".context"
UDID_FILE="${CONTEXT_DIR}/simulator-udid.txt"
BUNDLE_ID="com.tuckerr.light-weight"

mkdir -p "$CONTEXT_DIR"

DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
LATEST_RUNTIME=$(xcrun simctl list runtimes available | grep 'iOS' | tail -1 | sed 's/.*- //')

# Reuse existing simulator if it still exists and is on the latest runtime
if [ -f "$UDID_FILE" ]; then
  EXISTING_UDID=$(cat "$UDID_FILE")
  if xcrun simctl list devices | grep -q "$EXISTING_UDID"; then
    # Check if the existing simulator's runtime matches the latest
    CURRENT_RUNTIME=$(xcrun simctl list devices -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    for d in devices:
        if d['udid'] == '$EXISTING_UDID':
            print(runtime)
")
    if [ "$CURRENT_RUNTIME" = "$LATEST_RUNTIME" ]; then
      echo "Reusing existing simulator: $SIM_NAME ($EXISTING_UDID) on $LATEST_RUNTIME"
      xcrun simctl boot "$EXISTING_UDID" 2>/dev/null || true
      UDID="$EXISTING_UDID"
    else
      echo "Runtime changed ($CURRENT_RUNTIME -> $LATEST_RUNTIME), recreating simulator..."
      xcrun simctl shutdown "$EXISTING_UDID" 2>/dev/null || true
      xcrun simctl delete "$EXISTING_UDID"
    fi
  fi
fi

# Create a new simulator if we don't have one
if [ -z "${UDID:-}" ]; then
  echo "Creating iPhone 17 Pro simulator as '$SIM_NAME' on $LATEST_RUNTIME..."
  UDID=$(xcrun simctl create "$SIM_NAME" "$DEVICE_TYPE" "$LATEST_RUNTIME")
  echo "$UDID" > "$UDID_FILE"

  echo "Booting simulator..."
  xcrun simctl boot "$UDID"
fi

echo "Simulator UDID: $UDID"

# Build the app
echo "Building light-weight for simulator..."
xcodebuild -project light-weight.xcodeproj \
  -scheme light-weight \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$CONTEXT_DIR/DerivedData" \
  build 2>&1 | tail -3

# Find and install the .app
APP_PATH=$(find "$CONTEXT_DIR/DerivedData" -name "light-weight.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
  echo "Error: Build succeeded but .app not found" >&2
  exit 1
fi

echo "Installing app..."
xcrun simctl install "$UDID" "$APP_PATH"

echo "Launching app..."
xcrun simctl launch "$UDID" "$BUNDLE_ID"

echo ""
echo "Done! Simulator '$SIM_NAME' is running with UDID: $UDID"
echo "Pass this UDID to iOS simulator MCP tools via the 'udid' parameter."
