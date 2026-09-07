# review: <feature-slug>

<!-- Written by the `review` kind. The FORMAT is load-bearing: `reviewed?`
     counts lines matching `^- \[blocking\]` and cross-checks that count against
     the recorded evidence entry. A finding written any other way (`* [blocking]`,
     an indented bullet, prose) is invisible to the gate — it would record a
     clean verdict with defects on the page. Keep findings flush-left, one per
     line, in exactly the shape below. -->

reviewed-tree: <the tree sha this review covered — `gates/lib.sh ca_tree_sha`>
base: <the diff base this review read>

## findings

<!-- One per line, flush-left, `file:line` required. Nothing else at this level.
     blocking = fails an acceptance criterion, or a security/correctness defect.
     advisory = everything else (naming, structure, nits). Recorded, not gating.
     A clean review keeps this section with zero finding lines — do not delete it.

     Shape (these examples live inside the comment so they are not counted):
       - [blocking] auth: token compared with == not constant-time — src/auth.ts:42
       - [advisory] naming: `doIt` reads as a stub — src/cart.ts:88          -->

## notes

<!-- Optional prose: what you looked for and did not find, coverage you judged
     thin, anything the conductor should weigh. Never put findings here — the
     gate cannot see them. -->
