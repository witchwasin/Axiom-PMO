# Axiom-PMO — Interpreter Migration Master Plan (v3)

**Branch:** `feat/migrate-interpreter-to-node-ts`
**Status:** PLANNING — no implementation has started. This document is the executable handoff.
**Supersedes:** `master-plan.md` v2 (commit `5270008`), which closed F1–F10 and CR-001–CR-021
and was adjudicated by Claude Opus 5 in `Fixed_plan/Claude-Review-v2.md`. This v3 closes
G1–G4 plus the two adjudication tightenings from that round. The response log and the three
strategic disagreements are in `Deepseek-Fixed.md`.

---

## 0. Purpose and owner goals

This is a self-contained plan so a fresh AI agent (or human engineer) can execute the
migration without re-deriving the reasoning. It states what is changing, why, what must
not change, how equivalence is proven, in what order, and when it is safe to delete
PowerShell.

The **Human Owner's goals** (stated in this session, and the acceptance criteria for
this work) are:

1. The repository must be genuinely usable, so that an independent AI reviewer gives it
   near-full marks.
2. Two weak points are in scope:
   - **Weak point A — too many documents / too much process.** Answered by the
     Lite/Standard/Strict modes (user picks governance level and required handoff
     artifacts per job). **This is a separate workstream and is NOT part of this plan.**
   - **Weak point B — PowerShell.** The owner's reason: *"most people don't use
     PowerShell; it is the wrong fit for the target ecosystem."* **This migration is the
     answer to weak point B.**
