# Changelog

## 1.0.0 - 2026-07-14

First public release, published as **Axiom-PMO — The Anti-Hallucination
Framework for AI Agents**. This release rebrands the project from its private
working name and prepares it for open-source use. The deterministic validation
engine, anti-hallucination controls, risk-adaptive modes, and test suite are
unchanged in behavior; every enforced check that passed before this release
still passes.

### Added

- **Public identity as a governance control plane.** New positioning: Axiom-PMO
  is the source of truth for requirements, scope, risk, evidence policy, and
  release authority, designed to operate *alongside* AI execution frameworks
  (Superpowers, BMAD, spec-kit, OpenSpec, custom Claude Code setups) rather than
  replacing them.
- **MIT `LICENSE`.**
- **`CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, issue templates, and a pull-request
  template** that encode the "do not weaken governance" and "disclose
  AI-assisted changes" expectations.
- **Case study** (`case-studies/unauthorized-git-mutation.md`) — a sanitized
  account of the unauthorized-git-mutation incident that motivated the git
  authority controls, kept as a regression lesson.
- **Interoperability documentation** (`docs/integrations/`) describing a Level
  0–4 coexistence model and an authority-precedence order, plus an
  **experimental** generic execution-contract and result schema under
  `integrations/superpowers/` (not wired into the validator runtime).
- **Concept, architecture, governance, and tutorial docs** under `docs/`.
- **Cross-platform helpers**: a `Makefile` and `scripts/check.sh` /
  `scripts/check.cmd` wrappers around the PowerShell reference implementation
  (Linux/macOS via `pwsh` is labeled experimental), plus a non-destructive
  `scripts/prepare-public-release.ps1`.

### Changed

- Product identity, README, and user-facing script/diagram labels now read
  **Axiom-PMO**. The `pmo-` domain prefix on skills, config, scripts, and rule
  ids is retained as a stable, generic identifier.
- **Example golden snapshots are now checkout-portable.**
  `tests/golden/capture-examples.ps1` normalizes the resolved repository path to
  a `<REPO_ROOT>` placeholder (mirroring `run-validation-tests.ps1`), and the
  three example snapshots were regenerated so they verify on any clone. No
  validator rule or severity changed.
- Internal remediation reports were sanitized and archived; the changelog
  history below was scrubbed of private repository identifiers and internal
  references.

## 0.5.1 - 2026-07-13

> Round 3 final hardening (`reports/final-hardening-plan.md`), triggered by an
> independent an independent reviewer review of merged `0.5.0` scoring 8.4/10 with 5 concrete,
> reproduced validator bypasses. Merged to `main` via a pull request. See
> `reports/current-acceptance.md` for the close-out report.

### Fixed

- **Lite Release work-item bypass**: `PROJECT.md` merely containing the words "work
  item" satisfied the Lite Release requirement, leaving `DELIVERY.md` optional and
  silently skipping every release-completion check. `DELIVERY.md` is now required at
  Lite Release via the same artifact matrix every other mode uses.
- **Unverified Test Summary**: a Release could ship with every Test Summary row still
  `pending` and no evidence. New `TEST-RESULT-001` (must be `passed`, or explicitly
  skipped with a reason) and `TEST-EVIDENCE-002` (evidence must resolve).
- **RTM full-chain gaps**: `source_ref`, `design_ref`, and `status` were never checked,
  and evidence accepted any text that didn't look like a malformed `DEC-###`. New
  `RTM-008/009/010`; `RTM-005` now uses the typed reference resolver.
- **Untyped Lite evidence**: Lite approval and work-item evidence accepted any non-empty
  free text ("approved-by-chat"). Both now resolve through the typed reference
  resolver; unresolvable evidence is WARN_BLOCKING (blocks `-FailOnWarning`) rather than
  silently accepted.
- **GitHub Issues task source**: documented in `AGENTS.md` as an alternative to
  `DELIVERY.md`, but never implemented. `Task source: github` with a named
  `github_repository` now waives `DELIVERY.md` at Release with a non-blocking
  `TASK-003` note; a repo-less `github` declaration still requires `DELIVERY.md`.
- **Rule catalog drift**: `validation-rules.json` was missing roughly 20 rule ids the
  scripts actually emit. New `DOCTOR-007` scans every emitter and fails on any rule id
  missing from the catalog, or any catalog entry never emitted.
