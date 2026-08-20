# TEST-CASES - STRICT-HIGH-RISK

> Status: specified
> Mode: Strict
> Derived Target Cases: 6

## Test Cases Inventory

| Case ID | Category | Target Type | Target ID | Description | Preconditions | Input / Action | Expected Result | Pass Criteria | Strict Trigger | Source Ref | Evidence Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-001 | happy_path | requirement | REQ-001 | Authorized user successfully approves export | User possesses Export Approver role, request is in pending state | POST /api/v1/exports/:id/approve with valid JWT | Request status updated to approved | HTTP 200 and status == approved | auth | REQ-20260710 row 1 | supported |
| TC-002 | negative | requirement | REQ-001 | Unauthorized user is rejected when attempting approval | User possesses Support Agent role only | POST /api/v1/exports/:id/approve with agent JWT | Request rejected with 403 Forbidden | HTTP 403 and status unchanged | auth | REQ-20260710 row 1 | supported |
| TC-003 | boundary | requirement | REQ-001 | Non-existent export ID returns not found | User possesses Export Approver role | POST /api/v1/exports/unknown-uuid/approve | Request rejected with 404 | HTTP 404 error response | auth | REQ-20260710 row 1 | supported |
| TC-004 | happy_path | requirement | REQ-002 | Export approval creates immutable audit record | Request is in pending state | Execute successful export approval | Audit log table contains row with action=approved | Row exists with matching request_id and server timestamp | audit | REQ-20260710 row 2 | supported |
| TC-005 | negative | requirement | REQ-002 | Failed approval does not write audit record | Export approval encounters error | POST approval with invalid payload | Transaction rolls back completely | Zero new rows in AuditLog table | audit | REQ-20260710 row 2 | supported |
| TC-006 | security | requirement | REQ-001 | Unauthenticated request is rejected | Request lacks authorization header | POST /api/v1/exports/:id/approve with no token | Request rejected with 401 | HTTP 401 Unauthorized | auth | REQ-20260710 row 1 | supported |