3. The "actual usage / adoption" weakness is **explicitly accepted** by the owner ("no
   one is using this yet"). This lowers compatibility risk but is a belief about a
   public repo; Phase 0 verifies it (see §9 Phase 0, and §11).
4. The decision to migrate has **already been made** by the owner. The `DEC-026` (§12)
   records it; it is not a re-decision.

If anything here conflicts with the repository on disk, the code on disk wins — update
this document to match, do not silently diverge.

---

## 1. Executive summary (corrected)

Axiom-PMO's validation behavior is implemented in **~24,181 lines of PowerShell**
(9,277 in `scripts/lib/`, 5,268 in `scripts/*.ps1`, 9,636 in `tests/*.ps1`). The
`pmo-config/*.json` files hold **rule identity, severity, and remediation text** — but
the **firing conditions** (when a rule triggers, its blocking behavior, mode/gate
branching, reference resolution, filesystem/git semantics) live in that PowerShell.
This is a **behavioral reimplementation**, not a mechanical port of "machinery over a
JSON engine."

The migration reimplements the interpreter in Node.js + TypeScript, proves it
**canonical-form equivalent** to the current PowerShell implementation by
golden-master differential comparison (after raising golden coverage from ~46% to
~100%), then retires PowerShell.

**Net effect:** one runtime (Node) for CLI, validator, and GitHub Action; the
`DOCTOR-010`/`DOCTOR-011` portability defect class disappears; the governance logic
(rule catalog + policy JSON) is preserved byte-for-byte.

**Two deliberate separations, stated up front:**

- **Weak point A (modes) is out of scope.** This plan changes no rule, gate, mode, or
  artifact requirement. The modes redesign is a separate `DEC-###`, separate branch,
  separate plan.
- **Dropping Windows PowerShell 5.1 is a cheap prerequisite step in this plan, not a
  substitute for the migration.** It removes the 5.1/7 portability class early, but it
  does not satisfy the owner's ecosystem-fit goal (PowerShell 7 is still PowerShell).
  See §3.

---

## 2. Problem statement (evidence, corrected)

### 2.1 Ecosystem fit is the primary problem

The target audience — AI-delivery teams on macOS/Linux using Node-first frameworks
(spec-kit, BMAD, OpenSpec, Claude Code) — must install `pwsh` to run the framework. The
CLI (`cli/axiom.mjs`), the GitHub Action runner (`scripts/github-action/*.mjs`), and
the interactive onboarding already require Node. PowerShell is a second runtime the
target ecosystem otherwise does not use.

**Corrected caveat (CR-020):** the README documents a Node-free PowerShell path, so
"every user already has Node" is an assumption, not a fact. Node-only **removes a
supported path**. This is a deliberate breaking-support trade-off, documented in the
`DEC-026`, and costless only because the owner reports zero active users (§0.3).

### 2.2 PowerShell portability is a demonstrated bug source

From `pmo-config/validation-rules.json`:

> `DOCTOR-010`: "Windows PowerShell 5.1 turns any native command's stderr into a
> terminating error under Stop ... This has caused **three separate shipped defects**."

> `DOCTOR-011`: "$IsWindows ... does not exist in Windows PowerShell 5.1 ... It is
> invisible on PowerShell 7, which is where this repository is developed."

**Correction:** this class exists because the code must satisfy PowerShell 5.1 **and**
7 simultaneously. Dropping 5.1 removes it (one CI leg, `pwsh-host.ps1` simplified, two
doctor rules retired). That step is in the plan (§9 Phase 0) and is cheap — but it
fixes the **defect class**, not the **ecosystem-fit** problem, which is the owner's
actual reason for the migration.

### 2.3 "Two implementations would drift" is about a different problem

The `cli/axiom.mjs` header argues against a second *permanent* implementation. This
plan is a **migration**: PowerShell is the compatibility oracle only until the Node
implementation is proven equivalent, then it is deleted. There is exactly one
implementation at the end.

---

## 3. Decision and target state

| Axis | Current | Target |
|---|---|---|
| Validation interpreter | PowerShell (89 `.ps1` files) | TypeScript library under `src/`, compiled to a **committed, dependency-free `dist/` bundle** |
| CLI | `cli/axiom.mjs` spawns `pwsh` | `cli/axiom.mjs` calls the bundled library in-process |
| GitHub Action | Node `.mjs` → Node CLI → `pwsh` | **Action → Node CLI → Node library** (boundary preserved; CR-014) |
| Config / policy | `pmo-config/*.json` | **unchanged bytes** (semantics frozen; runtime-reference edits pre-authorized; CR-013) |
| Governance logic | JSON (catalog) + PowerShell (firing conditions) | same catalog JSON + TypeScript firing conditions, equivalent |
| Runtime requirement | Node **and** pwsh (or pwsh only) | **Node only** |
| Windows PowerShell 5.1 | supported | **dropped early** as a prerequisite (§9 Phase 0) |

**Distribution default (CR-007 / F6):** commit a dependency-free or bundled `dist/`
consumed by both CLI and Action. No `npm install` at runtime; `private: true`; no
publication path. This is decision #1 in §13 and requires the Human decision in the
`DEC-026`.

---

## 4. Why this approach

### 4.1 The port surface is large and behavioral — plan for it honestly

The `pmo-config/*.json` are a **catalog** (severity, description, suggestion), not a
rule engine. Every rule's firing condition is code. The migration therefore ports
**behavior**, not just plumbing. The plan sizes this correctly (24,181 lines) and
uses a strangler pattern so value ships incrementally and a stall at 60% does not leave
a half-ported, untrusted tree (§9).

A **behavior inventory** (produced in Phase 0) classifies every rule/capability as
`config-driven`, `code-driven`, or `hybrid`. Config-mutation tests then prove every
load-bearing policy key still drives the Node implementation (CR-003).

### 4.2 The oracle must be completed before it can be used

Golden masters currently cover **63 of 138 rules (46%)**. Equivalence is only provable
for rules that have a golden. Phase 0 raises coverage to ~100% against the **current**
PowerShell implementation, before any port begins. This is the single highest-value
item in the plan and retains its value even if the migration is cancelled.

### 4.3 Canonical-form equivalence, not byte equivalence

The existing `scripts/lib/golden-normalizer.ps1` deliberately ignores BOM, indentation,
CRLF/LF, `\uXXXX` escaping, and path separators. The correct equivalence claim is
**canonical-form**: ordered result sequence, `rule_id`, `level`, `blocking`, message
text, summary counters, and exit code must match. "Byte-for-byte" is not the contract
and is removed from the plan (F7 / CR-005).

### 4.4 Single runtime removes the defect class and the adoption tax together

Porting removes both §2.1 and §2.2. The dual-runtime state is temporary and bounded.

### 4.5 TypeScript, not JavaScript-only, and not Python

- **TypeScript** because the rule catalog and JSON schemas benefit from explicit types
  and the codebase is ESM-friendly.
- **Node, not Python**, because CLI + Action already require Node — Node makes it a
  single runtime.

---

## 5. Non-goals / out of scope

- **Do not change governance semantics.** No rule, gate, mode, artifact requirement, or
  approval matrix changes. The modes redesign (owner weak point A) is a **separate
  plan**.
- **Do not redesign the policy schema.** `pmo-config/*.json` bytes are frozen except a
  pre-authorized manifest of runtime-reference/version edits (CR-013).
- **Do not add features** (no new rules, gates, modes, dashboards).
- **Do not publish anything** (no npm package, no marketplace publish; `private: true`).
- **Do not change the diagnostics contract** except the schema-mandated fields (see §8.4).

---

## 6. Current architecture (complete inventory)

### 6.1 Components and their PowerShell surface

| Surface | Count | Notes |
|---|---:|---|
| `scripts/lib/*.ps1` | 35 | interpreter modules |
| top-level `scripts/*.ps1` | 25 | orchestrators + tools |
| `tests/*.ps1` | 29 (9,636 lines) | test suite, itself PowerShell |
| total tracked `.ps1` | **89** | the full deletion surface |

The v1 plan covered 35 lib modules + ~12 orchestrators. The complete set is materially
larger; Phase 0 produces the machine-checked disposition for all 89 (CR-002).

### 6.2 The JSON files are a catalog, not a rule engine (corrected)

`validation-rules.json` (138 rules) carries `severity`, `description`, `suggestion`,
and optional `documentation` — **no predicate, threshold, or matcher**. `policy.json`
carries enums, approval roles/checkpoints, table schemas, strict triggers, permissions.
Firing conditions live in PowerShell. Correct statement for the port:

> *Rule identity, severity, and remediation text are data; rule firing conditions are
> code and must be ported line by line.*

15 rule ids are emitted with no catalog entry (`SECRET-*`, `BRANCH-*`, `COMMIT-*`,
`LOCAL-PATH-*`, `OLD-NAME-*`, `OLD-URL-*` — from `check-public-hygiene.ps1`); 3 catalog
rules are never referenced (`DOCTOR-EXAMPLE`, `DOCTOR-HOOK`, `DOCTOR-STRUCT`). Phase 0
reconciles this in the behavior inventory.

### 6.3 Module disposition (complete, to be finalized in Phase 0)

The 89 files each get one disposition: `port | replace | temporary-oracle |
retire-with-evidence`. Every row records: callers, public/maintainer status, outputs,
filesystem/git side effects, replacement path, tests, and retirement criterion.

**Group A — Infrastructure (port mechanically, minus host detection):**

`config-loader`, `markdown-files`, `markdown-table-parser`, `marker-block`,
`ordinal-sort`, `path-containment`, `artifact-hash`, `golden-normalizer`,
`result-writer`, `framework-checkout`. **`pwsh-host.ps1` is retired, not ported** (no
Node equivalent needed).

**Group B — Policy-driven core (port with care):**

`mode-resolver`, `artifact-policy`, `approval-validator`, `reference-resolver`,
`execution-path-validator`.

**Group C — Domain validators (port; read policy + check artifacts):**

`source-validator`, `workitem-validator`, `rtm-validator`, `release-validator`,
`handoff-validator`, `scope-diff-validator`, `scope-diff-matcher`,
`scope-diff-git-adapter`, `execution-contract-schema`, `execution-contract-validator`,
`execution-contract-git`, `execution-contract-evidence`,
`adversarial-review-validator`, `change-control-validator`,
`externalization-validator`, `research-validator`, `design-provider-validator`,
`design-system-validator`, `visual-proof-validator`.

**Orchestrators/tools that v1 omitted (must be dispositioned; F9 / CR-002):**

`aggregate-diagnostics`, `build-plugin-package`, `capture-plugin-load-evidence`,
`check-public-hygiene`, `ci-profile`, `design-provider-digest`, `handoff-digest`,
`hook-scope-advisory`, `measure-context`, `prepare-public-release`, `run-ci-suite`,
`update-source-snapshot`, `visual-proof-digest`.

**Tests (F3):** `tests/*.ps1` (29 files, 9,636 lines) must be ported or re-derived from
goldens. A test suite ported by the same agent that ports the implementation is **not an
independent oracle**; the golden masters are the only independent oracle, which is why
their coverage must reach ~100% (Phase 0).

---

## 7. Target architecture

```
src/                         TypeScript interpreter
  config/                    config loader (BOM/no-BOM tolerant)
  markdown/                  table parser, marker blocks, files
  core/                      mode resolver, artifact policy, reference resolver,
                             ValidationContext (typed, per-run; no module globals)
  rules/                     one module per rule group; typed rule-ID registry
  output/                    result writer (Text/JSON), canonical normalizer
  git/                       scope-diff adapter, execution-contract git
  digest/                    canonical artifact SHA-256 (must match artifact-hash.ps1)
dist/                        committed, dependency-free bundle (CLI + Action consume this)
cli/axiom.mjs                thin dispatch over dist/ (no validation logic in the CLI)
scripts/github-action/*.mjs  unchanged shape; call CLI (Action -> CLI -> library)
pmo-config/*.json            UNCHANGED semantics (see CR-013 for the edit manifest)
tests/                       golden masters (independent oracle) + ported/re-derived tests
```

**Rules carried over from the reviews, now load-bearing:**

1. One permanent implementation at the end; dual-state is bounded.
2. Never edit a golden master to make the port pass.
3. Governance changes are separated from the migration and approved independently.
4. Differential comparison is a hard gate.
5. Human decisions required for toolchain, compatibility, cutover, deletion, release.
6. PowerShell is the **compatibility oracle** (not "correctness oracle") until final proof.

**`ValidationContext` (CR-012):** a typed, per-run object holding configuration, roots,
diagnostic accumulator, filesystem, Git/`gh`, clock, UUID, environment, and process
adapters. Do not port PowerShell `$script:` globals into Node module globals. Add
sequential and concurrent multi-project tests to catch state/cache leakage.

**Rule-ID registry (CR-018):** a typed registry or generated manifest consumed by
validators and `pmo-doctor` (`DOCTOR-007` reconciliation), so deleting PowerShell does
not leave `pmo-doctor` scanning for emitters that no longer exist.

---

## 8. Equivalence proof strategy

### 8.1 Golden master is the compatibility oracle

The current PowerShell implementation is the **compatibility oracle** for this
migration. The Node implementation is correct **iff** it produces the same canonical
output. Golden masters may preserve existing defects; intentional fixes belong in
separate, separately-reviewed changes (CR-005).

### 8.2 Comparator classes (CR-005 / F7)

| Output | Required comparison |
|---|---|
| JSON diagnostics | Strict deep equality of keys, types, `null`/absent, exact strings, ordered arrays, summaries, exit values; normalize only declared host paths |
| Text diagnostics | Canonical comparison via a versioned normalizer **or** raw bytes on one named platform — not both |
| Generated files | Command-specific byte, encoding, newline, digest, permission, overwrite checks |
| stdout/stderr | Captured separately; not merged unless the command contract merges them |
| Intentional changes | Allowed-delta ledger with Human decision reference |

### 8.3 Compatibility-case manifest (CR-006)

Validator behavior is defined by an **invocation tuple**, not a directory:

```text
entrypoint + project + mode + gate + format + FailOnWarning + optional flags
+ cwd + environment + git state + platform
```

Phase 0 extracts a versioned manifest. Every case declares: entrypoint, arguments, cwd,
environment, preconditions, required OS/runtime dimensions, expected exit, comparator
class, expected stdout/stderr, expected filesystem/git changes, allowed nondeterministic
fields, prohibited side effects, and required/skipped status. The full config-mutation
suite is part of the Phase 4 and Phase 6 gates.

### 8.4 Invariants that must be preserved exactly

- **Diagnostic row contract** (from `pmo-config/diagnostics-schema.json`): `schema_version`,
  `level`, `rule_id`, `message`, `blocking`, `artifact`, `item_id`, `field`,
  `suggestion`, `documentation_url`. (v1 incorrectly wrote `severity`/`file`/`line`.)
- **Envelope + summary consistency**, `null` vs absent behavior, optional `scope_diff`,
  privacy constraints (`sensitive_data_policy`), assessment envelope, CLI handoff
  envelope — validated against the schema as a hard, independent gate.
- **Exit codes are per-entrypoint, not one global map** (CR-008):
  - Validator: `0` pass, `1` ≥1 FAIL, `2` blocking WARN under `-FailOnWarning`.
  - CLI usage: `64`. Missing-host `127` (deleted after port).
  - `setup`: `2` for usage/error (not a blocking warning).
  - `axiom run`: propagates arbitrary child exit codes.
  - Reserve a distinct **infrastructure-failure** code (non-0/1/2) and add a top-level
    exception boundary so a Node crash is never misclassified as a governance verdict;
    Action report-only mode must never soften runtime/parsing/config failures.
- **Config reading semantics:** accept BOM and no-BOM; strip exactly one leading U+FEFF
  when present (CR-019 — not all files currently have a BOM).
- **Canonical artifact digest** (F8): text → strict UTF-8 decode, strip one BOM,
  CRLF/CR→LF, re-encode no-BOM, SHA-256; binary → raw bytes; extension allowlist
  `.md .markdown .json .puml .csv .txt .yaml .yml .html .htm`; unknown extension fails
  safe to byte hashing. These digests are **persisted in shipped artifacts**
  (`HANDOFF-REVIEW.json`, `VISUAL-REVIEW.json`, `INPUT-MANIFEST.json`, `REVIEW.json`);
  a divergence makes existing evidence go stale. Dedicated fixture set (LF/CRLF,
  BOM/no-BOM, binary, unknown extension, multi-file combined digest) verified before
  Phase 4.
- **Case and enums:** case-sensitive, from `policy.json`; free text is a failure.
- **Deterministic ordering:** match `ordinal-sort.ps1` semantics; a "helpful" JS sort
  with different collation breaks golden masters silently.
- **Path containment:** FILE: refs escaping the project root are a containment breach
  (`REF-002`); symlink/junction/case behavior covered by the security gate (CR-017).

### 8.5 Final-tree proof (CR-009)

The tree that passes the hard differential gate is not the delivered tree — Phases 8–9
rewire callers and delete PowerShell. Therefore:

- Build the harness skeleton + mutant self-tests in Phase 1, run it after every phase
  group.
- Run **direct reference** and **direct candidate** entrypoints; never let both route
  through one `AXIOM_IMPL` dispatcher.
- Re-run the final differential **after** all cutover rewiring and deletion changes.
- Keep the reference implementation in a detached checkout/worktree at the baseline SHA
  until final proof.
- Retain an implementation-neutral compatibility runner + archived proof report; remove
  only the PowerShell adapter.
- Harness mutants: changed exit, reordered result, missing field, stderr change,
  unexpected file write (each must fail the harness).

### 8.6 Stateful/mutating commands (CR-015)

Golden masters are validator output and cannot prove commands that write files, mint
timestamps/UUIDs, or touch user-owned files (`init`, `setup`, `export`, `run`,
`aggregate-diagnostics`, and the release helpers). Prove each such command by:

- Running reference and candidate in **separate fresh temporary trees**, then diffing the
  full file manifest before/after.
- Injecting or freezing clocks and UUIDs where the command mints them; otherwise use
  structural comparators for declared nondeterministic fields.
- Asserting no unrelated file changes; verifying encoding, BOM, newline, mode/executable
  bits, symlinks, and junction behavior.
- Covering dry-run, uninstall, and partial-failure atomicity for `new-project`,
  `setup-claude-integration`, `export-execution-contract`, `run-execution-command`, and
  `aggregate-diagnostics`.

Phase 5's exit criteria reference this methodology (see §9).

---

## 9. Migration phases (each gated; human-authority compliant)

Do not proceed past a phase until its exit criteria are met. **No autonomous commit.**
Per CR-011 and `AGENTS.md` §8: at the end of each phase, *prepare the scoped diff and
evidence, then stop for Human review and explicit commit authorization.* Push, PR,
merge, cutover, tag, and release each require separate authorization. Commit types
match the actual change (`feat`, `fix`, `test`, `docs`, `chore`).

### Phase -1 — Authorization

Record the `DEC-026` (§12) superseding ROADMAP Milestone 3.5's non-goal by appending the
§12 block to `ROADMAP.md`'s decision history (or `CHANGELOG.md`, per the existing
DEC-016…DEC-025 convention). The owner has already directed the migration; this phase
**records** it. Nothing proceeds past Phase 0 without the recorded DEC.

