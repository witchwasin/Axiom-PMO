# Codex Review — Interpreter Migration Master Plan

**Reviewed artifact:** `Fixed_plan/master-plan.md`  
**Branch:** `feat/migrate-interpreter-to-node-ts`  
**Reviewed commit:** `6432b6d`  
**Review date:** 2026-08-15  
**Reviewer:** Codex  
**Review type:** Static architecture, delivery, equivalence, governance, and rollout review  
**Verdict:** **REQUEST CHANGES — do not start Phase 1 from the current plan**

---

## 1. Executive verdict

The Node.js/TypeScript migration is a plausible direction, but the current document
is not yet a safe executable handoff. It materially understates the amount of
executable governance logic in PowerShell, omits live scripts and PowerShell-based
test infrastructure from the migration scope, defines equivalence inconsistently,
and does not specify a deployable TypeScript distribution model.

If executed as written, the plan could pass its Phase 6 validator comparison and
still break CI, the GitHub Action, Claude plugin workflows, release tooling, hooks,
or the Node-only test path during Phase 8 or Phase 9.

### Scorecard

| Area | Score | Assessment |
|---|---:|---|
| Strategic direction | 7/10 | The single-runtime objective is defensible, subject to Human authorization and an explicit compatibility decision. |
| Scope completeness | 3/10 | The plan covers the 35 library modules but misses many live entrypoints and the PowerShell test estate. |
| Equivalence strategy | 4/10 | The hard-gate idea is correct, but the comparator, corpus, side effects, and final-tree proof are incomplete. |
| Build and distribution readiness | 3/10 | No supported Node range, package/build contract, committed runtime artifact, or plugin/Action distribution decision exists. |
| Governance and rollout | 3/10 | The plan conflicts with earlier Human decisions, assumes commit authority, and lacks a testable canary/deletion gate. |
| **Overall execution readiness** | **4.5/10** | **Not ready to implement.** |

This review is candidate evidence, not an approval. No fresh full validation suite or
cross-host CI run was executed as part of this review; findings are supported by
static repository inspection.

---

## 2. Findings that block implementation (P0)

### CR-001 — The migration has not been authorized as a new framework decision

**Priority:** P0  
**Evidence status:** supported

The plan declares the Node/TS migration as a decided target state, but the accepted
Roadmap explicitly recorded that the earlier runtime-portability milestone would not
rewrite the validator in TypeScript and would retain Windows PowerShell 5.1
compatibility. The Roadmap also states that evaluating a `package.json`/npm manifest
requires a separate Human Owner decision.

This does not make the migration invalid. It means the new decision must explicitly
supersede the old one before implementation starts.

**Required change:** Add a Phase -1 that requires a named Human Owner to decide and
record:

1. authorization to migrate the validator and supporting framework to Node/TS;
2. which earlier decisions/non-goals are superseded;
3. whether Node-only applies to product runtime only or to contributor/test tooling;
4. the supported Node and OS matrix;
5. direct `.ps1` compatibility/deprecation and versioning policy;
6. authorization for a private package manifest and build toolchain;
7. the location and identifier of the framework-level `DEC-###` record.

**Source refs:**

- `Fixed_plan/master-plan.md:44-47`, `95-105`, `532-545`
- `ROADMAP.md:420-433`, `487-490`
- `ROADMAP.md:1591-1608`, `1630-1635`
- `README.md:174-204`

---

### CR-002 — Phase 9 deletes a larger PowerShell surface than the plan replaces

**Priority:** P0  
**Evidence status:** verified by repository inventory

The repository currently contains:

| Surface | Count |
|---|---:|
| `scripts/lib/*.ps1` | 35 |
| top-level `scripts/*.ps1` | 25 |
| PowerShell files under `tests/` | 29 |
| all tracked/worktree `.ps1` files outside `.git` | 89 |

Phase 5 names only about ten orchestrators before Phase 9 removes all PowerShell
under `scripts/`. Omitted live tools include:

- `aggregate-diagnostics.ps1`
- `build-plugin-package.ps1`
- `capture-plugin-load-evidence.ps1`
- `check-public-hygiene.ps1`
- `ci-profile.ps1`
- `design-provider-digest.ps1`
- `handoff-digest.ps1`
- `hook-scope-advisory.ps1`
- `measure-context.ps1`
- `prepare-public-release.ps1`
- `run-ci-suite.ps1`
- `update-source-snapshot.ps1`
- `visual-proof-digest.ps1`

