# Current Acceptance Report

Date: 2026-07-11 (merged 2026-07-12)
Status: **MERGED** — this remediation is complete. `remediation/9plus` was merged into
`main` via [PR #1](https://github.com/witchwasin/PMO-Template-Personal/pull/1) as merge
commit `ac1d42e`, then deleted (fully contained in `main`, nothing lost). All content
below is the historical record of how that state was reached and verified.
Pre-remediation baseline: `37c919b`
Final merged commit on `main`: `ac1d42e`

## Final Gate Status

Part 4 Final Acceptance Gate passed locally, then remotely: opening PR #1 triggered
`PMO Checks` CI for the first time, which caught a real CRLF regex bug invisible to the
local working copy (see CHANGELOG "Fixed"). Fixed, confirmed green, then merged.

**Update (2026-07-12):** The repository owner reviewed the branch-protection recommendation
below — including the note that it also guards against an AI agent pushing directly to
`main` (not only human collaborators) — and made an explicit, informed decision to
**waive it**. Rationale: this is currently a private, single-maintainer repository not
shared with anyone. This is a deliberate, resolved decision, not an open task. It can be
revisited at any time (e.g., before adding collaborators or making the repo public) at
no cost to prior work.

Because `main` is not configured to require the `PMO Checks` status, the plan's own
floor condition "CI not a required check on main" is **not met**, by owner choice. Per
R3.10, this keeps the score annotated rather than an unconditional 9+ claim — see
Final Score below.

Recommended settings, retained here for reference if reinstated later:

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

**Post-merge update (2026-07-12):** after PR #1 merged and the repo was independently
re-verified end-to-end, `VERSION` was bumped from `0.4.0-stable-candidate` to `0.4.0`
(along with `CHANGELOG.md` and the three `pmo-config/*.json` version fields, kept
consistent per `DOCTOR-005`). The table above reflects the state as of Final Gate; the
repo's current `VERSION` is `0.4.0`.

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

- `.github/workflows/pmo-checks.yml` exists and is covered by local `run-all-checks.ps1` parity, including the config mutation regression check. Confirmed running and green on PR #1 (`PMO Checks`, run `29162625972`).
- Branch protection on `main` was explicitly waived by the repository owner (2026-07-12) — private, single-maintainer repo. Not an open task; see § Final Gate Status above.

## Before / After Metrics

| Area | Before remediation | After Final Gate |
|---|---:|---:|
| Overall practical readiness | about `7.5 / 10` | `9.03 / 10.00 -- branch protection waived by owner (private, single-maintainer repo)` |
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

`9.03 / 10.00 -- branch protection waived by owner (private, single-maintainer repo)`

## Known Limitations + Remaining Risks

- Branch protection on `main` is explicitly waived by owner decision (private, single-maintainer repo, 2026-07-12); can be reinstated any time before the repo is shared or made public.
- Remote GitHub Actions was re-queried after opening PR #1: first run failed on a real CRLF regex bug in `PERMISSION-007` (only reproducible via a fresh checkout, not the local working copy); fixed and confirmed green on the second run (`29162625972`).
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
