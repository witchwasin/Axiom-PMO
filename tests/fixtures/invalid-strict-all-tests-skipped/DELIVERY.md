# DELIVERY - INVALID-STRICT-ALL-TESTS-SKIPPED

## Delivery Mode

- Mode: Strict
- Task source of truth: `file`
- Mode owner: Demo PM / Demo Security Lead
- Current status set: `To Do`, `In Progress`, `Review / Test`, `Done`

## Work Items

| ID | Mode | Strict Trigger | Mode Reason | Mode Approved By | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Priority | Status | Review Stage | Evidence Ref | Labels |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| D-001 | Strict | permission | permission, audit | Demo Security Lead | Export approval permission | REQ-001 | DESIGN/FLOW.puml | Non-approver cannot approve export | Happy, exception, role test | Demo Dev | high | Done | security | DEC-003 | high-risk |
| D-002 | Strict | permission | audit log | Demo Security Lead | Export audit record | REQ-002 | DESIGN/FLOW.puml | Every approved export writes audit record | Happy, exception | Demo Dev | high | Done | qa | DEC-003 | high-risk |
