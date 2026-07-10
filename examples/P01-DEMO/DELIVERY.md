# DELIVERY - P01-DEMO

## Delivery Mode

- Mode: Standard
- Task source of truth: `file`
- Current status set: `To Do`, `In Progress`, `Review / Test`, `Done`

## Work Items

| ID | Mode | Feature / Deliverable | Requirement Ref | Flow / Wireframe Ref | Acceptance Criteria | Test Checklist | Owner | Priority | Status | Review Stage | Labels |
|---|---|---|---|---|---|---|---|---|---|---|---|
| D-001 | Standard | Ticket creation | REQ-001 | DESIGN/FLOW.puml, DESIGN/WIREFRAME.md WF-001 | Valid ticket saves as To Do; invalid email shows message | Happy, exception | Demo Dev | high | Review / Test | qa | review:qa |
| D-002 | Standard | Ticket status workflow | REQ-002, BR-001 | DESIGN/FLOW.puml, DESIGN/WIREFRAME.md WF-002 | Ticket cannot move to Done without review notes | Happy, alternative, exception | Demo Dev | high | Review / Test | qa | review:qa |
| D-003 | Lite | High-priority visibility | REQ-003 | DESIGN/WIREFRAME.md WF-002 | PM can see high-priority open tickets | Happy | Demo Dev | medium | To Do | none | needs-client |

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
