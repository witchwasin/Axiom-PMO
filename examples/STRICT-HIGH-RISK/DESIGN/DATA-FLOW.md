# DATA-FLOW - STRICT-HIGH-RISK

> Status: specified
> Mode: Strict

## System Context and Trust Boundaries

Status: specified

All export approval requests originate from authenticated user sessions and terminate at the Export Approval API service. Authorization enforcement occurs prior to database mutation within the secured VPC perimeter.

## End-to-End Journeys

Status: specified

| Step ID | Journey | Actor | Trigger | Data In | System Action | Data Out | State Before | State After | Observable Result | Spec Element Ref |
|---|---|---|---|---|---|---|---|---|---|---|
| STEP-001 | Export Approval Flow | Export Approver | POST /api/v1/exports/:id/approve | request_id | Validate role claim, update ExportRequest status, write AuditLog row | updated ExportRequest | pending | approved | HTTP 200 OK with approval confirmation | REQ-001, approveExport |
| STEP-002 | Audit Verification Flow | Security Auditor | GET /api/v1/exports/:id/audit | request_id | Query AuditLog table for target request_id | array of AuditLog entries | approved | approved | HTTP 200 OK with audit event trail | REQ-002, listAuditLogs |

## Failure and Degradation Paths

Status: specified

When the database experiences temporary connection pool exhaustion, the approval endpoint returns HTTP 503 with a `Retry-After: 5` header and does not write partial audit state.
