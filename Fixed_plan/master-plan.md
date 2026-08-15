# Axiom-PMO — Interpreter Migration Master Plan

**Branch:** `feat/migrate-interpreter-to-node-ts`
**Scope:** Reimplement the validation interpreter in Node.js + TypeScript, prove byte-for-byte equivalence against the existing PowerShell implementation using the repository's golden-master test fixtures, then retire the PowerShell implementation entirely.
**Status:** PLANNING — no implementation has started. This document is the executable handoff.

---

## 0. Purpose of this document

This is a self-contained plan so that a fresh AI agent (or human engineer) can pick it
up and execute the migration without re-deriving the reasoning. It states:

1. **What** is changing and **why** (the problem, with evidence).
2. **What must not change** (the invariants that define correctness).
3. **How** equivalence will be proven (the golden-master oracle).
4. **In what order** to do the work (phases with entry/exit criteria).
5. **When** it is safe to delete PowerShell.

If anything here conflicts with the current state of the repository on disk, the code
on disk wins — update this document to match, do not silently diverge from it.

---

## 1. Executive summary

Axiom-PMO's real governance logic already lives in **JSON policy files**
(`pmo-config/*.json`). The PowerShell under `scripts/` is an **interpreter** that
reads those JSON files, parses Markdown artifacts, and emits diagnostics. That
interpreter is the single largest source of friction in the product for two reasons:

1. **Adoption friction** — the target audience (AI-delivery teams on macOS/Linux,
   using Node-first frameworks like spec-kit, BMAD, OpenSpec, and Claude Code) must
   install PowerShell (`pwsh`) just to run the framework. The Node CLI (`cli/axiom.mjs`)
   already requires Node, so PowerShell is a *second* runtime nobody in the target
   ecosystem otherwise uses.

2. **It is the root cause of its own defect class** — the framework must run on both
   PowerShell 7 (dev, macOS/Linux) and Windows PowerShell 5.1 (CI/Windows). The
   repository's own rule catalog documents this as having caused **three shipped
   defects** (`DOCTOR-010`), plus a second class of invisible `$IsWindows` bugs
   (`DOCTOR-011`).

**Decision:** port the interpreter to Node.js + TypeScript, driven by the **same**
`pmo-config/*.json` files, and use the existing golden-master fixtures as the
equivalence oracle. Once the Node path is proven identical across the full fixture
matrix and the example projects, delete the PowerShell implementation.

**Net effect:** one runtime (Node) for CLI, validator, and GitHub Action; the entire
`DOCTOR-010`/`DOCTOR-011` portability bug class disappears; and the governance logic
(which lives in JSON) is untouched.

---

## 2. Problem statement (evidence, not opinion)

### 2.1 The target runtime is already Node, so PowerShell is a tax

- `cli/axiom.mjs` is a Node program and already requires Node (it spawns `pwsh`).
- The GitHub Action runner (`scripts/github-action/run-action.mjs`,
  `render-report.mjs`, `emit-annotations.mjs`) is **already Node**.
- The interactive onboarding (`init`) is already Node (`node:readline`).
- Therefore every user already has Node installed. `pwsh` is an *additional*
  requirement on macOS/Linux that serves no purpose except hosting the interpreter.

### 2.2 PowerShell portability is a demonstrated bug source

From `pmo-config/validation-rules.json`:

> `DOCTOR-010`: "Windows PowerShell 5.1 turns any native command's stderr into a
> terminating error under Stop ... This has caused **three separate shipped defects**."

> `DOCTOR-011`: "$IsWindows ... does not exist in Windows PowerShell 5.1 ... It is
> invisible on PowerShell 7, which is where this repository is developed."

These are not hypothetical risks; they are recorded, shipped defect classes caused by
maintaining a 5.1/7-compatible codebase. A single-runtime interpreter eliminates the
class entirely.

### 2.3 The "two implementations would drift" argument is about a different problem

The comment at the top of `cli/axiom.mjs` argues against a *second permanent*
implementation, because it would drift from the PowerShell reference. That concern is
correct for the wrong reason. This plan is not a permanent fork; it is a **migration**:

