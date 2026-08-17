# Phase 9 — Human-approved PowerShell deletion: reference checklist

**Status:** COMPLETE. The PowerShell reference implementation is deleted
(`dfb6f8b`, 92 files: `scripts/*.ps1`, `tests/helpers/*.ps1`,
`tests/e2e/*.ps1`, `src/probe/marker-harness.ps1`, `src/probe/pwsh-resolver.ts`).
Every probe converted to golden-fixture regression; `run-all-checks.ts`,
`ci-profile.ts`/`ci-profile-cli.ts`, `run-ci-suite.ts`/`run-ci-suite-cli.ts`,
`hooks/scope-advisory.sh`, and `.github/workflows/pmo-checks.yml` all
ported/updated to need zero PowerShell. Final re-verification (the "zero
PowerShell present, not just zero invoked" proof master-plan.md requires)
is archived in `Fixed_plan/phase6/differential-proof-report.md` §4,
confirmed on real Windows/macOS/Linux CI (`dfb6f8b`, `98e7c13`, `56b5099`,
`38fa07b`, `333b1da`, `ff56d18`) and by a new permanent test
(`clean-room.test.ts`'s PowerShell-provably-absent case), not just this
session's own terminal checks. See the decision log for
how each precondition was resolved: CR-017 sign-off (DEC-031), second-reviewer
gap waived (DEC-032), Phase 8 live-period resolved as "proceed immediately"
(DEC-033), the mid-execution CI/CD workflow rewrite scope expansion approved
as DEC-034.

## Open point, resolved

`master-plan.md`'s own Definition of Done says: "A named Human authorized final
deletion; **a separate Human** reviewed the final diff." DEC-032 formally
waives this for this solo-maintainer project — the Human Owner is the sole
reviewer of the deletion diff, recorded as a deliberate acceptance rather
than an oversight.

## What deletion did, concretely

1. Deleted `scripts/*.ps1` (60), `tests/helpers/*.ps1` + `tests/e2e/*.ps1`
   (29), `src/probe/marker-harness.ps1`, `src/probe/pwsh-resolver.ts`, and
   the orphaned `dist/probe/pwsh-resolver.js` — 92 files, the entire
   reference implementation and its adapter code. `AXIOM_ROLLBACK_PWSH` had
   already been removed at Phase 8 cutover; there was nothing left to roll
   back to.
2. Kept, permanently: `Fixed_plan/phase0/` through `Fixed_plan/phase7/`
   reports, golden fixtures under `tests/golden/` (including the 11
   probe-specific fixtures Phase 9 itself added under
   `tests/golden/probes/`), `Fixed_plan/phase6/differential-proof-report.md`,
   `Fixed_plan/phase7/canary-log.md`. `Fixed_plan/phase0/capture-*.ps1` (7
   files) also kept, as the approved plan specified — historical record of
   how the original goldens were captured, not part of the active reference.
3. Re-ran the final-tree proof after the deletion landed —
   `Fixed_plan/phase6/differential-proof-report.md` §4. Confirms the repo
   works correctly with `AXIOM_PWSH` unset on real CI hosts (Windows,
   macOS, and Linux), plus a new permanent committed test
   (`clean-room.test.ts`) rather than only an ad-hoc session-time check.
   Does not additionally prove `pwsh` physically unresolvable via `PATH`
   scan — an earlier attempt at that broke Linux CI for a reason unrelated
   to PowerShell (see §4), and turned out unnecessary anyway: with
   `pwsh-resolver.ts` deleted, no code path left searches `PATH` for
   PowerShell, so `AXIOM_PWSH` unset already exercises everything reachable.

## What this phase found and fixed along the way

Ten distinct real bugs, each found by actual reproduction (a failing run,
a real Windows CI log, or independent re-verification before committing) and
fixed against the reference before it was gone — full account in
`Fixed_plan/phase6/differential-proof-report.md` §4. Notably: a
`runPortedChain` conditional-call gap that produced spurious findings for
any project with no `PROJECT.md`; six hardcoded `"/"` path-separator bugs
invisible on every non-Windows host all session, caught only by the first
real Windows CI run against the newly-ported `validation-fixtures.ts`; and
a `canonical-normalizer.ts` divergence from the reference's own literal
backslash-pair fold.

## What Phase 9 does not cover (Phase 10's job)

`README.md`, `TESTING.md`, `CONTRIBUTING.md`, and other consumer-facing
documentation still describe PowerShell as the engine. Left untouched here
per `AGENTS.md`'s own scope boundary for this phase and
`Fixed_plan/parallel-prep-inventory.md`'s disposition. Phase 10 starts only
on the Human Owner's separate instruction.
