---
name: product-shaping
description: Turn a vague request into product direction: real user problem, job-to-be-done, one clean core flow, testable quality bar, non-goals, and maturity position.
scope: planner
trigger: on-invoke
category: practice
---

# Product Shaping

The discipline that converts "I want to build X" into a product decision you
can defend: a real problem, a clean usable flow, and an explicit quality bar.
Used by the planner during framing and product reflection.

## The core move: solution → problem → clean flow

A feature request is almost always a *solution the user jumped to*. Shaping runs it backwards to the problem, then forward to the simplest flow that solves it.

```
"add a dashboard"  ──trace back──▶  what decision can't the user make today?
                                    └─▶ "they can't tell if the job succeeded"
                   ──forward──▶  the ONE flow: open → see status at a glance → act on failures
```

If you can't name the problem behind a request, that's the finding — surface it before any flow design.

## 1. Find the real problem

Ask, in order:
- **Who** specifically hurts? (one primary user — breadth kills clarity)
- **When** does the pain occur? (the triggering situation)
- **Why** do today's options fail them? (if they don't, there may be no product here)
- **What** does relief look like? (the outcome, not the feature)

A sharp problem statement names the user, the moment, and the unmet outcome. "Users want analytics" is not a problem; "a solo founder can't tell at a glance whether last night's batch job failed, so they find out from an angry customer" is.

## 2. Name the job-to-be-done

One JTBD sentence: **When** \<situation>, **I want to** \<motivation>, **so I can** \<outcome>. One primary job. Defer the rest explicitly — deferred is not denied, it's sequenced.

## 3. Design the ONE core flow

The minimal clean path that delivers the job. Rules:
- **One obvious path**, not a menu of options. Every branch is a usability tax.
- **Value early.** Mark the moment the user gets what they came for; minimize steps before it.
- **Draw it** as an ASCII flow (steps, decision points, the value moment). A prose-only flow can't be critiqued.
- **First-run matters most.** The empty/zero-data state is the flow most users see first — design it, don't default it.

## 4. Set the world-class bar

What separates usable from world-class *here*. Make each quality testable, not aspirational:
- ❌ "fast and intuitive"
- ✅ "value visible within 10s of first open; zero config to start; every error state has a recovery action"

Name 1-2 **anchors** — products that already clear the bar — so "world-class" has a concrete referent.

## 5. Declare non-goals

The explicit "we will NOT do X (because Y)". Non-goals are what keep the flow clean as the product grows; without them, scope creep is the default and every feature erodes the spine.

## 6. Place it on the maturity ladder

| Rung | Definition |
|------|------------|
| **MVP** | core flow works end-to-end for the primary job |
| **Solid** | reliable, handles errors, no rough edges on the core flow |
| **World-class** | clears the bar; users prefer it over the anchors |

State where the product is now and the **single most important gap** to the next rung. This makes evolution a sequence of concrete moves, not a vibe.

## Evolution: how direction compounds

In Review/Reflect modes, the question is never "what feature next" in isolation — it's **"what is the single highest-leverage move toward the world-class bar, given where we are on the ladder?"** Rank moves by problem-impact × distance-to-bar. A clean product also *removes* things — always ask what to cut.

## Anti-patterns

- **Feature-listing instead of problem-finding.** A backlog is not a direction.
- **Breadth too early.** Many users, many jobs → no clean flow for anyone.
- **Aspirational bars.** "Delightful" you can't test; "value in <10s" you can.
- **Moralizing.** Surface the missing problem once, with your read, then let the user decide. You inform direction; you don't gatekeep enthusiasm.
- **Resetting each feature.** Without an Evolution Log, every feature re-litigates direction. Compound it.
