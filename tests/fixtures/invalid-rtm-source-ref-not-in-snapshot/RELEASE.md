# RELEASE - INVALID-RTM-SOURCE-REF-NOT-IN-SNAPSHOT

> Release ID: REL-001

## Release Scope

| Deliverable | Requirement Ref | Included? | Notes |
|---|---|---|---|
| D-001 | REQ-001 | yes | |
| D-002 | REQ-002 | yes | |

## Test Summary

| ID | Test Area | Result | Evidence | Notes |
|---|---|---|---|---|
| TEST-001 | Role-based access | passed | DEC-003 | Non-approvers cannot approve exports. |
| TEST-002 | Audit record | passed | DEC-003 | Export actions are recorded. |

## QA / Security Review

| Review Type | Status | Reviewer | Role | Date | Evidence |
|---|---|---|---|---|---|
| QA | approved | Demo QA Lead | QA Lead | 2026-07-10 | DEC-003 |
| Security | approved | Demo Security Lead | Security Reviewer | 2026-07-10 | DEC-003 |

## Structured Rollback Plan

| Trigger | Owner | Steps | Verification | Evidence Ref |
|---|---|---|---|---|
| Permission or audit failure | Demo Security Lead | Disable export approval feature flag; revoke Export Approver role assignment until remediation is complete | Non-approvers cannot approve exports and audit checks are disabled | DEC-003 |

## Release Approval

| Gate | Approval Status | Approver | Role | Date | Evidence |
|---|---|---|---|---|---|
| Release Approved | approved | Demo PO | Product Owner | 2026-07-10 | DEC-003 |
