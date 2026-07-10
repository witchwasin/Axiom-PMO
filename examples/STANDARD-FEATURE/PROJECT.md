# PROJECT - STANDARD-FEATURE

> Status: release-approved
> Default mode: Standard
> Task source: file
> Owner: Demo PM
> Last updated: 2026-07-10

## Task Management

```yaml
task_management:
  source_of_truth: delivery_file
  delivery_file: DELIVERY.md
  github_repository:
  rule: DELIVERY.md is master for this Standard example
```

## Source Snapshot

| Source ID | Version / Date | Last Synced At |
|---|---|---|
| MOM-20260710 | v1 | 2026-07-10T10:00:00+07:00 |
| REQ-20260710 | v1 | 2026-07-10T10:00:00+07:00 |

## Summary

Add a simple ticket status board for internal support tracking.

## Scope

### In Scope

| ID | Requirement | Type | Source Ref | Evidence Status | Status |
|---|---|---|---|---:|---|
| REQ-001 | Staff can move tickets across four delivery statuses. | functional | REQ-20260710 row 1 | supported | confirmed |
| REQ-002 | PM can filter open high-priority tickets. | functional | MOM-20260710 item 2 | supported | confirmed |

### Out of Scope

- Customer-facing ticket portal.

## Business Rules

| ID | Rule | Source Ref | Evidence Status |
|---|---|---|---:|
| BR-001 | Tickets cannot move to Done without review notes. | REQ-20260710 row 2 | supported |

## Approvals

| Gate | Approver | Date | Evidence |
|---|---|---|---|
| Scope Approved | Demo PO | 2026-07-10 | DEC-001 |
| Design Ready | Demo Tech Lead | 2026-07-10 | DEC-002 |
| Release Approved | Demo PO | 2026-07-10 | DEC-003 |
