# RELEASE - STANDARD-FEATURE

## Release Scope

- D-001 Status board
- D-002 Priority filter

## Verification

- Happy path: move ticket across statuses.
- Exception path: block Done when review notes are missing.

## Structured Rollback Plan

| Trigger | Owner | Steps | Verification | Evidence Ref |
|---|---|---|---|---|
| Status board release blocker | Demo Tech Lead | Hide status board route and restore previous ticket list | Previous ticket list loads | DEC-003 |

## Release Approval

| Gate | Approval Status | Approver | Role | Date | Evidence |
|---|---|---|---|---|---|
| Release Approved | approved | Demo PO | Product Owner | 2026-07-10 | DEC-003 |
