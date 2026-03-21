# strong-ai

iOS workout coach app built with SwiftUI and SwiftData.

## Simulator Testing

Each worktree gets its own simulator so agents can QA test in parallel.

**Setup:** Run `./scripts/setup-simulator.sh` from the worktree root. This clones an iPhone 17 Pro simulator, builds the app, and installs it. The simulator UDID is saved to `.context/simulator-udid.txt`.

**Using MCP tools:** Read the UDID from `.context/simulator-udid.txt` and pass it as the `udid` parameter to all iOS simulator MCP tools (`ui_tap`, `ui_view`, `screenshot`, `ui_describe_all`, etc.).

**Rebuilding:** Run the script again after code changes — it reuses the existing simulator and rebuilds.
