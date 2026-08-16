# Phase 7 — Node-default canary + settling window: execution plan

**Status:** APPROVED FOR EXECUTION. Author: Claude (per explicit human instruction —
FreeBuFF executes this plan, does not design it). Decisions below that master-plan.md
reserves as Human-defined were confirmed with the Human Owner before writing this file,
not assumed.

**Prerequisite:** Phase 6 closed (`0fbc020`), independently verified. See
`Fixed_plan/phase6/differential-proof-report.md`.

---

## 0. Why this plan exists, not just master-plan.md's Phase 7 paragraph

Tracing `cli/axiom.mjs` and `scripts/github-action/run-action.mjs` shows every real
execution path — CLI and GitHub Action both — still spawns `.ps1` via `pwsh` for every
command. The differentially-proven Node/TS implementation (`src/` / `dist/`) is fully
verified equivalent but is not wired into anything a user or CI consumer actually runs.
"Make Node default" is not satisfiable without changing that. This plan is the concrete
answer to how, decided with the Human Owner rather than assumed.

---

## 1. Rollback mechanism

A single environment toggle, `AXIOM_ROLLBACK_PWSH`:

- **Unset (default):** `cli/axiom.mjs` calls the proven TS library in-process. This is
  the canary path Phase 7 measures.
- **Set to `1`:** `cli/axiom.mjs` uses its current, unchanged behavior — spawn `pwsh`
  and run the reference `.ps1`. Instantly reversible: no code revert, no redeploy, one
  environment variable.
- **No automatic silent fallback.** If the in-process TS path throws or crashes, that
  surfaces as a visible infra failure (per master-plan.md's CR-008: "Node crash misread
  as governance verdict... Action never softens infra failures"). It must NOT
  transparently retry via `pwsh` — that would hide exactly the drift this canary exists
  to catch. A human decides whether to set the rollback toggle after seeing a real
  failure, not the code deciding for them.
- `run-action.mjs` inherits this automatically — it only ever spawns `cli/axiom.mjs`.

## 2. CLI rewire — scope of the code change

For each dispatch-table entry in `cli/axiom.mjs` currently shaped
`{ script: "scripts/X.ps1", scriptArgs: [...] }`, add the `AXIOM_ROLLBACK_PWSH` branch
and call the already-proven TS entrypoint on the default path:

| CLI command | Current (`.ps1`) | Default path calls |
|---|---|---|
| `validate` | `scripts/validate-project.ps1` | `runPortedChain` (`src/probe/validate-chain.ts`) |
| `status` | `scripts/pmo-status.ps1` | `src/tools/pmo-status.ts` |
| `doctor` | `scripts/pmo-doctor.ps1` | `runPmoDoctor`/`formatDoctorText` (`src/doctor/pmo-doctor.ts`) |
| `assess-handoff` | `scripts/assess-handoff.ps1` | `src/tools/assess-handoff.ts` |
| `setup claude` | `scripts/setup-claude-integration.ps1` | `setupClaudeIntegration` (`src/tools/setup-claude-integration.ts`) |
| `new-project` / `init` | `scripts/new-project.ps1` | `src/tools/new-project.ts` |
| `export-execution-contract` | `scripts/export-execution-contract.ps1` | `exportExecutionContract` (`src/tools/export-execution-contract.ts`) |
| `run-execution-command` | `scripts/run-execution-command.ps1` | `runExecutionCommand` (`src/tools/run-execution-command.ts`) |
| `verify-execution-result` | `scripts/verify-execution-result.ps1` | `runVerifyExecutionResult` (`src/exec/verify-execution-result.ts`) |
| `demo` | `scripts/demo.ps1` | `src/tools/demo.ts` |
| `run-all-checks` | `scripts/run-all-checks.ps1` | `src/tools/run-all-checks.ts` |
| `doctor` (framework) | `scripts/pmo-doctor.ps1` | (same as `doctor` row) |

Every one of these TS entrypoints is already differential-proven byte-identical to its
`.ps1` reference by `tool-probe.js`, `surface-probe.js`, or `stateful-probe.js` (Phase 6).
This is wiring, not new implementation — **no behavior changes, no "improvements."** The
exact stdout/stderr/exit-code contract `surface-probe.js` already proved must not move.

`AXIOM_PWSH` / host-resolution logic (`HOST_CANDIDATES` etc.) stays in the file
unchanged, and is only reached when `AXIOM_ROLLBACK_PWSH=1`.

## 3. Reset-trigger design

- A committed baseline manifest, `Fixed_plan/phase7/canary-baseline.json`, recording
  SHA-256 of every file matching `src/**/*.ts`, `scripts/**/*.ps1`, `pmo-config/*.json`,
  `Fixed_plan/phase0/compatibility-case-manifest.md`, and the golden fixture directory
  (`tests/golden/**`), plus the git SHA the baseline was captured at. Reuse the exact
  hashing approach already established in `differential-proof-report.md` §2's
  comparator-hash table — same mechanism, continuous use, nothing new to invent.
- A new CI step (in `pmo-checks.yml`'s full-profile path, since that's the only trigger
  that already exercises the whole host matrix) recomputes the same hash set on every
  canary-eligible run and diffs it against the baseline.
- Any difference → the run logs `N RESET: <file/class that changed>` to
  `Fixed_plan/phase7/canary-log.md` and the counter restarts at 0. The baseline manifest
  is then re-captured at the new SHA so the next run has a correct comparison point.
- `canary-log.md` is append-only — every qualifying run (pass or reset) gets a line, so
  the full history stays auditable. No external state store; this is a committed file,
  matching how every other Phase 0–6 artifact in this project has been recorded.

## 4. Canary matrix

- **Node:** two versions — `24.18.0` (pinned in `action.yml` / current CI) and the
  `engines` floor from `package.json` (`>=22.0.0`, so the oldest supported LTS in the
  22.x line).
- **OS:** the same 4-host set `pmo-checks.yml`'s "full" profile already runs —
  `windows-ps51`, `windows-ps7`, `linux`, `macos`. Keep the two Windows-PowerShell
  variants even though Node is now the default: the rollback path must work on both if
  it's ever actually triggered, and this is the only place that gets exercised.
- **Qualifying run:** a push-to-main "full" profile CI run (the only trigger already
  covering the whole host set) with `AXIOM_ROLLBACK_PWSH` unset.

## 5. The four exercise surfaces — what "clean" means for each

1. **Real `uses: ./`** — add a step to `pmo-checks.yml`'s full profile that invokes this
   repo's own `action.yml` against its own example projects (mirrors what
   `surface-probe.js` already does for the Action locally). Clean = the Action's
   embedded JSON output is unchanged in shape and verdict from the Phase 6 baseline.
