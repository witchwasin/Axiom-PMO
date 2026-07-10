# DELIVERY - P01-DEMO

## Delivery Mode

- Mode: Standard
- Task source of truth: `file`
- Mode owner: Demo PM / Demo Tech Lead
- Current status set: `To Do`, `In Progress`, `Review / Test`, `Done`

## Task Source of Truth

```yaml
task_management:
  source_of_truth: delivery_file
  delivery_file: DELIVERY.md
  github_repository:
  sync_rule: DELIVERY.md is master; GitHub issues are optional links only
```

## Work Items

| ID | Mode | Mode Reason | Mode Approved By | Feature / Deliverable | Requirement Ref | Flow / Wireframe Ref | Acceptance Criteria | Test Checklist | Owner | Priority | Status | Review Stage | PR / Evidence | Labels |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| D-001 | Standard | normal feature | Demo PM | Ticket creation | REQ-001 | DESIGN/FLOW.puml, DESIGN/WIREFRAME.md WF-001 | Valid ticket saves as To Do; invalid email shows message | Happy, exception | Demo Dev | high | Review / Test | qa | demo evidence | review:qa |
| D-002 | Standard | business rule workflow | Demo Tech Lead | Ticket status workflow | REQ-002, BR-001 | DESIGN/FLOW.puml, DESIGN/WIREFRAME.md WF-002 | Ticket cannot move to Done without review notes | Happy, alternative, exception | Demo Dev | high | Review / Test | qa | demo evidence | review:qa |
| D-003 | Lite | low-risk dashboard visibility | Demo PM | High-priority visibility | REQ-003 | DESIGN/WIREFRAME.md WF-002 | PM can see high-priority open tickets | Happy | Demo Dev | medium | To Do | none | pending demo review | needs-client |

## Conditional Handoff

| Section | Required When | Included? | Notes |
|---|---|---|---|
| Data Model | New database/table/entity | yes | Ticket entity |
| API Spec | API or integration exists | no | Demo only |
| Component List | UI exists | yes | Ticket Form, Ticket Board |
| Security Checklist | Auth, payment, PII, permission, integration | no | No auth in demo |
| Analytics | KPI/tracking requirement exists | no | |
| UX Copy | Critical message/error wording exists | yes | Validation message |
| Infrastructure | Environment/deployment changes | no | |

## Dev Notes

- Branch / PR: demo/local
- Setup: static demo only
- Known limitations: no real authentication

## QA Notes

- Happy path: create ticket and move through statuses
- Alternative path: return ticket from Review / Test to In Progress
- Exception path: invalid email and missing review notes
