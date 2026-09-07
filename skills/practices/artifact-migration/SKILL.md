---
name: artifact-migration
description: Safely migrate legacy .coding-agent layouts into the canonical product/feature ledger model. User-approved, archive-first, reversible, and never automatic.
scope: conductor
trigger: on-invoke
category: practice
---

# Artifact Migration

Use this only when an existing project contains coordinator artifacts that do
not match the canonical layout:

```text
.coding-agent/
├── CURRENT
├── product.md
└── <feature>/
    ├── ledger.md
    ├── evidence.jsonl
    ├── review.md           optional
    └── design.*            optional
```

Migration protects history without letting two state models compete.

## When to apply

- The user asks to upgrade or clean up existing `.coding-agent/` state.
- Root-level `intent.md`, `spec.md`, `plan.md`, `work.md`, `progress.md`, or
  `.prev*` chains exist.
- A `.coding-agent/features/<slug>/` hierarchy exists beside canonical
  `.coding-agent/<slug>/ledger.md` directories.
- **Never auto-run.** Moving state requires the user to confirm the exact list.

## Safety rules

1. Archive first; never delete migration inputs.
2. Resolve the active feature from `CURRENT` before proposing any move.
3. Do not edit a canonical active ledger or evidence file.
4. Show every source and destination, then ask the user once.
5. Keep archive paths under `.coding-agent/.archive/<UTC timestamp>/`.
6. Do not translate approvals. A legacy `approved` field is historical context,
   not evidence of agreement in the new ledger.
7. Do not synthesize test evidence. Old logs can be archived but never appended
   to canonical `evidence.jsonl`.
8. If classification is ambiguous, leave the file in place and report it.

## Procedure

1. Inventory `.coding-agent/` without changing it.
2. Classify files as canonical live state, legacy feature history, legacy root
   state, or unknown.
3. Build a move table preserving each relative path below the timestamped
   archive directory.
4. Ask the user to approve the exact table.
5. Move only approved legacy paths.
6. To resume old work, initialize a fresh canonical ledger with
   `lib/ledger.sh init <slug>`, summarize the old goal and delivery steps as a
   draft, and ask the user to agree before freezing it.
7. Log the archive location in the new ledger or, without an active feature, in
   a small `.coding-agent/MIGRATION.md` note.

## Return

```text
archived_paths: [<source -> destination>]
canonical_paths_created: [<paths>]
active_feature: <slug or none>
needs_user_agreement: <draft sections that must be reviewed>
left_in_place: [<ambiguous or live paths and why>]
```

Migration is complete only when one canonical layout is active and every moved
artifact is recoverable from the archive.
