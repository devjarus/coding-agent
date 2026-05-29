---
template: research
# Research Template

```yaml
---
feature: <slug>
researched_by: orchestrator   # or architect, when it synthesizes for a spec
researched_at: <ISO>
state: complete
---
```

# Research: <the question>

## Question
The decision or question being researched. One or two sentences.

## Sub-questions
The independent threads fanned out (one investigator each).
- SQ-1: <sub-question> — <tool/lens>
- SQ-2: <sub-question> — <tool/lens>

## Findings
Each claim with its source and confidence. Confidence reflects how hard it was tried against.

| # | Claim | Source | Confidence |
|---|---|---|---|
| F-1 | <claim> | <url / Context7 lib / repo> | high / medium / low |

## Refuted / Demoted
Claims that did not survive verification. Why they were dropped or downgraded.
- <claim> — refuted by <source/reason>

## Synthesis
The reconciled answer. Contradictions resolved explicitly (winner + why). The recommendation, traceable to F-rows above.

## Open Questions
What couldn't be resolved and would need a decision or further investigation.
