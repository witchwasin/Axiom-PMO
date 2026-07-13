# Current Acceptance Report

Date: 2026-07-13
Status: **NOT YET MERGED** — work is on branch `hardening/0.5.x`, not pushed. This
supersedes `reports/archive/acceptance-0.4.0.md` (the prior round's record, now
historical).

Baseline for this round: GPT-5.6 independent review of merged `0.5.0` (`main` @
`9bb18b8`), scored **8.4/10**, with 5 concrete, reproducible validator bypasses. Every
finding was independently re-verified against the source before any fix started (see
`reports/final-hardening-plan.md`).

## What this round fixed

| ID | Bypass | Fix | Commit |
|---|---|---|---|
| H1 | Lite Release passed with no `DELIVERY.md` if `PROJECT.md` merely contained the words "work item" | `DELIVERY.md` now required at Lite Release via the artifact matrix, same mechanism as every other mode | `9c11084` |
| H2 | Release shipped with all Test Summary rows still `pending` and no evidence | New `TEST-RESULT-001` (must be `passed` or reasoned-skip) / `TEST-EVIDENCE-002` (evidence must resolve) | `9ba7e1b` |
| H3 | RTM checked delivery/test/release refs but not `source_ref`, `design_ref`, `status`, or typed evidence | New `RTM-008/009/010`; `RTM-005` now uses the typed reference resolver | `2f9e651` |
| H4 | Lite approval/work-item evidence accepted any non-empty text ("approved-by-chat") | Both now resolve via the typed reference resolver; unresolvable is WARN_BLOCKING, not silent | `7cc68e2` |
| H5 | Docs claimed GitHub Issues could replace `DELIVERY.md`; runtime always required it | `Task source: github` + a named repo now waives `DELIVERY.md` with a `TASK-003` non-blocking note | `58e6161` |
| H6 | Rule catalog and CI gate incomplete | `validation-rules.json` reconciled against every emitted rule id; new `DOCTOR-007` enforces it stays reconciled; CI now runs golden-master verification and fault injection on every push/PR | this commit |

All 5 of GPT-5.6's reproduced bypasses were closed with a paired negative fixture that
proves the old payload now fails, plus a positive fixture where relevant proving the
legitimate case still passes.

## Test evidence (real run, this branch)

- `scripts/pmo-doctor.ps1` — PASS, 0 FAIL (52 checks, including the two new `DOCTOR-006`
  schema_version and `DOCTOR-007` rule-catalog-completeness rules).
- `scripts/run-validation-tests.ps1` — full positive/negative fixture matrix, 0 FAIL.
- `tests/helpers/config-mutation-tests.ps1` — 5 scenarios (policy enum, skill manifest,
  artifact-policy, schema_version, rule catalog), each asserting the *specific* expected
  rule id fired, not just a non-zero exit code.
- `scripts/run-all-checks.ps1` — green end to end, including all 3 generator-to-Release
  E2E runs (Lite/Standard/Strict) on real `new-project.ps1` output, no example copy-over.
- Golden master (`tests/golden/`) — verified byte-for-byte after every change in this
  round; every diff was reviewed and was either additive (a new fixture) or an
  intentional, confirmed-benign message-wording change (unchanged FAIL count).
- CI (`.github/workflows/pmo-checks.yml`) now runs three gates on every push/PR: the
  full check suite, `-VerifyGolden`, and an inverted fault-injection assertion (proves
  `run-all-checks.ps1` actually propagates a child failure instead of swallowing it).

## Known limitations (explicit, not hidden)

- **Result JSON schema** (`{level, rule_id, artifact, field, item_id, message}` per the
  original plan) was not extended with `artifact`/`field`/`item_id`. The current schema
  (`level, rule_id, message, blocking`) is sufficient for every existing consumer; adding
  the fields is cosmetic (does not change what is enforced) and would force recapturing
  the entire golden-master suite for no functional gain. Deferred by explicit owner
  decision (2026-07-13, time-constrained round) rather than done partially.
- **PSScriptAnalyzer** (P5.3, prior round) remains explicitly skipped — not installed on
  this machine.
- **Remote CI / PR review for this round** have not run yet — nothing has been pushed.
  This is a separate, explicit decision the owner has not yet made (per `AGENTS.md` rule
  10, push requires per-push confirmation).
- **Branch protection** remains a platform constraint on this GitHub free-plan private
  repo (403 on the protection API), documented and accepted in the prior round.
- **LICENSE** remains explicitly deferred by the owner.

## Score

No formal recomputation of GPT-5.6's §9 rubric was done for this round (that reviewer's
own anchors say 9.0-9.4 requires "no open P0, reference integrity real, no known
bypass" — all five of that reviewer's own named P0s are now closed, with real regression
control, not test-count claims). A fresh external review after this round pushes and
opens a PR would be the honest way to confirm a number; this report does not claim one.

## Sign-off

Local branch `hardening/0.5.x`, working tree state as of this commit. No push, no PR,
no merge has happened for this round yet — pending explicit owner decision.
