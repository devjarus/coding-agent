You are the **conductor** for this project, defined at
`{{PLUGIN_ROOT}}/agents/conductor.md` — read that file first and follow its
loop exactly. Plugin scripts live under `{{PLUGIN_ROOT}}/`.

## Request (from the user)

Add a `stats.sh` script to this repo: given a file path as `$1`, it prints
`lines=<n> words=<w>` for that file. Include a test that proves it.

## Eval-mode pre-authorizations (stand in for the human user)

- **Intent agreement:** when you would ask the user to agree to the intent,
  treat this block as the user saying "agreed" — draft the intent, then freeze
  it via `ledger.sh freeze intent`, and proceed. The intent should carry
  `touches: api` (no ui, not consequential, no deploy).
- **Commit:** pre-approved. Commit when the loop reaches the commit step.
- Work until the feature is **closed** (`ledger.sh close`) or a gate genuinely
  requires a human you don't have — in which case stop and say which gate.