These are not dead files. CI, shipped skills, hooks, release checks, templates, and
diagnostic suggestions still call or name them. Porting only the validator library
and the public CLI verbs would leave the repository unable to run its own release and
governance controls.

**Required change:** Generate a machine-checked inventory of every `.ps1` with one
disposition:

`port | replace | temporary oracle | retire-with-evidence`

Each row must include callers, public/maintainer status, outputs, filesystem/git side
effects, replacement path, tests, and retirement criterion. Phase 9 must fail if any
live caller or active document still references a retired path.

**Source refs:**

- `Fixed_plan/master-plan.md:269-276`, `417-429`, `461-472`
- `scripts/run-all-checks.ps1:61-138`
- `.github/workflows/pmo-checks.yml:62-64`, `129-152`, `180-207`
- `hooks/scope-advisory.sh:39-49`
- `.claude/skills/pmo-design/SKILL.md:62`
- `.claude/skills/pmo-delivery/SKILL.md:44-55`

---

### CR-003 — “The governance logic is already in JSON” is materially inaccurate

**Priority:** P0  
**Evidence status:** supported

The JSON files are important sources of policy and configuration, but
`validation-rules.json` is primarily a rule catalog containing severity metadata,
descriptions, suggestions, and documentation. PowerShell still determines many
conditions, messages, blocking behaviors, evaluation orders, mode/gate branches,
and filesystem/git semantics.

Examples of code-owned behavior include hardcoded mode ranks and gate-dependent
severity, task-source parsing, approval evaluation order, sensitive filename
patterns, Markdown interpretation, reference resolution, and output order.

Describing the port as mostly mechanical makes the delivery estimate and risk model
unreliable. This migration ports executable governance semantics as well as plumbing.

**Required change:** Rewrite sections 1, 3, 4.1, and 6.2 to state that semantics are
split across JSON and code. Add a behavior inventory classifying each rule or
capability as:

- `config-driven`
- `code-driven`
- `hybrid`

Config mutation tests must prove that every load-bearing policy key still drives the
Node implementation.

**Source refs:**

- `Fixed_plan/master-plan.md:27-30`, `99-104`, `117-133`, `197-211`
- `pmo-config/validation-rules.json:1-8`
- `scripts/lib/result-writer.ps1:28-31`, `82-130`
- `scripts/lib/mode-resolver.ps1:38-74`
- `scripts/lib/source-validator.ps1:43-147`, `149-187`
- `CONTRIBUTING.md:47-72`, `145-159`

---

### CR-004 — The diagnostics invariant names the wrong fields

**Priority:** P0  
**Evidence status:** verified

Section 8.4 lists `severity`, `file`, and `line`. Those are not fields in the
diagnostic row contract. The required row is:

```text
schema_version
level
rule_id
message
blocking
artifact
item_id
field
suggestion
documentation_url
```

The envelope, summary consistency, `null` versus absent behavior, optional
`scope_diff`, privacy constraints, readiness-assessment output, and the CLI handoff
envelope are also part of the observable contract.

**Required change:** Replace the shorthand invariant with a per-command contract
matrix sourced from `pmo-config/diagnostics-schema.json`. Schema validation must be a
hard automated gate independent of golden comparison.

**Source refs:**

- `Fixed_plan/master-plan.md:340-358`
- `pmo-config/diagnostics-schema.json:7-32`, `49-190`, `194-246`
- `scripts/lib/result-writer.ps1:113-124`, `140-196`
- `docs/reference/diagnostics-contract.md:103-130`, `158-196`

---

### CR-005 — “Byte-for-byte” conflicts with the existing golden-master contract

**Priority:** P0  
**Evidence status:** verified

The existing golden comparison is deliberately canonical, not raw byte-exact. It
normalizes BOM, CRLF/LF, JSON indentation, numeric Unicode escapes, path separators,
and checkout roots. A Node output cannot be raw-byte-identical to both Windows
PowerShell 5.1 and PowerShell 7 where the reference hosts themselves serialize
differently.

The plan also says JSON will be parsed and compared field-by-field while Text will be
byte-identical. Those are different equivalence models and must not be described by
one blanket invariant.

