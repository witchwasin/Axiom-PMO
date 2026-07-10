# Changelog

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