- **CI gaps**: `pmo-checks.yml` ran the check suite but never verified the golden master
  or exercised fault injection. Both now run on every push/PR.
- **Golden-master not portable across checkouts**: the validator's JSON output embedded
  the absolute project path, which differs between a local clone and the GitHub Actions
  runner (`<ci-path>`), so all 86 golden cases mismatched on CI. The path is now
  normalized to a `<REPO_ROOT>` placeholder before capture/compare (`<commit>`).
- **Sensitive-source fixture dropped on CI**: `tests/fixtures/valid-source-others-and-
  sensitive/source/Quotation.xlsx` (a synthetic placeholder) was excluded by the
  `**/*Quotation*.xlsx` sensitive-file `.gitignore` pattern, so it was absent on CI and
  the `SENSITIVE-001` golden line disappeared. Added a scoped negation for that one
  fixture path and tracked the file (`<commit>`).
- **PSScriptAnalyzer real findings**: ran PSScriptAnalyzer (149 findings, 0 errors) and
  fixed the 10 genuine ones — auto-variable shadowing (`$args`/`$matches` renamed) and
  dead function parameters (`Test-DeliveryWorkItems` `$Mode`/`$ProjectText`,
  `Test-RequiredArtifacts` `$Project`). The rest are by-design (Write-Host console output,
  the `Add-Result` positional DSL) or false positives (`$script:`-scoped vars the
  per-file analyzer cannot see, a delegate-required parameter).

### Known limitations

- **Branch protection** was unavailable on the repository at this point (403 on
  the protection API) — a platform constraint, documented and accepted.
- **LICENSE** remains deferred.

## 0.5.0 - 2026-07-12

> Round 2 remediation, `reports/upgrade-plan-9plus.md` (v2 unified). Baseline honest
> score 8.3/10 (independent verdict on the merged 0.4.0 state). Worked on branch
> `remediation/9plus-v2` in two parallel tracks — Track A (validator/tests) and Track B
> (context map + skills + governance decisions, worktree `remediation/9plus-v2-codex`)
> — merged at Phase 8. See `reports/upgrade-manifest.md` for phase-by-phase status and
> `reports/current-acceptance.md` for the close-out report.

### Added

- Work-item completion enforcement at Release: every in-scope item must be `Done`,
  reviewed, and have resolvable test/evidence proof (`RELEASE-STATUS-001`,
  `REVIEW-001`, `TEST-EVIDENCE-001`). The existing "Release Scope" table is the
  exclusion mechanism for items intentionally left out of a release
  (`RELEASE-SCOPE-001`), replacing silent omission.
- Structured `QA / Security Review` table in `RELEASE.md`, replacing a regex that
  only checked whether the word "qa" appeared anywhere in `DELIVERY.md`
  (`QA-REVIEW-001`, `SECURITY-REVIEW-001`).
- Lite rollback waiver (`rollback_required: false` + `change_type` + `reason` +
  `approver`) as an alternative to a full rollback table, valid only for change types
  on the `pmo-config/policy.json` allowlist.
- `scripts/lib/*.ps1` — `validate-project.ps1` split from a 1055-line monolith into 11
  focused modules (config-loader, markdown-table-parser, reference-resolver,
  result-writer, mode-resolver, artifact-policy, approval-validator, source-validator,
  workitem-validator, rtm-validator, release-validator). The main script is now a
  ~120-line orchestrator.
- `tests/golden/` — byte-for-byte golden-master baseline (74 cases) proving the
  modular refactor changed zero observable validator behavior beyond two documented
  bug fixes (see Fixed).
- Generator-to-Release E2E tests (`tests/e2e/{lite,standard,strict}.ps1`) now validate
  real `new-project.ps1` output filled in deterministically
  (`tests/e2e/lib/fill-project.ps1`), instead of copying an example project's files
  over the generator's own output — the blind spot that hid the RTM.yaml vs RTM.json
  schema mismatch in Round 1.
- 4th config-mutation scenario (`artifact-policy.json`) and a schema_version mutation
  scenario, wired into `tests/helpers/config-mutation-tests.ps1`.
