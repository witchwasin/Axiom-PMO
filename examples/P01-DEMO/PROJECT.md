# PROJECT - P01-DEMO

> Status: design-ready
> Default mode: Standard
> Task source: file
> Owner: Demo PM
> Last updated: 2026-07-10

## Source Snapshot

| Source ID | Version / Date | Last Synced At |
|---|---|---|
| MOM-20260710 | v1 | 2026-07-10T00:00:00+07:00 |
| REQ-20260710 | v1 | 2026-07-10T00:00:00+07:00 |

## Summary

Demo project for a lightweight customer support request tracker.

## Source Inventory

| Source ID | Type | File / Location | Date | Notes |
|---|---|---|---|---|
| MOM-20260710 | MOM | `source/MOM/20260710_[MOM]_demo-kickoff.md` | 2026-07-10 | Synthetic kickoff |
| REQ-20260710 | Requirement | `source/REQ/20260710_REQs_DEMO.md` | 2026-07-10 | Synthetic requirements |

## Scope

### In Scope

| ID | Requirement | Type | Source Ref | Evidence Status | Status |
|---|---|---|---|---:|---|
| REQ-001 | Staff can create a support ticket with title, description, priority, and requester email. | functional | MOM-20260710 scope item 1 | supported | confirmed |
| REQ-002 | Staff can move a ticket through To Do, In Progress, Review / Test, and Done. | functional | REQ-20260710 row 2 | supported | confirmed |
| REQ-003 | PM can view open high-priority tickets before release. | functional | MOM-20260710 risk note | supported | confirmed |

### Out of Scope

- Customer-facing portal is out of scope for the demo (`source_ref: MOM-20260710 out-of-scope`, `evidence_status: supported`).

## Business Rules

| ID | Rule | Source Ref | Evidence Status |
|---|---|---|---:|
| BR-001 | A ticket cannot move to Done until review notes are filled. | REQ-20260710 row 3 | supported |

## Assumptions

| ID | Assumption | Validation Needed | Owner | Due | Status |
|---|---|---|---|---|---|
| A-001 | Email format validation is enough for demo. | Confirm with PM | Demo PM | 2026-07-12 | open |

## Open Questions

| ID | Question | Impact | Owner | Status |
|---|---|---|---|---|
| Q-001 | Should priority include Critical or only High/Medium/Low? | Affects UI options | Demo PM | open |

## Risks

| ID | Risk | Impact | Mitigation | Owner | Status |
|---|---|---|---|---|---|
| R-001 | Priority rules may be unclear. | QA may test wrong workflow. | Confirm priority set before release. | Demo PM | open |

## Approvals

| Gate | Approver | Date | Evidence |
|---|---|---|---|
| Scope Approved | Demo PO | 2026-07-10 | DEC-001 |
| Design Ready | Demo Tech Lead | 2026-07-10 | DEC-002 |
| Release Approved | Demo PO | 2026-07-10 | DEC-003 |
