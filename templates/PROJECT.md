# PROJECT - <PROJECT-CODE>

> Status: draft / scope-approved / design-ready / release-approved
> Default mode: Lite / Standard / Strict
> Task source: file / github
> Owner: <PM/PO>
> Last updated: <YYYY-MM-DD>

## Task Management

```yaml
task_management:
  source_of_truth: delivery_file # delivery_file or github
  delivery_file: DELIVERY.md
  github_repository:
  rule: only one task system is master; the other can only be an index or link
```

## Source Snapshot

| Source ID | Version / Date | Last Synced At |
|---|---|---|
| MOM-YYYYMMDD | v1 | <ISO-8601> |

## Summary

One-sentence project outcome:

> <Who will achieve what outcome by when, measured how?>

## Source Inventory

| Source ID | Type | File / Location | Date | Notes |
|---|---|---|---|---|
| MOM-YYYYMMDD | MOM | `source/MOM/<file>` | YYYY-MM-DD | <meeting purpose> |
| REQ-YYYYMMDD | Requirement | `source/REQ/<file>` | YYYY-MM-DD | <source note> |

## Scope

### In Scope

| ID | Requirement | Type | Source Ref | Evidence Status | Status |
|---|---|---|---|---:|---|
| REQ-001 | <atomic, testable requirement> | functional | MOM-YYYYMMDD item-1 | supported | confirmed |

### Out of Scope

- <Explicit non-goal> (`source_ref: MOM-YYYYMMDD item-2`, `evidence_status: supported`)

## Business Rules

| ID | Rule | Source Ref | Evidence Status |
|---|---|---|---:|
| BR-001 | <rule> | MOM-YYYYMMDD item-2 | supported |

## Assumptions

| ID | Assumption | Validation Needed | Owner | Due | Status |
|---|---|---|---|---|---|
| A-001 | <assumption> | <how to validate> | <owner> | YYYY-MM-DD | open |

## Open Questions

| ID | Question | Impact | Owner | Status |
|---|---|---|---|---|
| Q-001 | <question> | <scope/design/test impact> | <owner> | open |

## Risks

| ID | Risk | Impact | Mitigation | Owner | Status |
|---|---|---|---|---|---|
| R-001 | <risk> | <impact> | <mitigation> | <owner> | open |

## Approvals

| Gate | Approver | Date | Evidence |
|---|---|---|---|
| Scope Approved | <approver name> | YYYY-MM-DD | DEC-001 |
| Design Ready | <approver name> | YYYY-MM-DD | DEC-002 |
| Release Approved | <approver name> | YYYY-MM-DD | DEC-003 |
