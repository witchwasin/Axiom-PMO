# RELEASE - STANDARD-FEATURE

## Release Scope

| Deliverable | Requirement Ref | Included? | Notes |
|---|---|---|---|
| D-001 | REQ-001 | yes | |
| D-002 | REQ-002 | no | Deferred to next release; filter UX needs more validation with PM. |

## Verification

- Happy path: move ticket across statuses.
- Exception path: block Done when review notes are missing.

## Test Summary

| ID | Test Area | Result | Evidence | Notes |
|---|---|---|---|---|
| TEST-001 | Move ticket across statuses (happy path) | passed | DEC-003 | |
| TEST-002 | Block Done when review notes are missing (exception path) | passed | DEC-003 | |

## QA / Security Review

| Review Type | Status | Reviewer | Role | Date | Evidence |
|---|---|---|---|---|---|
| QA | approved | Demo QA Lead | QA Lead | 2026-07-10 | DEC-003 |

## Structured Rollback Plan

| Trigger | Owner | Steps | Verification | Evidence Ref |
|---|---|---|---|---|
| Status board release blocker | Demo Tech Lead | Hide status board route and restore previous ticket list | Previous ticket list loads | DEC-003 |

## Release Approval

| Gate | Approval Status | Approver | Role | Date | Evidence |
|---|---|---|---|---|---|
| Release Approved | approved | Demo PO | Product Owner | 2026-07-10 | DEC-003 |
