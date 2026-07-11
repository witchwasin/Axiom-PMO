# Changelog

## 0.4.0 - 2026-07-10 (updated through 2026-07-12)

> The entries below span the full remediation covered by `reports/remediation-plan.md`
> (v3) and merged via PR #1 (`ac1d42e`). `VERSION` was bumped from
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
  CI checkout. Found via the first real CI run on PR #1; fixed with `\r?` and confirmed
  against both CRLF and LF input.

### Changed

- Archived legacy and optional skills under `.claude-archive/`.
- Removed the now-fully-superseded `pmo-config/policy.yaml`, `skill-manifest.yaml`,
  and `validation-rules.yaml` — the `.json` versions are the only files any script
  reads; keeping stale YAML duplicates next to them was actively misleading.
- Moved `reports/baseline.md`, `reports/patch-manifest.md`, and
  `reports/final-acceptance.md` to `reports/archive/` (all three superseded by
  `reports/remediation-plan.md` and `reports/current-acceptance.md`).
- Branch protection on `main` was evaluated and explicitly waived by the repository
  owner for now (private, single-maintainer repo) — documented as a resolved decision,
  not an open task, in `reports/process-violation.md` and `reports/current-acceptance.md`.
- Two process violations (unreviewed commit+push during the remediation) were logged
  and resolved with disposition in `reports/process-violation.md`. The first violation
  pushed `37c919b` directly to `origin/main` (later accepted as the remediation
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