2. **Plugin install** — reuse `plugin-install-spike.test.ts`'s simulated-install
   fixture, but drive it through the now-rewired real CLI binary (not just the in-process
   library functions the test already calls), so the actual product install path gets
   exercised, not only the library underneath it. Clean = same result as the Phase 6
   differential proof.
3. **Read-only / non-checkout execution** — same simulated install, filesystem made
   read-only, run through the real rewired CLI end to end.
4. **Node-only clean rooms** — extend `clean-room.test.ts`'s scenario with a variant
   where `pwsh`/`AXIOM_PWSH` is provably absent from the environment entirely (not just
   unused), proving the rewired CLI needs zero PowerShell for a normal run — not merely
   that it doesn't call it this time.

## 6. N and exit

- **N = 10** qualifying canary runs (§4) with zero resets (§3) and zero unexplained
  deltas across all four surfaces (§5). Originally 30, reduced to 5 by DEC-028, revised
  to 10 by DEC-029 (`Fixed_plan/decision-log.md`) — read DEC-029 for why 10 specifically,
  not just the number.
- Record every run and every reset, append-only, in `Fixed_plan/phase7/canary-log.md`.
- **A run counts toward N only if the whole qualifying workflow run is green, not
  merely if `canary-baseline.mjs`'s own file-hash check is clean.** `canary-baseline.mjs`
  only diffs the specific manifest paths (§3) — it has no visibility into whether the
  other jobs in the same run (host matrix, hygiene, dogfood, `canary-matrix`) passed. A
  real regression that doesn't happen to touch a manifest path (e.g. a CRLF/LF
  comparison bug in `cli-tests.mjs`, discovered and fixed during the first two real
  canary runs on 2026-08-16) would otherwise bank N on a run that was actually broken.
  Concretely: if `canary-baseline.mjs --record` reports clean but the overall workflow
  run's conclusion is not success, do **not** commit that run's `run clean N=...` line
  from the `phase7-canary` artifact — treat it as superseded, matching the fix commit
  that resolved the failure, and let the next fully-green qualifying run bank the count
  instead. This was applied in practice (commits `b43dc94`, `3b468ba`) before it was
  written here; this paragraph makes it the documented rule rather than tribal
  knowledge.
- **Exit:** 10 consecutive clean qualifying runs. At that point Phase 7 is done and
  archived — this does **not** auto-advance to Phase 8. Cutover is a separate,
  explicit human authorization (§7 of `master-plan.md`), made after reviewing this
  evidence, not triggered by reaching N.

## 7. Gates that remain in force during this work

- `AXIOM_ROLLBACK_PWSH` must land as a real, working, tested toggle — not a stub. Verify
  it by actually setting it and confirming the old `.ps1` path still runs correctly,
  same as before the rewire.
- No removing `scripts/*.ps1` or any reference-side code. The reference stays exactly as
  Phase 6 proved it.
- No touching Phase 8/9 scope (doc updates, versioning, deletion).
- No naming or fabricating a CR-017 reviewer — that gate is separately resolved (the
  Human Owner has named themself; sign-off happens at Phase 8, not now).
- No push to origin.