- The PowerShell implementation remains the oracle **only until** the Node
  implementation is proven byte-identical by the golden master.
- After proof, PowerShell is **deleted**, leaving exactly one implementation.

There is no "two implementations live forever" state; there is a migration with a
temporary oracle and a permanent single implementation.

---

## 3. Decision and target state

| Axis | Current | Target |
|---|---|---|
| Validation interpreter | PowerShell (35 modules under `scripts/lib/`) | TypeScript library under `src/` (or `lib/`) |
| CLI | `cli/axiom.mjs` shells out to `.ps1` | `cli/axiom.mjs` calls the TS library in-process (thin dispatch over `lib/`) |
| GitHub Action | Node `.mjs` shells out to `.ps1` | Node `.mjs` calls the TS library |
| Config / policy source of truth | `pmo-config/*.json` | **unchanged** (same files, same contents) |
| Governance logic | JSON (already) | **unchanged** |
| PowerShell | reference implementation | **deleted** after proof |
| Runtime requirement | Node **and** pwsh | Node only |

**The non-negotiable invariant:** the *semantics* of validation — which artifact
fields are required per mode/gate, which enums are valid, which rule fires with which
severity and exit code — must be **byte-for-byte identical** between the final Node
implementation and the current PowerShell implementation. The proof of this is the
golden-master suite (see §8).

---

## 4. Why this approach (reasoning)

### 4.1 The hard part is already done — the logic is in JSON

The governance content is data, not code. `pmo-config/` contains 17 files, including:

- `policy.json` — enums, approval roles/checkpoints, table schemas, strict triggers,
  permission model.
- `validation-rules.json` — ~100 rules, each with `severity`, `description`,
  `suggestion`, and optional `documentation` path. This is the **rule catalog**; the
  PowerShell "rules" are largely interpreters over these definitions.
- `artifact-policy.json` — the mode×gate artifact matrix.
- `handoff-policy.json`, `scope-diff-policy.json`, `orchestration-policy.json`,
  `adversarial-review-policy.json`, `context-map.json`, and others.

The PowerShell is the *machinery*: Markdown table parsing, config loading, path
containment, reference resolution, result writing. Porting machinery is mechanical;
porting "governance logic" is not required because there is very little governance
logic outside the JSON.

### 4.2 The oracle already exists

The repository already contains the exact tool needed to prove equivalence:

- `tests/` — positive/negative fixture matrix + **golden masters**.
- `scripts/run-validation-tests.ps1` — runs the fixture matrix and diffs against
  golden masters.
- `scripts/run-all-checks.ps1` — goldens + config-mutation + end-to-end + CLI.
- `examples/` — 9 worked example projects (Lite, Standard, Strict, handoff, optional
  tracks, demo).

Golden-master testing is the *only* correct way to prove a rewrite did not change
behavior. It exists; we use it as the gate.

### 4.3 Single runtime removes a whole defect class and the adoption tax at once

Porting removes both problems in §2 with one change. There is no intermediate state
that is worse than today: until cut-over, both implementations run side by side and
must agree.

### 4.4 TypeScript, not JavaScript-only, and not Python

- **TypeScript** because the rule catalog and JSON schemas benefit from explicit
  types (rule ids, severities, table schemas) and the codebase is already
  Node/ESM-friendly (`cli/axiom.mjs` is ESM).
- **Node, not Python**, because the CLI and Action already require Node — porting to
  Python would still leave a second runtime. Node makes it a single runtime.

---

## 5. Non-goals / out of scope

- **Do not change governance semantics.** Do not add, remove, or weaken rules. If the
  golden master disagrees, the Node code is wrong (or, in a deliberate, separately
  reviewed change, the golden master itself is updated — but that is out of scope here
  and must be a separate, human-approved decision).
- **Do not redesign the policy schema.** `pmo-config/*.json` stays byte-identical
  unless a doctor check demands otherwise.