**Required change:** Define comparator classes explicitly:

| Output | Required comparison |
|---|---|
| JSON diagnostics | Strict deep equality of keys, types, `null`/absent, exact strings, ordered arrays, summaries, and exit values; normalize only declared host paths |
| Text diagnostics | Canonical comparison using a versioned normalizer, or raw bytes on one named platform—not both |
| Generated files | Command-specific byte, encoding, newline, digest, permission, and overwrite checks |
| stdout/stderr | Captured separately; do not merge unless the existing command contract merges them |
| Intentional changes | Allowed-delta ledger with Human decision reference |

The PowerShell implementation should be called the **compatibility oracle**, not the
correctness oracle. Golden masters can preserve existing defects; intentional fixes
belong in separate reviewed changes.

**Source refs:**

- `Fixed_plan/master-plan.md:3-5`, `86-88`, `107-111`, `304-328`
- `scripts/lib/golden-normalizer.ps1:1-23`, `25-84`
- `scripts/run-validation-tests.ps1:279-315`
- `TESTING.md:90-110`
- `CONTRIBUTING.md:123-143`

---

### CR-006 — The differential corpus is incomplete and not invocation-aware

**Priority:** P0  
**Evidence status:** supported

Validator behavior is defined by an invocation tuple, not by a directory alone:

```text
entrypoint + project + mode + gate + format + FailOnWarning + optional flags
+ cwd + environment + git state + platform
```

`run-validation-tests.ps1` invokes some fixture directories more than once with
different modes, gates, expectations, allowed secondary rules, and blocking-warning
settings. “Every fixture plus every example” loses this information.

The proposed Phase 6 also omits many observable behaviors that Phase 5 and Phase 9
change or delete: generator output, setup/uninstall mutation, execution-contract
artifacts, command-run evidence, doctor reconciliation, config mutation, digest
tools, plugin packaging, hooks, Action reports, annotations, summaries, and
filesystem side effects.

**Required change:** Extract a versioned compatibility-case manifest. Every case must
declare:

- implementation entrypoint;
- arguments, cwd, environment, and preconditions;
- required OS/runtime dimensions;
- expected exit and embedded result exit;
- comparator class;
- expected stdout and stderr handling;
- expected filesystem/git changes;
- allowed nondeterministic fields and their consistency rules;
- prohibited side effects;
- whether the case is required or explicitly skipped with a reason.

Make the full config-mutation suite part of the Phase 4 and Phase 6 gates. A manual
spot-check against catalog severities is not an exit criterion.

**Source refs:**

- `Fixed_plan/master-plan.md:317-338`, `409-415`, `431-437`
- `scripts/run-validation-tests.ps1:32-232`, `261-366`
- `scripts/run-all-checks.ps1:61-138`
- `tests/helpers/config-mutation-tests.ps1`
- `TESTING.md:112-170`

---

### CR-007 — The TypeScript runtime/distribution architecture is unresolved

**Priority:** P0  
**Evidence status:** verified

The repository currently has no `package.json` or TypeScript build configuration.
The composite GitHub Action sets up Node and directly runs committed JavaScript; it
does not install packages or compile TypeScript. The CLI and plugin are used directly
from the repository or a plugin cache, including read-only and non-checkout
installations.

Therefore, “`cli/axiom.mjs` calls `src/*.ts` in-process” is not yet a deployable target
architecture.

**Required change:** Before scaffolding, obtain the Human decisions from CR-001 and
define:

1. minimum and tested Node versions;
2. ESM and TypeScript compilation target;
3. committed `dist/` versus committed bundle;
4. whether runtime dependencies must be zero or bundled;
5. private package metadata and lockfile;
6. reproducible clean build and build-output drift check;
7. plugin package inclusion and read-only execution;
8. Action behavior without a runtime network install.

For the current product shape, the lower-risk default is a committed,
dependency-free or bundled `dist/` consumed by both the CLI and Action.

**Source refs:**

- `Fixed_plan/master-plan.md:95-105`, `155-161`, `280-298`, `376-385`
- `action.yml:99-127`
- `scripts/github-action/run-action.mjs:21-29`, `185-228`
- `README.md:174-204`, `650`, `739`
- `ROADMAP.md:1583-1608`, `1630-1635`
- `CONTRIBUTING.md:25-34`

