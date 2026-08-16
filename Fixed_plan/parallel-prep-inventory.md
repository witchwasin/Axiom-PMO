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

Stale *active* PowerShell instructions. Line-level detail below (superseding the
count-only table this section originally had) so Phase 10, once authorized, is a
line-number-in-hand edit pass, not a fresh search. Re-grep before acting if any time
has passed — this is a snapshot, not a live view. Command used per file:
`grep -inE "powershell|pwsh|powershell\.exe|\.ps1" <file>`.

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
| **Total** | **171 lines across 10 files** |

### README.md (26 lines)

- **L16-17**: version/license header line names "PowerShell reference implementation" —
  rewrite once Node is unconditional.
- **L140, 150, 164**: architecture diagram `[SYS] validate-project.ps1 -Gate ...` labels
  in three gate-flow illustrations — retarget to the Node entrypoint or drop the
  `[SYS]`/script-name framing entirely.
- **L176**: prerequisites line ("Requires PowerShell...") — the CLI won't require it once
  the rollback toggle is gone.
- **L198-204**: an entire "Without Node, the same things through PowerShell" fallback
  code block (4 commands) — this whole block's premise (Node is optional, PowerShell is
  the fallback) inverts at cutover; either delete it or invert it to document
  `AXIOM_ROLLBACK_PWSH` instead.
- **L237-238, 247**: prose describing `cli/` as "convenience wrappers... call the
  PowerShell reference implementation via `pwsh`" and "No local PowerShell install
  required" — both describe pre-cutover behavior specifically.
- **L348**: "deterministic PowerShell validator" in the governance-model prose.
- **L478**: aside about "Markdown or PowerShell stops working" at headcount — check
  whether this line's point still makes sense post-cutover or needs rewording.
- **L502-505**: a `powershell -File ...` code block for doctor/tests/run-all-checks.
- **L516**: CI matrix description naming "Windows PowerShell 5.1" as the min host.
- **L530**: `cli/` tree description, "Thin Node wrapper over the PowerShell scripts."
- **L626, 628**: two guide-index table rows linking `powershell-runtime.md` and
  `powershell-portability.md` — the links themselves stay (CR-021), but check the
  surrounding row label text for present-tense claims that go stale.
- **L748**: changelog-adjacent prose, "no-op on PowerShell 7" — likely historical
  (describes a past fix), check before touching.

### TESTING.md (52 lines)

Almost entirely `powershell -ExecutionPolicy Bypass -File ...` invocation examples and
surrounding prose across every section (doctor, goldens, config-mutation, e2e, CLI
regression): **L7-8, 13-14, 19-20, 25-26, 31-33, 36, 38, 40-41, 44-46, 50, 53, 55, 69,
74-75, 92, 94-95, 98, 104, 107, 110, 114-115, 124-128, 131-132, 135, 143-150, 167-168,
170**. This file's whole shape assumes PowerShell is the thing being invoked directly;
Phase 10 here is less "delete a mention" and more "decide the file's post-cutover
structure" (probably: Node command first, `AXIOM_ROLLBACK_PWSH=1` variant second) —
flag to the Human Owner as a design question, not a mechanical edit, when Phase 10
opens.

### CONTRIBUTING.md (19 lines)

- **L27-33**: an "Environment" prerequisites block explicitly listing PowerShell 7/5.1/
  Linux-macOS-via-pwsh as supported hosts, "no build step and no runtime dependencies
  beyond PowerShell."
- **L38-42**: a `powershell -File ...` quickstart block (4 commands).
- **L49-50, 88, 112, 128, 130, 132, 134, 155**: scattered prose references to specific
  `.ps1` files as where rules/goldens live.

### Makefile (24 lines)

- **L3-9**: header comment block explaining `PWSH`/`make check PWSH=powershell` and the
  CI host matrix.
- **L11-12**: `PWSH ?= pwsh` / `PS := $(PWSH) ...` — the actual dispatch variables every
  target below uses.
- **L35, 38, 41, 44, 47, 50, 53, 56, 59, 62-63, 66-69, 84**: every target body (`demo`,
  `doctor`, `golden`, `capture-golden`, `test`, `config-mutation-test`,
  `diagnostics-contract-test`, `line-ending-test`, `handoff-test`, `e2e-*`, `check`)
  invokes `$(PS) scripts/*.ps1` or `tests/**/*.ps1` directly. This is the file where
  Phase 10 is least "delete text" and most "decide whether targets call `node
  cli/axiom.mjs` instead" — a real design decision, flag it rather than mechanically
  edit.

### scripts/check.sh (10 lines)

Whole-file: it exists specifically to find a PowerShell host and forward to
`run-all-checks.ps1` (**L2, 4-5, 8-14, 21**). Once Node is unconditional this file's
entire reason to exist changes — likely retarget to call `cli/axiom.mjs` directly, or
retire it if the Makefile/CLI already covers its case.

### clean-room/Dockerfile (13 lines)

- **L15, 23, 27**: header comments describing PowerShell 5.1 as "the reference
  platform" and prerequisites.
- **L35, 58-68**: the actual image build — `ARG PWSH_VERSION`, arch detection, and the
  curl/tar install of PowerShell itself. This is the largest actual *behavior* change
  in Phase 10 (not just prose): the clean-room image installing PowerShell at all
  becomes optional once Node is unconditional, though `AXIOM_ROLLBACK_PWSH` staying
  available until Phase 9 argues for keeping it through Phase 8 at least.

### hooks/scope-advisory.sh (10 lines)

**L5, 9, 39-46, 48-49**: resolves a PowerShell host (`AXIOM_PWSH` / `pwsh` / `powershell`
on `PATH`) and shells out to `hook-scope-advisory.ps1`, no-op if none found. Same shape
as `scripts/check.sh` — becomes a design question (call the Node tool directly?) rather
than a text edit.

### action.yml (5 lines)

- **L2**: the Action's own `description:` field names "PowerShell validator" — a
  consumer-facing string, worth getting right rather than just deleting.
- **L54, 84**: exit-code docs referencing "no PowerShell host found" as the 127 case.
- **L109-110**: composite-run comment about runner images already shipping PowerShell.

### docs/guides/powershell-runtime.md (12 lines)

Whole-file, all 12 lines (**L1, 3-4, 10, 17, 23, 28, 32, 35, 40-42**): this file's sole
purpose is explaining PowerShell host setup. Once `AXIOM_ROLLBACK_PWSH` is gone
(post-Phase 9), the file likely retires entirely rather than getting edited line by
line — flag as a whole-file decision, not a line-level one.

### Preserved untouched (CR-021 reviewed allowlist)

Historical records keep their PowerShell mentions as-is: `CHANGELOG.md`, release notes,
`docs/architecture/powershell-portability.md`.

---

## Status

- Nothing here is gated work; each item is a survey or a policy finding for
  the Human Owner to act on when the relevant phase's own preconditions are
  met (Phase 8: N + CR-017; Phase 9: Phase 8 live + reviewer decision; Phase
  10: Phase 9 complete).
- Canary surface untouched by this document (`Fixed_plan/**` is not in the
  manifest except `phase0/compatibility-case-manifest.md`).
