---
name: ios-testing-debugging
description: iOS testing and debugging — XcodeBuildMCP for builds/tests/LLDB, ios-simulator-mcp for simulator UI interaction/screenshots, XCTest/Swift Testing for unit tests, XCUITest for UI automation.
---

# iOS Testing & Debugging

Testing and debugging iOS apps using MCP servers (XcodeBuildMCP + ios-simulator-mcp), Xcode CLI tools, and test frameworks.

## When to Apply

- Building and testing iOS apps
- Managing iOS simulators (boot, install, launch, screenshot)
- Writing XCTest or Swift Testing unit tests
- Writing XCUITest UI automation tests
- Debugging crashes, memory leaks, layout issues
- Verifying UI flows on simulator

## MCP Servers Available

Two MCP servers are configured in `.mcp.json` for iOS development:

### XcodeBuildMCP (`mcp__xcodebuild__*`)

The primary tool for building, testing, and debugging:

- **Build**: `xcodebuild_build` — build project/workspace for simulator or device
- **Test**: `xcodebuild_test` — run unit and UI test suites
- **Debug**: `xcodebuild_debug` — attach LLDB, set breakpoints, inspect variables
- **Resolve errors**: build errors include fix suggestions; iterate automatically

### ios-simulator-mcp (`mcp__ios-simulator__*`)

Simulator control and UI interaction:

- **Screenshots**: `screenshot` — capture current simulator screen
- **UI inspection**: `ui_describe_all` — get accessibility tree of entire screen
- **Tap**: `ui_tap` — tap at coordinates or element
- **Type**: `ui_type` — input text into focused field
- **Swipe**: `ui_swipe` — swipe gestures
- **Point inspection**: `ui_describe_point` — get element at coordinates
- **View**: `ui_view` — compressed screenshot as base64
- **Video**: `record_video` / `stop_recording` — capture interaction videos
- **App lifecycle**: `install_app`, `launch_app` — install and launch on simulator

## Testing Workflow

### For Evaluator (verifying iOS apps)

1. **Build the app** — use XcodeBuildMCP to build for simulator
2. **Boot simulator** — use `xcrun simctl boot` via Bash or MCP
3. **Install and launch** — use ios-simulator-mcp `install_app` + `launch_app`
4. **Inspect UI** — `ui_describe_all` to get accessibility tree
5. **Test flows** — `ui_tap`, `ui_type`, `ui_swipe` to interact
6. **Screenshot evidence** — `screenshot` at each step for review.md
7. **Run test suite** — use XcodeBuildMCP to run XCTest/XCUITest
8. **Clean up** — `xcrun simctl shutdown all`

### For Implementor (writing tests)

1. **Unit tests first** (TDD):
   - XCTest: `XCTAssertEqual`, `XCTAssertTrue`, `XCTAssertThrowsError`
   - Swift Testing (iOS 16+): `@Test`, `#expect`, `#require`, `@Suite`
   - Test ViewModels and business logic — not view hierarchy
   - Mock dependencies via protocol conformance

2. **UI tests for critical flows**:
   - XCUITest: `XCUIApplication().launch()`, query by accessibility identifier
   - Interact: `.tap()`, `.typeText()`, `.swipeUp()`
   - Assert: `.exists`, `.waitForExistence(timeout:)`

3. **Build and run** — use XcodeBuildMCP from CLI

## Fallback: CLI Commands (rules/cli-fallback.md)

When MCP servers aren't available, use Bash directly:

```bash
# List simulators
xcrun simctl list devices available

# Boot and install
xcrun simctl boot "iPhone 16"
xcrun simctl install booted ./build/MyApp.app
xcrun simctl launch booted com.example.MyApp

# Screenshot
xcrun simctl io booted screenshot /tmp/screen.png

# Build and test
xcodebuild test -scheme MyApp -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Clean up
xcrun simctl shutdown all
```

## Debugging (rules/debugging.md)

- **XcodeBuildMCP LLDB** — attach debugger, set breakpoints, inspect variables via MCP
- **Console.app** — filter by app process for os_log/print output
- **Instruments** — Time Profiler, Allocations, Leaks, Network
- **Memory Graph** — detect retain cycles and leaks

## Rules

1. **Prefer MCP tools over raw CLI** — XcodeBuildMCP and ios-simulator-mcp provide structured output
2. **Always clean up simulators** — shutdown after testing to free resources
3. **Use accessibility identifiers** — not labels for element queries (labels change with localization)
4. **Test on multiple sizes** — iPhone SE, iPhone 16, iPad
5. **Mock network in unit tests** — use URLProtocol stubbing, not real API calls
6. **Screenshot on failure** — capture simulator state for debugging
7. **Never hardcode simulator UDIDs** — query by name/type
