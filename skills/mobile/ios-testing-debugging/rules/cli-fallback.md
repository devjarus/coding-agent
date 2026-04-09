# CLI Fallback Commands

When MCP servers are unavailable, use these Bash commands directly.

## Simulator Management

```bash
# List available simulators (name, UDID, state)
xcrun simctl list devices available

# Boot a specific device by name
xcrun simctl boot "iPhone 16"

# Install app on booted simulator
xcrun simctl install booted /path/to/MyApp.app

# Launch app by bundle ID
xcrun simctl launch booted com.example.MyApp

# Take screenshot
xcrun simctl io booted screenshot /tmp/screenshot.png

# Set clean status bar for screenshots
xcrun simctl status_bar booted override --time "9:41" --batteryLevel 100 --cellularMode active

# Open URL in simulator (deep linking)
xcrun simctl openurl booted "myapp://deep/link"

# Reset simulator to clean state
xcrun simctl erase "iPhone 16"

# Shutdown all simulators
xcrun simctl shutdown all
```

## Building

```bash
# Build for simulator
xcodebuild -scheme MyApp -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# Build with specific configuration
xcodebuild -scheme MyApp -configuration Debug \
  -sdk iphonesimulator build

# Clean build folder
xcodebuild clean -scheme MyApp

# Build workspace (CocoaPods/SPM)
xcodebuild -workspace MyApp.xcworkspace -scheme MyApp \
  -sdk iphonesimulator build
```

## Testing

```bash
# Run all tests
xcodebuild test -scheme MyApp -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Run specific test class
xcodebuild test -scheme MyApp -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:MyAppTests/ViewModelTests

# Run with code coverage
xcodebuild test -scheme MyApp -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -enableCodeCoverage YES

# Test results in JSON (for parsing)
xcodebuild test -scheme MyApp -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -resultBundlePath /tmp/results.xcresult
```

## Logs

```bash
# Stream simulator logs
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.example.MyApp"'

# Get crash logs
find ~/Library/Logs/DiagnosticReports -name "MyApp*" -newer /tmp/test-start
```