- **Do not add features** (new rules, new gates, new modes, dashboards).
- **Do not publish anything** (no npm package, no marketplace publish).
- **Do not change the diagnostics contract** (`schema_version`, field names, exit
  codes). Consumers depend on it. See §8.4 for the exact contract.

---

## 6. Current architecture (as of branch point)

### 6.1 Components

```
cli/axiom.mjs                     Thin Node wrapper: finds pwsh, maps verb → script, forwards args, preserves exit code.
scripts/*.ps1                     Orchestrators (validate-project, new-project, pmo-doctor, assess-handoff,
                                  run-validation-tests, run-all-checks, demo, export-execution-contract,
                                  verify-execution-result, run-execution-command, pmo-status, setup-claude-integration, …).
scripts/lib/*.ps1                 35 interpreter modules (see §6.3).
scripts/github-action/*.mjs       Node action runner (already Node).
pmo-config/*.json                 Source-of-truth policy (17 files).
templates/                        Blank artifacts.
examples/                         Worked example projects (the differential-test corpus).
tests/                            Fixture matrix + golden masters.
```

### 6.2 The JSON-first insight (read this before porting anything)

The validator's behavior is driven by JSON in `pmo-config/`, not by hardcoded logic:

- Rule ids, severities, descriptions, suggestions → `validation-rules.json`.
- Valid enums (modes, gates, statuses, evidence statuses, roles, strict triggers) →
  `policy.json`.
- Required artifacts per mode/gate → `artifact-policy.json`.
- Approval role matrix → `policy.json` `approval_roles`.
- Table column schemas → `policy.json` `table_schemas`.

**Implication for the port:** the TypeScript modules should read these same JSON files.
Do not transcribe enum values or rule text into TypeScript source; load them from
`pmo-config/` at runtime exactly as the PowerShell does. This is what makes
"byte-identical" achievable and keeps future rule edits in one place.

### 6.3 Classification of the 35 `scripts/lib/*.ps1` modules

Port these in dependency order. Group A first (pure plumbing), then B (policy-driven
core), then C (domain validators).

**Group A — Infrastructure / plumbing (port mechanically):**

| Module | Responsibility |
|---|---|
| `pwsh-host.ps1` | Host detection (`$IsWindows` workaround, `Test-WindowsHost`). **Obsolete after port — delete, not port.** |
| `config-loader.ps1` | Load `pmo-config/*.json` (handles UTF-8 BOM). |
| `markdown-files.ps1` | Discover/read Markdown artifacts. |
| `markdown-table-parser.ps1` | Parse Markdown tables → rows/columns. |
| `markdown-table-parser` deps | (see `ordinal-sort`, `marker-block`) |
| `ordinal-sort.ps1` | Deterministic ordering (guarantees stable output). |
| `marker-block.ps1` | Parse marker-delimited blocks in Markdown. |
| `path-containment.ps1` | Ensure FILE: refs stay inside project root. |
| `artifact-hash.ps1` | SHA-256 digesting. |
| `golden-normalizer.ps1` | Normalize output before golden-master diff. |
| `result-writer.ps1` | Emit diagnostics (Text / JSON), attach suggestions. |
| `framework-checkout.ps1` | Locate framework root vs project root. |

**Group B — Policy-driven core (port with care; logic must mirror JSON):**

| Module | Responsibility |
|---|---|
| `mode-resolver.ps1` | Resolve effective mode (Lite/Standard/Strict), non-downgrade. |
| `artifact-policy.ps1` | Required-artifact lookup per mode/gate. |
| `approval-validator.ps1` | Approval table checks, role matrix, named-person rules. |
| `reference-resolver.ps1` | Resolve source/design/decision/release refs. |
| `execution-path-validator.ps1` | Validate `execution_path` declaration. |

**Group C — Domain validators (port; mostly read policy + check artifacts):**

