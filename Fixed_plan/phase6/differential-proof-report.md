# Phase 6 — Final-tree differential proof report (validator surface)

**Branch:** `feat/migrate-interpreter-to-node-ts`
**Date:** 2026-08-15
**Method:** direct reference (PowerShell) vs direct candidate (Node/TypeScript) on the
same fixtures, canonical-form compared. No `AXIOM_IMPL` dispatcher; each side runs its
own entrypoint.

## Result: 63 differential cases, 63 PASS

| Probe | Cases | Reference entrypoint | Candidate entrypoint |
|---|---:|---|---|
| `differential-probe.js` | 38 | `scripts/validate-project.ps1` | `src/probe/validate-chain.ts` |
| `execution-probe.js` | 3 | `scripts/verify-execution-result.ps1` | `src/exec/verify-execution-result.ts` |
| `marker-probe.js` | 16 | `scripts/lib/marker-block.ps1` | `src/marker/marker-block.ts` |
| `marker-io-probe.js` | 6 | `scripts/setup-claude-integration.ps1` | `src/marker/marker-io.ts` |
| `doctor-probe.js` | 1 (58 rows) | `scripts/pmo-doctor.ps1` | `src/doctor/pmo-doctor.ts` |

## Coverage by rule family

| Rule family | Rules | Status |
|---|---|---|
| STRUCT/TASK/PATH/PLACEHOLDER/SENSITIVE/LINK | — | ✅ differential-green |
| SOURCE/EVIDENCE/REF | SOURCE-001..003, EVIDENCE-001, REF-001/002 | ✅ |
| APPROVAL | APPROVAL-001..005 | ✅ |
| MODE/ENUM/STRICT/WORKITEM | MODE-001..003, ENUM-001, STRICT-001/002, WORKITEM-001 | ✅ |
| CHANGE | CHANGE-001..003 | ✅ |
| EXT | EXT-001..004 | ✅ |
| RESEARCH | RESEARCH-001..007 | ✅ |
| DPROV | DPROV-001..007 | ✅ |
| DESIGN/VPROOF | DESIGN-001, VPROOF-001/002 | ✅ |
| RTM/TEST/RELEASE | RTM-001..010, TEST-RESULT-001, TEST-EVIDENCE-001..003, TEST-SUMMARY-001, RELEASE-001, RELEASE-SCOPE-001, RELEASE-STATUS-001, REVIEW-001, QA-REVIEW-001, SECURITY-REVIEW-001, BLOCKER-001 | ✅ |
| HANDOFF | HANDOFF-001..014, TEST-DESIGN-001/002 | ✅ |
| SCOPE-DIFF | SCOPE-DIFF-001..005 | ✅ |
| EXEC | EXEC-001..008 | ✅ |
| AREV | AREV-001..007 | ✅ |
| DOCTOR/PERMISSION/TABLE | DOCTOR-000..014, PERMISSION-000..007, TABLE-001 | ✅ |

## Bugs the differential probes found and fixed

1. `getDecisionIds` returned `[]` instead of `null` (PowerShell collapses empty `return @()` to `$null`).
2. `release-validator` used PS-only `\z` end-of-string.
3. `workitem-validator` did not pass `sentinel_rules` to `testFieldValue`.
4. `table-parser` passed PS inline flags `(?i)` to JS RegExp.
5. `marker-harness.ps1` used `ConvertFrom-Json` (PSCustomObject) instead of `-AsHashtable` for named-parameter splatting.
6. `pmo-doctor` `loadJson` did not strip UTF-8 BOM (policy.json / skill-manifest.json carry one).

## Remaining (not yet done — see Phase 5 gaps)

The validator library and doctor are fully ported and differential-green. Still open:
- `cli/axiom.mjs` rewire to call the library in-process (still spawns `pwsh`).
- Orchestrators/tools: pmo-status, assess-handoff, digest tools, ci-profile, stateful
  commands (new-project, setup-claude-integration, export-execution-contract,
  run-execution-command, aggregate-diagnostics), release/hook/plugin tools.
- `tests/` porting (per `Fixed_plan/phase0/tests-disposition.md`).

The above are the Phase 5 remainder; Phase 6's hard differential gate for the
*validator surface* is satisfied and archived here.
