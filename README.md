# PMO Template Personal

Lightweight PMO operating template for small teams using AI.

Current version: `0.4.0-stable-candidate`

## What It Does

This repo turns project source into a controlled delivery flow:

Source -> Requirement -> Design -> Delivery -> Build Review -> QA -> Release

It supports three modes:

- `Lite`: small, low-risk fixes
- `Standard`: normal feature delivery
- `Strict`: payment, PII, authentication, permission, integration, compliance, migration, or production-risk work

## Start In 5 Minutes

1. Pick the closest example:
   - `examples/LITE-BUGFIX`
   - `examples/STANDARD-FEATURE`
   - `examples/STRICT-HIGH-RISK`
2. Create a project:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/new-project.ps1 -ProjectCode P02-MYPROJECT -Mode Standard
```

3. Put source files under `source/`.
4. Fill `PROJECT.md` and `DELIVERY.md`.
5. Validate:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-all-checks.ps1
```

## Core Files

- `AGENTS.md`: shared AI behavior rules
- `CLAUDE.md`: intent router
- `CONTEXT-ROUTER.md`: context loading rules
- `pmo-config/policy.yaml`: central enums and policy
- `pmo-config/skill-manifest.yaml`: active skill runtime
- `scripts/validate-project.ps1`: project validator
- `scripts/pmo-doctor.ps1`: framework doctor

## Active Skills

Only these 7 skills are active by default:

- `pmo-intake`
- `pmo-design`
- `pmo-delivery`
- `pmo-build-review`
- `pmo-quality-release`
- `pmo-governance`
- `pmo-git-safety`

Archived skills live under `.claude-archive/` and are reference-only unless explicitly restored.