| Module | Responsibility |
|---|---|
| `source-validator.ps1` | Source-of-truth checks, source_ref, placeholders. |
| `workitem-validator.ps1` | Work-items table checks. |
| `rtm-validator.ps1` | RTM.json traceability (Strict). |
| `release-validator.ps1` | Release gate (rollback, test summary, QA/security review). |
| `handoff-validator.ps1` | Handoff gate (build order, owners, acceptance cases). |
| `scope-diff-validator.ps1` | SCOPE-DIFF orchestration. |
| `scope-diff-matcher.ps1` | Path-pattern matching against SCOPE.json. |
| `scope-diff-git-adapter.ps1` | Git diff (base..head) invocation. |
| `execution-contract-schema.ps1` | EXECUTION-CONTRACT schema. |
| `execution-contract-validator.ps1` | Contract validation. |
| `execution-contract-git.ps1` | Git ground-truth reconciliation. |
| `execution-contract-evidence.ps1` | Evidence checks (ci-check, run records). |
| `adversarial-review-validator.ps1` | AREV (EXECUTION-REVIEW) checks. |
| `change-control-validator.ps1` | CHANGE-REQUESTS checks. |
| `externalization-validator.ps1` | EXTERNALIZATION checks. |
| `research-validator.ps1` | RESEARCH + PROVENANCE checks. |
| `design-provider-validator.ps1` | Claude Design manifest/review checks. |
| `design-system-validator.ps1` | Design-system token contract checks. |
| `visual-proof-validator.ps1` | Visual Proof (VISUAL-REVIEW) checks. |

### 6.4 Orchestrators that must also be ported or replaced

`validate-project.ps1` (219 lines) is the main entrypoint and must become the Node
entrypoint. Others: `new-project.ps1` (generator), `pmo-doctor.ps1` (framework
self-check), `assess-handoff.ps1` (readiness assessment), `demo.ps1`,
`run-validation-tests.ps1`, `run-all-checks.ps1`, `export-execution-contract.ps1`,
`verify-execution-result.ps1`, `run-execution-command.ps1`, `pmo-status.ps1`,
`setup-claude-integration.ps1`. Each maps to an existing CLI verb in `cli/axiom.mjs`.

---

## 7. Target architecture

```
src/                         TypeScript interpreter library
  config/                    config loader (pmo-config/*.json)
  markdown/                  table parser, marker blocks, files
  core/                      mode resolver, artifact policy, reference resolver
  rules/                     one module per rule group (mirrors §6.3 groups B & C)
  output/                    result writer (Text/JSON), golden normalizer
  git/                       scope-diff adapter, execution-contract git
cli/axiom.mjs                thin dispatch over src/ (no validation logic remains here)
scripts/github-action/*.mjs  unchanged shape, now call src/ instead of spawning .ps1
pmo-config/*.json            UNCHANGED
tests/                       UNCHANGED fixtures + golden masters (the oracle)
```

**Principle carried over from the old CLI comment, inverted:** the "zero validation
logic in the CLI" rule becomes "validation logic lives only in `src/`; the CLI is a
thin dispatcher over `src/`." There is still exactly one implementation of the logic.

---

## 8. Equivalence proof strategy (the core of this migration)

### 8.1 Golden master as oracle

The PowerShell implementation is correct **by definition** for this migration. The
Node implementation is correct **iff** it produces the same output.

The existing golden masters in `tests/` are the frozen expected outputs. Strategy:

1. Before touching anything, **freeze a baseline**: run `run-validation-tests.ps1`
   and `run-all-checks.ps1`, confirm green, and record the golden-master files and
   exit codes as the frozen baseline (copy them to a `Fixed_plan/baseline/` snapshot
   for reference — read-only, never edited).
2. The Node implementation must reproduce those outputs **exactly**.

### 8.2 Differential harness

Build a harness that runs **both** implementations over the same corpus and diffs:

- **Corpus:** every fixture in `tests/` **plus** every project in `examples/`.
- **Comparison points (must all match):**
  1. Exit code (0 pass / 1 fail / 2 blocking-warning).
  2. JSON diagnostics — parsed and compared field-by-field (not string diff, to
     tolerate key ordering, **but** aim for byte-identical where the contract
     allows).
  3. Text diagnostics for `-Format Text` — byte-identical (this is where ordering and
     wording bugs hide).
