<!-- Single source of truth: the durable design system (tokens + component look-contracts + guardrails). Follows the google design.md format (https://github.com/google-labs-code/design.md): YAML token front matter + canonical prose. Framework-agnostic, readable without any CLI. Distilled from shipped UI; per-feature in-flight mockups are not kept here. Generate only for projects with a UI. -->

---
name: <Product Name>
version: 1
colors:
  primary: "<#hex>"
  background: "<#hex>"
  surface: "<#hex>"
  text: "<#hex>"
  muted: "<#hex>"
typography:
  font: "<family>"
  scale: "<e.g. 1.25 modular>"
rounded: "<none | sm | md | lg | full>"
spacing: "<base unit, e.g. 4px>"
components: [button, input, card, nav, modal]
---

# DESIGN.md

> The look & feel and component system. What the product *is* lives in [PRODUCT.md](PRODUCT.md); component file wiring lives in [docs/architecture.md](docs/architecture.md).

## Overview / Brand & Style

<2-3 sentences: the visual personality and the feeling the UI should evoke.>

## Colors

<role → token → usage. Reference the YAML above; don't restate hex twice — name the role and its intent.>

## Typography

<families, weights, the type scale, when to use each level.>

## Layout & Spacing

<grid, spacing rhythm, breakpoints, density.>

## Elevation & Depth

<shadow/elevation levels and when each applies.>

## Shapes

<corner radii, borders, the shape language.>

## Components

<per component: anatomy, states (default/hover/active/disabled/loading/error), and the look-contract. Structure only — implementation matches the project's real stack.>

## Do's and Don'ts

- ✅ <a guardrail that keeps the UI coherent>
- ❌ <an anti-pattern to avoid>
