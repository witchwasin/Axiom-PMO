# Changelog

## Unreleased

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

### Fixed

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

### Changed

- Product identity, README, and user-facing script/diagram labels now read
  **Axiom-PMO**. The `pmo-` domain prefix on skills, config, scripts, and rule
  ids is retained as a stable, generic identifier.
- **Example golden snapshots are checkout-portable.**
  `tests/golden/capture-examples.ps1` normalizes the resolved repository path to
  a `<REPO_ROOT>` placeholder, and the example snapshots verify on any clone.
- Internal remediation reports were sanitized and archived; historical release
  notes below were shortened to public-facing changes rather than private
  development diary entries.

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

- The close-out report is archived at
  `reports/archive/acceptance-0.5.1.md`.
- The CI fixture incident is archived at
  `reports/archive/ci-golden-fixture-postmortem.md`.

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

- Archived legacy and optional skills under `.claude-archive/`.
- Removed superseded YAML runtime config files.
- Moved superseded reports under `reports/archive/`.
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
