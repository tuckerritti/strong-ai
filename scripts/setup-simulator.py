#!/usr/bin/env python3
"""Creates (or reuses) a per-worktree iOS simulator, builds the app, and installs it.

The simulator UDID is saved to .context/simulator-udid.txt for use with MCP tools.
"""

import json
import subprocess
import sys
from pathlib import Path

DEVICE_TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
BUNDLE_ID = "com.tuckerr.light-weight"

worktree_name = Path.cwd().name
sim_name = f"light-weight-{worktree_name}"
context_dir = Path(".context")
udid_file = context_dir / "simulator-udid.txt"

context_dir.mkdir(exist_ok=True)


def run(cmd, **kwargs):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kwargs)


def get_latest_runtime():
    result = run(["xcrun", "simctl", "list", "runtimes", "available", "-j"])
    runtimes = json.loads(result.stdout)["runtimes"]
    ios_runtimes = [r for r in runtimes if r["platform"] == "iOS"]
    if not ios_runtimes:
        print("Error: No iOS runtimes available", file=sys.stderr)
        sys.exit(1)
    return ios_runtimes[-1]["identifier"]


def get_device_runtime(udid):
    result = run(["xcrun", "simctl", "list", "devices", "-j"])
    data = json.loads(result.stdout)
    for runtime, devices in data["devices"].items():
        for device in devices:
            if device["udid"] == udid:
                return runtime
    return None


def device_exists(udid):
    result = run(["xcrun", "simctl", "list", "devices", "-j"])
    data = json.loads(result.stdout)
    for devices in data["devices"].values():
        for device in devices:
            if device["udid"] == udid:
                return True
    return False


latest_runtime = get_latest_runtime()
udid = None

# Reuse existing simulator if it still exists and is on the latest runtime
if udid_file.exists():
    existing_udid = udid_file.read_text().strip()
    if device_exists(existing_udid):
        current_runtime = get_device_runtime(existing_udid)
        if current_runtime == latest_runtime:
            print(f"Reusing existing simulator: {sim_name} ({existing_udid}) on {latest_runtime}")
            subprocess.run(["xcrun", "simctl", "boot", existing_udid],
                           capture_output=True)  # may already be booted
            udid = existing_udid
        else:
            print(f"Runtime changed ({current_runtime} -> {latest_runtime}), recreating simulator...")
            subprocess.run(["xcrun", "simctl", "shutdown", existing_udid], capture_output=True)
            subprocess.run(["xcrun", "simctl", "delete", existing_udid], capture_output=True)

# Create a new simulator if we don't have one
if udid is None:
    print(f"Creating iPhone 17 Pro simulator as '{sim_name}' on {latest_runtime}...")
    result = run(["xcrun", "simctl", "create", sim_name, DEVICE_TYPE, latest_runtime])
    udid = result.stdout.strip()
    udid_file.write_text(udid)

    print("Booting simulator...")
    run(["xcrun", "simctl", "boot", udid])

print(f"Simulator UDID: {udid}")

# Build the app
print("Building light-weight for simulator...")
build_result = subprocess.run(
    [
        "xcodebuild",
        "-project", "light-weight.xcodeproj",
        "-scheme", "light-weight",
        "-destination", f"platform=iOS Simulator,id={udid}",
        "-derivedDataPath", str(context_dir / "DerivedData"),
        "build",
    ],
    capture_output=True,
    text=True,
)
# Print last 3 lines of output
output_lines = build_result.stdout.strip().splitlines()
print("\n".join(output_lines[-3:]))
if build_result.returncode != 0:
    print(build_result.stderr, file=sys.stderr)
    sys.exit(1)

# Find and install the .app
derived_data = context_dir / "DerivedData"
app_paths = list(derived_data.rglob("light-weight.app"))
app_paths = [p for p in app_paths if p.is_dir()]

if not app_paths:
    print("Error: Build succeeded but .app not found", file=sys.stderr)
    sys.exit(1)

app_path = app_paths[0]

# Read actual bundle ID from built app (may differ from base, e.g. .debug suffix)
plist_result = run(["plutil", "-extract", "CFBundleIdentifier", "raw", str(app_path / "Info.plist")])
actual_bundle_id = plist_result.stdout.strip()

print("Installing app...")
run(["xcrun", "simctl", "install", udid, str(app_path)])

print(f"Launching app ({actual_bundle_id})...")
run(["xcrun", "simctl", "launch", udid, actual_bundle_id])

print()
print(f"Done! Simulator '{sim_name}' is running with UDID: {udid}")
print("Pass this UDID to iOS simulator MCP tools via the 'udid' parameter.")
