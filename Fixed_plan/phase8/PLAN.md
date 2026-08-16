# Phase 8 — Human-approved cutover: reference checklist

**Status:** DOCUMENTED FOR REFERENCE ONLY. Not authorized to execute. Per
`master-plan.md`, Phase 8 requires "separate Human authorization after reviewing Phase
6/7 evidence" — reaching Phase 7's N=30 does not itself authorize this. Do not start any
item below without an explicit go-ahead from the Human Owner at that time.

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
- `Fixed_plan/phase7/canary-log.md` (N=30 clean qualifying runs, zero resets)

## Named security reviewer (CR-017)

The Human Owner (Witchwasin K.) has named themself as the CR-017 reviewer. Sign-off on
the supply-chain/containment surface happens at this gate, not before — this file
records who signs off, not that it has happened yet.
