# Protocol — Product Direction

**Entry:** opt-in / escalated — never auto-triggered. One of: direction is unclear at intake, the user asks "what should I build / is this the right thing", the user invokes a product review, or a feature reaches close-out (reflection).
**Exit:** `.coding-agent/product.md` exists/sharpened and (Shape/Review) the user has confirmed direction; or a reflection entry is appended (Reflect).
**Owner:** Orchestrator (dispatches Product-Lead; owns the user-approval gate). Product-Lead writes `product.md`; never signs.

This protocol exists for the case where the user is eager to build without clear product direction. It makes direction **concrete** (a real problem + a clean flow) and **compounding** (a north-star that evolves), without forcing a ceremony on users who already know what they want.

## When the orchestrator brings in the Product-Lead

**Opt-in — offer, don't impose.** Trigger signals:

| Signal | Action |
|---|---|
| User says "not sure what to build", "what should I build", "is this the right thing", "I don't know what I want" | **Offer** Shape mode (one line: "Want me to pin the product direction first — the problem + core flow — before we build?"). Proceed only if the user accepts. |
| Architect returns discovery answers of "I don't know" to product-shape questions | Offer Shape mode, same as above. |
| User explicitly invokes ("product direction", "shape this", "/product-review") | Enter the named mode directly. |
| A feature reaches close-out AND `product.md` exists | Run **Reflect** (lightweight, no gate). Skip for touch-up/micro and when `product.md` doesn't exist. |

**Never** insert a product-direction gate in front of a user who has stated a clear, decided request ("just build X"). The whole point is opt-in: direction is available, not mandatory.

## Shape mode

1. **Dispatch Product-Lead** (`Mode: shape`) with: paths to `profile.md`, existing `product.md` (if any), `learnings.md`, and the user's request verbatim.
2. Product-Lead engages the `product-shaping` skill, traces the request back to a real problem, designs the ONE core flow, sets the world-class bar + non-goals, places the product on the maturity ladder, and writes/sharpens `product.md` (`state: draft`).
3. **Approval gate (orchestrator).** Direction is the user's call. Surface `product.md` for confirmation:
   - Print a 5-line summary (problem · user/job · core flow · world-class bar · the next rung) + `AskUserQuestion(approve / adjust / skip-direction)`.
   - On `approve` → flip `product.md` `state: approved`, set `approved_by: user` + `approved_at`. Direction now feeds the architect's spec phase.
   - On `adjust` → re-dispatch Product-Lead with the user's notes (one revision pass).
   - On `skip-direction` → leave `product.md` as draft; proceed to build as the user wishes. (Opt-in means the user can always decline.)
   - If Product-Lead returned `ask_user.questions` (genuinely forked directions), bundle them into the same `AskUserQuestion` call first, then re-dispatch with the answers.
4. The architect reads approved `product.md` before writing a spec — the spec serves the north-star and the core flow, not a one-off idea.

## Reflect mode (per-feature, at close-out)

Runs as a step in `${CLAUDE_PLUGIN_ROOT}/protocols/close-out.md` (full close-out only; skipped for touch-up/micro and when no `product.md` exists). No user gate.

1. **Dispatch Product-Lead** (`Mode: reflect`) with: the feature's `spec.md` + `review.md` summary + `product.md` path.
2. Product-Lead returns one `evolution_entry` (did this move the north-star? next-best-move? maturity change?).
3. **Orchestrator appends** the entry to `product.md § Evolution Log` (append-only; orchestrator is the writer of the on-disk update, consistent with single-writer discipline) and updates the maturity-ladder "Now:" line if it changed.
4. Append action-log: `product-reflect | <slug> | <north-star delta>`.

## Review mode (periodic / `/product-review`)

1. **Dispatch Product-Lead** (`Mode: review`) with: `product.md`, `learnings.md`, shipped-feature list.
2. Product-Lead assesses maturity honestly, proposes the next 1-3 highest-leverage moves toward world-class (ranked, each tied to the user problem + world-class bar), flags anything to cut, and evolves `product.md`.
3. **Approval gate (orchestrator):** same as Shape step 3 — print the sharpened direction + ranked moves, `AskUserQuestion(approve / adjust / skip)`. On approve, the evolved `product.md` becomes the new north-star; the ranked moves are candidates the user can turn into feature intents.
4. Append action-log: `product-review | <N moves proposed> | maturity: <rung>`.

## Hard rules

- **Opt-in, always.** This protocol never blocks shipping on its own. The orchestrator offers; the user decides.
- **Product-Lead writes `product.md` only.** Direction, not implementation. Spec/plan/code stay with architect/implementor.
- **Orchestrator owns the on-disk Evolution Log append and all user approvals.** Product-Lead returns structured payloads; it does not sign or directly mutate coordinator state, consistent with the single-dispatcher model.
- **`product.md` body evolves; the Evolution Log is append-only.** Sharpen direction in place; never rewrite logged history.

## Checks fired

| Check | When |
|-------|------|
| `action-logged` | continuous (reflect/review log their entries) |
