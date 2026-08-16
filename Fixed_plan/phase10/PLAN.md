# Phase 10 — Documentation reconciliation: reference checklist

**Status:** DOCUMENTED FOR REFERENCE ONLY. Not authorized to execute. Logically follows
Phase 9 (assumes PowerShell is actually gone from the active runtime) — do not run this
early just because it looks mechanical.

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