---

### CR-008 — Exit codes are not one global 0/1/2 contract

**Priority:** P0  
**Evidence status:** supported

Codes 0/1/2 describe the project validator. Other entrypoints use additional or
different semantics:

- CLI usage errors use 64;
- the existing missing-host path uses 127;
- setup uses 2 for a usage/error path, not a blocking warning;
- `axiom run` propagates arbitrary child-process exit codes;
- Action parsing, scope-diff infrastructure, and child launch failures have their own
  fail-open/fail-closed requirements.

A new unhandled Node exception normally exits 1. The Action currently treats 1 as a
governance verdict and report-only mode may soften governance codes 0/1/2. Without a
distinct infrastructure-failure contract, a Node crash risks being misclassified as
a non-enforced finding.

**Required change:** Create a per-entrypoint exit-code map. Reserve and document a
non-0/1/2 runtime/infrastructure failure code, add a top-level exception boundary,
and test that report-only mode never softens runtime, parsing, or configuration
failures. Retirement or reinterpretation of 127 is a compatibility change requiring
an allowed delta and Human decision.

**Source refs:**

- `Fixed_plan/master-plan.md:165-176`, `340-347`, `486-500`
- `cli/axiom.mjs:15-29`
- `scripts/lib/result-writer.ps1:140-149`
- `scripts/run-execution-command.ps1:139-145`, `188-201`
- `scripts/github-action/run-action.mjs:30-45`, `225-256`, `324-347`
- `action.yml:82-88`
- `pmo-config/diagnostics-schema.json:28-33`

---

### CR-009 — The final delivered tree is not the tree that passes differential proof

**Priority:** P0  
**Evidence status:** supported

The hard differential gate is Phase 6. Phases 8-10 then rewire callers, remove the
fallback, change configuration and documentation, delete PowerShell, remove doctor
rules, and delete the differential harness. The released tree can therefore differ
substantially from the tree that passed the hard gate.

The checklist also says to run the harness after every phase group, but the plan does
not build it until Phase 6.

**Required change:**

- Build the harness skeleton and harness self-tests in Phase 0/1.
- Run direct reference and direct candidate entrypoints; never let both sides route
  through the same `AXIOM_IMPL` dispatcher.
- Execute the final differential after all cutover rewiring and deletion changes.
- Keep the reference implementation available in a detached checkout/worktree at the
  recorded baseline SHA until final proof is complete.
- Retain an implementation-neutral compatibility runner and archived proof report;
  remove only the temporary PowerShell adapter.
- Add deliberate harness mutants: changed exit, reordered result, missing field,
  stderr change, and unexpected file write.

**Source refs:**

- `Fixed_plan/master-plan.md:362-365`, `431-472`, `488-500`, `559-564`
- `scripts/run-validation-tests.ps1:252-315`
- `docs/architecture/ci-risk-based.md:20-27`, `170-179`

---

### CR-010 — CI does not yet prove the claimed Node/OS support matrix

**Priority:** P0  
**Evidence status:** verified

The risk-based classifier considers the current PowerShell runtime paths high-risk,
but it does not recognize future `src/**`, `dist/**`, `package*.json`, or
`tsconfig*` paths as full-matrix changes. Unknown paths are routed to a targeted Linux
run. A succession of green runs could therefore omit the Windows and macOS behaviors
the migration claims to support.

The settling criterion “N consecutive green CI runs / a few days” is not auditable
until N, the required jobs, reset rules, allowable skips, and platform/runtime matrix
are fixed.

**Required change:** Update and test the CI classifier before interpreter code lands.
During migration, require:

- candidate Node on the minimum supported and current supported Node versions;
- Windows, Linux, and macOS candidate coverage;
- the relevant PS 5.1/PS 7 reference jobs while differential proof is active;
- full-matrix evidence bound to the exact candidate SHA;
- zero unexplained skips;
- a numeric N and reset of N whenever the interpreter, harness, comparator, config,
  golden, or case manifest changes.

If the plan claims macOS support, macOS cannot remain permanently non-blocking at the
cutover gate.

**Source refs:**

- `Fixed_plan/master-plan.md:439-446`, `448-459`
- `scripts/ci-profile.ps1:85-115`, `117-177`
- `.github/workflows/pmo-checks.yml`
- `docs/architecture/ci-risk-based.md:20-27`, `47-63`, `95-131`, `170-179`

