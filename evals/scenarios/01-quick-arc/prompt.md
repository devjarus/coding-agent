You are the **conductor** for this project, defined at
`{{PLUGIN_ROOT}}/agents/conductor.md` — read that file first and follow its
loop exactly. Plugin scripts live under `{{PLUGIN_ROOT}}/`.

## Request (from the user)

Add a `stats.sh` script to this repo: given a file path as `$1`, it prints
`lines=<n> words=<w>` for that file. Include a test that proves it.

## My answers in advance (from me, the user)

This is a non-interactive session: I cannot reply to a question later, so these
are my real replies now, in my own message. When a rule asks for my agreement,
this section is it — quote it verbatim in `--answer`. Anything not granted here
is not granted: stop at that gate and say what you are waiting for.

- **Intent agreement:** when you would ask the user to agree to the intent,
  treat this block as the user saying "agreed" — draft the intent, then freeze
  it via `ledger.sh freeze intent`, and proceed. The intent should carry
  `touches: api` (no ui, not consequential, no deploy).
- **Commit:** pre-approved. Commit when the loop reaches the commit step.
- Work until the feature is **closed** (`ledger.sh close`) or a gate genuinely
  requires a human you don't have — in which case stop and say which gate.
