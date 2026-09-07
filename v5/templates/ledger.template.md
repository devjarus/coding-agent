# ledger: <feature>

## intent
<!-- conditional gate tags — keep the ones that apply, delete the rest:
     touches: ui          (turns on designed?; also forces an e2e tier)
     consequential: yes   (turns on architected?)
     deploys: yes         (turns on shipped? + observed?)
     tiers:               REQUIRED — the verification tiers proven? demands,
                          e.g. `tiers: typecheck, unit, e2e`. Every one of them
                          needs its own green run bound to the final tree.
     test-command-<tier>: REQUIRED — the exact command approved for each tier,
                          e.g. `test-command-unit: npm test -- --runInBand`.
                          record.sh rejects substitutes. -->
goal:
tiers:
test-command-<tier>:
scope:
non-goals:
acceptance:
<!-- the conductor stamps `frozen: agreed` here once you approve (ledger.sh freeze intent) -->

## plan
1.
<!-- frozen marker added by ledger.sh freeze plan -->

## evidence
see evidence.jsonl  (append-only, written only by record.sh)

## log