---

### CR-011 — The plan grants git authority that repository policy withholds

**Priority:** P0  
**Evidence status:** verified

The plan tells the executing agent to commit at the end of every phase. Repository
policy requires explicit per-action Human confirmation for commit, push, tag, PR,
merge, and release actions. A planning document is not standing authorization for a
future autonomous agent.

**Required change:** Replace “commit per phase” with:

```text
Prepare the scoped diff and evidence for the phase.
Stop for Human review and explicit commit authorization.
Push, PR, merge, cutover, tag, and release each require separate authorization.
```

Commit types should match the actual change (`feat`, `fix`, `test`, `docs`, `chore`)
rather than forcing every phase to use `feat(node-interpreter)`.

**Source refs:**

- `Fixed_plan/master-plan.md:362-365`, `543-545`, `559-564`
- `docs/concepts/human-authority.md:3-18`, `55-64`
- `.claude/skills/pmo-git-safety/SKILL.md:20-40`
- `CONTRIBUTING.md:14-23`, `161-187`

---

## 3. Major corrections required before cutover (P1)

### CR-012 — The A/B/C grouping is not a reliable dependency graph

**Priority:** P1  
**Evidence status:** supported

The proposed order labels several modules as mechanical plumbing even though they
contain governance or security-sensitive behavior. Examples include config-loader
validation, marker-block mutation of user-owned agent files, physical path
containment, and shared script-scope state. Some nominal Group B functions depend on
functions located in Group C modules.

**Required change:** Derive a real function/module dependency graph before Phase 2.
Define a typed, per-run `ValidationContext` containing configuration, roots,
diagnostic accumulator, filesystem, Git/`gh`, clock, UUID, environment, and process
adapters. Do not port PowerShell `$script:` globals into Node module globals. Add
sequential and concurrent multi-project tests to catch state/cache leakage.

**Source refs:**

- `Fixed_plan/master-plan.md:213-267`, `387-415`
- `scripts/validate-project.ps1:63-93`
- `scripts/lib/config-loader.ps1:61-172`
- `scripts/lib/marker-block.ps1`
- `scripts/lib/path-containment.ps1:1-70`
- `scripts/lib/approval-validator.ps1:70-81`

---

### CR-013 — Freezing all `pmo-config/*.json` bytes is impossible

**Priority:** P1  
**Evidence status:** verified

Active configuration contains PowerShell entrypoint descriptions, exit 127, script
paths in suggestions, PowerShell-specific doctor rules, and version fields. Those
references must change if PowerShell is removed.

**Required change:** Freeze governance semantics, not every config byte. Create a
pre-authorized manifest of runtime-reference and version edits. Prohibit behavioral
policy changes outside that manifest and report them as unexpected deltas.

**Source refs:**

- `Fixed_plan/master-plan.md:102-104`, `165-176`, `292-293`, `467-469`, `498-500`
- `pmo-config/diagnostics-schema.json:2-6`, `28-33`
- `pmo-config/validation-rules.json:5-6`, `31`, `406`, `543-553`, `630`, `708`, `718`
- `pmo-config/public-hygiene-allowlist.json`

---

### CR-014 — Preserve Action → CLI → library as one public behavior boundary

**Priority:** P1  
**Evidence status:** supported

The Action currently invokes the Node CLI. It does not call PowerShell directly.
Making the Action import the library separately creates a second argument/default
adapter and increases drift risk, particularly around scope-diff forwarding and
report-only behavior.

**Required change:** Keep:

```text
GitHub Action -> Node CLI -> shared Node library
```

The CLI may call the library in-process. The Action should continue testing the CLI as
the public boundary unless a separate decision and equivalence proof justify changing
that architecture.

**Source refs:**

- `Fixed_plan/master-plan.md:97-105`, `280-298`
- `scripts/github-action/run-action.mjs:21-29`, `185-228`

---

### CR-015 — Stateful and mutating commands need command-specific proof

**Priority:** P1  
**Evidence status:** supported

Commands such as `init`, `setup`, `export`, `run`, aggregation, and release helpers
write files, produce timestamps/UUIDs, preserve or normalize encodings, create hash
sidecars, use temporary files, and may modify user-owned integration files. Validator
goldens cannot prove these behaviors.