**Exit:** `DEC-026` present in `ROADMAP.md` (or `CHANGELOG.md`) with the evidence payload
(§12).

### Phase 0 — Complete inventory, immutable baseline, golden-coverage gap

- Generate the machine-checked 89-file `.ps1` disposition matrix (port/replace/
  temporary-oracle/retire-with-evidence), with callers and side effects.
- Derive a function/module-level dependency graph across the 89-file disposition set; use
  it (not the Group A/B/C table) to sequence Phases 2–4 (CR-012 / G2).
- Extract and version the compatibility-case manifest (§8.3).
- **Drop Windows PowerShell 5.1** as a prerequisite: delete the 5.1 CI leg, simplify
  `pwsh-host.ps1`, retire `DOCTOR-010`/`DOCTOR-011` (recorded, not silent).
- Record baseline: Git SHA, golden/comparator hashes, config hashes, commands, OS,
  PowerShell/Node/Git versions, locale, timezone, filesystem behavior, CI run IDs.
- Run and record the full cross-host matrix at the same SHA.
- **Raise golden coverage to ~100%** against the current PowerShell implementation, for
  every rule that currently lacks one (75 rules).
- Keep the reference runnable from an immutable detached checkout/worktree.
- Produce the behavior inventory (§4.1) classifying each rule `config-driven /
  code-driven / hybrid`.

