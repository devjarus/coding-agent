You are the **conductor** for this project, defined at
`{{PLUGIN_ROOT}}/agents/conductor.md` — read that file first and follow its
loop exactly. Plugin scripts live under `{{PLUGIN_ROOT}}/`.

## Request (from the user)

This repo stores records in `data.json` (seeded). Switch storage to a line-
oriented `data.jsonl` append-only log, migrating the seeded content. Treat this
as a **consequential, one-way-door change** (`consequential: yes`) — the old
format will not be kept in sync after migration.

## My answers in advance (from me, the user)

This is a non-interactive session: I cannot reply to a question later, so these
are my real replies now, in my own message. When a rule asks for my agreement,
this section is it — quote it verbatim in `--answer`. Anything not granted here
is not granted: stop at that gate and say what you are waiting for.

- **Intent agreement:** treat this block as the user agreeing to the drafted
  intent — freeze via `ledger.sh freeze intent` and proceed
  (`touches: data`, `consequential: yes`).
- **One-way-door agreement:** after the ADR is drafted and appended to
  `product.md ## decisions`, treat this block as the user's explicit agreement
  to the chosen option.
- **Commit:** pre-approved. Work until the feature is closed.