**Required change:** Run reference and candidate commands in separate fresh temporary
trees and compare:

- before/after file manifests;
- exact bytes where contractual;
- encoding, BOM, newline, mode/executable bits, symlinks, and junction behavior;
- hashes and self-consistency;
- backup, overwrite, dry-run, uninstall, and partial-failure atomicity;
- absence of unrelated file changes;
- privacy-safe stdout/stderr and report artifacts.

Inject or freeze clocks/UUIDs where possible; otherwise use structural comparators for
declared nondeterministic fields.

**Source refs:**

- `scripts/new-project.ps1`
- `scripts/setup-claude-integration.ps1`
- `scripts/export-execution-contract.ps1`
- `scripts/run-execution-command.ps1:137-201`
- `scripts/aggregate-diagnostics.ps1`
- `tests/helpers/setup-integration-tests.ps1`
- `tests/helpers/execution-contract-tests.ps1`

---

### CR-016 — Rollback and deletion are not operationally consistent

**Priority:** P1  
**Evidence status:** supported

Phase 8 removes the PowerShell fallback, while the rollback plan says it can be
restored after Phase 8. That is a new code change, not an immediate rollback switch.
`git revert` alone also does not address installed plugin caches, Action consumers
pinned to tags/SHAs, version metadata, or the time required to publish a corrected
reference.

**Required change:** Separate Node-default cutover and PowerShell deletion into
different PR/release decisions. Either keep a tested fallback for one defined
post-cutover window, or roll back to an immutable previous tag/ref. Define trigger,
owner, maximum response time, supported previous version, and tested rollback
procedures for CLI, Action, and plugin installations.

PowerShell deletion requires fresh Human authorization after Node-default canary and
clean-room evidence exist.

**Source refs:**

- `Fixed_plan/master-plan.md:448-472`, `518-528`, `532-545`
- `docs/concepts/human-authority.md:6-18`

---

### CR-017 — The migration introduces a new supply-chain and security surface

**Priority:** P1  
**Evidence status:** inferred from proposed toolchain change; requires Human review

The current repository has no npm dependency graph. Adding TypeScript tooling,
package installation, bundling, or test dependencies introduces new package,
lifecycle-script, license, lockfile, and update risks. The port also touches
security-sensitive behavior: physical path containment, symlink/junction handling,
Git arguments, arbitrary command execution, annotation escaping, and secret-safe
failure reporting.

**Required change:** Add a security/supply-chain gate covering:

- zero runtime dependencies by default, or explicit bundled dependencies;
- committed lockfile and reproducible `npm ci` for development/build;
- `private: true` and no publication path;
- dependency/license review and update policy;
- install/lifecycle-script policy;
- containment tests for symlinked directories, broken links, Windows junctions,
  case behavior, and non-existent final paths;
- command/shell equivalence for `axiom run` on Windows and POSIX;
- Action annotation/report privacy and fail-closed infrastructure errors;
- named Human security reviewer before cutover/deletion.

**Source refs:**

- `Fixed_plan/master-plan.md:155-161`, `376-385`, `504-514`, `532-545`
- `scripts/lib/path-containment.ps1:1-70`
- `scripts/run-execution-command.ps1:87-153`
- `scripts/lib/scope-diff-git-adapter.ps1:1-129`
- `scripts/github-action/run-action.mjs:148-183`, `225-307`
- `.github/dependabot.yml`

---

### CR-018 — `pmo-doctor` needs a designed rule-registry replacement

**Priority:** P1  
**Evidence status:** supported

`DOCTOR-007` currently reconciles catalog rule IDs by scanning PowerShell emitters.
Deleting PowerShell requires a reliable replacement. A loose regex over TypeScript
source would be fragile and would not provide the type-level guarantees the migration
claims as a benefit.

**Required change:** Introduce a typed rule-ID registry or generated manifest consumed
by validators and doctor. Add compile-time/catalog reconciliation and mutation tests.
The plan must also replace doctor checks that require specific `.ps1` entrypoints,
permission allowlists, or PowerShell paths; removing only `DOCTOR-010/011` is
insufficient.

**Source refs:**

- `Fixed_plan/master-plan.md:419-421`, `467-469`, `496-500`
- `scripts/pmo-doctor.ps1:207-213`, `331-369`, `414-593`, `638-646`
- `CONTRIBUTING.md:47-64`

---

## 4. Factual corrections (P2)

### CR-019 — Repository counts and BOM statement are stale

**Priority:** P2  
**Evidence status:** verified by static inventory

| Claim in plan | Current repository state |
|---|---|
| `pmo-config/` contains 17 JSON files | 16 JSON files |
| `validation-rules.json` contains approximately 100 rules | 138 catalog entries |
| `examples/` contains 9 worked example directories | 7 direct child project directories |
| `pmo-config/*.json` ship with a UTF-8 BOM | Only `policy.json`, `reference-types.json`, and `skill-manifest.json` currently have a BOM |

The correct loader invariant is: accept BOM and no-BOM; strip exactly one leading
U+FEFF when present. The plan should derive counts automatically from the recorded
baseline SHA rather than hardcode them without a drift check.

**Source refs:**

- `Fixed_plan/master-plan.md:119-128`, `137-144`, `180-195`, `350-352`
- `pmo-config/*.json`
- `examples/`

---

### CR-020 — “Every user already has Node” is a compatibility assumption, not fact

**Priority:** P2  
**Evidence status:** verified

The current README explicitly supports direct PowerShell usage without Node and says
the CLI additionally requires Node. Node-only therefore removes a supported path and
makes Node mandatory for an existing class of user.

**Required change:** Present this as a deliberate breaking-support trade-off requiring
the Human decision in CR-001. Do not use the current optional CLI as proof that every
existing user already has Node.

**Source refs:**

- `Fixed_plan/master-plan.md:57-64`, `149-161`
- `README.md:174-204`
- `CONTRIBUTING.md:25-34`

---

### CR-021 — “No PowerShell mention anywhere” is the wrong cleanup criterion

**Priority:** P2  
**Evidence status:** supported

Historical release notes, incident records, decisions, migration rationale, and
portability lessons should retain accurate PowerShell history. Deleting those
mentions reduces auditability and can erase why the new controls exist.

**Required change:** Define the exit criterion as:

> No active runtime, CI, skill, hook, template, configuration, support, or current
> installation documentation requires or invokes PowerShell. Historical records are
> preserved under a reviewed allowlist.

**Source refs:**

- `Fixed_plan/master-plan.md:474-482`, `486-500`
- `CHANGELOG.md`
- `docs/releases/`
- `docs/architecture/powershell-portability.md`

---

## 5. Principles from the plan that should remain

The following controls are appropriate and should survive the rewrite:

1. The migration must end with one permanent implementation; the dual state is
   temporary and bounded.
2. Golden masters must never be edited merely to make the port pass.
3. Governance improvements and compatibility changes must be separated from the
   interpreter migration and explicitly approved.
4. Differential comparison is a hard gate, not an optional confidence check.
5. Human decisions are required for toolchain, compatibility, cutover, deletion, and
   release.
6. PowerShell remains available as a frozen compatibility oracle until the final
   delivered Node tree is proven.

---

## 6. Recommended phase sequence

### Phase -1 — Authorization and compatibility decisions

Record the Human decision described in CR-001. No implementation begins before this
gate is complete.

### Phase 0 — Complete inventory and immutable baseline

- Generate the 89-file PowerShell disposition inventory.
- Extract/version the compatibility-case manifest.
- Record baseline Git SHA, golden/comparator hashes, config hashes, commands, OS,
  PowerShell, Node, Git, locale, timezone, filesystem behavior, and CI run IDs.
- Run and record the current full cross-host matrix at the same SHA.
- Keep the reference runnable from an immutable detached checkout/worktree.
- Store a manifest of hashes and evidence; do not duplicate goldens as a second
  editable oracle.

### Phase 1 — Build contract, harness, and CI routing

- Decide and implement the Node/build/distribution contract.
- Add the differential harness skeleton and mutant self-tests.
- Update CI classification for all new runtime/build paths.
- Add candidate-only jobs that poison/unset PowerShell access so accidental fallback
  cannot pass.

### Phases 2-4 — Incremental core and validator port

- Derive a real dependency graph.
- Introduce explicit per-run contexts and adapters.
- Port incrementally with unit, characterization, config-mutation, sequential,
  concurrent, and per-group differential tests.
