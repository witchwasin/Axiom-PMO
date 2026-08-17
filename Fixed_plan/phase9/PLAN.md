# Phase 9 — Human-approved PowerShell deletion: reference checklist

**Status:** EXECUTING. Every precondition resolved: CR-017 sign-off given (DEC-031),
second-reviewer gap waived (DEC-032), Phase 8 live-period resolved as "proceed
immediately" (DEC-033) — all `Fixed_plan/decision-log.md`, 2026-08-17.

## Open point that needs the Human Owner's decision when this comes up

`master-plan.md`'s own Definition of Done says: "A named Human authorized final
deletion; **a separate Human** reviewed the final diff." That literally asks for two
different people. If this stays a solo-maintainer effort, that line can't be satisfied
as written — worth deciding in advance how to handle it (an external reviewer for just
this one diff, or the Human Owner explicitly deciding to waive/reinterpret this specific
DoD line) rather than discovering the contradiction at the moment of deletion.

## What deletion concretely does, when authorized

1. Delete `scripts/*.ps1` (the reference implementation), the reference-adapter code the
   probes used to spawn PowerShell (`src/probe/pwsh-resolver.ts` and the `spawnSync`
   reference calls inside each probe), and the `AXIOM_ROLLBACK_PWSH` toggle entirely —
   there is nothing left to roll back to once the reference is gone.
2. Keep, permanently: the implementation-neutral corpus/case data and every proof
   artifact — `Fixed_plan/phase0/` through `Fixed_plan/phase7/` reports, golden fixtures
   under `tests/golden/`, `Fixed_plan/phase6/differential-proof-report.md`,
   `Fixed_plan/phase7/canary-log.md`. These are the audit trail; master-plan.md is
   explicit that only "the reference adapter and retired implementation" get removed.
3. Re-run the final-tree proof **after** the deletion changes land — master-plan.md
   requires this explicitly, since removing the reference changes what "final tree"
   even means. This is a new proof pass (does the repo work correctly with zero
   PowerShell *present*, not just zero PowerShell *invoked*), not a re-read of the old
   one.

## Evidence this decision will be made from

- Phase 8 cutover having been live for some period (how long is itself a decision the
  Human Owner should make at that time — not invented here).
- No regressions or rollback-toggle usage reported during that period.
