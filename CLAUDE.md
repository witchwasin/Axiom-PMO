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
5. Run validation before release (replace `<project-folder>` with your project, e.g. `examples/STANDARD-FEATURE`; `examples/P01-DEMO` is intentionally left at `design-ready` and will not pass a Release gate):

```bash
node cli/axiom.mjs validate --project <project-folder> --mode Standard --gate Release --fail-on-warning
node cli/axiom.mjs doctor
node dist/tools/run-ci-suite-cli.js -Suite validation-fixtures -RepoPath .
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
| "visual direction", "creative direction", "art direction", "งานไม่เหมือนทั่วไป", "เลือกแนวทางก่อนทำ UI" | Standard | `PROJECT.md`, existing `DESIGN/VISUAL-DIRECTION.md`, `DESIGN/WIREFRAME.md`, `DESIGN/BRAND/`, `decision-log.md` | `pmo-design` (intent `visual_direction`) |
| "ทำ design system", "อยากเห็นหน้าตาก่อน", "visual sheet", "brand", "logo", "UI kit" | Standard | `PROJECT.md`, `DESIGN/VISUAL-DIRECTION.md`, `DESIGN/WIREFRAME.md`, `decision-log.md` | `pmo-design` (intent `design_system`) |
| "แตกงาน", "handoff dev" | Standard | `PROJECT.md`, `DESIGN/`, `DELIVERY.md` | `pmo-delivery` |
| "พร้อมส่ง dev ยัง", "handoff review", "พร้อม demo ไหม", "review visual proof" | Standard | `PROJECT.md`, `DELIVERY.md`, `HANDOFF.md`, `DESIGN/BUILD-SPEC.md`, conditional visual-review artifacts | `pmo-delivery` |
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

## Handoff Gate

```text
Draft -> Scope -> Design -> Handoff -> Release
```

`Handoff` answers one question: **can a developer start, integrate, and
demonstrate this?** It introduces no new human approval -- it reuses the
existing `Design Ready` approval and checks whether the contract is complete
enough to act on.

Required artifacts (see `pmo-config/artifact-policy.json`):

| Mode | Required at Handoff |
|---|---|
| Lite | `PROJECT.md`, `DELIVERY.md`, `HANDOFF.md` |
| Standard | above plus `DESIGN/`, `DESIGN/BUILD-SPEC.md` |
| Strict | above plus `RAID-log.md`, `decision-log.md` |

When `PROJECT.md` declares `> Spec depth: full` (the default `axiom init`
scaffolds), Standard and Strict additionally require `DESIGN/SRS.md`,
`DESIGN/DATA-DICTIONARY.md`, and `TESTS/TEST-CASES.md`, with Strict also
requiring `DESIGN/DATA-FLOW.md` and a test case for every
`(spec element, category)` pair `pmo-config/depth-policy.json` derives from
the project's own declared complexity. A project without the declaration
defaults to `legacy` and this paragraph does not apply to it. See
`docs/concepts/document-depth.md`.

Two layers, deliberately separate:

1. **Deterministic** (`HANDOFF-001` to `HANDOFF-014`) checks what the artifacts
   declare. It never infers domain meaning -- it will not decide that a photo is
   PII or that a scanner needs HTTPS.
2. **Semantic review** (`pmo-delivery`, intent `handoff_review`) supplies
   judgement and records it in `HANDOFF-REVIEW.json`. That file is **candidate
   evidence, not an approval.**
3. **Visual Proof** applies only when `DESIGN/VISUAL-DIRECTION.md`,
   `DESIGN/DESIGN-SYSTEM.md`, and `DESIGN/DESIGN-SYSTEM.html` all exist. It records a
   named human's review of committed desktop/mobile captures in `DESIGN/VISUAL-REVIEW.json`.
   The check verifies evidence shape and freshness, never aesthetic quality or a new approval.

Readiness is reported per stage, not as one boolean:

```bash
node cli/axiom.mjs validate --project <project> --mode <mode> --gate Handoff
node cli/axiom.mjs handoff --project <project> --mode <mode>
```

Details: `docs/concepts/handoff-readiness.md`, `docs/architecture/visual-proof.md`, `docs/rules/`.

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
| HANDOFF-DEMO | Standard Demo Handoff | `examples/HANDOFF-DEMO` | Ready | Handoff gate, build order, demo milestone, semantic review |
| LITE-BUGFIX | Lite Bug Fix Example | `examples/LITE-BUGFIX` | Ready | Minimal docs for low-risk change |
| STANDARD-FEATURE | Standard Feature Example | `examples/STANDARD-FEATURE` | Ready | Normal flow, delivery, QA, release |
| DESIGN-SYSTEM-DEMO | Visual Direction and Design System at the Design Gate | `examples/DESIGN-SYSTEM-DEMO` | Ready | Brief, selected direction, brand, tokens, components, mockups; stops at Design on purpose |
| STRICT-HIGH-RISK | Strict High-Risk Example | `examples/STRICT-HIGH-RISK` | Ready | Permission/audit example with RTM; full spec depth (SRS, data dictionary, ERD, derived test matrix) |
| DEMO-BROKEN / DEMO-FIXED | Three-minute proof | `demo/` | Ready | Synthetic; drives `make demo` |

## Active Skill Runtime

The active runtime is limited to the 7 skills in `pmo-config/skill-manifest.json`:

- `pmo-intake`
- `pmo-design`
- `pmo-delivery`
- `pmo-build-review`
- `pmo-quality-release`
- `pmo-governance`
- `pmo-git-safety`

Only active skills under `.claude/skills/` are shipped and loaded by default.
Visual Proof has no `.agents/skills` mirror; refresh the generated `skills/` package only through
the repository build command.

---

## Hook Policy

Fake echo hooks have been removed. Use `node cli/axiom.mjs validate` for real validation.
Use `node cli/axiom.mjs doctor` for framework health and `node dist/tools/run-ci-suite-cli.js -Suite validation-fixtures -RepoPath .` for positive/negative validator fixtures.

Suggested validation command:

```bash
node cli/axiom.mjs validate --project <project-folder> --mode Standard --gate Release --fail-on-warning
node cli/axiom.mjs doctor
node dist/tools/run-ci-suite-cli.js -Suite validation-fixtures -RepoPath .
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
