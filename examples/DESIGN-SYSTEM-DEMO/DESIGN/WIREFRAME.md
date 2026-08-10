# WIREFRAME - DESIGN-SYSTEM-DEMO

## Screen List

| Screen ID | Name | Requirement Ref | Flow Ref | Status |
|---|---|---|---|---|
| WF-001 | Today availability | REQ-001 | FLOW.puml | approved |
| WF-002 | Booking form | REQ-002, REQ-003 | FLOW.puml | approved |

## Screen Details

### WF-001 - Today availability

- Purpose: answer "is there a free room right now" without the user reading anything
- Primary user: any member of staff
- Key fields: room name, capacity, current status, next free time
- Validation: none, this screen is read only
- Empty state: no rooms configured yet
- Source ref: REQ-20260805 row 1

### WF-002 - Booking form

- Purpose: book a free slot, and refuse an overlap in a way the user can act on
- Primary user: any member of staff
- Key fields: room, date, start time, end time, purpose
- Validation: end after start, and no overlap with an existing booking per BR-001
- Empty state: not applicable, the form always has a room preselected
- Error state: overlap refusal naming the conflicting booking
- Source ref: REQ-20260805 row 2, row 3