**Exit:** disposition matrix complete; dependency graph derived; goldens ~100%; baseline
fingerprint archived; DEC recorded; 5.1 dropped and doctor green; zero-active-user check
completed and recorded (actual result, not assumed — if any external consumer exists, the
fuller CR-016/CR-020 machinery is restored).

### Phase 1 — Build/distribution contract, harness skeleton, CI routing

- Decide and implement the Node/build/distribution contract (default: committed,
  dependency-free bundled `dist/`; `private: true`; reproducible `npm ci` for dev only).
- Add the differential harness skeleton + mutant self-tests.
- Update the CI risk classifier to treat `src/`, `dist/`, `package*.json`, `tsconfig*`
  as full-matrix changes (CR-010).
- Add candidate-only CI jobs that poison/unset PowerShell access so accidental fallback
  cannot pass.

**Exit:** `tsc` compiles; harness self-tests pass; CI classifier recognizes new paths.

### Phases 2–4 — Strangler port, golden-coverage-anchored (F10 + F2 merged)

Port **one leaf validator group at a time**, in this order of operation per group:

1. Confirm goldens exist for that group (from Phase 0).
2. Port the group to TypeScript against the same `pmo-config/*.json`.
3. Unit + characterization + config-mutation + sequential/concurrent tests.
4. Differential-check just that group (direct reference vs direct candidate).
5. Land green with both implementations live for that group.