- **Determinism check:** run the Node implementation N times over the same input and
  assert identical output (guards against non-deterministic ordering; the existing
  `ordinal-sort.ps1` exists precisely to make output deterministic).

### 8.3 The differential harness must itself be runtime-agnostic

The harness can be Node (run `.ps1` via a `pwsh` child for the reference side, and
the TS library in-process for the candidate side). The reference side may use `pwsh`
only until the migration completes; the harness is a migration tool and is deleted
with PowerShell.

### 8.4 Invariants that must be preserved exactly

These are non-negotiable; the golden master and the diagnostics contract encode them.

- **Exit codes:** `0` pass, `1` ≥1 FAIL, `2` `-FailOnWarning` with blocking WARN,
  `64` CLI usage error, `127` no PowerShell host (the `127` case is **deleted** after
  the port — Node no longer needs a host; the CLI must never emit 127 again, and
  consumers/tests that assert 127 must be updated in the cut-over phase).
- **Diagnostics contract:** JSON `schema_version`, per-result fields (`rule_id`,
  `severity`, `message`, `suggestion`, `documentation_url`, `file`, `line`).
- **Config reading semantics:** `pmo-config/*.json` ship with a UTF-8 BOM;
  `JSON.parse` rejects it, so the loader must strip it (`﻿`) exactly as
  `cli/axiom.mjs` already does and as `ConvertFrom-Json` tolerated it.
- **Case and enums:** enum values are case-sensitive and come from `policy.json`;
  free text in an enum column is a failure (`ENUM-001`).
- **Deterministic ordering:** output ordering must match `ordinal-sort.ps1`; a
  "helpful" JS sort with different collation will break golden masters silently.
- **Path containment:** FILE: refs escaping the project root are a containment
  breach (`REF-002`); path resolution must use the same containment rules.

---

## 9. Migration phases (ordered, each gated)

Do **not** proceed past a phase until its exit criteria are met. Commit at the end of
each phase with a message prefix `feat(node-interpreter): …`.

### Phase 0 — Freeze baseline

- Record HEAD SHA as the branch point.
- Run the full suite (PowerShell) once; confirm green.
- Snapshot golden masters + exit codes into `Fixed_plan/baseline/` (read-only).

**Exit:** baseline is green and snapshotted; `Fixed_plan/baseline/README.md` lists the
commands run and the SHA they were run at.

### Phase 1 — Scaffold the Node/TS interpreter

