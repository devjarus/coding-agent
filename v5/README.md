# coding-agent v5 (parallel build)

A from-scratch reimagining grounded in primitives. Built alongside the live v4
plugin so both can run; v5 is **not yet wired as a plugin** — it's a runnable
skeleton you can dogfood by hand while we harden it.

**Design:** [`docs/concepts/v5-design.md`](../docs/concepts/v5-design.md)
**Craft plane:** [`principles.md`](principles.md)

## The shape
One ledger, one law, three moves, two roles.

- **Law:** no claim advances without evidence; evidence is recorded only by `record.sh`.
- **Primitives:** ledger · evidence · gate.
- **Roles:** conductor (single writer) + worker (stateless, 7 kinds).
- **Lifecycle:** Frame → [Architect] → [Design] → Build → Prove → [Ship → Observe].

## Layout
```
v5/
├── agents/      conductor.md · worker.md      # the two system prompts
├── principles.md                              # operating · build · prove · architect
├── lib/         record.sh · ledger.sh         # record.sh = the only evidence writer
├── gates/       lib.sh + 7 gate predicates
├── hooks/       hooks.json · evidence-wall.sh · session-start.sh
└── templates/   product.template.md · ledger.template.md
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

## Promotion path (when it earns it)
1. Add frontmatter wiring: register `agents/` + merge `hooks/hooks.json` into the
   plugin manifest, scoping paths under `v5/`.
2. Port the ~12 surviving skills into `v5/skills/`.
3. Build the design surface under `v5/surface/`.
4. Dogfood on `~/workspace/personal`; compare against v4 on real runs.
5. When v5 wins, retire v4 and lift `v5/` to the root.
