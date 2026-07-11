# Current Acceptance Report

Date: 2026-07-11
Branch: `remediation/9plus`
Baseline main: `37c919b`
Latest pushed branch commit before Final Gate: `ba3a22b`

## Final Gate Status

Part 4 Final Acceptance Gate passed locally. No commit or push was performed during this gate.

Branch protection on `main` remains a pending human action for the repository owner. It must be configured in GitHub settings; executor automation cannot enforce it from the working tree.

Required branch-protection settings:

- require pull request before merge
- require the `PMO Checks` status check
- block direct push to `main`
- require at least one approval
- disallow force push

## Version Before / After

| Item | Before Final Gate | After Final Gate |
|---|---|---|
| `VERSION` | `0.4.0-stable-candidate` | `0.4.0-stable-candidate` |
| top `CHANGELOG.md` version | `0.4.0-stable-candidate` | `0.4.0-stable-candidate` |

No version bump was made in Part 4 because this gate only added/adjusted acceptance-test evidence and the close-out report.

## Files Created / Modified / Moved

Created:

- `tests/helpers/config-mutation-tests.ps1`

Modified:

- `reports/current-acceptance.md`
- `tests/fixtures/invalid-part2-matrix/RELEASE.md`
- `tests/fixtures/invalid-empty-rtm/DELIVERY.md`
- `tests/fixtures/invalid-rtm-references-missing-requirement/DELIVERY.md`

Moved:

- none

## Commands + Exit Codes

| Command | Exit | Result |
|---|---:|---|
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/pmo-doctor.ps1` | 0 | `PASS=48 WARN=0 FAIL=0` |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-validation-tests.ps1` | 0 | matrix `PASS=53 FAIL=0` |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-all-checks.ps1` | 0 | doctor, matrix, config mutation, Lite/Standard/Strict examples, and E2E all passed |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-all-checks.ps1 -TestChildScript tests/helpers/exit-1.ps1` | 1 | expected fail; fault injection is not swallowed |
| `powershell -NoProfile -ExecutionPolicy Bypass -File tests/helpers/config-mutation-tests.ps1 -RepoPath D:\GitHub\PMO-Template-Personal` | 0 | JSON runtime config proved as source of truth |

Targeted gate checks also passed:

| Check | Result |
|---|---|
| TODO / placeholder in `source/` | does not fail Release gate |
| TODO / placeholder in governed files | fails Release gate |
| fabricated `REQ`, `DEC`, and `D` references | fail reference/evidence validation |
| empty RTM | fails |
| RTM referencing missing requirement | fails |
| empty rollback row | fails |
| `WIREFRAME.html` | passes without false-positive placeholder errors |
| Lite minimal Release | passes with `Release Approved`, no `RELEASE.md`, no QA, no RTM, no RAID |

## Test Summary

Framework doctor:

- active skills: exactly 7
- `DOCTOR-SKILL-001`: PASS
- `TABLE-001`: PASS
- fake echo hooks: none found
- permission checks: PASS
- local markdown links: PASS

Validation matrix:

- positive cases: 12
- negative cases: 36
- doctor-negative cases: 5
- total: 53
- result: `PASS=53 FAIL=0`

Run-all gate:

- Lite E2E: PASS
- Standard E2E: PASS
- Strict E2E: PASS
- final result: PASS

CI / repository controls:

- `.github/workflows/pmo-checks.yml` exists and is covered by local `run-all-checks.ps1` parity, including the config mutation regression check.
- Branch protection is still pending human repository-owner action on GitHub.

## Before / After Metrics

| Area | Before remediation | After Final Gate |
|---|---:|---:|
| Overall practical readiness | about `7.5 / 10` | `9.03 / 10.00 pending branch protection` |
| Validation matrix size | 38 cases after early runtime hotfix | 53 cases |
| Framework doctor result | not final-gate clean | `PASS=48 WARN=0 FAIL=0` |
| Runtime modes | Lite / Standard / Strict defined | Lite / Standard / Strict validated with examples and E2E |
| Config source of truth | partly document-driven | JSON config mutation-tested as runtime source of truth |
| Release approval | inconsistent Lite exemption found | all modes require valid `Release Approved` |

## Final Score

Decision score uses the exact 8 dimensions and weights from `reports/remediation-plan.md` section `R3.10`.

| Dimension | Weight | Score | Weighted |
|---|---:|---:|---:|
| Architecture & Workflow Fit | 15% | 9.2 | 1.38 |
| AI Runtime Fit | 10% | 9.0 | 0.90 |
| Context Discipline | 10% | 9.1 | 0.91 |
| Validator Correctness | 20% | 9.1 | 1.82 |
| Templates & Examples | 10% | 9.0 | 0.90 |
| Active Skills Quality | 15% | 8.8 | 1.32 |
| Tooling, CI & Release Gate | 10% | 9.0 | 0.90 |
| Traceability & Governance | 10% | 9.0 | 0.90 |

Formula:

`Final Score = SUM(dimension score * dimension weight) = 9.03 / 10.00`

Public claim should remain:

`9.03 / 10.00 pending branch protection`

## Known Limitations + Remaining Risks

- Branch protection on `main` is pending human action in GitHub settings.
- Remote GitHub Actions status was not re-queried during this local Final Gate; local parity checks passed.
- The accepted process violation remains recorded in `reports/process-violation.md`; future commit/push work must be reviewed before push.
- `.claude/settings.json` guardrails depend on the AI runtime honoring those settings.

## Git Status + Diff Summary

Working tree after Final Gate is intentionally not committed.

Changed files:

- `reports/current-acceptance.md`
- `tests/fixtures/invalid-part2-matrix/RELEASE.md`
- `tests/fixtures/invalid-empty-rtm/DELIVERY.md`
- `tests/fixtures/invalid-rtm-references-missing-requirement/DELIVERY.md`
- `tests/helpers/config-mutation-tests.ps1`

Diff purpose:

- add config mutation proof helper
- wire config mutation proof into `run-all-checks.ps1`, which is the CI entry point
- tighten negative fixtures used by Final Gate reference-integrity checks
- record the Final Acceptance close-out report
