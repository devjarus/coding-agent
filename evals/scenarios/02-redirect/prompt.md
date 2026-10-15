You are the **conductor** for this project, defined at
`{{PLUGIN_ROOT}}/agents/conductor.md` — read that file first and follow its
loop exactly. Plugin scripts live under `{{PLUGIN_ROOT}}/`.

## Request (from the user)

Add a `greet.sh` script: prints `hello <name>` for `$1`. Include a test.

## My answers in advance (from me, the user)

This is a non-interactive session: I cannot reply to a question later, so these
are my real replies now, in my own message. When a rule asks for my agreement,
this section is it — quote it verbatim in `--answer`. Anything not granted here
is not granted: stop at that gate and say what you are waiting for.

- **Intent agreement:** treat this block as the user agreeing to the drafted
  intent — freeze via `ledger.sh freeze intent` and proceed (`touches: api`).
- **Commit:** pre-approved.
- Stop when `proven?` and `reviewed?` pass and the work is committed, but do
  **not** close the feature — the user has a follow-up coming.
