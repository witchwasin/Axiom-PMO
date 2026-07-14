# Current Acceptance Report

Date: 2026-07-14
Status: **MERGED** — Round 3 hardening merged to `main` via PR #3 (merge commit
`<commit>`, 2026-07-13); branch `hardening/0.5.x` deleted. This supersedes
`reports/archive/acceptance-0.4.0.md` (the prior round's record, now historical).

Baseline for this round: an independent reviewer independent review of merged `0.5.0` (`main` @
`<commit>`), scored **8.4/10**, with 5 concrete, reproducible validator bypasses. Every
finding was independently re-verified against the source before any fix started (see
`reports/final-hardening-plan.md`).

## What this round fixed

| ID | Bypass | Fix | Commit |
|---|---|---|---|
| H1 | Lite Release passed with no `DELIVERY.md` if `PROJECT.md` merely contained the words "work item" | `DELIVERY.md` now required at Lite Release via the artifact matrix, same mechanism as every other mode | `<commit>` |
| H2 | Release shipped with all Test Summary rows still `pending` and no evidence | New `TEST-RESULT-001` (must be `passed` or reasoned-skip) / `TEST-EVIDENCE-002` (evidence must resolve) | `<commit>` |
| H3 | RTM checked delivery/test/release refs but not `source_ref`, `design_ref`, `status`, or typed evidence | New `RTM-008/009/010`; `RTM-005` now uses the typed reference resolver | `<commit>` |
| H4 | Lite approval/work-item evidence accepted any non-empty text ("approved-by-chat") | Both now resolve via the typed reference resolver; unresolvable is WARN_BLOCKING, not silent | `<commit>` |
| H5 | Docs claimed GitHub Issues could replace `DELIVERY.md`; runtime always required it | `Task source: github` + a named repo now waives `DELIVERY.md` with a `TASK-003` non-blocking note | `<commit>` |
| H6 | Rule catalog and CI gate incomplete | `validation-rules.json` reconciled against every emitted rule id; new `DOCTOR-007` enforces it; CI now runs golden-master verification and fault injection on every push/PR | `<commit>` |

All 5 of an independent reviewer's reproduced bypasses were closed with a paired negative fixture that
proves the old payload now fails, plus a positive fixture where relevant proving the
legitimate case still passes.

## Fixed during the PR (found by CI, not present locally)

| Symptom | Root cause | Fix |
|---|---|---|
| All 86 golden cases mismatched on CI, passed locally | Validator JSON embedded the absolute project path, which differs between a local clone and the GitHub runner (`<ci-path>`) | Normalize the repo root to a `<REPO_ROOT>` placeholder before capture/compare (`<commit>`) |
| 1 golden case (`others-and-sensitive-source-do-not-fail-release`) mismatched on CI | The `Quotation.xlsx` fixture placeholder was excluded by the `**/*Quotation*.xlsx` sensitive `.gitignore` pattern, so it was absent on CI and the `SENSITIVE-001` line disappeared | Scoped `.gitignore` negation for that one fixture path + tracked the file (`<commit>`) |

Both were logged in `reports/pending-issues.md` (PI-001) and are marked resolved there.

## Post-merge cleanup

- **PSScriptAnalyzer** was run over `scripts/` and `tests/` (149 findings, 0 errors) and
  the 10 genuine findings were fixed: auto-variable shadowing (`$args` -> `$psArgs`,
  `$matches` -> `$linkMatches`) and dead function parameters. The remaining 139 are
  by-design (Write-Host console output, the `Add-Result` positional DSL) or false
  positives (`$script:`-scoped variables the per-file analyzer cannot see across
  dot-sourced modules, and a `MatchEvaluator` delegate-required parameter). No CI gate
  was added — this was a one-off cleanup, not standing tooling.

## Test evidence (real run)

- `scripts/pmo-doctor.ps1` — PASS, 0 FAIL (52 checks, including `DOCTOR-006`
  schema_version and `DOCTOR-007` rule-catalog-completeness).
- `scripts/run-validation-tests.ps1` — full positive/negative fixture matrix, 0 FAIL.
- `tests/helpers/config-mutation-tests.ps1` — 5 scenarios (policy enum, skill manifest,
  artifact-policy, schema_version, rule catalog), each asserting the *specific* expected
  rule id fired, not just a non-zero exit code.
- `scripts/run-all-checks.ps1` — green end to end, including all 3 generator-to-Release
  E2E runs (Lite/Standard/Strict) on real `new-project.ps1` output, no example copy-over.
- Golden master (`tests/golden/`) — verified byte-for-byte, 86/86, after every change
  including the PSScriptAnalyzer cleanup (signature changes did not alter any output).
- CI (`.github/workflows/pmo-checks.yml`) green on PR #3: full check suite, `-VerifyGolden`,
  and an inverted fault-injection assertion.

## Known limitations (explicit, not hidden)

- **Branch protection** remains a platform constraint on this GitHub free-plan private
  repo (403 on the protection API), documented and accepted in the prior round.
- **LICENSE** remains explicitly deferred.

## Score

No formal recomputation of an independent reviewer's §9 rubric was done. That reviewer's own anchors say
9.0-9.4 requires "no open P0, reference integrity real, no known bypass" — all five of
that reviewer's named P0s are now closed with real regression control (not test-count
claims), merged to `main`, and green on remote CI. A fresh external review would be the
honest way to confirm a number; this report does not claim one.

## Sign-off

Merged to `main` via PR #3 (`<commit>`) on 2026-07-13, CI green. The PSScriptAnalyzer
cleanup is a follow-up on branch `chore/psanalyzer-cleanup`, pending its own push/PR
decision by the owner.
