# Phase 0 — Baseline fingerprint + zero-active-user check

**Branch:** `feat/migrate-interpreter-to-node-ts`
**Captured by:** Deepseek (executing agent)
**Date:** 2026-08-15
**Status:** COMPLETE for all fields except the cross-host CI matrix (CI-only, runs on
GitHub-hosted Windows/Linux/macOS runners).

## Baseline fingerprint

| Field | Value |
|---|---|
| Git SHA (full) | `db259338d054df51b7379728b3558815c42a18c6` |
| Git SHA (short) | `db25933` |
| OS | macOS 26.6.2 (arm64) |
| PowerShell | PowerShell 7.6.4 at `/Users/arm/tools/pwsh/pwsh` |
| Node | v23.11.0 |
| Git | 2.50.1 (Apple Git-155) |
| Locale / TZ | `LANG=C.UTF-8`, `TZ=+07` (UTC+07:00) |
| Golden corpus aggregate SHA-256 (pre-expansion) | `72ce62444f912f00395e038a0877dd4b973d2bd871e22d9cebf902a7a1db1d8e` |
| `pmo-config/*.json` aggregate SHA-256 (pre-drop-5.1) | `1cf64cebd860b64ef6ce8e613bb310a5b3192f4ff076a90041a5158dcc966ede` |
| Baseline suite result | `run-validation-tests.ps1 -VerifyGolden` → **PASS=161 FAIL=0**, all 156 golden masters match (canonical) |
| Golden coverage | **63/138 (46%) → 135/136 real firing rules (~99%)** after Phase 0 capture |
| Cross-host matrix run IDs | **deferred** — CI-only (Windows pwsh7 / Linux pwsh7 / macOS pwsh7 jobs) |

## Zero-active-user check (adjudication (c) — verify, not assume)

| Signal | Result | Source |
|---|---|---|
| Forks | **0** | `gh repo view --json forkCount` |
| Stars | 2 | `gh repo view --json stargazerCount` |
| Watchers/subscribers | **0** | `gh api repos/.../subscribers` |
| Dependents (Action consumers) | none (endpoint 404 = no dependency-graph data) | `gh api repos/.../dependents` |
| Published releases | exist (v1.1.0 … v2.0.0) — but no fork/watcher activity | `gh release list` |

**Result: CONFIRMED zero active users.** 0 forks, 0 watchers, 2 stars (trivial), no
dependency-graph data. Lighter rollback/compat machinery is justified per §7(c), and the
Phase 0 exit-criterion requirement (actual result, recorded) is satisfied. If any
consumer appears later, restore the full CR-016/CR-020 machinery.

## Drop Windows PowerShell 5.1 (Phase 0 prerequisite — DONE)

| Change | Status |
|---|---|
| `pmo-checks.yml` 5.1 job (`pmo-checks`, `shell: powershell`) | removed |
| `pwsh-host.ps1` resolution order (`powershell`/`powershell.exe`) | removed (pwsh only) |
| `pwsh-host.ps1` `Test-WindowsHost` | simplified (PSEdition check removed) |
| `run-execution-command.ps1` `$onWindows` | simplified (PSEdition check removed) |
| `m4-m6-tests.ps1` `$IsWindows` branch | simplified |
| `pmo-doctor.ps1` DOCTOR-010 / DOCTOR-011 | retired (recorded, not silent) |
| `validation-rules.json` DOCTOR-010 / DOCTOR-011 | removed (138 → 136 rules) |
| Post-change verification | `pmo-doctor` PASS=58 FAIL=0; `run-validation-tests -VerifyGolden` PASS=158 FAIL=0 |

**Note (per instructions):** 5.1-only defects may not reproduce on pwsh 7 locally; the
Windows 5.1 CI leg is removed, so any residual 5.1-only behavior is retired by definition
rather than ported. `docs/rules/DOCTOR-010.md` / `DOCTOR-011.md` are now orphaned docs and
are left for Phase 10 documentation reconciliation (CR-021 allowlist).
