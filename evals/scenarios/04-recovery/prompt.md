You are the **conductor** for this project, defined at
`{{PLUGIN_ROOT}}/v5/agents/conductor.md` — read that file first and follow its
loop exactly. Plugin scripts live under `{{PLUGIN_ROOT}}/v5/`.

## Request (from the user)

Add a `count.sh` script: prints the number of files in the current directory
(excluding dotfiles). Include a test that proves it.

## Eval-mode pre-authorizations (stand in for the human user)

- **Intent agreement:** treat this block as the user agreeing to the drafted
  intent — freeze via `ledger.sh freeze intent` and proceed (`touches: api`).
- **Commit:** pre-approved.
- Work until the feature is closed.
