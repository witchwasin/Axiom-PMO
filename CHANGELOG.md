# Changelog

## Unreleased

**Milestones 7, 8.0, 8.1, and 9 — CLOSED and MERGED to `main`, 2026-08-03**
(`DEC-016`), merge commit `1235034`. Independently reviewed by Independent AI Reviewer across
three rounds: round 1 REQUEST CHANGES (1 FATAL + 2 MAJOR against Milestones
8.1/9, all fixed and regression-tested); round 2 REQUEST CHANGES (1
compatibility finding against Milestone 8.1, fixed and regression-tested,
plus two items recorded as known limitations rather than implemented per
Independent AI Reviewer's explicit scope lock); round 3 final verdict **ACCEPT** for all four
milestones. Not part of the `v1.3.0` tag; no further tag or release
authorized by this closure.

**Milestone 7 — Onboarding and the Two Execution Paths.** Authorized for
implementation 2026-08-03 (`DEC-011`), on branch
`m7-onboarding-execution-paths`.

- `execution_path` (`development_handoff` | `governed_ai_execution`) is now a
  governed declaration in `PROJECT.md`, defaulting to `development_handoff`
  so every existing project validates unchanged. New rules `PATH-001`
  (declaration missing/unrecognized) and `PATH-002` (declaration looks stale
  against an active, unresolved `.execution/**` package — archived or
  completed execution evidence never triggers it).
- `axiom init` prompts interactively on a TTY: which delivery path, then
  which governance mode, with a "Help me decide" strict-trigger
  questionnaire. Every answer is a declaration, never a claimed detection.
  Non-interactive callers (CI, `--no-interactive`, or any flag already
  supplied) are unaffected.
- New `axiom status` verb: reports a project's execution path, effective
  governance mode, current gate, and the validator's own next blocking
  finding.
- New `pmo-config/onboarding-questions.json`, kept in sync with
  `policy.json`'s strict-trigger enum by a new `DOCTOR-013` check.
- See [`docs/concepts/execution-paths.md`](docs/concepts/execution-paths.md)
  and `research/m7-m9-proposal.md` for full design.

Backward compatible. No existing required artifact changed for either path;
the path-artifact delta is empty as of this milestone.

**Milestone 8.0 — Adversarial Review Evidence: research.** Delivered,
recommending **GO WITH REFRAME**. See
[`docs/architecture/adversarial-review.md`](docs/architecture/adversarial-review.md).
No code changed — this is the research and threat-model deliverable
`DEC-012` authorized.

**Milestone 8.1 — Adversarial Review Evidence: implementation.** Authorized
2026-08-03 (`DEC-014`), implemented, and closed (`DEC-016`).

- New `AREV-001`..`AREV-006` rules (`scripts/lib/adversarial-review-validator.ps1`),
  checked by `axiom verify` whenever `EXECUTION-REVIEW.json` exists or is
  required for the project's effective mode (Lite disabled, Standard
  advisory, Strict required).
- Reuses `pmo-config/execution-contract-policy.json`'s existing
  `evidence_provenance` model (`artifact-observed`, `externally-observed`)
  rather than a parallel one, adding only `human-attested`. A new
  `review-evidence-accepted` authority-claim type is registered alongside
  `test-evidence-accepted`, reusing `EXEC-007`'s existing promotion
  mechanism unchanged.
- `externally-observed` requires all four bindings from
  `docs/architecture/adversarial-review.md` §3.3 -- reusing `Test-CiCheckEvidence`'s
  `check_run_id` binding unchanged, plus an API-attested artifact digest, a
  pinned workflow content digest, and contract/commit identity. Ships with
  `pinned_workflow_digest: null` by default, so it fails closed until an
  organization pins its own review workflow.
- Finding-lifecycle authority by role, not by AI/human kind: the executor may
  only move a finding to `disputed`; only a human may close a finding under a
  security/legal/business/privacy category.
- `axiom export` now adds the pinned review-workflow path to every
  contract's `prohibited_paths` by default, so `EXEC-004` protects it.
- New `axiom verify --preflight` flag: runs the mechanical `EXEC-*` checks
  and skips the one check that can make a live GitHub API call.
- `tests/helpers/adversarial-review-tests.ps1` (now 24 cases, written
  adversarially): self-forged decision records, executor self-closure, an AI
  reviewer closing a human-only-category finding, artifact-observed alone
  never satisfying Strict, an unrelated successful check run on the same
  commit not satisfying `externally-observed`.

**Independent AI Reviewer independent review, round 1: REQUEST CHANGES.** 1 FATAL, 2 MAJOR, all
fixed; pending re-review before merge to `main`.

- **FATAL** — `externally-observed` verified `check_run_id`'s commit,
  status, conclusion, artifact digest, and the pinned workflow's content
  digest, but never verified the cited check run was actually *produced by*
  the pinned workflow. An unrelated successful check run on the same commit,
  primed to print the review artifact's digest in its own output, passed
  every check. Fixed by resolving the check run's `check_suite.id` to its
  GitHub Actions workflow run and requiring that run's `path` match the
  pinned workflow path — reproduced and regression-tested with a stubbed
  `gh` against both the attack and the legitimate case.
- **MAJOR** — `closure_policy.settable_by` was loaded from policy and never
  applied: an `ai`-kind reviewer could set `false_positive`/`accepted_risk`/
  `deferred` on any finding, human-only category or not, whenever a bound
  decision resolved outside the verified range. Fixed by deriving the
  human-only-status set from policy and enforcing it.
- (Third finding was against Milestone 9 — see below.)

**Independent AI Reviewer independent review, round 2: scope-locked final direction.** One
compatibility fix required and applied; no other finding raised.