Start with `scope-diff-validator` (~5 rules, self-contained, git-backed). If effort
stops after three groups, three validators are in Node, nothing is broken, no revert
needed.

**Exit:** each ported group is golden-covered, unit-tested, mutation-tested, and
differentially green.

### Phase 5 — Complete executable + test surface

Port/replace every public, maintainer, CI, hook, plugin, digest, release, and test
entrypoint in the disposition inventory. Preserve Action → CLI → library as the public
boundary. Port/re-derive `tests/` so `node cli/axiom.mjs check` runs without PowerShell.

**Exit:** the Node path runs the full fixture matrix + config-mutation + end-to-end
without invoking PowerShell; stateful/mutating commands pass the §8.6 fresh-tree
methodology.

### Phase 6 — Final-tree differential gate

Run every compatibility case against direct frozen reference and direct Node candidate
entrypoints. Compare diagnostics, exits, stdout/stderr, generated files, permissions,
hashes, git/filesystem side effects, privacy behavior, CLI, Action, plugin, clean-room
operation.

**Exit:** zero unexplained skips, zero unapproved differences; archived report binding
both SHAs, manifest/comparator hashes, host versions, skips, deltas.

### Phase 7 — Node-default canary + settling window

Make Node default while retaining the chosen rollback mechanism. Run a Human-defined
numeric N across the Node/OS matrix; reset N on any interpreter/harness/comparator/
config/golden/case-manifest change. Exercise real `uses: ./`, plugin install,
read-only/non-checkout execution, Node-only clean rooms.

