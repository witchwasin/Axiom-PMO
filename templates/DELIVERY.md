# DELIVERY - <PROJECT-CODE>

> Source of truth for delivery tasks unless GitHub Issues is used.

## Delivery Mode

- Mode: Lite / Standard / Strict
- Task source of truth: `file` / `github`
- Mode owner: PM / Tech Lead
- Current status set: `To Do`, `In Progress`, `Review / Test`, `Done`

## Task Source of Truth

```yaml
task_management:
  source_of_truth: delivery_file # delivery_file or github
  delivery_file: DELIVERY.md
  github_repository:
  sync_rule: if GitHub is master, this file is an index; if this file is master, GitHub issues are links only
```

## Work Items

| ID | Mode | Strict Trigger | Mode Reason | Mode Approved By | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Priority | Status | Review Stage | Evidence Ref | Labels |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| D-001 | Standard | none | normal feature | PM | <feature> | REQ-001 | DESIGN/FLOW.puml | <criteria> | <happy/alt/exception> | <owner> | high | To Do | none | | |

## Conditional Handoff

Complete only the sections that apply.

| Section | Required When | Included? | Notes |
|---|---|---|---|
| Data Model | New database/table/entity | no | |
| API Spec | API or integration exists | no | |
| Component List | UI exists | no | |
| Security Checklist | Auth, payment, PII, permission, integration | no | |
| Analytics | KPI/tracking requirement exists | no | |
| UX Copy | Critical message/error wording exists | no | |
| Infrastructure | Environment/deployment changes | no | |

## Dev Notes

- Branch / PR:
- Setup:
- Known limitations:

## QA Notes

- Happy path:
- Alternative path:
- Exception path:
