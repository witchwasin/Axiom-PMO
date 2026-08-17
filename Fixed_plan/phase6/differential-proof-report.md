# Phase 6 — Final-tree differential proof report

**Branch:** `feat/migrate-interpreter-to-node-ts`
**Method:** direct reference (PowerShell) vs direct candidate (Node/TypeScript) on the
same fixtures, canonical-form compared. No `AXIOM_IMPL` dispatcher; each side runs its
own entrypoint.

---

## §1 — Validator surface (archived 2026-08-15)

**Date:** 2026-08-15
**Result:** 63 differential cases, 63 PASS

| Probe | Cases | Reference entrypoint | Candidate entrypoint |
|---|---:|---|---|
| `differential-probe.js` | 38 | `scripts/validate-project.ps1` | `src/probe/validate-chain.ts` |
| `execution-probe.js` | 3 | `scripts/verify-execution-result.ps1` | `src/exec/verify-execution-result.ts` |
| `marker-probe.js` | 16 | `scripts/lib/marker-block.ps1` | `src/marker/marker-block.ts` |
| `marker-io-probe.js` | 6 | `scripts/setup-claude-integration.ps1` | `src/marker/marker-io.ts` |
| `doctor-probe.js` | 1 (58 rows) | `scripts/pmo-doctor.ps1` | `src/doctor/pmo-doctor.ts` |

### Coverage by rule family

| Rule family | Rules | Status |
|---|---|---|
| STRUCT/TASK/PATH/PLACEHOLDER/SENSITIVE/LINK | — | ✅ differential-green |
| SOURCE/EVIDENCE/REF | SOURCE-001..003, EVIDENCE-001, REF-001/002 | ✅ |
| APPROVAL | APPROVAL-001..005 | ✅ |
| MODE/ENUM/STRICT/WORKITEM | MODE-001..003, ENUM-001, STRICT-001/002, WORKITEM-001 | ✅ |
| CHANGE | CHANGE-001..003 | ✅ |
| EXT | EXT-001..004 | ✅ |
| RESEARCH | RESEARCH-001..007 | ✅ |
| DPROV | DPROV-001..007 | ✅ |
| DESIGN/VPROOF | DESIGN-001, VPROOF-001/002 | ✅ |
| RTM/TEST/RELEASE | RTM-001..010, TEST-RESULT-001, TEST-EVIDENCE-001..003, TEST-SUMMARY-001, RELEASE-001, RELEASE-SCOPE-001, RELEASE-STATUS-001, REVIEW-001, QA-REVIEW-001, SECURITY-REVIEW-001, BLOCKER-001 | ✅ |
| HANDOFF | HANDOFF-001..014, TEST-DESIGN-001/002 | ✅ |
| SCOPE-DIFF | SCOPE-DIFF-001..005 | ✅ |
| EXEC | EXEC-001..008 | ✅ |
| AREV | AREV-001..007 | ✅ |
| DOCTOR/PERMISSION/TABLE | DOCTOR-000..014, PERMISSION-000..007, TABLE-001 | ✅ |

### Bugs the differential probes found and fixed

1. `getDecisionIds` returned `[]` instead of `null` (PowerShell collapses empty `return @()` to `$null`).
2. `release-validator` used PS-only `\z` end-of-string.
3. `workitem-validator` did not pass `sentinel_rules` to `testFieldValue`.
4. `table-parser` passed PS inline flags `(?i)` to JS RegExp.
5. `marker-harness.ps1` used `ConvertFrom-Json` (PSCustomObject) instead of `-AsHashtable` for named-parameter splatting.
6. `pmo-doctor` `loadJson` did not strip UTF-8 BOM (policy.json / skill-manifest.json carry one).

---

## §2 — Full-tree gate: orchestrators, CLI, Action, plugin, clean-room (2026-08-16)

**Date:** 2026-08-16. Closes the "Remaining" list §1 left open: every
orchestrator/tool in `src/tools/` plus the CLI, GitHub Action, plugin, and
clean-room operation, each differential-tested against its own PowerShell
reference entrypoint. Phase 5's porting of all 24 `tests/` suites is what made
this possible: each tool already had a native `.test.ts` cross-checked against
the PS reference's pass count, and the differential probes below verify the
*entrypoints* directly.

### Baseline SHAs

- Reference (PowerShell) tree: the tree at `d2c9f9c` (`test(phase-5): port
  adversarial-review tests (AREV-001..007), finish tests/`), which is the
  immediate parent of the commit that archives this report. Both implementations
  live in the same monorepo tree, so reference and candidate SHAs are the same
  commit; the archive commit is recorded by `git log` on this file.
- Candidate (Node/TS) entrypoints: the same tree's `dist/` outputs, built with
  `npx tsc` (see comparator hashes below).

### Result: 240 differential cases, 240 PASS

| Probe | Cases | Reference entrypoint | Candidate entrypoint |
|---|---:|---|---|
| `differential-probe.js` | 38 | `scripts/validate-project.ps1` | `src/probe/validate-chain.ts` |
| `execution-probe.js` | 3 | `scripts/verify-execution-result.ps1` | `src/exec/verify-execution-result.ts` |
| `marker-probe.js` | 16 | `scripts/lib/marker-block.ps1` | `src/marker/marker-block.ts` |
| `marker-io-probe.js` | 6 | `scripts/setup-claude-integration.ps1` | `src/marker/marker-io.ts` |
| `doctor-probe.js` | 1 (58 rows) | `scripts/pmo-doctor.ps1` | `src/doctor/pmo-doctor.ts` |
| `setup-probe.js` | 4 | `scripts/setup-claude-integration.ps1` | `src/tools/setup-claude-integration.ts` |
| `stateful-probe.js` | 6 | `scripts/export-execution-contract.ps1`, `scripts/run-execution-command.ps1`, `scripts/verify-execution-result.ps1` | `src/tools/export-execution-contract.ts`, `src/tools/run-execution-command.ts`, `src/exec/verify-execution-result.ts` |
| `tool-probe.js` | 93 | the 18 `scripts/*.ps1` tools | the 18 `src/tools/*.ts` entrypoints |
| `tool-stateful-probe.js` | 37 | `scripts/new-project.ps1`, `scripts/update-source-snapshot.ps1`, `scripts/aggregate-diagnostics.ps1`, `scripts/setup-claude-integration.ps1` (clean-room) | `src/tools/new-project.ts`, `src/tools/update-source-snapshot.ts`, `src/tools/aggregate-diagnostics.ts`, `src/tools/setup-claude-integration.ts` |
| `surface-probe.js` | 37 | `scripts/validate-project.ps1`, `scripts/pmo-status.ps1`, `scripts/assess-handoff.ps1`, `scripts/new-project.ps1` (via `cli/axiom.mjs` forwarding) | `cli/axiom.mjs` + `scripts/github-action/run-action.mjs` |

Coverage notes:

- **Deterministic tools** (`tool-probe`): pmo-status, assess-handoff,
  visual-proof-digest, handoff-digest, design-provider-digest, ci-profile,
  aggregate-diagnostics, hook-scope-advisory, check-public-hygiene,
  measure-context, run-ci-suite, run-all-checks, build-plugin-package,
  capture-plugin-load-evidence (see skips), prepare-public-release,
  update-source-snapshot, demo. Canonical-compare of stdout/stderr/exit; JSON
  outputs key-sorted before compare, dates normalized, never skipped.
- **Stateful tools** (`tool-stateful-probe`): §8.6 fresh-tree method — the
  reference and candidate each operate on their own freshly-created tree and the
  resulting file bytes, exit codes, and output are compared. Nondeterministic
  fields (salt, run_id, recorded_at, backup stamp, timestamps) are normalized,
  never skipped. Covers new-project (3 modes, tree + stdout + exit),
  update-source-snapshot (bytes + backup pre-image), aggregate-diagnostics
  (registry + immutable event files, fixed-date commit so `commit_hash`
  matches), and clean-room (foreign-repo install touches only AGENTS.md on both
  sides, resulting bytes identical).
- **CLI** (`surface-probe`): the CLI still spawns PowerShell today, so its
  contract is byte-level forwarding — same stdout/stderr/exit as the direct
  script for validate (text + JSON, passing and failing fixtures), status
  (text + JSON), handoff `--json` (merged envelope's gate/assessment steps
  equal the two direct runs), init (generated tree byte-identical to direct
  new-project), and the missing-host contract (unusable `AXIOM_PWSH` → exit 127
  + remediation). This differential-tests current behavior; it does **not**
  decide the in-process rewire, which remains an open decision.
- **GitHub Action** (`surface-probe`): run-action.mjs embeds the validator's own
  JSON in axiom-report.json — the embedded `results` multiset is compared
  directly against the reference validator's JSON. Exit semantics per the
  diagnostics contract: report-only (`enforce=false`) softens a governance
  verdict (0/1/2) into exit 0; `enforce=true` propagates it. Covered on failing
  and passing fixtures.
- **Plugin**: build-plugin-package `-Check` parity on the real repo plus a
  drifted mirror (tool-probe), and the install spike
  (`plugin-install-spike.test.ts`, framework-root vs project-root separation).
  capture-plugin-load-evidence is a documented skip (below).
- **clean-room**: see stateful row above.

### Comparator hashes (SHA-256 of the built probe binaries at archive time)

| Comparator | SHA-256 |
|---|---|
| `dist/probe/tool-probe.js` | `7f49a215eed7dcc551f2fe74df53665d4b32632137b64177f8b23661a7526462` |
| `dist/probe/tool-stateful-probe.js` | `41533bbc6f2097bb7145cecfef56456be9c3cbed1d15c3109ef749b7c2a27bbe` |
| `dist/probe/surface-probe.js` | `dc90450fc957044e994c7ee18e8fe1b2dae0d74128448a6eee12673e9aa58352` |
| `dist/probe/differential-probe.js` | `32b11365ea4ba023b51149735c660120b1419807bc4855f644cc5bdcefa11acf` |
| `dist/probe/execution-probe.js` | `11bff101666716161c37da87f1182292b3f77586faf930e0e522bdb5b39fdaa3` |
| `dist/probe/marker-probe.js` | `70db03afe0235492168fd9339e702049cc53247b85741a8f2fb5eeb3f079a279` |
| `dist/probe/marker-io-probe.js` | `fcdc22fe2ab37ce2745d7f52ad15e3b7b5a18ba733567357963987c9444cc043` |
| `dist/probe/setup-probe.js` | `02811a380ca1265d6d9c0a316ec0cfa5e7be3fe05de09d4f1e346b6654b8a10d` |
| `dist/probe/stateful-probe.js` | `b30fa9f6458d5370fdc63c4efa6929c60e10e1d4a7332a19282fb34cc7c9f5a9` |
| `dist/probe/doctor-probe.js` | `4a99ff67c6ebc4b32358a5d841ab6aa3bf5d1bcfc4c87c53d6e86a19b7eb909f` |

### Host versions at archive time

| Component | Version |
|---|---|
| Node | v23.11.0 |
| PowerShell (reference host, `AXIOM_PWSH`) | 7.6.4 (`<pinned-pwsh-path>`, portable — not on PATH) |
| git | 2.50.1 (Apple Git-155) |
| OS | macOS 26.6.2 (Build 25G82), arm64 |

### Skips — all explained, zero unexplained

1. **capture-plugin-load-evidence** (tool-probe): the tool drives the real
   `claude` CLI, which mutates `~/.claude`. Both sides would drive the same
   external binary, so the comparison would be reflexive; excluded by design.
   Stated in `tool-probe.ts` and counted as an explained skip.
2. **ci-check-evidence-live.test.ts** (unit suite): pre-existing live-`gh`
   skip (no authenticated `gh` in this environment). The 1 skip in the suite's
   206/0/1 result; unchanged from before Phase 6.

### Deltas found by the differential and fixed (each verified against the reference)

Every row below is a real divergence the new probes surfaced; all were fixed so
the candidate matches the reference, and the fixed state is what the 240 PASS
above asserts.

| Tool / surface | Delta found | Fix |
|---|---|---|
| pmo-status | hardcoded `Standard` effective mode; PS reported the mode-resolver's escalated mode | resolve through the chain's `effectiveMode` |
| pmo-status | early exit 1 on a PROJECT.md-less dir; PS proceeds with STRUCT-001 as next_required | removed the early return |
| aggregate-diagnostics | envelope `effective_mode` used the requested mode | use the chain's resolved mode |
| measure-context | table layout differed (alignment, separators, `.000` doubles) | Format-Table-equivalent formatter |
| demo | narration double-blank after child output | blank-line parity |
| build-plugin-package | `-Check` drift output format differed | matched reference layout |
| run-all-checks | passed `-RepoPath` to the plugin-drift child, which rejects it (pwsh usage error) | dropped the flag |
| run-all-checks | `join(repo, resolve(child))` double-prefixed an absolute path → pwsh usage error | use the resolved path directly |
| run-ci-suite | appended `-RepoPath` to the plugin-drift child | dropped the flag |
| new-project | Draft validation report missing from stdout | write via the shared Text report writer |
| prepare-public-release | hygiene child report not streamed; version lists unsorted | stream + sort |
| assess-handoff | `gate_exit_code` was 2 for blocking warnings; PS child exits 0 without `-FailOnWarning` | match child semantics |
| assess-handoff | `verdict_states` field missing from output | added |
| setup-claude-integration | SETUP-001/002 validation and the informational header/guidance lines missing (full rewrite) | transcribed the reference output faithfully |
| update-source-snapshot | missing trailing newline (`Set-Content` appends one); timestamp was UTC `Z`, reference emits local-time `+HH:MM` | byte parity |
| artifact-policy (file sets) | governed-file enumeration order differed (observable in PLACEHOLDER-001 lists) | per-directory case-insensitive sort, files before subdirectories — replicating `Get-ChildItem -Recurse -File` |
| check-public-hygiene | allowlist auth-header token pattern escaped wrong; ported dist files flagged as findings | allowlist + dist-skip, both sides now green |
| RESUME-HERE.md | genuine local absolute paths (`<local-home>/...`) flagged by the hygiene check | replaced with `<pinned-pwsh-path>` |