**Exit:** N clean runs with no drift; N and reset rules recorded.

### Phase 8 — Human-approved cutover (separate decision)

Separate Human authorization after reviewing Phase 6/7 evidence. Update active runtime
surfaces, migration docs, support policy, versioning, consumer contracts.

### Phase 9 — Human-approved PowerShell deletion (separate decision)

Deletion is a separate PR/release decision. Re-run the final-tree proof **after**
deletion changes. Retain the implementation-neutral corpus runner + proof artifacts;
remove only the reference adapter and retired implementation.

### Phase 10 — Documentation reconciliation

Remove stale active PowerShell instructions from README, TESTING, CONTRIBUTING,
`docs/guides/powershell-runtime.md`, `Makefile`, `scripts/check.sh`,
`clean-room/Dockerfile`, `hooks/`, `action.yml`. Preserve historical records (CHANGELOG,
release notes, `powershell-portability.md`) under a reviewed allowlist (CR-021).

**Exit:** no active runtime/CI/skill/hook/template/config/support/install doc invokes
PowerShell; historical records intact.

---

## 10. Definition of Done (Codex's revised list, adopted)

The migration is complete only when all of the following are true:

- [ ] A named Human Owner authorized and recorded migration, compatibility, build,
      support, cutover, and deletion decisions.
