# WIREFRAME - P01-DEMO

## Screen List

| Screen ID | Name | Requirement Ref | Flow Ref | Status |
|---|---|---|---|---|
| WF-001 | Ticket Form | REQ-001 | DESIGN/FLOW.puml | draft |
| WF-002 | Ticket Board | REQ-002, REQ-003 | DESIGN/FLOW.puml | draft |

## WF-001 - Ticket Form

- Purpose: create a support ticket
- Primary user: Staff
- Key fields: title, description, priority, requester email
- Validation: required fields and email format
- Error state: inline validation message
- Source ref: MOM-20260710 scope item 1

## WF-002 - Ticket Board

- Purpose: move tickets through the four statuses
- Primary user: Staff, PM, QA
- Key fields: status, priority, review notes
- Validation: Done requires review notes
- Source ref: REQ-20260710 row 2, REQ-20260710 row 3
