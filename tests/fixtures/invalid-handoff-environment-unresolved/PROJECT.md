# PROJECT - HANDOFF-DEMO

> Status: design-ready
> Default mode: Standard
> Task source: file
> Owner: Demo PM
> Last updated: 2026-07-14

## Task Management

```yaml
task_management:
  source_of_truth: delivery_file
  delivery_file: DELIVERY.md
  github_repository:
  rule: DELIVERY.md is master for this handoff example
```

## Source Snapshot

| Source ID | Version / Date | Last Synced At |
|---|---|---|
| MOM-20260714 | v1 | 2026-07-14T09:00:00+07:00 |
| REQ-20260714 | v1 | 2026-07-14T09:00:00+07:00 |

## Summary

A tablet page for the workshop floor: look up a part by scanning its label, and adjust its on-hand count. Demonstrated on the sponsor's tablet on 2026-08-05.

## Scope

### In Scope

| ID | Requirement | Type | Source Ref | Evidence Status | Approval Status |
|---|---|---|---|---:|---|
| REQ-001 | A user can find a part by scanning the code on its label. | functional | REQ-20260714 row 1 | supported | approved |
| REQ-002 | A user can record stock consumed from a part's on-hand count. | functional | REQ-20260714 row 2 | supported | approved |
| REQ-003 | A user can record stock received into a part's on-hand count. | functional | REQ-20260714 row 2 | supported | approved |
| REQ-004 | A user can attach a photo to a part record. | functional | REQ-20260714 row 3 | supported | approved |

### Out of Scope

- Multi-site or multi-warehouse stock.
- Purchase orders and supplier records.

## Business Rules

| ID | Rule | Source Ref | Evidence Status |
|---|---|---|---:|
| BR-001 | On-hand count is a whole number of pieces and cannot go below zero. | MOM-20260714 item 4 | supported |
| BR-002 | Part photos stay on the site network. | MOM-20260714 item 5 | supported |

## Approvals

| Gate | Approval Status | Approver | Role | Date | Evidence |
|---|---|---|---|---|---|
| Scope Approved | approved | Demo PO | Product Owner | 2026-07-14 | DEC-001 |
| Design Ready | approved | Demo Tech Lead | Tech Lead | 2026-07-15 | DEC-002 |