- [ ] Every `.ps1` has a reviewed disposition; every live caller has a replacement or
      approved retirement.
- [ ] The Node library uses explicit per-run state and passes sequential/concurrent
      isolation tests.
- [ ] The Node CLI, Action, plugin, hooks, maintainer tools, generator, execution tools,
      release tools, and test runner all work without PowerShell.
- [ ] Candidate-only tests run where PowerShell is unavailable or deliberately poisoned.
- [ ] The full compatibility-case manifest passes with zero unexplained skips and zero
      unapproved differences.
- [ ] JSON output validates against `diagnostics-schema.json` and the assessment schema.
- [ ] Config mutation proves the same policy files remain load-bearing.
- [ ] All intentional deltas are listed with before/after behavior and a `DEC-###`.
- [ ] Runtime/infrastructure failures cannot be softened by Action report-only mode.
- [ ] The supported Node/OS matrix passes on the exact final SHA.
- [ ] Clean-room CLI, `uses: ./`, and read-only/non-checkout plugin tests pass.
- [ ] Rollback to the baseline SHA has been exercised and has a named owner.
- [ ] A named Human security reviewer has signed off on the supply-chain and containment
      surface (CR-017) before Phase 8 cutover.
- [ ] A named Human authorized final deletion; a separate Human reviewed the final diff.
- [ ] No active runtime surface invokes PowerShell; historical records remain intact.

---

## 11. Risks & mitigations (corrected)

| Risk | Impact | Mitigation |
|---|---|---|
| Firing-condition port drifts from PS behavior | High | Golden coverage ~100% (Phase 0) + per-group differential gate (Phases 2–4) |
| Golden comparison normalizes away a real diff | High | Comparator-class table (§8.2); deep-equality for JSON; harness mutants prove the harness fails on real diffs |
| Digest divergence makes shipped evidence go stale (F8) | High | Canonical digest is a named invariant + dedicated fixture set, verified before Phase 4 |
| `tests/` ported by the same agent as impl → not independent | High | Golden masters are the independent oracle; coverage raised first; decide port vs re-derive explicitly |
| 5.1/7 bifurcation bugs (DOCTOR-010/011) | Medium | Dropped in Phase 0 as prerequisite; class eliminated, not ported |
| Supply-chain surface from TS tooling (CR-017) | High | Zero runtime deps, `private: true`, committed lockfile, dependency/license review, lifecycle-script policy, containment tests (symlink/junction/case), named security reviewer |
| Stateful commands (init/setup/export/run) not proven by goldens (CR-015) | High | Fresh-tree before/after comparison; inject/freeze clocks/UUIDs; structural comparators for nondeterministic fields |
| Config bytes reference PowerShell paths (CR-013) | Medium | Freeze semantics; pre-authorized manifest of runtime-reference/version edits; unexpected deltas reported |
| `pmo-doctor` reconciliation breaks after PS deletion (CR-018) | Medium | Typed rule-ID registry/generated manifest; replace `.ps1`-scanning doctor checks |
| CI omits Windows/macOS (CR-010) | High | Update classifier before code lands; candidate jobs on min+current Node × Win/Linux/macOS |
| Node crash misread as governance verdict (CR-008) | High | Distinct infra-failure code + top-level exception boundary; Action never softens infra failures |
| Final delivered tree ≠ proven tree (CR-009) | High | Re-run final differential after cutover + deletion; reference kept in detached worktree |
| Abandonment at 60% | Medium | Strangler by value (Phases 2–4); each group lands green; stop-after-N leaves nothing broken |
| "No users" assumption wrong | Medium | Phase 0 verifies; if consumers exist, restore full CR-016/CR-020 machinery |

