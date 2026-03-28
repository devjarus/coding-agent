---
name: accessibility
description: Web accessibility patterns and requirements (WCAG 2.1 AA). Use when building any user-facing UI.
---

# Accessibility

## Perceivable

- Write meaningful alt text that conveys purpose, not just appearance. Decorative images use `alt=""`.
- Never use color as the sole carrier of information (e.g., red for error — also use an icon or text).
- Maintain contrast ratios: 4.5:1 for normal text, 3:1 for large text (18pt+ or 14pt+ bold).
- Ensure content remains readable and functional when zoomed to 200%.

## Operable

- All interactive elements must be reachable and usable with keyboard alone.
- Maintain a logical, predictable focus order that follows the visual/DOM flow.
- Focus indicators must be visible — never remove outlines without providing an alternative.
- No keyboard traps: users must be able to tab into and out of every component.
- Respect `prefers-reduced-motion`: wrap animations in `@media (prefers-reduced-motion: no-preference)` or disable them via JS.

## Understandable

- Use visible labels — placeholders disappear on input and do not substitute for `<label>` elements.
- Error messages must identify the specific field and describe how to correct it.
- Set `lang` attribute on `<html>` (e.g., `<html lang="en">`).
- Keep navigation consistent across pages — same order, same labels.

## Robust

- Use semantic HTML: `<button>` for actions, `<a>` for navigation. Never use `<div onclick>` or `<span onclick>`.
- Apply ARIA correctly — it supplements semantics, it does not replace them. Prefer native elements.
- Custom interactive components must expose roles, states, and properties via ARIA (e.g., `role="dialog"`, `aria-expanded`, `aria-checked`).

## Common Patterns

### Buttons vs Links
- `<button>`: triggers an action (submit, open modal, toggle).
- `<a href>`: navigates to a new location or resource.

### Modals
- Trap focus inside the modal while it is open.
- Close on Escape key.
- Return focus to the trigger element on close.
- Set `aria-hidden="true"` on background content while modal is open.

### Forms
- Pair every input with a `<label>` using matching `for` / `id` attributes.
- Mark required fields with `aria-required="true"`.
- Link error messages to their field using `aria-describedby`.
- Use action-specific submit button text ("Save changes", not just "Submit").

### Live Regions
- Use `aria-live="polite"` for dynamic content updates, toasts, and loading states.
- Use `aria-live="assertive"` only for critical, time-sensitive alerts.
- Keep live region containers in the DOM from the start; inject content into them dynamically.
