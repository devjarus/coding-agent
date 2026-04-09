# Debugging iOS Apps

## LLDB via XcodeBuildMCP

The `xcodebuild_debug` MCP tool provides LLDB access:

- Attach to running process
- Set breakpoints by file:line or symbol
- Inspect variables and memory
- Execute LLDB expressions
- Step through code

## Common Debug Scenarios

### Crash Investigation

1. Check crash logs: `~/Library/Logs/DiagnosticReports/`
2. Symbolicate if needed: `atos -arch arm64 -o MyApp.app.dSYM/Contents/Resources/DWARF/MyApp -l <load_address> <crash_address>`
3. Set exception breakpoint in LLDB: `breakpoint set -E swift`
4. Reproduce and inspect backtrace: `bt`

### Memory Leaks

1. Run with Instruments > Leaks template
2. Or use LLDB: `leaks <pid>` 
3. Check for retain cycles: `@objc` closures capturing `self`
4. Use `[weak self]` or `[unowned self]` in escaping closures
5. Memory Graph debugger for visual cycle detection

### Layout Issues

1. Use ios-simulator-mcp `ui_describe_all` — get full accessibility/layout tree
2. Screenshot at different sizes — use `xcrun simctl` with different device types
3. Check Auto Layout constraint conflicts in console:
   - Filter: `UIViewAlertForUnsatisfiableConstraints`
4. Use `_printHierarchy()` in LLDB for UIKit views

### Performance

1. Instruments > Time Profiler — find hotspots
2. Instruments > Allocations — track memory growth
3. SwiftUI: Instruments > SwiftUI template — view body evaluation count
4. LLDB: `expression CATransaction.setDisableActions(true)` to test without animation

### Network Debugging

1. Use Network Link Conditioner (Settings > Developer) to simulate slow networks
2. Console.app — filter by `nw_` for network subsystem logs
3. `URLSession` delegate for request/response inspection in tests