---

## 12. Decision record (draft — owner chooses the recording location)

```markdown
### DEC-026 — Supersede Milestone 3.5 non-goal: authorize Node/TypeScript validator

- **Status:** Approved
- **Approved by:** WITCHWASIN K. (Human Owner)
- **Date:** 2026-08-15
- **source_ref:** ROADMAP.md (Milestone 3.5 non-goals); Fixed_plan/master-plan.md v3
- **session_ref:** directed by the Human Owner in the planning conversation of 2026-08-15
  (that conversation is not visible to downstream agents; this pointer is recorded so the
  DEC stands on its own)
- **evidence_status:** supported

**Decision:** The ROADMAP Milestone 3.5 non-goal "Rewriting the validator in TypeScript
or another language" is superseded. A Node.js/TypeScript reimplementation of the
validation interpreter is authorized, proven canonical-form equivalent to the current
PowerShell implementation by golden-master differential comparison, after which
PowerShell is retired. Milestone 3.5's second non-goal "Dropping Windows PowerShell 5.1
before compatibility evidence supports it" is addressed separately: 5.1 is dropped as an
independent prerequisite step (evidence: the recorded 5.1/7 portability defects), not as
part of the TypeScript decision.

**Scope:** interpreter (runtime) migration only. No governance rule, gate, mode, or
artifact requirement changes. The modes redesign is a separate decision.

**Evidence:** port surface 24,181 lines PowerShell (9,277 lib + 5,268 scripts + 9,636
tests); golden coverage 63/138 rules (46%) to be raised to ~100% before port;
distribution target = committed, dependency-free Node bundle.
```

---

## 13. Open decisions requiring the Human Owner

These are decisions the executing agent must **not** make unilaterally; record a
`DEC-###` before the relevant phase.

1. **Distribution/build contract** (Phase 1): committed dependency-free `dist/` bundle
   (recommended default) vs `npm ci && build` vs container. This outranks the toolchain
   question.
2. **TS toolchain**: `tsc` + which test runner (`node:test` vs `vitest`), minimal,
   dependency-light.
3. **Supported Node/OS matrix**: minimum and current Node versions; which OS are
   blocking at the cutover gate (CR-010).
4. **Settling window N** and its reset rules (Phase 7).
5. **`DEC-026` recording location** (Phase -1): append the §12 block to `ROADMAP.md`'s
   decision history or `CHANGELOG.md` (the existing DEC-016…DEC-025 convention) — not a
   separate `decision-log.md`, which exists only per-project.
6. **Zero-active-user assumption** confirmation (Phase 0) — if disproven, restore full
   compatibility machinery.
7. **Branch/PR strategy**: single long-lived branch vs stacked PRs; squash vs merge to
   `main`.

The three **strategic disagreements** for the next review round are recorded in
`Deepseek-Fixed.md` §7: (a) drop-5.1 is a prerequisite not a substitute; (b) the DEC is
a record not a re-decision; (c) "no users" justifies lighter rollback/compat machinery.

---

## 14. Handoff checklist for the executing agent

Before starting:

- [ ] Read `AGENTS.md`, `CLAUDE.md`, `CONTEXT-ROUTER.md`, `TESTING.md`.
- [ ] Confirm `DEC-026` is recorded in `ROADMAP.md`/`CHANGELOG.md` (Phase -1).
- [ ] Run the current suite once to establish green.
- [ ] Confirm the 89-file disposition matrix and behavior inventory are generated.
- [ ] Record the baseline SHA and fingerprints (Phase 0).

While working:

- [ ] Never edit `tests/` golden masters or `pmo-config/*.json` to make the port pass.
- [ ] Never commit autonomously — prepare the diff, stop for Human authorization.
- [ ] Keep the differential harness running after each phase group lands.
- [ ] Keep governance changes (if any) in separate, approved changes — none are in scope.
- [ ] Surface §13 decisions as `DEC-###` records; do not decide them silently.

Definition of done is §10 in full.
