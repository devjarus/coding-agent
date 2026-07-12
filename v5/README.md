# coding-agent v5 (parallel build)

A from-scratch reimagining grounded in primitives. Built alongside the live v4
plugin so both can run. As of v5.0.0 the five v5 agents are **registered in the
plugin manifest** (dispatchable as `subagent_type: conductor|planner|developer|
designer|deployer`) and the v5 hooks are wired — but the conductor is **not the
default entry** yet. Promotion to default is gated on dogfooding (see
[`PLAN.md`](PLAN.md) Phase 4).

**Design:** [`docs/concepts/v5-design.md`](../docs/concepts/v5-design.md)
**Craft plane:** [`principles.md`](principles.md)

## The shape
One ledger, one law, one conductor + four kind-specific agents.

- **Law:** no claim advances without evidence; evidence is recorded only by `record.sh`.
- **Primitives:** ledger · evidence · gate.
- **Roles:** conductor (single writer) dispatches four stateless agents —
  planner (frame · architect) · developer (build · prove · diagnose · review) ·
  designer (design) · deployer (ship).
- **Gates:** framed? → architected? → designed? → proven? → reviewed? → clean? →
  shipped? → observed? (conditional gates go `n/a` when they don't apply).
- **Lifecycle:** Frame → [Architect] → [Design] → Build → Prove → Review →
  [Ship → Observe].

## Layout
```
v5/
├── agents/      conductor.md + planner · developer · designer · deployer
├── principles.md                              # operating · build · prove · review · architect
├── lib/         record.sh · ledger.sh         # record.sh = the only evidence writer
├── gates/       lib.sh + 8 gate predicates
├── hooks/       hooks.json · evidence-wall.sh · session-start.sh
├── templates/   product.template.md · ledger.template.md
├── PLAN.md      the promotion plan (phased task list)
└── design-vet.md  the adversarial review + v4-vs-v5 lifecycle comparison
```

## Try it by hand
```bash
cd <a test project>
v5=/Users/suraj-devloper/workspace/codingAgent/v5

bash $v5/lib/ledger.sh product-init
bash $v5/lib/ledger.sh init my-feature
# write intent into .coding-agent/my-feature/ledger.md, then:
bash $v5/lib/ledger.sh freeze intent

bash $v5/gates/framed.sh          # → pass
bash $v5/gates/proven.sh          # → block (no test evidence yet)
bash $v5/lib/record.sh "echo ok" run    # records, but kind=run
bash $v5/gates/proven.sh          # → still block (hollow proof rejected)
bash $v5/lib/record.sh "<real test cmd>" test
bash $v5/gates/proven.sh          # → pass (bound to current tree)
```

## Promotion path (tracked in [`PLAN.md`](PLAN.md))
1. ~~Fix the vetted breaks~~ (Phase 1) and ~~port the load-bearing v4 muscles~~
   (Phase 2) — **done**.
2. ~~Register the agents + wire the hooks in the manifest~~ (Phase 3) — **done**
   (v5.0.0); live subagent-resolution verification is the one interactive step.
3. Dogfood on the test suite + a real feature; A/B vs v4 (Phase 4).
4. When v5 wins, make the conductor the default and retire v4 incrementally
   (Phase 5).
