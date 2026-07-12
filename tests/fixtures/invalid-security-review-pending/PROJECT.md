# PROJECT - STRICT-HIGH-RISK

> Status: release-approved
> Default mode: Strict
> Task source: file
> Owner: Demo PM
> Last updated: 2026-07-10

## Task Management

```yaml
task_management:
  source_of_truth: delivery_file
  delivery_file: DELIVERY.md
  github_repository:
  rule: DELIVERY.md is master for this Strict example
```

## Source Snapshot

| Source ID | Version / Date | Last Synced At |
|---|---|---|
| REQ-20260710 | v1 | 2026-07-10T10:00:00+07:00 |
| DEC-20260710 | v1 | 2026-07-10T10:00:00+07:00 |

## Summary

Add role-based approval for exporting internal ticket data.

## Scope

### In Scope

| ID | Requirement | Type | Source Ref | Evidence Status | Approval Status |
|---|---|---|---|---:|---|
| REQ-001 | Only users with Export Approver role can approve exports. | permission | REQ-20260710 row 1 | supported | approved |
| REQ-002 | Export action must write an audit record. | audit | REQ-20260710 row 2 | supported | approved |

### Out of Scope

- Payment, external data sharing, and customer-facing export UI.

## Risks

| ID | Risk | Impact | Mitigation | Owner | Status |
|---|---|---|---|---|---|
| R-001 | Permission misconfiguration could expose internal data. | High | Separate QA and manual security review. | Demo Tech Lead | closed |

## Approvals

| Gate | Approval Status | Approver | Role | Date | Evidence |
|---|---|---|---|---|---|
| Scope Approved | approved | Demo PO | Product Owner | 2026-07-10 | DEC-001 |
| Design Ready | approved | Demo Security Lead | Tech Lead | 2026-07-10 | DEC-002 |
| Release Approved | approved | Demo PO | Product Owner | 2026-07-10 | DEC-003 |
