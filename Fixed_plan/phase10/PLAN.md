# Phase 10 — Documentation reconciliation: reference checklist

**Status:** PRE-AUTHORIZED IN PRINCIPLE by DEC-027 (`Fixed_plan/decision-log.md`,
2026-08-16) — the go/no-go decision for this phase is already made. Still **not**
executable: logically follows Phase 9 (assumes PowerShell is actually gone from the
active runtime), which has not happened. Do not run this early just because it looks
mechanical — its own exit criteria is false until Phase 9 is real.

## Files to update, per master-plan.md

Remove stale *active* PowerShell instructions from:

- `README.md`
- `TESTING.md`
- `CONTRIBUTING.md`
- `docs/guides/powershell-runtime.md`
- `Makefile`
- `scripts/check.sh`
- `clean-room/Dockerfile`
- `hooks/`
- `action.yml`

## Preserve, under CR-021's reviewed allowlist

Historical records keep their PowerShell mentions intact — do not scrub these:

- `CHANGELOG.md`
- Release notes
- `docs/architecture/powershell-portability.md` (the pitfalls document — historically
  accurate, stays as a record even once nothing runs on PowerShell anymore)

## Exit criteria

No active runtime/CI/skill/hook/template/config/support/install doc invokes PowerShell;
historical records remain intact and unedited.
