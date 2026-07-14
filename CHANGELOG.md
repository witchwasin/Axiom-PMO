# Changelog

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