- 8 new fixtures covering the rules above plus `security-review-pending`,
  `evidence-file-missing`, `malformed-external-evidence`, and
  `source-broken-link-non-blocking` (positive).
- `pmo-config/context-map.json` (converted from `context-map.yaml`), Mode x Intent
  structure, fixing the standing Lite `qa_release` conflict (`PROJECT.md` required,
  `DELIVERY.md` conditional, `RELEASE.md` optional).
- `schema_version` on every `pmo-config/*.json` file, checked by a new `DOCTOR-006`
  rule (not just present once at authoring time — proven by a mutation test).
- `DOCTOR-006` (schema_version) rule.

### Fixed

- **`new-project.ps1 -Mode Lite`** generated a work item defaulting to `Mode: Standard`
  with `Design Ref: DESIGN/FLOW.puml` (Lite never creates `DESIGN/`), silently
  escalating every fresh Lite project's effective mode to Standard and failing
  `REF-001` on a design file that was never created.
- `<PROJECT-CODE>` was never substituted in generated `RELEASE.md` / `RAID-log.md` /
  `decision-log.md` / `RTM.json` (only `PROJECT.md`/`DELIVERY.md` got it).
- `RTM.json`'s required/optional status was hardcoded Strict-only/always-optional in
  the validator instead of going through the Mode x Gate artifact matrix like every
  other artifact — found by the new artifact-policy config-mutation test.
- Two PowerShell `@($x).Count` array-wrapping bugs found during the modular refactor:
  a `$null` value bound through a function parameter reports `Count=1` instead of 0,
  and so does a never-initialized script variable — both different from a plain
  script-level `$null` (`Count=0`). One was already live in this round's own Release
  work-item-completion code, silently producing phantom failures with blank IDs
  whenever `DELIVERY.md` was missing entirely.
- `DOCTOR-004`'s legacy-pattern scan flagged skills that correctly *prohibit*
  "log every minor AI action" as if they contained the old over-logging anti-pattern
  instruction itself; now negation-aware.
- `new-project.ps1` now propagates its Draft-validation exit code instead of always
  exiting 0.

### Governance

- Branch protection: confirmed 403 on the repository (platform
  constraint, not a policy waiver). Recorded as option (C): PR workflow + CI + explicit
  per-push human confirmation are the compensating controls.
- LICENSE: deferred adding one for now (2026-07-12) — recorded as an
  intentional decision, not an omission.
- P5.3 (PSScriptAnalyzer static analysis) explicitly skipped by decision
  (2026-07-12) — not installed on this machine.

## 0.4.0 - 2026-07-10 (updated through 2026-07-12)

> The entries below span the full remediation covered by `reports/remediation-plan.md`
> (v3) and merged via a pull request. `VERSION` was bumped from
> `0.4.0-stable-candidate` to `0.4.0` on 2026-07-12, once this state was independently
> verified end-to-end and merged rather than self-reported. See
> `reports/current-acceptance.md` for the full close-out report and score (`9.03/10.00`).

### Added

- Runtime config converted to JSON (`pmo-config/policy.json`, `skill-manifest.json`,
  `validation-rules.json`) and proven — not just claimed — to be the real source of
  truth for `validate-project.ps1` / `pmo-doctor.ps1` via an automated mutation-test
  helper (`tests/helpers/config-mutation-tests.ps1`), wired into `run-all-checks.ps1`.
- YAML frontmatter added to all 7 active skills (`DOCTOR-SKILL-001`), so skill
  descriptions are discoverable instead of falling back to the folder name.
- `TABLE-001` catches markdown table column mismatches; canonical approval/work-item
  table schema applied consistently across templates, examples, and fixtures.
- Governed-vs-user-source file segregation: placeholder/link checks (`PLACEHOLDER-001`,
  `LINK-001`) now skip `source/`, `MOM/`, `REQ/`, `Transcript/` — a customer `TODO` in a
  meeting note no longer blocks Release. Broken links inside those folders are reported
  as `SOURCE-LINK-001` (info/warn), never a hard failure.
- Mode × Gate severity matrix: Design approval is conditional for Lite; Lite Release
  requires `DELIVERY.md` or a `PROJECT.md` Work Item section, with a lightweight (not
  `N/A`) `not_required` sentinel for fields that don't apply.
