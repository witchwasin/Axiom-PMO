# Phase 0 — Behavior inventory (138 rules, first pass)

**Status:** FIRST PASS. Classifies every catalog rule by whether its behavior is
`config-driven` (metadata only), `code-driven` (firing conditions live only in
PowerShell), or `hybrid` (identity/severity/remediation from JSON, firing from code).
Per F1/CR-003, firing conditions are code, so `hybrid` is the default; the exceptions are
the orphan catalog entries and the code-emitted IDs with no catalog entry.

## Rule-ID prefix census (138 rules)

| Prefix | Count | Classification | Notes |
|---|---:|---|---|
| DOCTOR | 18 | hybrid (3 non-numeric IDs: `DOCTOR-EXAMPLE`, `DOCTOR-HOOK`, `DOCTOR-STRUCT`) | registry + emitters in `pmo-doctor.ps1` |
| HANDOFF | 14 | hybrid | `handoff-validator.ps1` |
| RTM | 10 | hybrid | `rtm-validator.ps1` |
| EXEC | 8 | hybrid | `execution-contract-*` |
| PERMISSION | 8 | hybrid | permission model |
| AREV | 7 | hybrid | `adversarial-review-validator.ps1` |
| DPROV | 7 | hybrid | `design-provider-validator.ps1` |
| RESEARCH | 7 | hybrid | `research-validator.ps1` |
| TEST | 7 | hybrid | test-summary rules |
| APPROVAL | 5 | hybrid | `approval-validator.ps1` |
| SCOPE | 5 | hybrid | `scope-diff-*` |
| SOURCE | 4 | hybrid | `source-validator.ps1` |
| EXT | 4 | hybrid | `externalization-validator.ps1` |
| CHANGE | 3 | hybrid | `change-control-validator.ps1` |
| MODE | 3 | hybrid | `mode-resolver.ps1` |
| RELEASE | 3 | hybrid | `release-validator.ps1` |
| TASK | 3 | hybrid | task-source parsing |
| PATH | 2 | hybrid | `path-containment.ps1` |
| REF | 2 | hybrid | `reference-resolver.ps1` |
| STRICT | 2 | hybrid | strict triggers |
| VPROOF | 2 | hybrid | `visual-proof-validator.ps1` |
| BLOCKER / DESIGN / ENUM / EVIDENCE / GENERAL / LINK / PLACEHOLDER / QA / REVIEW / SECURITY / SENSITIVE / STRUCT / TABLE / WORKITEM | 1 each (14) | hybrid | single-rule groups |

## Code-emitted IDs with NO catalog entry (15)

`SECRET-001…006`, `BRANCH-001/002`, `COMMIT-001/002`, `LOCAL-PATH-001…003`,
`OLD-NAME-001`, `OLD-URL-001` — all from `check-public-hygiene.ps1`. **Classification:
`code-driven`** (no JSON metadata at all). The port must re-home these into the typed
rule-ID registry so `pmo-doctor` reconciliation (DOCTOR-007) still finds them.

## Catalog rules with no numeric suffix (not orphans — regex-coverage artifact)

`DOCTOR-EXAMPLE`, `DOCTOR-HOOK`, `DOCTOR-STRUCT` are present in `validation-rules.json`
**and** emitted by `pmo-doctor.ps1`, but they carry no `-\d{3}` suffix, so the golden
coverage regex misses them. They are covered by the `doctor-baseline.txt` golden. (The v1
plan's "3 never-referenced rules" claim was inaccurate for these three — pmo-doctor emits
all of them.) No action needed beyond keeping the coverage regex aware of non-numeric IDs.

## Config-mutation coverage requirement

Per CR-003/CR-006, every load-bearing `policy.json` key must be proven load-bearing by a
config-mutation test in the Phase 4/6 gates. This inventory is the index for that suite;
the mutation matrix itself is generated during Phase 4 (gated on the pwsh run).

## Reconciliation note

The `hybrid` default is a *placeholder grouping*, not a per-rule reading. The precise
per-rule classification (which fields are config vs code per rule) is finalized in the
same pass that raises golden coverage to ~100%, because capturing a golden for each rule
is exactly what proves which side (config vs code) drives its firing.
