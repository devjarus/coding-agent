# coding-agent v5 (parallel build)

A from-scratch reimagining grounded in primitives. Built alongside the live v4
plugin so both can run. As of v5.0.0 the five v5 agents are **registered in the
plugin manifest** (dispatchable as `subagent_type: conductor|planner|developer|
diagnostician|designer|deployer`) and the v5 hooks are wired — but the conductor is **not the
default entry** yet. Promotion to default is gated on dogfooding (see
[`PLAN.md`](PLAN.md) Phase 4).

**Design:** [`docs/concepts/v5-design.md`](../docs/concepts/v5-design.md)
**Craft plane:** [`principles.md`](principles.md)

## The shape
One ledger, one law, one conductor + five kind-specific agents.

- **Law:** no claim advances without evidence; evidence is recorded only by `record.sh`.
- **Primitives:** ledger · evidence · gate.
- **Roles:** conductor (single writer) dispatches five stateless agents —
  planner (frame · architect) · developer (build · prove · review) ·
  diagnostician (diagnose) · designer (design) · deployer (ship).
- **Architecture dialogue:** before a consequential ADR, the planner can return
  one to three system- or component-level questions. The conductor asks them in
  the main conversation, records the answers, and redispatches the planner.
- **Gates:** framed? → architected? → designed? → proven? → reviewed? → clean? →
  shipped? → observed? (conditional gates go `n/a` when they don't apply).
- **Lifecycle:** Frame → [Architect] → [Design] → Build → Prove → Review →
  [Ship → Observe].

## Layout
```
v5/
├── agents/      conductor.md + planner · developer · diagnostician · designer · deployer
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
# write intent, including `test-command-<tier>:` entries, then record the reply:
bash $v5/lib/ledger.sh freeze intent --answer "yes, proceed"

bash $v5/gates/framed.sh          # → pass
bash $v5/gates/proven.sh          # → block (no test evidence yet)
bash $v5/lib/record.sh "echo ok" run    # records, but kind=run
bash $v5/gates/proven.sh          # → still block (hollow proof rejected)
bash $v5/lib/record.sh "<frozen test-command-unit>" test unit
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
