---
artifact: product
writer: product-lead
mutability: evolving                 # body is sharpened in Shape/Review; only Evolution Log is append-only
state: draft                         # product-lead writes draft; orchestrator flips to approved after user confirms direction
approved_by:                         # leave blank — ONLY the orchestrator sets this, after the user confirms direction
approved_at:                         # leave blank — ONLY the orchestrator sets this
north_star:                          # one sentence — the outcome that defines success
updated:                             # ISO date of last sharpening
---

# Product — <product name>

> The north-star this product is steering toward. Read by the architect before every spec and by the orchestrator when direction is in question. Opt-in: it exists to make direction concrete and compounding, not to gate shipping.

## Problem

The real user problem, stated sharply — who hurts, when, and why today's options fail them. (Not the feature; the pain behind it.)

## Target User & Jobs-to-be-Done

- **Primary user:** <one user — resist breadth>
- **Core job:** When <situation>, I want to <motivation>, so I can <expected outcome>.
- **Secondary jobs (later):** <explicitly deferred>

## North-Star

The single outcome/metric that means this product is working. Everything is measured against moving this.

## Core Flows

The essential, clean path(s) through the product — the spine. Keep it minimal; every added branch is a tax on usability.

```
<ASCII flow: entry → steps → decision points → the moment of value>
```

## World-Class Bar

What separates *usable* from *world-class* for THIS product. The qualities, made testable.

- <e.g. value in <10s of first open>
- <e.g. zero-config first run>
- <e.g. recoverable from any error state>
- **Anchors:** <1-2 products that set the standard to clear>

## Non-Goals

What this product explicitly will NOT do. The discipline that keeps the flow clean as the product grows.

- <out of scope — and why>

## Principles

Decision rules that resolve future tradeoffs without re-litigating.

- <e.g. "default over configure", "one obvious path over many options">

## Maturity Ladder

Where the product is and where it's headed.

| Rung | Definition | Status |
|------|------------|--------|
| **MVP** | core flow works end-to-end for the primary job | <current? > |
| **Solid** | reliable, handles errors, no rough edges on the core flow | |
| **World-class** | clears the bar above; users prefer it over anchors | |

**Now:** <rung> — **Next rung gap:** <the single most important thing between here and the next rung>

## Evolution Log

Append-only. Newest entry on top. Each feature's reflection + each periodic review lands here — this is how direction compounds.

<!-- ## YYYY-MM-DD — <feature slug | product-review> -->
<!-- - Shipped: <what> -->
<!-- - North-star delta: <toward world-class | sideways | regressed — why> -->
<!-- - Next best move: <the highest-leverage gap toward the bar> -->
<!-- - Maturity: <ladder position if it changed> -->
