# RELEASE - <PROJECT-CODE>

> Use this for UAT, release decision, deployment notes, and closeout.
> Release ID: REL-001

## Release Scope

| Deliverable | Requirement Ref | Included? | Notes |
|---|---|---|---|
| D-001 | REQ-001 | yes | |

## Acceptance Status

| Check | Status | Evidence / Source Ref | Owner |
|---|---|---|---|
| Acceptance criteria complete | pending | DELIVERY.md D-001 | QA/PM |
| UAT approved | pending | <Decision ID or MOM> | PO/Client |
| High-risk issues resolved | pending | RAID-log.md | PM |
| Rollback plan ready | pending | This file | Tech Lead |

## Test Summary

| ID | Test Area | Result | Evidence | Notes |
|---|---|---|---|---|
| TEST-001 | Happy path | pending | | |
| TEST-002 | Alternative path | pending | | |
| TEST-003 | Exception path | pending | | |

## QA / Security Review

> Standard requires an approved QA row at Release. Strict also requires an approved Security row. Lite is exempt (Test Summary evidence is sufficient).

| Review Type | Status | Reviewer | Role | Date | Evidence |
|---|---|---|---|---|---|
| QA | pending | <reviewer> | QA Lead | YYYY-MM-DD | <evidence ref> |

## Deployment Notes

- Target environment:
- Deploy owner:
- Deploy window:

## Structured Rollback Plan

> Lite may replace this table with a waiver when the change type is on the
> config allowlist (`pmo-config/policy.json` `rollback_waiver`):
> ```
> rollback_required: false
> change_type: content-only
> reason: state why rollback is not needed
> approver: approver name
> ```

| Trigger | Owner | Steps | Verification | Evidence Ref |
|---|---|---|---|---|
| <rollback trigger> | <owner> | <numbered rollback steps> | <how rollback is verified> | <evidence ref> |

## Known Issues

| ID | Issue | Severity | Accepted By | Notes |
|---|---|---|---|---|

## Release Approval

| Gate | Approval Status | Approver | Role | Date | Evidence |
|---|---|---|---|---|---|
| Release Approved | pending | <approver name> | Product Owner | YYYY-MM-DD | DEC-001 |
