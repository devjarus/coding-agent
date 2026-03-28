---
name: e2e-testing
description: End-to-end testing and visual validation using Playwright MCP and Chrome DevTools MCP. Use when verifying frontend UI, testing user flows, running Lighthouse audits, or validating application behavior in the browser.
---

# End-to-End Testing

## Two MCP Servers, Two Purposes

| Server | Use For | Key Strength |
|--------|---------|--------------|
| **Playwright MCP** | Testing flows, assertions, generating locators, recording traces | Token-efficient (accessibility tree), cross-browser, built-in test assertions |
| **Chrome DevTools MCP** | Performance profiling, Lighthouse audits, memory snapshots, debugging live sessions | Deep browser internals, network inspection, attach to existing sessions |

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

## Chrome DevTools MCP — Performance & Debugging

### Lighthouse Audit

Run `lighthouse_audit` on any page to get scores for:
- Performance (LCP, FID, CLS)
- Accessibility (contrast, ARIA, labels)
- Best Practices (HTTPS, no errors)
- SEO (meta tags, crawlability)

Use after implementation to verify frontend quality metrics.

### Performance Profiling

1. `performance_start_trace` — begin recording
2. Interact with the page (navigate, click, scroll)
3. `performance_stop_trace` — stop and get trace data
4. `performance_analyze_insight` — get analysis of bottlenecks

### Memory Profiling

`take_memory_snapshot` — detect memory leaks, especially in SPAs with route changes.

### Network Inspection

- `list_network_requests` — see all requests, filter by type
- `get_network_request` — inspect specific request/response headers and body

Useful for verifying API contracts between frontend and backend.

### Console Monitoring

- `list_console_messages` — catch client-side errors, warnings
- `get_console_message` — inspect specific messages

## Testing Patterns

### Smoke Test (after scaffolding)
1. Start the dev server
2. Navigate to localhost
3. Verify the page loads (no console errors, main content visible)
4. Take a screenshot as baseline

### Feature Verification (after implementation)
1. Navigate to the feature
2. Walk through the happy path (fill forms, click buttons, verify results)
3. Test error states (invalid input, network errors)
4. Verify accessibility (Lighthouse audit)
5. Take screenshots for review

### Visual Regression
1. Take screenshots before changes
2. Make changes
3. Take screenshots after changes
4. Compare visually (agent can describe differences)

### API Integration Test
1. Navigate to a page that calls the API
2. `list_network_requests` — verify correct endpoints are called
3. `get_network_request` — verify request/response shapes match spec
4. Check no unexpected errors in console

## Which Agents Use What

| Agent | Playwright MCP | Chrome DevTools MCP |
|-------|---------------|-------------------|
| Frontend Lead | Testing flows, assertions | Lighthouse audit after review |
| Frontend Specialists | Verify their component works in browser | Debug rendering issues |
| Reviewer | Verify spec compliance visually, run Lighthouse | Performance profiling, network contract validation |
| Debugger utility | — | Console errors, network inspection |
