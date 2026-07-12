# RELEASE - STRICT-HIGH-RISK

> Release ID: REL-001

## Release Scope

- D-001 Export approval permission
- D-002 Export audit record

## Test Summary

| ID | Test Area | Result | Evidence | Notes |
|---|---|---|---|---|
| TEST-001 | Role-based access | passed | DEC-003 | Non-approvers cannot approve exports. |
| TEST-002 | Audit record | passed | DEC-003 | Export actions are recorded. |
| TEST-003 | Manual security review | passed | DEC-003 | Reviewed by Security Lead. |

## Structured Rollback Plan

| Trigger | Owner | Steps | Verification | Evidence Ref |
|---|---|---|---|---|
| Permission or audit failure | Demo Security Lead | Disable export approval feature flag; revoke Export Approver role assignment until remediation is complete | Non-approvers cannot approve exports and audit checks are disabled | DEC-003 |

## Release Approval

| Gate | Approval Status | Approver | Role | Date | Evidence |
|---|---|---|---|---|---|
| Release Approved | approved | Demo PO | Product Owner | 2026-07-10 | DEC-003 |
