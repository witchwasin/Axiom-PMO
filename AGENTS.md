# PMO Template - Agent Behavioral Guide

> Shared rules for Claude, Codex, Cursor, Copilot, and other AI agents.
> Keep this file short. Detailed methods live in `.claude/skills/` and are loaded on demand.

---

## What This Repo Is

This repo is a lightweight PMO operating template for small teams. It helps AI agents turn meeting sources into scope, flow, delivery, QA, and release artifacts without creating unnecessary documentation overhead.

The operating core stays simple:

| Core | Purpose | Main Outputs |
|---|---|---|
| Core 1 - Discovery & Product Design | Understand source, confirm scope, design only what is needed | `PROJECT.md`, `DESIGN/FLOW.puml`, optional wireframe |
| Core 2 - Delivery & Engineering | Break work down, hand off, build, and review engineering readiness | `DELIVERY.md` or GitHub Issues |
| Core 3 - Quality & Release | Verify, test, approve, close, and release safely | `RELEASE.md`, `RAID-log.md`, `decision-log.md` |

Default project shape:

```text
projects/P01-CODE/
+-- PROJECT.md
+-- source/
|   +-- MOM/
|   +-- Transcript/
|   +-- REQ/
+-- DESIGN/
|   +-- FLOW.puml
|   +-- WIREFRAME.md or WIREFRAME.html
+-- DELIVERY.md
+-- RELEASE.md                  <- required when release/UAT exists
+-- RAID-log.md                 <- required for Strict or meaningful risks
+-- decision-log.md             <- required for Strict or meaningful decisions
```

Legacy folders such as `MOM/`, `REQ/`, `SystemFlow/`, `Wireframe/`, and `TaskBreakdown/` are still acceptable for old projects. New projects should prefer the lightweight shape above.

Examples show the intended artifact weight by mode:

- `examples/LITE-BUGFIX`: minimal low-risk bug fix.
- `examples/STANDARD-FEATURE`: normal feature with flow, delivery, QA, and release.
- `examples/STRICT-HIGH-RISK`: high-risk permission/audit work with RTM and separate review.

---

## Operating Modes

Choose the smallest mode that controls the real risk. Mode is selected per work item, not only per project.

| Mode | Use When | Required Outputs |
|---|---|---|
| Lite | Low-risk bug fix or small feature | `PROJECT.md` section update, one delivery item or GitHub Issue, acceptance criteria, test note |
| Standard | Normal feature with flow, UI, handoff, or QA | `PROJECT.md`, `DESIGN/` when needed, `DELIVERY.md` or GitHub Issue, test checklist |
| Strict | Any strict trigger applies | Full source references, `RAID-log.md`, `decision-log.md`, release checklist, separate QA or human approval |

Strict triggers:

- Payment or financial calculation
- PII, sensitive customer data, or confidential source
- Authentication, authorization, permission, or audit log
- Irreversible action
- External system integration
- Legal or compliance requirement
- Production data migration
- Critical infrastructure
- Public-sector formal acceptance

AI may escalate Lite -> Standard -> Strict. AI must not downgrade Strict without PM or Tech Lead approval.

Approval gates:

1. Scope Approved
2. Design Ready
3. Release Approved

Work status:

```text
To Do -> In Progress -> Review / Test -> Done
```

Use labels for detail: `blocked`, `needs-client`, `bug`, `high-risk`, `ready-to-release`, `review:code`, `review:qa`, `review:business`, `test:failed`.

---

## Non-Negotiable Rules

1. Read the relevant source before producing PMO output. Use `CONTEXT-ROUTER.md` and `pmo-config/context-map.yaml` to keep the read set small.
2. Never invent requirements, actors, business rules, dates, acceptance criteria, or approvals.
3. Separate `Confirmed`, `Assumption`, and `Open Question` in every important output.
4. Do not add features outside scope. If something seems missing, flag it as an open question or gap.
5. Every important requirement, decision, risk, flow, or test claim needs a structured `source_ref`.
6. Evidence must be marked as `verified`, `supported`, `inferred`, `missing`, or `conflict`. `inferred`, `missing`, and `conflict` require review.
7. Use one source of truth for tasks: either `DELIVERY.md` or GitHub Issues. Declare it in `PROJECT.md` and `DELIVERY.md`; do not keep both as competing task boards.
8. Log only meaningful changes: requirement change, scope change, business decision, design approval, release approval, high-risk issue.
9. Treat `source/`, `MOM/`, `REQ/`, `Transcript/`, and `Others/` as user-owned inputs. Do not edit, create, or delete source files unless the user explicitly asks.
10. AI must not push, deploy, approve production, or approve business scope by itself. Commit requires explicit user instruction; push and production release require human confirmation.

---

## AI Guardrails

Use these fields in structured outputs when possible:

```yaml
id: REQ-001
statement: "User can reset password by verified email."
source_ref:
  - source_id: MOM-20260710
    locator: item-2.1
evidence_status: supported
acceptance_criteria:
  - "Given a registered email, when the user requests reset, then a reset link is sent."
```

Guardrail policy:

- `source_ref` is mandatory for requirements, design decisions, test cases, and release claims.
- `verified` means direct source plus human approval.
- `supported` means direct source exists but final approval is still pending.
- `inferred` means the item is reasoned from partial source and needs review.
- `missing` means not found in source and cannot become a requirement.
- `conflict` means sources disagree and must be resolved before final output.
- If the source does not contain the information, say "not found in source" and do not fabricate.
- Empty result is valid. Do not create fake issues just to fill a section.
- Sensitive sources stay local. For PII, financial data, customer confidential data, or restricted data, use Strict mode.

Strict handling means:

- Do not send raw PII, credentials, or confidential customer data to web search or external MCP services.
- Do not copy real customer data into examples.
- Use redacted identifiers in summaries.
- Do not commit confidential source files unless the user explicitly confirms they are allowed.
- Human approval is required before external service use.
- Release requires security/privacy review.

---

## Logging Policy

Do not log every small AI action. Use these files only for meaningful project memory:

- `decision-log.md`: scope, business, design, risk acceptance, release decisions. Required for Strict; optional for Lite/Standard unless meaningful decisions exist.
- `RAID-log.md`: risks, assumptions, issues, dependencies. Required for Strict; optional for Lite/Standard unless meaningful risks exist.
- `PROJECT.md`: current source-backed project summary.
- `RELEASE.md`: final release scope, UAT status, deployment and rollback notes.

If the user says "record", "log", "track", or "จดไว้" without a target, default to `decision-log.md` for decisions and `RAID-log.md` for risks/issues.

---

## Skill Loading

Load skills on demand only. Never load all `.claude/skills/*` at once.

Active skill groups are defined in `pmo-config/skill-manifest.json`:

- Intake: `pmo-intake`
- Design: `pmo-design`
- Delivery: `pmo-delivery`
- Build review: `pmo-build-review`
- QA / Release: `pmo-quality-release`
- Governance: `pmo-governance`
- Git safety: `pmo-git-safety`

Archived skills under `.claude-archive/` are preserved for reference only and must not be loaded by default.

---

## Validation

Before treating a project as ready, run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath examples/P01-DEMO -Mode Standard -Gate Release -FailOnWarning
powershell -ExecutionPolicy Bypass -File scripts/pmo-doctor.ps1
powershell -ExecutionPolicy Bypass -File scripts/run-validation-tests.ps1
```

Validation checks structure, placeholders, source references, approval authenticity, task source consistency, blockers, sensitive file pre-checks, basic local links, and negative fixtures.
