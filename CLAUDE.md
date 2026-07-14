@AGENTS.md

# Axiom-PMO - Entry Point & Router

> Behavioral rules live in `AGENTS.md`.
> Context loading rules live in `CONTEXT-ROUTER.md`.
> This file routes user intent to the smallest useful workflow and skill set.

---

## Quick Start

### New Project

1. Copy `templates/` into a new folder such as `projects/P01-ABC/` or use the closest example: `examples/LITE-BUGFIX`, `examples/STANDARD-FEATURE`, or `examples/STRICT-HIGH-RISK`.
2. Put source files under `source/MOM/`, `source/Transcript/`, and `source/REQ/`.
3. Fill `PROJECT.md` from source.
4. Choose a default mode using `docs/process/`, then choose mode per work item in `DELIVERY.md`.
5. Run validation before release:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath examples/P01-DEMO -Mode Standard -Gate Release -FailOnWarning
powershell -ExecutionPolicy Bypass -File scripts/pmo-doctor.ps1
powershell -ExecutionPolicy Bypass -File scripts/run-validation-tests.ps1
```

### Existing Legacy Project

Legacy folders are supported. Map them this way:

| Legacy | Lightweight Equivalent |
|---|---|
| `MOM/`, `REQ/`, `Others/` | `source/` |
| `UserFlow/`, `SystemFlow/`, `UseCase/` | `DESIGN/` |
| `Wireframe/` | `DESIGN/WIREFRAME.*` |
| `TaskBreakdown/` | `DELIVERY.md` or GitHub Issues |

---

## Intent Router

| User Intent | Mode Default | Read First | Load Skills |
|---|---|---|---|
| "เริ่ม project", intake, analyze MOM/REQ | Standard | `CONTEXT-ROUTER.md`, source, `PROJECT.md` | `pmo-intake` |
| "สรุป scope", "ถาม requirement" | Lite | `PROJECT.md`, source only if needed | `pmo-intake`, `pmo-governance` |
| "ทำ flow", "system flow", "activity diagram" | Standard | `PROJECT.md`, `DESIGN/` | `pmo-design` |
| "ทำ use case" | Standard | `PROJECT.md`, `DESIGN/` | `pmo-design` |
| "ทำ wireframe" | Standard | `PROJECT.md`, `DESIGN/FLOW.puml` | `pmo-design` |
| "แตกงาน", "handoff dev" | Standard | `PROJECT.md`, `DESIGN/`, `DELIVERY.md` | `pmo-delivery` |
| "Dev เสร็จแล้ว", "review dev" | Standard | `DELIVERY.md`, relevant design | `pmo-build-review` |
| "QA", "test", "bug" | Standard | `DELIVERY.md`, `RAID-log.md`, `RELEASE.md` | `pmo-quality-release` |
| "release", "deploy", "close" | Strict if production | `RELEASE.md`, `RAID-log.md`, `decision-log.md` | `pmo-quality-release`, `pmo-governance` |
| "commit", "push" | Strict | git status/diff | `pmo-git-safety` |

Risk override: switch a work item to `Strict` when it involves payment, financial calculation, PII, sensitive data, authentication, authorization, permission, irreversible action, external integration, legal/compliance requirement, production data migration, critical infrastructure, or public-sector formal acceptance.

---

## Mode Router

### Lite

Use for small changes or low-risk clarification.
Detailed guide: `docs/process/lite.md`.

Required:
- `PROJECT.md` updated or referenced
- one `DELIVERY.md` item or one GitHub Issue
- Acceptance criteria
- Test note

Skip unless needed:
- Use Case
- Full System Flow
- Wireframe
- Formal release pack

### Standard

Use for normal feature delivery.
Detailed guide: `docs/process/standard.md`.

Required:
- `PROJECT.md`
- `DESIGN/FLOW.puml` if logic or actor flow exists
- `DELIVERY.md` or GitHub Issue
- Test checklist

Optional:
- Wireframe for UI
- Use Case for actor-heavy scope
- ADR for notable technical decision

### Strict

Use for high-risk work.
Detailed guide: `docs/process/strict.md`.

Required:
- Full `source_ref`
- `evidence_status` on every requirement, decision, test, and release claim
- `RAID-log.md`
- `decision-log.md`
- Human verification before final
- Release and rollback notes
- Separate QA or human approval

---

## Core 1-2-3 Mapping

| Core | Packages | Gate |
|---|---|---|
| Core 1 - Discovery & Product Design | Intake & Scope, Flow & UX | Gate 1 Scope Approved, Gate 2 Design Ready |
| Core 2 - Delivery & Engineering | Plan & Handoff, Build | Delivery ready for review |
| Core 3 - Quality & Release | Verify, Release & Close | Gate 3 Release Approved |

---

## Project Registry

Update this when a reusable project/example is added.

| Project Code | Full Name | Folder | Status | Notes |
|---|---|---|---|---|
| P01-DEMO | Demo Intake to Release | `examples/P01-DEMO` | Ready | Synthetic data only |
| LITE-BUGFIX | Lite Bug Fix Example | `examples/LITE-BUGFIX` | Ready | Minimal docs for low-risk change |
| STANDARD-FEATURE | Standard Feature Example | `examples/STANDARD-FEATURE` | Ready | Normal flow, delivery, QA, release |
| STRICT-HIGH-RISK | Strict High-Risk Example | `examples/STRICT-HIGH-RISK` | Ready | Permission/audit example with RTM |

## Active Skill Runtime

The active runtime is limited to the 7 skills in `pmo-config/skill-manifest.json`:

- `pmo-intake`
- `pmo-design`
- `pmo-delivery`
- `pmo-build-review`
- `pmo-quality-release`
- `pmo-governance`
- `pmo-git-safety`

Archived skills under `.claude-archive/` are not loaded by default.

---

## Hook Policy

Fake echo hooks have been removed. Use `scripts/validate-project.ps1` for real validation.
Use `scripts/pmo-doctor.ps1` for framework health and `scripts/run-validation-tests.ps1` for positive/negative validator fixtures.

Suggested validation command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project-folder> -Mode Standard -Gate Release -FailOnWarning
powershell -ExecutionPolicy Bypass -File scripts/pmo-doctor.ps1
powershell -ExecutionPolicy Bypass -File scripts/run-validation-tests.ps1
```

---

## Git Safety

Load `pmo-git-safety` before committing or pushing.

Minimum manual checks:

1. `git status`
2. `git diff --cached` if files are staged
3. Search for secrets: API keys, passwords, tokens
4. Confirm no confidential MOM, transcript, pricing, customer data, or audio files are included
5. Push only after explicit human confirmation
