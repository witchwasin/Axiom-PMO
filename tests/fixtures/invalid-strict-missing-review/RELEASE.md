# RELEASE - STRICT-HIGH-RISK

## Release Scope

- D-001 Export approval permission
- D-002 Export audit record

## Verification

- Role-based access test completed.
- Audit record test completed.
- Manual security review completed.

## Structured Rollback Plan

| Trigger | Owner | Steps | Verification | Evidence Ref |
|---|---|---|---|---|
| Permission or audit failure | Demo Security Lead | Disable export approval feature flag; revoke Export Approver role assignment until remediation is complete | Non-approvers cannot approve exports and audit checks are disabled | DEC-003 |

## Release Approval

| Gate | Approval Status | Approver | Role | Date | Evidence |
|---|---|---|---|---|---|
| Release Approved | approved | Demo PO | Product Owner | 2026-07-10 | DEC-003 |