- A legitimate GitHub Actions workflow-run `path` can carry a trailing
  `@ref` (e.g. `.github/workflows/adversarial-review.yml@main`), which
  round 1's exact-match comparison would have rejected as a false
  mismatch. Fixed by normalizing the suffix away before comparing —
  strictly more lenient about the suffix format, never about the path text
  the round-1 FATAL fix binds against. New regression case added
  alongside the existing unrelated-workflow negative case (kept unchanged
  per Independent AI Reviewer's explicit instruction); `tests/helpers/adversarial-review-tests.ps1`
  now 25 cases.
- Two items recorded as known, non-blocking limitations rather than
  implemented, per Independent AI Reviewer's explicit scope lock — see
  `docs/architecture/adversarial-review.md` §11: non-closure transitions
  (`disputed`) inside a reviewer-authored review file are not fully
  actor-attributed at the per-finding level, and a `workflow_id` binding is
  optional future hardening. Neither weakens any enforced authority
  guarantee.

**Milestone 9 — Failure Pattern Registry and Governed Improvement
Proposals.** Boundary confirmed 2026-08-03 (`DEC-013`), authorized and
implemented the same day (`DEC-015`), closed (`DEC-016`).

- New `scripts/aggregate-diagnostics.ps1`: one immutable event file per
  validation run (`.axiom/learning/events/<utc-timestamp>-<run-id>.jsonl`,
  never reopened), a rebuildable `FAILURE-PATTERNS.json`, and
  `IMPROVEMENT-CANDIDATE.json` proposals for clusters crossing a
  multi-dimensional threshold (distinct projects/commits/days-span -- never
  a raw occurrence count).
- Local and opt-in: no network call anywhere in the script; raw events and
  the per-repository salt are git-ignored by default
  (`.axiom/learning/events/`, `.axiom/learning/salt`).
- Every event field carries an explicit retain/normalize/hash/drop
  disposition (`pmo-config/learning-policy.json field_disposition`) --
  "metadata-only" is not treated as a privacy guarantee by itself.
- New optional `lifecycle` field on catalog rules, with a new `DOCTOR-014`
  enforcing the invariant that an `experimental` rule can never carry a
  blocking severity.
- `tests/helpers/learning-registry-tests.ps1` (now 15 cases) plus a
  `DOCTOR-014` case in `tests/helpers/config-mutation-tests.ps1`: no
  artifact content or free text reaches an event, rebuild-from-events
  equality, twenty reruns of one unfixed defect produce zero candidates, an
  experimental rule with a blocking severity fails `pmo-doctor` itself.

**Independent AI Reviewer independent review, round 1: REQUEST CHANGES.** 1 MAJOR, fixed;
pending re-review before merge to `main`.

- **MAJOR** — `ConvertTo-NormalizedItemId` replaced digits only (`\d+` ->
  `#`), so a purely alphabetic id (`ACME-fraud-case`, `patient-HIV`) passed
  through byte-for-byte unchanged into every event; `execution_path` was
  copied verbatim from `PROJECT.md`'s regex capture with no enum validation
  despite `learning-policy.json` already declaring it a closed enum. Both
  are now allowlist/enum-validated against new
  `item_id_allowed_patterns` / `execution_path_allowed_values` policy
  fields — anything not matching is bucketed to `"other"` / `"unknown"`,
  never partially sanitized and retained.

## 1.3.0 - 2026-08-02

**The Claude Code integration, and execution-evidence hardening.** Milestone 6
ships Axiom-PMO as an optional Claude Code plugin; Milestone 5.5 closes a
provenance gap in `ci-check` evidence. Milestones 1-5 remain the product --
nothing in them requires the integration.

Backward compatible. Every existing local invocation and the GitHub Action are
unchanged; the plugin and its advisory hook are both opt-in, and the hook is
off by default.

### Closed — three independent review rounds, ACCEPT WITH MINOR REVISIONS

- **Claude Code integration (Milestone 6).** Optional. Milestones 1-5 are the
  product; this is a bridge for teams who choose to continue implementation in
  Claude Code after a handoff is verified, and nothing in Milestones 1-5
  requires it.

  **Closed 2026-08-01.** Tested and accepted by the Human Owner (`DEC-005`);
  independently reviewed across three rounds -- every round REQUEST CHANGES,
  final verdict **ACCEPT WITH MINOR REVISIONS**; accepted and closed by the
  Human Owner (`DEC-007`), certified at commit
  `1d85d6091bc07bd1eb59d221310f18adf5287b83`, CI run
  `30736667616`. Closure itself authorized closure only; merge to `main`
  was separately confirmed by the Human Owner. The `v1.3.0` git tag was
  separately authorized and created on 2026-08-02. No GitHub Release,
  marketplace publication, or npm publication has occurred.

  Ten findings across three rounds, all reproduced before being fixed, all
  in the code that writes to the user's own file:

  | Round | Findings |
  |---|---|
  | 1 | FATAL: ownership decided by a self-declared, unkeyed SHA-256 the block declared about itself -- arbitrary content plus a correct digest read as framework-generated and was deleted without `-Force`. MAJOR: removal reassembled surrounding text with `TrimEnd`/`Trim`, collapsing blank lines the user owned. |
  | 2 | FATAL: unsupported encodings mangled rather than refused -- a UTF-16 file had its BOM turned to replacement characters and every byte rewritten. MAJOR x4: mutable `sep=`/`tail=` marker metadata could widen a deletion even on an `owned` block; file provenance was inferred from post-removal contents, deleting pre-existing whitespace-only files; the Windows hook path was unverified; `DEC-003` referenced two different decisions. |
  | 3 | MAJOR x3: a bridging newline kept outside the marker span broke the exact round trip (two bytes on CRLF); the Windows assertion checked only exit code, which is 0 whether the hook advises or does nothing -- asserting the message instead exposed that the shim never un-escaped JSON `cwd`, so the advisory had never fired on Windows at all; governance records referenced stale IDs. MINOR x2: UTF-32 BOM detection ran after UTF-16's and mis-identified UTF-32LE files; wording overstated the digest as proof of authorship rather than recognition. |
  | Final | ACCEPT WITH MINOR REVISIONS -- a duplicated heading in the reviewer index and a stale ROADMAP row, both fixed in the closure pass. |

  Same lesson as Milestone 5, arriving twice more in different clothes: a
  digest proves integrity since hashing, never authorship, and inferring
  provenance from a file's current contents is guessing dressed as logic.
  Two of the ten findings were caused by earlier fixes -- round 2's mutable
  marker metadata was added by round 1's fix, and round 3's bridging newline
  was kept by round 2's fix. The design that finally passed writes **nothing**
  outside the marker span: no separator, no bridging byte, nothing to
  reclaim and nothing left to trade away.

  The framework installs as a Claude Code plugin, outside the user's
  repository. One fenced, namespaced block goes into the repository's
  `AGENTS.md` -- that file has to be a file, because Codex and Cursor read it
  too and a Claude-only plugin would not reach them.

  **What it does not do, stated first because it is the easiest thing to
  misrepresent:** it hands Claude Code the approved scope and authority as
  governed context. It does not enforce them. Nothing in Milestone 6 prevents
  an out-of-scope edit; SCOPE-DIFF and the `EXEC-*` rules detect one
  afterwards, exactly as before. No authority, evidence, or approval logic
  moved out of Milestones 1-5.

  - **6.1 spike** established what a plugin can actually do, from a real
    installed marketplace rather than recollection, and proved the framework
    runs from a non-checkout, non-cwd, read-only install root. Accepted by the
    Human Owner 2026-07-31. It also found that no directory move is needed and
    that the approved fallback was not needed.
  - **6.2 packaging.** Plugin root is the repository root, so `scripts/`,
    `cli/`, `pmo-config/` and `templates/` stay exactly where they are and the
    validator is not duplicated. Claude Code discovers skills only from
    `<plugin-root>/skills/`, so that directory is a generated mirror of
    `.claude/skills/` with a CI drift gate covering four separate directions.
    Maintainer-only tools now fail with `FRAMEWORK-001` outside a checkout
    instead of a raw exception.
  - **6.3 setup and uninstall.** One fenced block, ownership decided by
    matching a frozen registry of framework-generated bodies (never by a
    self-declared digest), exact-span removal with nothing written outside the
    markers, atomic writes, backups, idempotent, byte-identical round trip
    for every file shape tested including CRLF, BOM, and no trailing newline.
    Refuses rather than guessing when markers are malformed, the block was
    hand-edited, or the encoding is not UTF-8.
  - **6.4 clean-room.** Ten pre-existing repository shapes -- CLAUDE.md,
    AGENTS.md, both, custom skills and commands, Superpowers, BMAD, malformed
    markers, already-installed, edits-after-setup -- fingerprinted file by
    file. Plus a real `claude plugin` install transcript: 7 skills, 1 hook.
  - **6.5 advisory hook.** Opt-in per project, report-only, ~9 ms disabled and
    ~230 ms enabled. It cannot emit a permission decision, asserted against
    its source rather than only its output. Functionally verified on Windows
    with a POSIX shell by asserting the advisory message, not just an exit
    code -- which is what surfaced the un-escaped-`cwd` defect above. Windows
    without a POSIX shell does not receive the hook, by product decision:
    setup, the CLI, and validators remain fully supported there.

  Known limitations, acknowledged by the Human Owner and **not closed** by
  this closure: plugin update/version drift is untested, cross-plugin hook
  ordering is unverified, and a git-source install carries the whole
  repository (~10 MB, mostly `tests/`). Full list in
  `docs/architecture/m6-threat-model.md`.

  Tests: 17 spike, 40 packaging, 229 setup, 63 clean-room, 56 hook, 50 CLI.
  The Human Owner has run `docs/guides/claude-code-walkthrough.md`. It has
  still not been run by anyone outside the team that built it, which is the
  independent signal that walkthrough exists to produce.

### Accepted and closed

- **Execution contract verification (Milestone 5).** Reviewed by Independent AI Reviewer across
  five rounds, verdict ACCEPT at round 5; CI green 7/7 including Windows
  PowerShell 5.1; **accepted and closed by the Human Owner on 2026-07-31**
  (`DEC-004`), certified at commit `2888769`, CI run `30643605031`.

  Milestone 5 is part of the **core product**: Milestones 1-5 together are the
  Axiom-PMO governance and development-handoff framework. Milestone 6 remains
  an optional Claude Code integration bridge (`DEC-006`).

  `axiom export` turns an
  approved `DELIVERY.md` work item into an `EXECUTION-CONTRACT.json` an AI
  execution workflow can be handed; `axiom verify` checks the returned
  `EXECUTION-RESULT.json` against that contract and against observed git
  state; `axiom run` executes a command for real and seals a verifiable
  runner-exit-record. Rules `EXEC-001` to `EXEC-008`; policy in
  `pmo-config/execution-contract-policy.json`; reference in
  `docs/reference/execution-contract.md`.

  Five review rounds shaped what this actually does, and every one is worth
  recording because each corrected the one before it.

  **Round 1** found the implementation checked claim *shape*, not ground
  truth: test-evidence adapters confirmed an entry's fields were present
  without opening a file, hashing anything, or querying an API; the
  contract's digest sidecar was checked only when present, so deleting it
  skipped the tamper check; and a human-authority claim's `decision_ref`
  was checked for non-emptiness, never resolved against `decision-log.md`.

  **Round 2** found the fix for the first of those was still incomplete.
  The new `runner-exit-record` check did real work -- containment, digest
  recomputation against a `.sha256` sidecar, contract and work-item
  binding, exit code -- but record and sidecar both live under
  `.execution/**`, which the verified actor can write. A fully hand-forged
  record with a genuinely matching sidecar passed, with `axiom run` never
  invoked. Computing a SHA-256 is exactly as easy as writing the JSON it
  summarises.

  The correction is not a better check on the file. **No check on a file
  the verified actor can write establishes who wrote it** -- a digest
  proves integrity from the moment it was taken and never provenance. So
  evidence now carries an explicit provenance tier:

  - `externally-observed` (`ci-check`, queried live from the GitHub API,
    matched to an exact commit SHA, never reading the result's own claimed
    conclusion) satisfies a required test on its own;
  - `artifact-observed` (`junit-artifact`, `runner-exit-record`) is real,
    digest-checked and tamper-evident, but does **not** satisfy a required
    test alone;
  - `agent-claimed` (`agent-assertion`) never does.

  **Round 3** found the human-vouch path that promotes artifact-observed
  evidence was itself a single global boolean: any resolvable
  `test-evidence-accepted` claim promoted *every* artifact-observed entry in
  the execution. Demonstrated with a fabricated JUnit report claiming 99
  passing tests, vouched by a real decision record about which logging
  library to use.

  Binding the claim to the evidence is necessary but not sufficient, and the
  distinction matters: the result document is written by the actor being
  verified, so a binding that lives only in the claim is defeated by forging
  the artifact, hashing it, and copying that hash into your own claim.
  Self-consistent forgery is still forgery. The anchor is therefore the
  decision row itself, which the actor cannot author within the verified
  commit range -- `decision-log.md` must not change inside `base..head`, so a
  row naming the artifact's digest had to exist before the work began.

  A vouch now promotes one evidence entry, never all of them, and must name
  `test_name` and `evidence_sha256` matching what the adapter actually
  computed, and cite a resolving `DEC-###` not written in-range.

  **Round 4** found the decision-row anchor was still too weak, in two
  places. First, it searched the row for the digest as a *substring*. That
  answers "does this row mention these bytes", not "did a human approve this
  artifact for this test" -- so a row approving a JUnit report for `unit
  tests` was reusable for `integration tests` by relabelling the evidence
  entry and the claim, both of which the verified actor writes. Reproduced
  here before the fix: verdict `pass`, no rule raised. Second, the binding
  check ran only for `test-evidence-accepted`; every other human-only claim
  (`release-approval`, `qa-approval`, `security-approval`, `scope-change`,
  `risk-mode-downgrade`) still resolved on `decision_ref` alone, so any
  `DEC-###` in the log satisfied any of them.

  A substring is not a statement. The decision row must now carry a
  structured `axiom-authority: type=...; work_item=...; contract=...;
  test=...; evidence=...` token, parsed field by field per table cell --
  required on **every** human-only claim, with `test` and `evidence`
  additionally required for a test vouch. A row that merely mentions a digest
  in prose authorizes nothing, and a row with no token fails closed.

  Deliberately a claim rather than a config flag: a weakening that is
  per-execution, attributable, and recorded in a governed artifact can be
  reviewed later; a boolean cannot. It proves accountability, not inspection
  -- and an actor could still plant a binding in an earlier execution's
  decision row, which is documented rather than papered over.

  Also fixed across the two rounds: the contract's digest sidecar is now
  mandatory and fails closed (`EXEC-002`); `decision_ref` resolves against
  a real parse of `decision-log.md`, must be unique, and must not have been
  added or edited within the commit range under verification; and the
  changed-files check now catches a result *claiming* a file changed that
  git shows no evidence of, not only the reverse.

  120 adversarial tests (up from 57) reproduce each gap and confirm each
  fix, including the decisive ones: a hand-forged run record with a valid
  sidecar; a genuine record without a vouch; a vouch citing a real but
  unrelated decision; a vouch whose bindings are all self-consistent but
  whose decision row never names the digest; a real artifact approved for one
  test and relabelled for another; a digest present in the row only as prose;
  and a `release-approval` citing a decision that says nothing about
  releasing this work item.

  **Round 5 accepted it**, with one non-blocking mismatch: the docs said a
  decision row could carry several `axiom-authority` tokens, while the parser
  matched greedily to end-of-cell and read two tokens sharing a cell as one
  malformed payload. Fixed in the parser -- a token runs until the next
  `axiom-authority:` or the end of its cell -- bringing the suite to 120.

  See `ROADMAP.md`'s Milestone 5.1-5.4 section for the full sequence -- kept
  in full rather than summarized away, because five rounds of review on one
  authority mechanism is the more useful record.

## 1.2.0 - 2026-07-30

**GitHub Action, with changed-file scope enforcement.** Axiom-PMO can now run
directly inside a pull request instead of requiring a local CLI invocation,
and can prove a PR's changed files stayed inside a project's pre-approved
implementation scope.

Backward compatible. Every existing local invocation (`validate-project.ps1`,
`assess-handoff.ps1`, the CLI) is byte-for-byte unchanged; the Action and
SCOPE-DIFF are both opt-in additions.

### Added

- **Reusable GitHub Action** (`action.yml`, `uses: witchwasin/Axiom-PMO@v1.2.0`
  in ten lines or fewer). Wraps the existing validator/CLI with no duplicated
  validation logic. Produces a GitHub Job Summary, `axiom-report.json` and
  `axiom-report.md` artifacts, and PR annotations mapped to file, item, field,
  and rule id. `enforce` defaults to `false` (report-only); logs and reports
  never contain source-sensitive content or raw local paths.
- **SCOPE-DIFF** (`SCOPE.json`, opt-in via `enable-scope-diff: true` or
  `-ScopeDiffBase`/`-ScopeDiffHead`): compares a PR's actual changed files
  against a project's approved `implementation_scope` using a small
  deterministic glob grammar and a real `git diff --name-status`. A missing
  `SCOPE.json` always fails closed (`SCOPE-DIFF-002`), never "everything is
  approved." Rules `SCOPE-DIFF-001` through `SCOPE-DIFF-005`, each documented
  under `docs/rules/`. Renames are checked at both the old and new path, with
  a structured `scope_diff.renames[]` field carrying both paths and both
  per-side verdicts. `pmo-config/scope-diff-policy.json` holds a small,
  reviewable, explicitly-validated repo-wide exemption list (lockfiles,
  `CHANGELOG.md`) — entries with an empty pattern/reason, a duplicate
  pattern, or a pattern broad enough to match effectively everything (`**`,
  `*`, `**/*`) are rejected outright. Path matching is case-sensitive and
  rename detection is pinned via explicit `git diff` options, independent of
  the runner's own git configuration. See `docs/reference/scope-declaration.md`.
- **Diagnostics contract**: new optional `scope_diff` envelope field, present
  only when SCOPE-DIFF was requested. See `docs/reference/diagnostics-contract.md`.

### Notes

- No breaking changes to the JSON result contract; `diagnostics_schema_version`
  stays at `1.1`.
- `axiom-report.json`/`.md` are uploaded even when validation fails, and the
  Action never persists raw validator stdout or git stderr into a report,
  annotation, or Job Summary — only a small set of known, safe diagnostic
  messages, with the underlying detail going to the workflow run log only.

## 1.1.1 - 2026-07-26

A patch release: two validation rules that were deferred from 1.1.0, and a CI
change that halves the duplicated work in the test suite. No behavioural change
to any gate that existed in 1.1.0.

### Added

- **`HANDOFF-013`** ([#6](https://github.com/witchwasin/Axiom-PMO/issues/6)) —
  every governed table's header must match the columns declared in
  `pmo-config/handoff-policy.json`, by name and in order. The validator reads
  cells by column name, so a renamed header previously yielded empty cells and
  the failure surfaced as some *other* rule complaining about a value the author
  had filled in. A reordered header is reported separately from a renamed one,
  because the fix differs.
- **`HANDOFF-014`** ([#7](https://github.com/witchwasin/Axiom-PMO/issues/7)) —
  `HANDOFF.md` and `HANDOFF-REVIEW.json` must name the project `PROJECT.md`
  declares. `Project` was the only metadata field checked against nothing while
  its neighbours (mode, horizon, build-spec reference) were all cross-checked.
  The exposure is a project started by copying another, which is exactly what a
  filled-in handoff sheet invites.

### Changed

- **CI runs the fixture matrix once instead of twice.** Golden verification was
  a separate workflow step that re-executed all 148 fixture cases — the most
  expensive thing the suite does — for output `run-all-checks` had just
  produced. It now happens inside that single pass. Measured at ~2.5 minutes
  saved per CI run, and the saving grows with every fixture added. No coverage
  was removed: golden drift still fails the suite, verified by reverting a
  golden file and confirming the failure.

### Fixed

- **The example goldens were verified nowhere.** Not in `run-all-checks`, not in
  the workflow. `tests/golden/capture-examples.ps1 -Verify` is now part of the
  suite, so the worked examples in the README are held to their recorded output.
- **`demo/broken-project` and `demo/fixed-project` named the wrong project.**
  Both were copied from `examples/HANDOFF-DEMO` with only their headings
  renamed, so their handoff artifacts still said `HANDOFF-DEMO`. Found by
  `HANDOFF-014` on its first run — the rule's own worked example.

## 1.1.0 - 2026-07-26

**Handoff-Ready.** Adds a checking layer between `Design` and `Release` that
answers a question 1.0 could not: is this documentation sufficient for a
developer to start building, integrate, and demonstrate on time?

```text
Draft -> Scope -> Design -> Handoff -> Build/QA -> Release
```

Backward compatible. Projects that do not request the new gate validate exactly
as they did in 1.0; the only change visible to an existing consumer is additive
fields on the JSON diagnostic.

### Added

- **`Handoff` gate** (`scripts/validate-project.ps1 -Gate Handoff`) with rules
  `HANDOFF-001` to `HANDOFF-012`. It introduces **no new human approval** -- it
  reuses the existing `Design Ready` approval and checks whether the contract is
  complete enough to act on. Policy lives in `pmo-config/handoff-policy.json`.
- **Canonical handoff artifacts**: `templates/HANDOFF.md` (developer entry
  point), `templates/BUILD-SPEC.md` (technical specification with per-section
  `Status: specified | not_required` and a required rationale for every waiver),
  and `templates/HANDOFF-REVIEW.json` (machine-readable readiness evidence).
- **Semantic handoff review** as a second, separate layer. `pmo-delivery` gains
  a `handoff_review` intent with twelve config-driven review lenses. The
  deterministic validator checks only what the artifacts *declare*; judgement
  about whether the declarations make sense is recorded as structured evidence
  in `HANDOFF-REVIEW.json`. **A review is candidate evidence, never an
  approval.**
- **Review freshness.** `HANDOFF-REVIEW.json` records a digest of `PROJECT.md`'s
  Source Snapshot table; when the sources change the review is reported as stale
  by `HANDOFF-010`. `scripts/handoff-digest.ps1` prints the current digest.
- **Readiness assessment** (`scripts/assess-handoff.ps1`, Text and JSON). Reports
  six stage verdicts -- Contract Valid, Ready to Start Development, Ready to
  Integrate, Ready to Demo, Ready for UAT, Ready for Release -- rather than one
  boolean, because "ready to build" and "ready to demo" are different questions
  with different owners. Each verdict is `true`, `false`, or **`null`** for
  "cannot be determined", with a per-stage reason; an absence of recorded
  findings is never reported as an absence of problems. Blockers are drawn from
  **both** `HANDOFF-REVIEW.json` findings and `HANDOFF.md` open actions,
  deduplicated. Includes a 100-point score with hard caps: `BLOCKED` on any
  deterministic FAIL, max 70 without a usable review, max 69 with a missing
  owner or an unexecutable build sequence, max 49 with an open critical
  `before_build` finding. **The score is not an approval.**
- **Enforced closure authority.** Any finding status other than `open` requires
  a resolvable `decision_ref`; an AI reviewer may only set `resolved`; and an AI
  may never close a finding under a human-only lens (privacy classification,
  environment constraints) whatever decision it cites. Previously this boundary
  existed only as skill instructions, which an agent can ignore. Configured in
  `handoff-policy.json` `semantic_review.closure_policy`.
- **Two freshness digests.** `source_snapshot.digest` covers the material the
  requirements came from; `review_inputs.digest` covers the governed artifacts
  the reviewer actually read. With only the first, editing `DESIGN/BUILD-SPEC.md`
  or the build sequence after a review left it reporting as current.
  `scripts/handoff-digest.ps1` prints both.
- **Resolved references at the Handoff gate.** Acceptance cases must cite
  requirements that exist in `PROJECT.md`; classification, retention, and
  environment decision columns must lead with a resolvable reference rather than
  prose; `HANDOFF.md` metadata must agree with the effective mode, carry an
  ISO-8601 horizon, and point at a build spec that exists.
- **Structured diagnostics v1.1.** Every JSON diagnostic now carries `artifact`,
  `item_id`, `field`, `suggestion`, `documentation_url`, and `schema_version`
  alongside the v1.0 fields. `suggestion` and `documentation_url` are resolved
  from the rule catalog, so remediation text for a rule lives in one place.
  Contract defined in `pmo-config/diagnostics-schema.json` and documented in
  `docs/reference/diagnostics-contract.md`.
- **Rule reference pages** under `docs/rules/`, one per handoff rule. Each states
  what is checked, why it blocks, **what the validator deliberately does not
  decide**, and how to fix it.
- **Three-minute demo.** `demo/broken-project` and `demo/fixed-project`, driven
  by `scripts/demo.ps1` / `make demo` / `node cli/axiom.mjs demo`. Two synthetic
  projects that both pass every 1.0 gate; one of them cannot be built on Monday
  morning. Runs in seconds and every line is real validator output.
- **Thin local CLI** (`cli/axiom.mjs`): `demo`, `check`, `doctor`, `validate`,
  `handoff`, `init`. Contains zero validation logic -- it locates a PowerShell
  host, forwards arguments, and preserves stdout, stderr, and exit codes.
  Honours `AXIOM_PWSH`, and reports a missing PowerShell host with remediation
  rather than skipping the check.
- **Project generator options**: `new-project.ps1 -IncludeHandoff -Target
  <demo|pilot|production|internal> -HorizonDays <n>`. Default behaviour is
  unchanged. The generated scaffold deliberately **fails** the Handoff gate
  until it is filled in; a generator that emitted a passing handoff would be
  manufacturing evidence.
- **Doctor checks** `DOCTOR-008` (every fail/warn rule carries a suggestion) and
  `DOCTOR-009` (every rule documentation path resolves, so a diagnostic can
  never advertise a dead link).
- **Worked example** `examples/HANDOFF-DEMO`: a Standard demo handoff that
  passes every deterministic check and still reports "ready to build, not ready
  to demo".
- **Docs**: `docs/concepts/handoff-readiness.md`,
  `docs/guides/three-day-demo-handoff.md`, `docs/guides/artifact-map.md`,
  `docs/reference/diagnostics-contract.md`, `docs/rules/`.
- **Tests**: 33 new handoff fixtures (positive and negative, each asserting a
  specific rule id and level), diagnostics contract tests, handoff assessment
  tests, demo smoke test, CLI tests, a Handoff end-to-end run, and six new
  config-mutation cases proving the handoff policy is genuinely config-driven.
- **Roadmap**: `Milestone 2.5 - Engineering Handoff Readiness`, with the
  dependency chain `1 -> 2 -> 2.5 -> 3 -> 4 -> 5`. Milestones 6 to 8 keep their
  original intent.
- **Experimental Linux CI leg** running the full suite under `pwsh`, marked
  non-blocking. It exists to produce evidence for the cross-platform claim
  rather than assertions about it.

### Fixed

- **Test runners could not run on PowerShell 7.** Every child invocation was
  hardcoded to `powershell`, which does not resolve outside Windows PowerShell
  5.1, so the entire fixture suite reported `PASS=0 FAIL=95` on any other host
  for reasons unrelated to the validator. Added `scripts/lib/pwsh-host.ps1`,
  which resolves `AXIOM_PWSH`, then the running host's own executable, then
  `pwsh` / `powershell` / `powershell.exe`.
- **A count rendered as empty in a diagnostic message.** `Where-Object` results
  were used without `@()`, so a pipeline matching exactly one row returned a
  bare object whose `.Count` rendered as nothing: `" requirement line(s) may be
  missing source_ref"`. Fixed in `source-validator.ps1`, `workitem-validator.ps1`,
  and `pmo-doctor.ps1`. Two golden masters had recorded the defective message and
  were corrected.
- **Generated dates used the wrong calendar.** `Get-Date -Format` follows the
  current culture, so on a machine with a Thai locale every generated project
  was dated in the Buddhist year (`2569-07-26`). `scripts/new-project.ps1`,
  `scripts/update-source-snapshot.ps1`, and the E2E filler now format with
  `InvariantCulture`.
- **Golden masters were host-specific.** UTF-8 BOM, JSON indentation, numeric
  character escapes, and path separators all differ between PowerShell hosts, so
  `-VerifyGolden` reported all 90 cases as mismatched whenever the verifying
  host differed from the capturing one. `scripts/lib/golden-normalizer.ps1`
  compares canonically; rule ids, levels, blocking flags, messages, counters, and
  exit codes are all still compared exactly. Golden files are now stored in that
  canonical form, so a capture on any host produces the same bytes.
- **`axiom handoff --json` did not emit JSON.** It streamed two JSON documents
  with human-readable labels between them, which no parser accepts despite
  `--json` being advertised. The two steps are now merged into a single
  versioned envelope, `{schema_version, gate, assessment}`.
- **The CLI truncated large JSON output at 8 KB.** `process.exit()` tears the
  process down before an asynchronous pipe write drains, so the envelope looked
  correct in a terminal (a TTY flushes synchronously) and failed to parse under
  `| jq`. The CLI now sets `process.exitCode` and lets Node exit naturally.
- **A template placeholder regex could not match on a Windows checkout.**
  `.gitattributes` marks `*.md` as text, so a Windows checkout gets CRLF, and
  .NET's `(?m)$` matches only immediately before `\n` -- never before the `\r`
  of a `\r\n` pair. The E2E handoff filler's `(?m)^<[^>\r\n]+>$` therefore
  matched nothing on Windows: every prose placeholder survived and the
  generated project failed its own Handoff gate. Reproduced by converting the
  repository to CRLF, confirmed with a negative control, and covered by
  `tests/helpers/line-ending-tests.ps1`, which asserts that regexes, digests,
  and golden comparison behave identically under both line endings.
- **Freshness digests and diagnostic ordering were culture-dependent.**
  `Sort-Object` compares strings using the current culture, and it was used
  both inside the review-input digest and in diagnostics that golden masters
  compare byte-for-byte. Switching to ordinal changed the digest value, which
  proves the two orderings genuinely differed -- a review recorded on one
  machine could have read as stale on another. `scripts/lib/ordinal-sort.ps1`
  now backs every sort whose output reaches a digest or a diagnostic.
- **A stale review still printed "is current".** The freshness WARN and the
  summary PASS were emitted independently, so a stale review produced both.
- **The missing-PowerShell CLI test assumed POSIX.** It emptied `PATH` to hide
  the host, which does not work on Windows: `CreateProcess` searches the system
  directory whatever `PATH` says, so `powershell.exe` is still found and the
  assertion tested the harness rather than the CLI. The cross-platform case now
  runs through `AXIOM_PWSH`, and the `PATH` technique is skipped on Windows
  with a printed reason. An unreachable `AXIOM_PWSH` now prints the same
  remediation as a missing host.
- **An empty `AllowedSecondaryRules` disabled the check it was meant to
  tighten.** `@()` is falsy in PowerShell, so a fixture declaring "this must
  fire nothing else" asserted nothing at all. The runner now tests for key
  presence, and every handoff negative fixture genuinely isolates its rule.
- **The release helper suggested the previous release's tag.**
  `scripts/prepare-public-release.ps1` hardcoded `v1.0.0`; it now derives the
  tag and commit message from `VERSION`. A helper that names a stale version
  reads as authoritative, and the version it prints is the one that gets typed.
- **A vague privacy declaration bypassed `HANDOFF-011`.** Anything that was not
  a recognised "yes" was treated as "no", so a `Contains Sensitive Data` cell
  reading `maybe` skipped the classification requirement entirely. An
  unrecognised value is now an *undeclared* classification and fails. The
  validator still never decides what is sensitive — it insists the author does.
- **A blocked demo could still score 100/100.** Open actions blocked a stage
  verdict without costing score, so the report printed a perfect number
  directly above `Ready to Demo: NO`. Open actions now cost points in the
  dimension their blocking point belongs to.
- **Human-only closure rested on a self-declared `reviewer_kind`.** Writing
  `"human"` in the review was enough to close a privacy finding. Closure under
  a human-only lens now requires a `DEC-###` that exists in `decision-log.md`
  with a named decider. This makes the closure traceable to a governed
  artifact, not provably human — a limit now stated in the release notes rather
  than implied away.

### Changed

- `pmo-config/policy.json` gains `approval_checkpoints`, replacing the hardcoded
  gate-to-approval mapping in `source-validator.ps1`. This is how the Handoff
  gate reuses `Design Ready` without a code change.
- `pmo-config/artifact-policy.json` gains a `Handoff` column per mode. Handoff
  artifacts are reported only when the matrix asks for them, so runs at other
  gates are unchanged.
- Text output attaches an indented `where:` / `fix:` / `docs:` block to WARN and
  FAIL rows only. A clean run reads exactly as it did in 1.0.

### Compatibility

- The v1.0 diagnostic fields `level`, `rule_id`, `message`, and `blocking` keep
  their names, meanings, and relative order. A v1.0 consumer reads v1.1 output
  without changes.
- New fields are always present and `null` when they do not apply -- never
  omitted, never `""`.
- Exit codes are unchanged: `0` pass, `1` fail, `2` blocking warning under
  `-FailOnWarning`. The CLI adds `127` for a missing PowerShell host and `64`
  for a usage error, neither of which the validator itself emits.
- Golden masters were intentionally re-captured for the additive diagnostic
  fields. The diff was reviewed group by group and is additive only: no existing
  field changed name, value, or position.
- **Migration**: none required. To adopt the gate, add `HANDOFF.md` and (for
  Standard/Strict) `DESIGN/BUILD-SPEC.md`, then run `-Gate Handoff`.

## 1.0.0 - 2026-07-14

First public release, published as **Axiom-PMO — The Anti-Hallucination
Framework for AI Agents**. This release rebrands the project from its private
working name and prepares it for open-source use. The deterministic validation
engine, anti-hallucination controls, risk-adaptive modes, and test suite are
unchanged in behavior; every enforced check that passed before this release
still passes.

### Added

- **Public identity as a governance control plane.** Axiom-PMO is the source of
  truth for requirements, scope, risk, evidence policy, and release authority,
  designed to operate alongside AI execution frameworks rather than replacing
  them.
- **MIT `LICENSE`.**
- **`CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, issue templates, and a pull-request
  template** that encode governance-preserving contribution expectations.
- **Case study** (`case-studies/unauthorized-git-mutation.md`) — a sanitized
  account of the unauthorized-git-mutation incident that motivated the git
  authority controls.
- **Interoperability documentation** (`docs/integrations/`) describing a Level
  0–4 coexistence model and an authority-precedence order, plus an
  **experimental** generic execution-contract and result schema under
  `integrations/superpowers/`.
- **Concept, architecture, governance, and tutorial docs** under `docs/`.
- **Cross-platform helpers**: a `Makefile` and `scripts/check.sh` /
  `scripts/check.cmd` wrappers around the PowerShell reference implementation,
  plus a non-destructive `scripts/prepare-public-release.ps1`.
- Removed historical working archives and slide-generation source folders from
  the public tree; the release keeps the final user-facing deck and current
  public evidence only.

### Changed

- Product identity, README, and user-facing script/diagram labels now read
  **Axiom-PMO**. The `pmo-` domain prefix on skills, config, scripts, and rule
  ids is retained as a stable, generic identifier.
- **Example golden snapshots are checkout-portable.**
  `tests/golden/capture-examples.ps1` normalizes the resolved repository path to
  a `<REPO_ROOT>` placeholder, and the example snapshots verify on any clone.
- Internal remediation reports were shortened to public-facing changes rather
  than private development diary entries.

## 0.5.1 - 2026-07-13

### Fixed

- Closed the Lite Release work-item bypass by requiring `DELIVERY.md` through
  the same artifact matrix used by other modes.
- Required Release Test Summary rows to be `passed` or explicitly skipped with a
  reason, and required test evidence to resolve.
- Added full-chain RTM validation for `source_ref`, `design_ref`, status, and
  typed evidence.
- Required Lite approval and work-item evidence to resolve through the typed
  reference resolver instead of accepting arbitrary free text.
- Implemented GitHub Issues as a task source: `Task source: github` with a named
  `github_repository` can waive `DELIVERY.md` at Release with a non-blocking
  `TASK-003` note.
- Added rule-catalog completeness checking (`DOCTOR-007`).
- Expanded CI to run golden-master verification and fault-injection propagation.
- Normalized golden-master output paths to `<REPO_ROOT>` so snapshots verify
  across local and hosted checkouts.
- Added a scoped synthetic fixture exception so sensitive-source fixture coverage
  remains stable in clean CI checkouts.
- Cleaned real PSScriptAnalyzer findings without changing validator output.

### Historical Notes

- Historical working reports were removed from the public tree after the
  public-facing release notes and case study were retained.

## 0.5.0 - 2026-07-12

### Added

- Release work-item completion enforcement: every in-scope item must be done,
  reviewed, and backed by resolvable test/evidence proof.
- Structured `QA / Security Review` table in `RELEASE.md`.
- Lite rollback waiver support for documentation, content, and config-only
  changes that meet policy allowlists.
- Modular validator implementation under `scripts/lib/*.ps1`.
- Golden-master baseline and generator-to-Release end-to-end tests for Lite,
  Standard, and Strict projects.
- Config mutation tests for runtime JSON policy files.
- `pmo-config/context-map.json` and `schema_version` checks for all
  `pmo-config/*.json` files.

### Fixed

- `new-project.ps1 -Mode Lite` no longer generates Standard-mode design
  references for a Lite project.
- `<PROJECT-CODE>` substitution now reaches generated release, RAID, decision,
  and RTM artifacts.
- `RTM.json` required/optional behavior now goes through the mode/gate artifact
  matrix.
- Fixed PowerShell null/array-count edge cases that could produce phantom
  validation failures.
- `new-project.ps1` now propagates Draft-validation exit codes.

### Changed

- Runtime config moved fully to JSON.
- Branch-protection constraints were recorded as a platform limitation during
  the historical development period; human review and explicit per-push
  confirmation remained required.

## 0.4.0 - 2026-07-10

### Added

- Runtime config source-of-truth checks for policy, skill manifest, and
  validation-rule catalog.
- YAML frontmatter on all seven active skills.
- Markdown table column validation (`TABLE-001`).
- Source-folder ownership behavior: placeholders and broken links inside
  user-owned source inputs no longer block release as governed artifacts.
- Mode x gate severity behavior for Lite, Standard, and Strict.
- Reference integrity checks for requirement, design, decision, delivery, and RTM
  references.
- Deterministic end-to-end tests and first CI workflow for the framework.

### Fixed

- Lite Release now requires valid release approval evidence.
- HTML wireframes no longer trigger placeholder false positives.
- `run-all-checks.ps1` now propagates child-script failures.
- Sensitive `.gitignore` pattern checks work across CRLF and LF line endings.

### Changed

- Removed legacy and optional skills from the active public tree.
- Removed superseded YAML runtime config files.
- Removed superseded working reports from the active public tree.
- Preserved the process-violation record as a historical governance lesson.

## 0.3.0-lite-ai-guardrails - 2026-07-10

### Added

- Added version marker in `VERSION`.
- Added Lite, Standard, and Strict examples.
- Added validation fixture runner and negative fixtures for missing project
  files, missing source references, fake approvals, open blockers, missing
  rollback notes, and broken local links.

### Changed

- Hardened release validation so fake approvals, missing source references, and
  missing evidence status fail at release gate.
- Added task source-of-truth fields and work-item mode governance fields.
- Updated framework doctor checks for validation command permissions.

## 0.2.0-lite-ai-workflow - 2026-07-10

### Added

- Added `CONTEXT-ROUTER.md` and `pmo-config/context-map.yaml`.
- Added lightweight project templates.
- Added sample project `examples/P01-DEMO`.
- Added `scripts/validate-project.ps1` and `scripts/pmo-doctor.ps1`.

### Changed

- Reworked `AGENTS.md` into a shorter behavioral guide.
- Reworked `CLAUDE.md` into an intent and mode router.
- Removed fake echo hooks from Claude settings.

## 0.1.0-baseline

### Notes

- Baseline PMO template before Lite and AI guardrails hardening.