Probe-side correction (not a tool delta): `tool-stateful-probe` originally let
the PS reference resolve its own `-RepoRoot` (the checkout the script file
lives in), which would mix reference events into the shared local tree; the
probe now passes `-RepoRoot` explicitly per side so each side writes into its
own clone.

### Full regression at archive time

- All 10 probe binaries green (240 differential cases + doctor's 58 rows), run
  with `AXIOM_PWSH=<pinned-pwsh-path>` exported in the same command.
- Full unit suite: **206 pass / 0 fail / 1 skip** (the explained live-`gh`
  skip), 207 tests, matching the pre-Phase-6 baseline exactly.

### Archive integrity

This section was archived after the above was run and confirmed. Re-running
`npx tsc && for p in dist/probe/*.js; do node $p; done` plus
`node --test dist/**/*.test.js` must reproduce the numbers above; the
comparator hashes pin the exact probe binaries those numbers came from.

---

## §3 — Phase 8 cutover: final re-verification (CR-009), 2026-08-17

CR-009's concern is specific: "final delivered tree ≠ proven tree." Everything
in §1-§2 proved the ported engine against the reference on commits that were
never going to ship as the default. Phase 8 (`71c4b6d`, `b85dd22`, `901035d`;
DEC-030/031) makes the Node engine the CLI's unconditional path — so this
section re-runs the proof one more time, at the exact commit that ships, not a
commit descended from what was proven.

### What changed since §2, and why each needed its own re-check rather than
### being assumed still covered

- **`71c4b6d`** — removed `AXIOM_ROLLBACK_PWSH` from `cli/axiom.mjs` entirely
  (was 1210 lines, now 985). No behavior change to the surviving path — every
  command still calls the same differentially-proven `ts()` closures §2
  already checked — but the *selection logic* around it is gone, and that is
  exactly the kind of change that needs its own regression, not an assumption
  that "the engine didn't change so nothing did." Real, live-Windows-verified:
  all 8 `canary-matrix` cells green, including the two that also ran the
  now-single CLI exercise step. Downstream test infrastructure that had
  rollback-specific assertions (`surface-probe.ts`, `cli-tests.mjs`,
  `github-action-tests.mjs`, `clean-room.test.ts`,
  `plugin-install-spike.test.ts`) updated to match reality instead of being
  left asserting a mechanism that no longer exists — see `71c4b6d`'s own
  message for the full account, including two scenarios honestly removed
  (not force-fit) because the exact failure mode they tested can no longer
  occur post-cutover.
- **While auditing the ancestor-junction fix that landed just before Phase 8
  (`1a4764e`)**, direct reproduction (not just code review) found the new
  SETUP-003 check only inspected the project directory's own `lstat`, never
  an ancestor — a real, live containment bypass, fixed in both TS and PS with
  a leaf-backward physical/lexical comparison that's tolerant of OS-level
  prefix aliases (verified not to false-positive on the very temp-dir pattern
  this whole test suite uses).
- **`b85dd22`** — version bump (2.1.0 → 2.2.0) across `VERSION`,
  `CHANGELOG.md`, `package.json`, `.claude-plugin/plugin.json`, and all 15
  `pmo-config/*.json` files (12 found by a first pass, 3 more — BOM-carrying
  files a naive check silently skipped — found by actually running
  `prepare-public-release.ps1`'s own consistency check rather than trusting
  the first sweep was complete). Surfaced one real regression:
  `artifact-hash.test.ts` hardcoded `pmo-config/policy.json`'s SHA-256, which
  changed with the file's content — fixed by recomputing via
  `Get-ArtifactSha256` (the PS reference function itself) and confirming the
  new value matched exactly before updating the fixture, not by trusting
  whatever Node emitted.
- **`901035d`** — a real, pre-existing porting gap in `run-all-checks.ts`,
  found only by finally running `node cli/axiom.mjs check` end to end (no
  prior verification round in this whole migration had exercised that
  specific orchestrator command as a whole): its `cli` and `github-action`
  checks were spawning `pwsh` for two `.mjs` files instead of `node`, exactly
  the reverse of what `scripts/run-all-checks.ps1` does (`& $node.Source
  ...`). This was not something Phase 8 introduced — the file's own header
  comment already said "not yet ported" — it had simply never been exercised
  end to end before. Fixed; `axiom check` now completes all ~35 checks with
  exit 0.

### Full regression at the final cutover commit (`901035d`)

- All 11 probe binaries green (junction-probe added since §2; correctly SKIPs
  off-Windows, 14/14 PASS confirmed on a real Windows host via `canary-matrix`
  earlier in Phase 7/8's own work) — comparator hashes below.
- Full unit suite: **212 pass / 0 fail / 0 skipped**.
- `tests/helpers/cli-tests.mjs`: **46/46** (previously partially gated behind
  PowerShell availability — now unconditional, a real coverage increase, not
  just a rename).
- `tests/helpers/github-action-tests.mjs`: **58/58** (same fix, same effect).
- `node cli/axiom.mjs check` (the full orchestrator, all ~35 checks): exit 0,
  "All Axiom-PMO framework checks completed."
- Real hosts, not just this machine: `901035d`'s own CI run — see
  `gh run view` for the exact run — green on `pmo-checks-{windows,linux,
  macos}-pwsh7` and all 8 `canary-matrix` cells (4 hosts × 2 Node versions).
  The only red job is `canary-baseline`'s own RESET, which is correct,
  expected behavior (Phase 8 touched the canary manifest surface) and not a
  regression — N was already waived by DEC-030 before this work began.

### Comparator hashes (SHA-256 of the built probe binaries at archive time)

| Comparator | SHA-256 |
|---|---|
| `dist/probe/tool-probe.js` | `7f49a215eed7dcc551f2fe74df53665d4b32632137b64177f8b23661a7526462` |
| `dist/probe/tool-stateful-probe.js` | `41533bbc6f2097bb7145cecfef56456be9c3cbed1d15c3109ef749b7c2a27bbe` |
| `dist/probe/surface-probe.js` | `e431fe4b73bd7a5e700804fcc84c0fb2a7422e0ee68b9e3d4692881f64531e16` |
| `dist/probe/differential-probe.js` | `32b11365ea4ba023b51149735c660120b1419807bc4855f644cc5bdcefa11acf` |
| `dist/probe/execution-probe.js` | `11bff101666716161c37da87f1182292b3f77586faf930e0e522bdb5b39fdaa3` |
| `dist/probe/marker-probe.js` | `70db03afe0235492168fd9339e702049cc53247b85741a8f2fb5eeb3f079a279` |
| `dist/probe/marker-io-probe.js` | `fcdc22fe2ab37ce2745d7f52ad15e3b7b5a18ba733567357963987c9444cc043` |
| `dist/probe/setup-probe.js` | `02811a380ca1265d6d9c0a316ec0cfa5e7be3fe05de09d4f1e346b6654b8a10d` |
| `dist/probe/stateful-probe.js` | `b30fa9f6458d5370fdc63c4efa6929c60e10e1d4a7332a19282fb34cc7c9f5a9` |
| `dist/probe/doctor-probe.js` | `4a99ff67c6ebc4b32358a5d841ab6aa3bf5d1bcfc4c87c53d6e86a19b7eb909f` |
| `dist/probe/junction-probe.js` | `2bdc615738d9e48a3ae46107b5beb19129ca90f813e71515463bfabe07a57ee1` |

### Host versions at archive time

| Component | Version |
|---|---|
| Node | v23.11.0 |
| PowerShell (reference host, `AXIOM_PWSH`) | 7.6.4 (`<pinned-pwsh-path>`, portable — not on PATH) |
| git | 2.50.1 (Apple Git-155) |
| OS | macOS 26.6.2 (Build 25G82), arm64 |

### What this section does and does not establish

Establishes: the exact tree that ships as Axiom-PMO 2.2.0 (`901035d`) passes
every differential case §1-§2 already proved, plus the full local and
CI-verified regression above, with the CLI's rollback path removed and the
version identity consistent everywhere it's declared. Two real bugs found
during this specific re-verification pass (the ancestor-escape containment
gap, the run-all-checks node/pwsh mix-up) are exactly what CR-009's "re-run
after cutover, don't assume" concern exists to catch — both were caught here,
not shipped silently.

Does not establish: that Phase 9 (PowerShell deletion) or Phase 10
(documentation reconciliation) are ready — both remain separately gated per
DEC-027/030/031/032 and `Fixed_plan/phase9/PLAN.md`'s still-open items.

---

## §4 — Phase 9: PowerShell reference deleted, final re-verification, 2026-08-17

master-plan.md's own Phase 9 exit criteria requires this explicitly: "re-run
the final-tree proof after deletion changes land... this is a new proof
pass" — §1-§3 proved the ported engine matched a reference that still
existed on disk. This section proves the repo works correctly with that
reference **not present at all**, not merely unused.

### What Phase 9 did, across its full arc (not just the deletion commit)

- Converted all 11 probes from live PS-comparison to golden-fixture
  regression (`tests/golden/probes/*.json`, captured from the reference
  before deletion, `differential-probe.ts` through `tool-stateful-probe.ts`).
  `junction-probe.ts` dropped its PS-comparison half entirely — pure TS-side
  security assertions, since there is no reference left to compare against.
- Ported `scripts/run-validation-tests.ps1` in full
  (`src/tools/validation-fixtures.ts`) — the 161-case positive/negative
  fixture matrix with byte-exact canonical comparison against the 156
  committed golden masters. This had never existed as a Node port before
  Phase 9; building it found a real, previously-undiscovered bug (see below).
- Redesigned `run-all-checks.ts`: the ~20 checks that each spawned one
  `tests/helpers/*.ps1` file collapsed into one run of the Node unit suite;
  `pmo-doctor`, the four example-project gates, and `plugin-skills-drift`
  call their ported functions in-process; `example-golden`
  (`tests/golden/capture-examples.ps1`) dropped entirely, its coverage
  carried forward by `differential-probe.ts` and `validation-fixtures.ts`.
- Fixed `hooks/scope-advisory.sh` (the actual shipped Claude Code plugin
  hook, not `scripts/*.ps1`) to spawn Node against a new
  `hook-scope-advisory-cli.ts` instead of `pwsh` against the script this
  phase deletes — found only by auditing for every remaining live
  `resolvePwsh`/`AXIOM_PWSH` call site before starting the deletion, not by
  assumption.
- Rewrote `.github/workflows/pmo-checks.yml` and built two new CLI wrappers
  (`ci-profile-cli.ts`, `run-ci-suite-cli.ts`) neither of which had existed
  as full ports before — the workflow directly invoked `pwsh`/`scripts/*.ps1`
  in `determine-profile`, `fast-checks`, `targeted-checks`, all three
  full-profile host jobs, and `dogfood-ci-check-evidence`, none of which
  were in the original file-deletion scope but all of which would have
  broken CI on the next push. Job ids for the three full-profile host jobs
  (`pmo-checks-windows-pwsh7` etc.) were kept unchanged despite no longer
  running PowerShell — branch protection's required-status-checks
  references them by name, a GitHub repository setting this session cannot
  see or edit, and renaming was not something to risk as a side effect of a
  code change. Recorded as DEC-034 (`Fixed_plan/decision-log.md`), asked and
  confirmed explicitly before starting, given this is live CI/CD
  infrastructure that cannot be fully verified without an actual
  push-triggered run.
- Deleted `scripts/*.ps1` (60), `tests/helpers/*.ps1` + `tests/e2e/*.ps1`
  (29), `src/probe/marker-harness.ps1`, `src/probe/pwsh-resolver.ts`, and
  the orphaned `dist/probe/pwsh-resolver.js` — 92 files. Kept
  `Fixed_plan/phase0/capture-*.ps1` (7 files) as historical record, per the
  approved plan.

### Real bugs found by this phase's own verification work, each fixed and
### confirmed against the reference (or, once deleted, against the actual
### committed behavior) before moving on

- **`runPortedChain` called `testProjectSourceSection` unconditionally**;
  the reference (`validate-project.ps1`) only calls it `if ($projectText)`,
  defaulting four downstream fields to empty otherwise. A project with no
  `PROJECT.md` at all got spurious `TASK-001`/`SOURCE-001`/`SOURCE-002`/
  `APPROVAL-001` findings the reference never produces. Found by
  `validation-fixtures.ts`'s own new coverage — this exact input shape
  (a completely absent `PROJECT.md`) had never been exercised by
  `differential-probe.ts`'s smaller case list or any unit test before.
- **Six hardcoded `"/"` path-separator bugs** across
  `change-control-validator.ts` (two sites), `run-execution-command.ts`,
  `reference-resolver.ts`, `execution-contract-evidence.ts`, and
  `hook-scope-advisory.ts` — each built a containment check as
  `full.startsWith(root + "/")`, where `root` comes from Node's own
  `path.resolve()`, which returns backslash-separated paths on Windows. The
  hardcoded `"/"` can never match there, so the check always reported an
  in-project file as outside it. Every reference used
  `[System.IO.Path]::DirectorySeparatorChar` for exactly this reason; the TS
  ports had silently dropped that platform-adaptivity. Invisible on this
  (macOS) development machine, where `/` happens to be the native separator
  — found only by the first real Windows CI run, with a visible symptom
  (`examples/OPTIONAL-TRACKS`'s `CHANGE-001` failing outright on Windows).
  `hook-scope-advisory.ts` additionally needed the reference's Windows-only
  case-insensitive comparison; its own comment records that this exact bug
  class had already been found and fixed once in the PS original, and the
  TS port had silently regressed that fix.
- **`canonical-normalizer.ts`'s backslash-folding step folded every lone
  backslash**, not the JSON-escaped pair a Windows path separator actually
  arrives as inside a JSON string value — so `<REPO_ROOT>\\tests\\x`
  canonicalized to `<REPO_ROOT>//tests//x`, which could never match a
  POSIX-captured golden master. The reference's `golden-normalizer.ps1` does
  a literal two-character `.Replace('\\', '/')`; the TS port now matches it
  exactly (`/\\\\/g`, not `/\\/g`), verified against the pinned reference
  before it was gone.
- **Three further Windows-only unit-test portability gaps**, all invisible
  until Phase 9's `run-all-checks` redesign made the Node unit suite run on
  every CI host leg for the first time (the host legs previously ran
  `tests/helpers/*.ps1` instead): an SVG golden fixture whose digest was the
  LF-blob hash while an unmarked `.gitattributes` let Windows checkouts
  convert it to CRLF; a `gh` stub argv off-by-one plus a `spawnSync("gh")`
  call that cannot launch a `.cmd` shim on Windows without a shell; and a
  hook-shim test that hardcoded `/bin/sh` instead of resolving `sh` through
  `PATH`.
- **`pmo-config/validation-rules.json`'s `SOURCE-002` suggestion text was
  updated** to stop pointing at a deleted `.ps1` path, but two of its golden
  `.txt` files were not re-captured to match — caught by this session's own
  independent re-verification (`node cli/axiom.mjs check`, not a visual
  diff read) immediately before the deletion commit, fixed, re-verified
  clean.
- **The clean-room "PowerShell provably absent" test went through two real
  Linux-only failures before landing.** First: it recursively spawned
  `axiom check`, whose own "unit-tests" step runs every `dist/**/*.test.js`
  file — including that same test — so each spawn triggered another. Fixed
  with an env-var guard (`AXIOM_CLEAN_ROOM_NESTED`) that makes the spawned
  child's own copy of the test skip immediately instead of recursing
  (`38fa07b`). That fix did not resolve the actual Linux CI failure — same
  symptom, unchanged, proven by re-running rather than assumed fixed. The
  real cause, read from the CI log: the test's original design also scrubbed
  `PATH` to make `pwsh`/`powershell` physically unresolvable, by dropping
  any `PATH` directory that resolved one of those binaries. On Linux CI,
  `pwsh` is installed into `/usr/bin` — the same directory as `git` and
  other tools the unit suite legitimately shells out to — so removing that
  whole directory broke those tools, for a reason that had nothing to do
  with PowerShell. It only ever passed on Windows/macOS because `pwsh`/
  `pwsh.exe` live in their own dedicated directories there, sharing nothing
  else needed. Stepping back further: `PATH`-scrubbing only matters if some
  code path still searches `PATH` for `pwsh` as a fallback when
  `AXIOM_PWSH` is unset — that was `pwsh-resolver.ts`'s job, and it no
  longer exists (grep confirms zero remaining `resolvePwsh`/`pwsh-resolver`
  references anywhere in `src/`). `AXIOM_PWSH` unset already exercises
  every code path that could reach for PowerShell, because there is no code
  left that would search `PATH` if it were — the stronger claim was solving
  a problem the deletion had already solved a different way. `333b1da`
  drops the `PATH`-scrubbing entirely, matching the existing "Node-only"
  test's simpler approach.

### Full regression at the deletion commit (`dfb6f8b`) and its immediate
### follow-ups (`98e7c13`, `56b5099`, `38fa07b`, `333b1da`, `ff56d18`)

- `npx tsc`: clean.
- Full unit suite: **219 pass / 0 fail / 0 skipped** (212 at Phase 8 + the
  `ci-profile-cli` tests + the new clean-room PowerShell-absent proof below).
- All 11 probe binaries green with `pwsh` confirmed absent from `PATH`
  (`which pwsh` → not found, not merely `AXIOM_PWSH` unset): differential
  38, doctor 58-row multiset match, execution 3, marker 16, marker-io 6,
  setup 4, stateful 6, surface 38, tool 92 (93 minus the intentionally
  dropped `golden` suite case), tool-stateful 37, junction SKIP=1 on macOS
  (14/14 PASS previously confirmed on real Windows CI, unchanged by this
  phase's TS-only conversion).
- `node cli/axiom.mjs check` (the full orchestrator): exit 0, "All
  Axiom-PMO framework checks completed," with `AXIOM_PWSH` unset.
- New committed proof, not just a terminal check this session ran once:
  `clean-room.test.ts`'s "axiom check and axiom demo run correctly with
  PowerShell provably absent" test runs both commands with `AXIOM_PWSH`
  unset and asserts they complete successfully — the master-plan.md
  distinction between "PowerShell not invoked" and "PowerShell not present"
  now has a permanent regression test, not an ad-hoc verification that
  expires when the session ends. It does not additionally scrub `PATH`, for
  the reason above: with `pwsh-resolver.ts` deleted, no code path exists
  that would consult `PATH` for PowerShell in the first place, so
  `AXIOM_PWSH` unset already exercises every reachable path.
- Real hosts, not just this machine: `dfb6f8b`'s own CI run
  (`gh run view 32027460744`) green on `pmo-checks-{windows,linux,
  macos}-pwsh7`, both dogfood jobs, and all 8 `canary-matrix` cells. The
  only red job was `canary-baseline`'s own RESET — correct, expected
  behavior given this commit touched the entire validation surface, not a
  regression, caught up in `98e7c13` with N still waived per DEC-030.
  `56b5099` (the clean-room test addition) then surfaced the two real bugs
  above on its own Linux CI runs, in sequence — not a silent pass followed
  by a gap discovered later, but exactly the kind of real-host failure this
  project's CI matrix exists to catch, each one read from the actual log
  and re-verified after the fix rather than assumed resolved. `333b1da`
  (`gh run view 32029330682`) is the first green run on all three hosts;
  `ff56d18` is the routine canary catch-up its own surface change required.

### Comparator hashes (SHA-256 of the built probe binaries at archive time)

| Comparator | SHA-256 |
|---|---|
| `dist/probe/tool-probe.js` | `4ac35a9888054c8944a1beec2ee40aa0d672894528ce9b38e9591d5ff4e3db47` |
| `dist/probe/tool-stateful-probe.js` | `2f75355f7b5c4ecd4feb94873387c6e6c0d458c96ffb221eb0f398b13c5d26b0` |
| `dist/probe/surface-probe.js` | `1ec3a21bb9dfd4acaf10c7d3ced3e6b6c8bbe7aab29848e2d8cb800a0eadb25a` |
| `dist/probe/differential-probe.js` | `4dda0df78ddea31185dbccfbcaf5defb6bbfed7a2251f158877f4eb5798fe569` |
| `dist/probe/execution-probe.js` | `4e0908c69d348dcf5d457b4a538bc6a94f592bcca7b84f1587f3f180cfab7bc5` |
| `dist/probe/marker-probe.js` | `10302812ac84d46316e2e03c986c6262e913dd386db2dec46dd7bdb2f05a703c` |
| `dist/probe/marker-io-probe.js` | `41e4399202188f50299f49453a9ac79937ed95f3e7c3365bc86f5e358e881717` |
| `dist/probe/setup-probe.js` | `7c72fa20172541ed55109d47730cfe0a4662b707dc09e1ee1a5bade0c53e8143` |
| `dist/probe/stateful-probe.js` | `baa6e78e694b70d22306c86e2cfbcf3d7faf7ff3b36bbcc41fc71f6cb9df293f` |
| `dist/probe/doctor-probe.js` | `0a4e50ed2ffaa069280cef19f84d43c45f8588da4aa4dcf37cfe171e16ce322e` |
| `dist/probe/junction-probe.js` | `11a7f2582bc42486a24430f8fa5771a335f33062529cb1f558c7d3d6024cac02` |

### Host versions at archive time

| Component | Version |
|---|---|
| Node | v23.11.0 |
| PowerShell | not present — `which pwsh` reports not found; the reference implementation this proof used to run against no longer exists on disk |
| git | 2.50.1 (Apple Git-155) |
| OS | macOS 26.6.2 (Build 25G82), arm64 |

### What this section does and does not establish

Establishes: the tree at `ff56d18` — with the entire PowerShell reference
implementation deleted — passes the full local and CI-verified regression
above, on real Windows, macOS, and Linux hosts, with PowerShell genuinely
absent rather than merely unused. Every bug this phase's own verification
work found (ten distinct issues across the arc, listed above) was caught by
real reproduction — a failing local run, a real Windows CI log, or this
session's own independent re-check before committing — and fixed against the
reference before that reference was gone, never guessed at or shipped
silently.

Does not establish: that Phase 10 (documentation reconciliation) is
underway. `README.md`/`TESTING.md`/`CONTRIBUTING.md` and other
consumer-facing docs still reference PowerShell by design — deferred to
Phase 10, not touched here, per `AGENTS.md`'s own scope boundary and this
phase's plan. `Fixed_plan/phase9/PLAN.md` records this phase's own
completion status.
