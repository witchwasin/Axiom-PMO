# Phase 7 Canary Log

Qualifying run: a push-to-main CI run of the full profile with
AXIOM_ROLLBACK_PWSH unset (PLAN.md §4). N = consecutive clean qualifying
runs; any validation-surface drift (canary-baseline.json mismatch) logs a
RESET and restarts N at 0 (PLAN.md §3). Every qualifying run appends a line
below; the appended lines are committed from the phase7-canary artifact by
the maintainer -- this is a committed file, matching every other Phase 0-6
artifact. No external state store.

## 2026-08-16 — baseline captured, mechanism landed

- `Fixed_plan/phase7/canary-baseline.json` records the SHA-256 of the
  validation surface (`src/**/*.ts`, `scripts/**/*.ps1`, `pmo-config/*.json`,
  `Fixed_plan/phase0/compatibility-case-manifest.md`, `tests/golden/**`) at
  commit `34e201c` (367 files hashed).
- The rewired CLI (`cli/axiom.mjs`, default in-process TS engine with
  `AXIOM_ROLLBACK_PWSH` rollback) landed in the same commit.
- N = 0. No qualifying CI runs yet; the counter accrues over real time.
- Canary matrix: Node 24.18.0 and 22.x on windows-ps51 (powershell.exe
  rollback), windows-ps7, linux, and macos (PLAN.md §4).
2026-08-16T15:47:25.941Z run clean N=1 sha=3b468ba node=v24.18.0 hosts=windows-ps51,windows-ps7,linux,macos
2026-08-16T17:06:32.511Z RESET N=1->0 sha=6b132b0 changed=scripts/setup-claude-integration.ps1,src/tools/setup-claude-integration.ts,src/tools/setup-integration.test.ts,src/probe/junction-probe.ts
2026-08-16T18:01:08.398Z RESET N=0->0 sha=3c7d342 changed=scripts/lib/path-containment.ps1,scripts/setup-claude-integration.ps1,src/core/path-containment.ts,src/probe/junction-probe.ts,src/tools/setup-claude-integration.ts,src/tools/setup-integration.test.ts
