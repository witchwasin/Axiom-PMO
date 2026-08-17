# Phase 8 — Human-approved cutover: reference checklist

**Status:** EXECUTING. N=10 was waived by DEC-030 (proceeding at N=1, banked at
`0fda09e`); CR-017 sign-off was actually given by the Human Owner, DEC-031. Both
recorded in `Fixed_plan/decision-log.md`, 2026-08-16.

## What "cutover" concretely does, when authorized

1. Remove the `AXIOM_ROLLBACK_PWSH` gate from `cli/axiom.mjs` — the Node path becomes
   unconditional for every consumer, not just the canary population. The `.ps1` spawn
   code path is deleted from the *default* flow (the reference scripts themselves are
   NOT deleted yet — that is Phase 9, a separate decision).
2. Update active docs: README, TESTING, CONTRIBUTING, support-policy language,
   `action.yml`'s description if it names PowerShell as the execution engine.
3. Versioning: a version bump per whatever semver/release policy this project already
   uses — not decided by this plan; confirm the policy before bumping anything.
4. Consumer contracts: anything published externally (Action marketplace listing,
   plugin manifest) that documents runtime requirements gets updated to reflect Node,
   not PowerShell, as what actually runs.
5. Re-verify at the exact cutover commit: per CR-009 ("final delivered tree ≠ proven
   tree"), re-run the full Phase 6 differential proof one more time at the commit that
   is about to ship, not just at some earlier commit in the canary window. What ships
   must be what was proven, not merely descended from it.

## Evidence this decision will be made from

- `Fixed_plan/phase6/differential-proof-report.md` (240 differential cases)
- `Fixed_plan/phase7/canary-log.md` (N=10 clean qualifying runs, zero resets — 30 → 5 →
  10 by DEC-028/DEC-029)

## Named security reviewer (CR-017)

The Human Owner (Witchwasin K.) has named themself as the CR-017 reviewer. Sign-off on
the supply-chain/containment surface happens at this gate, not before — this file
records who signs off, not that it has happened yet.