- Choose and wire a TS build/test setup (e.g. `tsc` + a minimal test runner, or
  `vitest`/`node:test` — match whatever keeps the repo dependency-light; no runtime
  framework that forces a config the repo doesn't want).
- Set up `src/` with the directory layout in §7.
- Add a CI-visible `npm run build` / `npm test` that is currently empty/skipped.

**Exit:** `tsc` compiles; a trivial unit test passes; CI still green (nothing depends
on the new code yet).

### Phase 2 — Port infrastructure (Group A)

Port: `config-loader`, `markdown-files`, `markdown-table-parser`, `marker-block`,
`ordinal-sort`, `path-containment`, `artifact-hash`, `golden-normalizer`,
`result-writer`, `framework-checkout`.

- Unit-test each against the same inputs the PowerShell version consumes.
- **Delete `pwsh-host.ps1` from the port scope** — host detection has no Node
  equivalent and is not needed.

**Exit:** each module has unit tests; a small end-to-end smoke (load a config, parse a
table, emit a JSON result) matches the PowerShell output for a hand-written fixture.

### Phase 3 — Port policy-driven core (Group B)

Port: `mode-resolver`, `artifact-policy`, `approval-validator`, `reference-resolver`,
`execution-path-validator`.

**Exit:** effective-mode resolution matches `mode-resolver.ps1` for a matrix of
{requested mode} × {PROJECT.md default} × {work-item mode/trigger} cases, including
the non-downgrade FAIL/WARN behavior (`MODE-001`).

### Phase 4 — Port domain validators (Group C)

Port all Group C modules, driven by `validation-rules.json` and `artifact-policy.json`.

**Exit:** the Node library can run a full `validate-project` equivalent on
`examples/` and produce structured diagnostics; manually spot-check a few examples
against `pmo-config/validation-rules.json` severities.

### Phase 5 — Port orchestrators & wire the CLI

Port `validate-project` (the entrypoint), `new-project`, `assess-handoff`,
`pmo-doctor`, `demo`, `export-execution-contract`, `verify-execution-result`,
`run-execution-command`, `pmo-status`, `setup-claude-integration`.

- Rewire `cli/axiom.mjs` to call `src/` in-process for these verbs (remove the
  `pwsh` spawn). Keep the verb surface identical.
- Keep `pwsh` fallback **temporarily** via an env flag (e.g. `AXIOM_IMPL=pwsh`) so
  the differential harness can still run the reference side.

**Exit:** `node cli/axiom.mjs validate --project examples/STANDARD-FEATURE --gate Release`
runs entirely in Node and prints a result.

### Phase 6 — Differential harness (the gate)

Build the harness (§8.2) and run it over `tests/` + `examples/` with both
implementations.

**Exit:** **zero** differences across the full corpus — exit codes, JSON diagnostics,
and Text output all match. This is the hard gate; no phase 7 until it is green.

### Phase 7 — Dual-run in CI

- Add a CI job that runs the differential harness on every push.
- Run both the PowerShell suite and the Node suite for a settling period (this is the
  "migration with temporary oracle" window).

**Exit:** N consecutive green CI runs (pick N = a few days of commits, or as the team
decides) with no drift.

### Phase 8 — Cut over

- Make Node the default and only path for the CLI and the GitHub Action.
- Remove the `AXIOM_IMPL=pwsh` fallback from the CLI.
- Update `action.yml`, `Makefile`, `scripts/check.sh`, `clean-room/Dockerfile`, and
  `hooks/` to drop the `pwsh` dependency.
- Update docs (`README.md`, `TESTING.md`, `CONTRIBUTING.md`, `docs/guides/powershell-runtime.md`,
  the "Requires PowerShell" text, install instructions) to say "Node only".
- Update any test/consumer that asserted exit code `127` (no PowerShell host).

**Exit:** the framework runs with Node as the only runtime; the `pwsh` requirement is
gone from every entrypoint and doc.

### Phase 9 — Delete PowerShell

- Remove `scripts/*.ps1` and `scripts/lib/*.ps1`.
- Remove the differential harness (its job is done; the golden-master suite remains,
  now run by Node).
- Delete `docs/guides/powershell-runtime.md` (or repurpose to a "runtime: Node" note).
- Remove the now-obsolete doctor rules that checked PowerShell portability
  (`DOCTOR-010`, `DOCTOR-011`) and their doc pages — they no longer describe any code.
  **This is a deliberate rule-catalog edit and must be recorded as such** (see §11).

**Exit:** no `.ps1` remains under `scripts/`; the full golden-master suite passes on
Node alone; `pmo-doctor` is green.

### Phase 10 — Cleanup & documentation

- Update `AGENTS.md`/`CLAUDE.md`/`CONTEXT-ROUTER.md` if they reference PowerShell.
- Update `CHANGELOG.md` and `VERSION` per the release process.
- Record the migration in `decision-log`/`DEC-###` style per repo convention, and add
  a ROADMAP note.

**Exit:** the repo no longer mentions PowerShell as a runtime anywhere, and the
change is documented for the next reader.

---

## 10. Success criteria / Definition of Done

1. `node cli/axiom.mjs check` (or its Node equivalent) passes the full fixture matrix
   + golden masters, with **zero** PowerShell involved.
2. The differential harness reported **zero** differences for the full corpus before
   PowerShell was removed.
3. No `.ps1` file remains under `scripts/`.
4. The GitHub Action runs on Node alone and still emits the same report contract.
5. All docs and entrypoints describe a **Node-only** runtime; exit code `127` is
   retired.
6. `pmo-doctor` is green against the new Node implementation and no longer contains
   the PowerShell-portability rules (`DOCTOR-010`/`DOCTOR-011`).
7. Governance semantics are unchanged: no rule was added, removed, or weakened other
   than the two obsolete doctor rules removed in Phase 9 (which is a *cleanup*, not a
   governance change).

---

## 11. Risks & mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Subtle output differences (ordering, BOM, case, collation) break golden masters silently | High — wrong merge | Differential harness over full corpus + determinism check (§8.2–8.3); preserve `ordinal-sort` semantics exactly |
| Someone "improves" behavior while porting | Silent governance change | Golden master is authoritative; any diff is a bug unless it's a separate human-approved decision; **never edit a golden master to make a port pass** |
| Port stalls halfway → two implementations drift | Medium | Phases are gated; PowerShell stays the oracle until Phase 8; no partial cut-over |
| `DOCTOR-010`/`DOCTOR-011` removal touches the rule catalog | Low | Record as a deliberate cleanup decision; these rules describe deleted code |
| TS build config over-engineering | Low | Keep it minimal (tsc + node:test/vitest); no framework that fights the repo |
| Losing the `127` "no pwsh" semantics confuses a consumer | Low | No consumer should rely on 127 after Node-only; update tests/docs in Phase 8 |
| Markdown table parser edge cases differ | High | Port the parser to match `markdown-table-parser.ps1` exactly; add fixture cases for empty cells, pipes-in-cells, marker blocks, multi-line cells |

---

## 12. Rollback plan

- **Before Phase 8 (cut-over):** the change is additive and the PowerShell path
  remains default, so rollback is trivial — revert the branch commits. Nothing ships.
- **After Phase 8 but before Phase 9:** PowerShell files still exist; the
  `AXIOM_IMPL=pwsh` fallback can be restored (keep the code in the CLI until Phase 9)
  and the default flipped back.
- **After Phase 9 (PowerShell deleted):** rollback means reverting to the pre-migration
  SHA — which is why Phase 0 snapshots the baseline SHA and golden masters. Reverting
  is a `git revert` of the migration commits; the golden masters and fixtures were
  never changed, so the reverted PowerShell suite still passes.

---

## 13. Open decisions for the Human Owner

These are decisions the executing agent should **not** make unilaterally; surface them
and record a `DEC-###` before proceeding past the relevant phase.

1. **TS toolchain choice** (Phase 1): `tsc` + which test runner (`node:test` vs
   `vitest` vs other). Recommend the minimal one consistent with the repo's
   dependency-light posture.
2. **Settling window length N** (Phase 7): how many green CI runs before cut-over.
3. **`DOCTOR-010`/`DOCTOR-011` removal** (Phase 9): confirm these two rule entries and
   their doc pages are authorized to be deleted as obsolete.
4. **Branch/PR strategy**: single long-lived branch vs stacked PRs per phase. This
   plan assumes commits land on `feat/migrate-interpreter-to-node-ts`; a merge strategy
   to `main` (squash vs merge) is a separate decision.

---

## 14. Handoff checklist for the executing agent

Before starting, confirm:

- [ ] Read `AGENTS.md`, `CLAUDE.md`, `CONTEXT-ROUTER.md` (repo rules).
- [ ] Read `TESTING.md` and run the current suite once to establish green.
- [ ] Confirm `pmo-config/*.json` contents match the assumptions in §6.2.
- [ ] Confirm the 35-module list in §6.3 matches `ls scripts/lib/`.
- [ ] Record the baseline SHA and golden-master snapshot (Phase 0).

While working:

- [ ] Never edit `tests/` golden masters or `pmo-config/*.json` to make the port pass.
- [ ] Commit per phase with the `feat(node-interpreter):` prefix.
- [ ] Keep the differential harness running after each phase group lands.
- [ ] Surface §13 decisions as `DEC-###` records, do not decide them silently.

Definition of done is §10 in full.
