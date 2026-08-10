# PROJECT - DESIGN-SYSTEM-DEMO

> Status: design-ready
> Default mode: Standard
> Task source: file
> Owner: Demo PM
> Last updated: 2026-08-05

## Task Management

```yaml
task_management:
  source_of_truth: delivery_file
  delivery_file: DELIVERY.md
  github_repository:
  rule: DELIVERY.md is master for this example
```

## Source Snapshot

| Source ID | Version / Date | Last Synced At |
|---|---|---|
| MOM-20260805 | v1 | 2026-08-05T10:00:00+07:00 |
| REQ-20260805 | v1 | 2026-08-05T10:00:00+07:00 |

## Summary

Let staff see which meeting rooms are free and book one themselves, replacing a
paper sheet at reception that is never current.

This example exists to show the design system in its natural place: produced
during design, as input to the Design Ready decision, before anything is handed
to a developer. It stops at that gate on purpose. There is no `HANDOFF.md` and
no `RELEASE.md`, because this project has not reached either.

## Scope

### In Scope

| ID | Requirement | Type | Source Ref | Evidence Status | Approval Status |
|---|---|---|---|---:|---|
| REQ-001 | Staff can see which meeting rooms are free right now. | functional | REQ-20260805 row 1 | supported | approved |
| REQ-002 | Staff can book a free room for a time slot on the current day. | functional | REQ-20260805 row 2 | supported | approved |
| REQ-003 | Staff can cancel a booking they made themselves. | functional | REQ-20260805 row 4 | supported | approved |

### Out of Scope

- Recurring bookings, room equipment, catering, and external visitors (`source_ref: MOM-20260805 item-4`, `evidence_status: supported`)
- Anything that touches the building access system (`source_ref: MOM-20260805 item-4`, `evidence_status: supported`)

## Business Rules

| ID | Rule | Source Ref | Evidence Status |
|---|---|---|---:|
| BR-001 | A room cannot be booked for a time that overlaps an existing booking. | REQ-20260805 row 3 | supported |

## Open Questions

| ID | Question | Impact | Owner | Status |
|---|---|---|---|---|
| Q-001 | Is "RoomBook" the name this tool ships under? | The wordmark and every document that names the tool | Demo PM | open |

## Approvals

| Gate | Approval Status | Approver | Role | Date | Evidence |
|---|---|---|---|---|---|
| Scope Approved | approved | Demo PO | Product Owner | 2026-08-05 | DEC-001 |
| Design Ready | approved | Demo Tech Lead | Tech Lead | 2026-08-07 | DEC-003 |
| Release Approved | pending | Demo PO | Product Owner | 2026-08-07 | DEC-003 |