- Reference integrity checks that confirm IDs actually resolve (requirement, design,
  decision, delivery, RTM), not just that they look like the right shape.
- `RTM.yaml` and structured rollback tables are parsed and validated row-by-row.
- Deterministic end-to-end tests for Lite/Standard/Strict (`tests/e2e/`).
- `.github/workflows/pmo-checks.yml` — first real CI for this repo.
- `reports/remediation-plan.md`, `reports/executor-brief.md`,
  `reports/process-violation.md`, `reports/current-acceptance.md`.

### Fixed

- Lite Release could previously pass with zero release approval at all (the
  `Release Approved` check was skipped entirely for Lite mode) — fixed to require a
  valid approval row with lightweight evidence (e.g. `ISSUE-123`), while staying
  otherwise lightweight (no `RELEASE.md`, QA, RTM, or RAID required).
- HTML placeholder false-positive: `DESIGN/WIREFRAME.html` containing normal tags like
  `<div>` no longer trips the placeholder scanner.
- `run-all-checks.ps1` now propagates child-script exit codes for real (previously a
  failing check could still leave the aggregator exiting 0).
- `PERMISSION-007` (`.gitignore` sensitive-pattern check) used a `(?m)^pattern$` regex
  that silently failed on CRLF line endings — invisible locally (mixed line endings in
  the working copy) but caused every required pattern to report as missing on a clean
  CI checkout. Found via the first real CI run on a pull request; fixed with `\r?` and confirmed
  against both CRLF and LF input.

### Changed

- Archived legacy and optional skills under `.claude-archive/`.
- Removed the now-fully-superseded `pmo-config/policy.yaml`, `skill-manifest.yaml`,
  and `validation-rules.yaml` — the `.json` versions are the only files any script
  reads; keeping stale YAML duplicates next to them was actively misleading.
- Moved `reports/baseline.md`, `reports/patch-manifest.md`, and
  `reports/final-acceptance.md` to `reports/archive/` (all three superseded by
  `reports/remediation-plan.md` and `reports/current-acceptance.md`).
- Branch protection on `main` was evaluated and explicitly waived for now
  (a single-maintainer repository) — documented as a resolved decision,
  not an open task, in `reports/archive/process-violation.md` and
  `reports/archive/current-acceptance.md`.
- Two process violations (unreviewed commit+push during the remediation) were logged
  and resolved with disposition in `reports/process-violation.md`. The first violation
  pushed `<commit>` directly to `origin/main` (later accepted as the remediation
  baseline); the second only affected the `remediation/9plus` working branch and never
  touched `main`.

- Added active skill runtime with 7 skills: `pmo-intake`, `pmo-design`, `pmo-delivery`, `pmo-build-review`, `pmo-quality-release`, `pmo-governance`, and `pmo-git-safety`.
- Added `pmo-config/skill-manifest.json`.
- Added `pmo-config/policy.json` for shared enums and stable workflow policy.
- Added `pmo-config/validation-rules.json` as a central rule catalog for validator and doctor output.
- Added baseline and patch manifest reports under `reports/`.
- Added full validation matrix coverage with 7 positive cases and 25 negative fixture cases.

### Changed

- Archived legacy and optional skills under `.claude-archive/`.
- Updated router and behavioral guide to load only the 7 active PMO skills by default.
- Hardened `TASK-002` task source conflict detection and Strict release guardrail validation.

## 0.3.0-lite-ai-guardrails - 2026-07-10

### Added

- Added version marker in `VERSION`.
- Added Lite, Standard, and Strict examples to show the intended artifact weight for each mode.
- Added validation fixture runner and negative fixtures for missing project files, missing source references, fake approvals, open blockers, missing rollback notes, and broken local links.

### Changed

- Hardened release validation so fake approvals, missing source references, and missing evidence status fail at release gate.
- Added task source-of-truth fields and work item mode governance fields.
- Updated framework doctor checks for validation command permissions.

### Notes

- This version is suitable for small-team pilot use and close to stable for Standard-mode work.
- Strict-mode use should still include human security/privacy review when sensitive data, payment, authentication, authorization, or external integrations are involved.

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

- Baseline PMO template before Lite + AI Guardrails hardening.
