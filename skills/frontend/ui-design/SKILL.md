---
name: ui-design
description: Visual design principles for building polished, professional UIs. Use when creating or styling frontend components to ensure they look intentional and refined, not generic or developer-default.
---

# UI Design

Visual design principles that transform functional UI into polished, professional interfaces.

## When to Apply

- Building new pages, dashboards, or component layouts
- Styling components with Tailwind or CSS
- Reviewing frontend output for visual quality
- Any work order that includes UI elements users will see

## Rules (rules/design-rules.md)

### CRITICAL

- **DES-01:** Visual hierarchy -- one primary focal point, supporting secondaries, de-emphasized tertiary
- **DES-02:** Spacing and rhythm -- 4px/8px base unit, tight grouping for related, generous between sections
- **DES-03:** Color usage -- limited palette, semantic colors, background hierarchy, sparing accents

### HIGH

- **DES-04:** Typography -- 2 body sizes, 2-3 heading sizes, 1.5 line height, max 65-75ch width
- **DES-05:** Component polish -- consistent radii, sparing shadows, transitions on interactives, consistent icons
- **DES-06:** Layout patterns -- sidebar+main for dashboards, grid for cards, centered for content, space-y for forms

### MEDIUM

- **DES-07:** Empty states -- illustration + message + CTA; skeleton screens over spinners
- **DES-08:** Design references -- model after Linear, Vercel, Stripe for the appropriate UI type

## Anti-Patterns

- Flat hierarchy (everything same size/weight)
- Multiple competing primary buttons
- Cramped layouts with minimal padding
- Rainbow of unrelated colors
- Pure black on pure white (too harsh)
- No hover states on clickable elements
- Mixed border radii and icon families
- Full-width text on wide screens

## Priority Summary

| ID | Rule | Priority |
|----|------|----------|
| DES-01 | Visual hierarchy | CRITICAL |
| DES-02 | Spacing and rhythm | CRITICAL |
| DES-03 | Color usage | CRITICAL |
| DES-04 | Typography | HIGH |
| DES-05 | Component polish | HIGH |
| DES-06 | Layout patterns | HIGH |
| DES-07 | Empty states | MEDIUM |
| DES-08 | Design references | MEDIUM |
