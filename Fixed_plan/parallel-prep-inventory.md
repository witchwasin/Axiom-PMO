# Phase 8/9/10 — Parallel prep inventory (compiled while N accrues)

**Purpose:** read-only prep work for Phases 8/9/10, compiled during the Phase 7
settling window so each phase is mechanical when its gate actually opens. This
is **not** phase execution: no code changed, no doc rewritten, no script
deleted — nothing here advances any phase or alters the canary surface. It is
the survey each phase's checklist needs, done early.

Compiled 2026-08-16 against `main` at `236a35e`.

---

## Phase 8 — cutover prep

### Versioning policy (PLAN.md item 3: "confirm the policy")

- Pattern in `CHANGELOG.md`: `## X.Y.0 - YYYY-MM-DD` headers, semver-style,
  with `### Added` / `### Changed` sections; no release automation visible.
- Current release: **2.1.0** (2026-08-15). The migration (Phases 0–7) landed on
  main without a bump.
- Next bump lands at cutover. Phase 8 changes the execution engine default
  (Node replaces PowerShell) but the CLI output/exit contract is byte-identical
  (Phase 6/7 proof), so this is not a breaking consumer change under the
  project's own semver use — a `2.2.0`-shaped bump is the natural fit. Confirm
  with the Human Owner at cutover time; this is a finding, not a decision.

### Consumer-contract staleness (PLAN.md items 2/4 — survey, no edits)

- `action.yml`: 5 lines mention PowerShell/pwsh/.ps1 (description names the
  execution engine).
- `README.md`: 26 lines mention PowerShell/pwsh/.ps1.
- Full per-file inventory overlaps with Phase 10 below (same files).

---

## Phase 9 — PowerShell deletion prep

### Deletion diff review package (for the "separate Human reviewer" decision)

- **`scripts/*.ps1`: 25 files** — the reference implementation.
- **Probes that spawn the reference** (the reference-adapter code): 5 probes —
  `doctor-probe.ts`, `execution-probe.ts`, `marker-io-probe.ts`,
  `stateful-probe.ts`, `tool-probe.ts` (each `spawnSync`s a `scripts/*.ps1`).
- **`src/probe/pwsh-resolver.ts`** — the shared host resolver; imported by
  **14 files** (`src/`, `cli/`, `tests/`).
- **`AXIOM_ROLLBACK_PWSH` references: 14 files** — `cli/axiom.mjs` (the
  toggle), `scripts/github-action/run-action.mjs` (inherits it),
  `scripts/canary-baseline.mjs`, `tests/helpers/cli-tests.mjs`,
  `tests/helpers/github-action-tests.mjs`, `src/tools/plugin-install-spike.test.ts`,
  `src/tools/clean-room.test.ts`, `src/probe/surface-probe.ts`,
  `.github/workflows/pmo-checks.yml`, and the `Fixed_plan/` docs.
- **Open decision the Human Owner must make before Phase 9** (unchanged by
  this prep): the DoD line "a separate Human reviewed the final diff" needs an
  external reviewer for this one diff, or an explicit Human-owner decision to
  waive/reinterpret that line.

### What deletion must keep (audit trail, per PLAN.md item 2)

`Fixed_plan/phase0/`–`phase7/` reports, `tests/golden/**`,
`Fixed_plan/phase6/differential-proof-report.md`, `Fixed_plan/phase7/canary-log.md`.

---

## Phase 10 — documentation reconciliation prep

Stale *active* PowerShell instructions, measured today (lines matching
`powershell|pwsh|powershell.exe|.ps1`, case-insensitive):

| File | Lines with PowerShell mentions |
|---|---|
| `README.md` | 26 |
| `TESTING.md` | 52 |
| `CONTRIBUTING.md` | 19 |
| `Makefile` | 24 |
| `scripts/check.sh` | 10 |
| `clean-room/Dockerfile` | 13 |
| `hooks/scope-advisory.sh` | 10 |
| `hooks/hooks.json` | 0 (config only) |
| `action.yml` | 5 |
| `docs/guides/powershell-runtime.md` | 12 |
| **Total** | **~171 lines across 10 files** |

Preserved untouched per CR-021's reviewed allowlist (historical records keep
their PowerShell mentions): `CHANGELOG.md`, release notes,
`docs/architecture/powershell-portability.md`.

---

## Status

- Nothing here is gated work; each item is a survey or a policy finding for
  the Human Owner to act on when the relevant phase's own preconditions are
  met (Phase 8: N + CR-017; Phase 9: Phase 8 live + reviewer decision; Phase
  10: Phase 9 complete).
- Canary surface untouched by this document (`Fixed_plan/**` is not in the
  manifest except `phase0/compatibility-case-manifest.md`).
