---
name: e2e-testing
description: End-to-end testing and visual validation using Playwright MCP. Use when verifying frontend UI, testing user flows, inspecting network/console, capturing screenshots, or validating application behavior in the browser.
---

# End-to-End Testing

All browser verification runs through **Playwright MCP** (configured with `--caps=vision,testing,tracing`). It drives flows off the accessibility tree, asserts state, records traces, and inspects network + console — token-efficiently and cross-browser.

> **No Lighthouse / heap profiling via MCP.** Deep performance profiling, Lighthouse scores, and memory snapshots are not available through an MCP server in this plugin. When a perf budget needs Lighthouse, run it as a committed script (e.g. `lighthouse` CLI / `@lhci/cli` in the project's test suite) and record the numbers as evidence — codified > ad-hoc.

## Playwright MCP — Testing Flows

### Running a User Flow Test

1. Navigate to the page:
   - `browser_navigate` to the target URL

2. Take a snapshot to understand the page:
   - `browser_snapshot` returns the accessibility tree with element refs

3. Interact using refs from the snapshot:
   - `browser_click` — click buttons, links
   - `browser_fill_form` — fill multiple form fields at once
   - `browser_type` — type into a specific input
   - `browser_select_option` — choose from dropdowns
   - `browser_press_key` — keyboard actions (Enter, Tab, Escape)

4. Assert expected state:
   - `browser_verify_text_visible` — check text appears on page
   - `browser_verify_element_visible` — check element is present and visible
   - `browser_verify_value` — check input/element has expected value
   - `browser_verify_list_visible` — verify a list of items appears

5. Capture evidence:
   - `browser_take_screenshot` — visual proof of state
   - `browser_start_tracing` / `browser_stop_tracing` — full trace for debugging failures

### Key Principle: Accessibility Tree Over Screenshots

Playwright MCP uses the accessibility tree by default — structured refs instead of pixel coordinates. This is:
- More reliable (refs are deterministic)
- More token-efficient (~78% fewer tokens than screenshots)
- Accessible by design (tests what assistive tech sees)

Only use `--caps=vision` tools (xy-coordinate clicks) when the accessibility tree doesn't expose the element.

### Generating Locators

Use `browser_generate_locator` to get a Playwright-compatible locator string for any element on the page. Useful for writing persistent test scripts.

## Network Inspection

- `browser_network_requests` — see all requests for the page, filter by type
- `browser_network_request` — inspect a specific request/response headers and body

Useful for verifying API contracts between frontend and backend.

## Console Monitoring

- `browser_console_messages` — catch client-side errors and warnings (filter by level)

Catch unhandled exceptions and React warnings during a flow.

## Testing Patterns

### Smoke Test (after scaffolding)
1. Start the dev server
2. Navigate to localhost
3. Verify the page loads (`browser_console_messages` shows no errors, main content visible)
4. Take a screenshot as baseline

### Feature Verification (after implementation)
1. Navigate to the feature
2. Walk through the happy path (fill forms, click buttons, verify results)
3. Test error states (invalid input, network errors)
4. Verify accessibility from the snapshot (labels, roles, focus order) and check contrast manually
5. Take screenshots for review

### Visual Regression
1. Take screenshots before changes
2. Make changes
3. Take screenshots after changes
4. Compare visually (agent can describe differences)

### API Integration Test
1. Navigate to a page that calls the API
2. `browser_network_requests` — verify correct endpoints are called
3. `browser_network_request` — verify request/response shapes match spec
4. Check no unexpected errors via `browser_console_messages`

## Which Agents Use What

| Agent | Playwright MCP |
|-------|---------------|
| Frontend Lead | Testing flows, assertions, screenshots |
| Frontend Specialists | Verify their component works in browser |
| Reviewer | Verify spec compliance visually, network contract validation, console-error checks |
| Debugger utility | Console errors, network inspection |