- Do not rely on manual spot checks as exit evidence.

### Phase 5 — Port the complete executable and test surface

- Port/replace every public, maintainer, CI, hook, plugin, digest, release, and test
  entrypoint in the inventory.
- Preserve Action -> CLI -> library as the default public boundary.
- Port all suites necessary for `node cli/axiom.mjs check` to run without PowerShell.

### Phase 6 — Full final-tree equivalence gate

- Run every required compatibility case against direct frozen reference and direct
  Node candidate entrypoints.
- Compare diagnostics, exits, stdout/stderr, generated files, permissions, hashes,
  git/filesystem side effects, privacy behavior, CLI, Action, plugin, and clean-room
  operation.
- Require zero unexplained skips and zero unapproved differences.
- Archive a machine-readable report binding both SHAs, manifest/comparator hashes,
  host versions, skips, and deltas.

### Phase 7 — Node-default canary and settling window

- Make Node default while retaining the explicitly chosen rollback mechanism.
- Run the Human-defined numeric N across the required Node/OS matrix.
- Reset N on any interpreter, harness, comparator, config, golden, or case-manifest
  change.
- Exercise real `uses: ./`, plugin installation, read-only/non-checkout execution, and
  Node-only clean rooms.

### Phase 8 — Human-approved cutover

Require separate Human authorization after reviewing the Phase 6/7 evidence. Update
active runtime surfaces, migration documentation, support policy, versioning, and
consumer contracts.

### Phase 9 — Separate Human-approved PowerShell deletion

Deletion is a separate PR/release decision. Run the final-tree proof again after
deletion changes. Retain the implementation-neutral corpus runner and proof artifacts;
remove only the reference adapter and retired implementation.

### Phase 10 — Historical and current documentation reconciliation

Remove stale active runtime instructions while preserving historical records under an
explicit allowlist.

---

## 7. Revised Definition of Done

The migration is complete only when all of the following are true:

- [ ] A named Human Owner has authorized and recorded the migration, compatibility,
      build, support, cutover, and deletion decisions.
- [ ] Every PowerShell file has a reviewed disposition and every live caller has a
      replacement or approved retirement.
- [ ] The Node library uses explicit per-run state and passes sequential/concurrent
      isolation tests.
- [ ] The Node CLI, Action, plugin, hooks, maintainer tools, generator, execution
      tools, release tools, and test runner all work without PowerShell.
- [ ] Candidate-only tests run in an environment where PowerShell is unavailable or
      deliberately poisoned.
- [ ] The full compatibility-case manifest passes with zero unexplained skips and
      zero unapproved differences.
- [ ] JSON output validates against the exact diagnostics and assessment schemas.
- [ ] Config mutation proves the same policy files remain load-bearing.
- [ ] All intentional deltas are listed with before/after behavior and a Human
      `DEC-###` reference.
- [ ] Runtime/infrastructure failures cannot be softened by Action report-only mode.
- [ ] The supported Node/OS matrix passes on the exact final SHA.
- [ ] Clean-room CLI, `uses: ./`, and read-only/non-checkout plugin tests pass.
- [ ] Rollback to the supported previous version/ref has been exercised and has a
      named owner and response target.
- [ ] A named Human has authorized the final deletion and a separate Human review has
      examined the final diff and evidence.
- [ ] No active runtime surface invokes PowerShell; historical records remain intact.

---

## 8. Repository-state observation

At the beginning of the original review, `Fixed_plan/` was reported by Git as
untracked. During the review, the branch advanced to commit `6432b6d` and the plan
became committed. Codex and its review subagents did not edit, stage, or commit that
change. Verify the provenance and intended authorization of `6432b6d` before using it
as the approved migration baseline.

At the time this review file was created, an unrelated untracked
`Fixed_plan/Claude-Review.md` was present. This review did not modify that file.

---

## 9. Final recommendation

Do not begin the interpreter port from the current phase list. First resolve CR-001
through CR-011 and rewrite the master plan around a complete executable inventory,
deployable Node distribution, invocation-aware contract matrix, immutable reference,
final-tree differential proof, and separate Human-authorized cutover/deletion gates.

Once those P0 findings are closed, the migration can be evaluated as an executable
engineering plan rather than a directionally sound proposal.
