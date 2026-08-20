# DATA-DICTIONARY - STRICT-HIGH-RISK

> Field-level data dictionary and PII classification inventory.
> Binds technical data models from `DESIGN/BUILD-SPEC.md` to privacy classifications and lifecycle policies.

Status: specified
Mode: Strict

## Field Inventory

| Field ID | Entity | Attribute | Type | Unit | Allowed Values | Classification | Source of Record | Enters At | Leaves At | Transformation | Retention | Masking | Source Ref |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| FD-001 | ExportRequest | request_id | uuid | n/a | UUIDv4 | internal | Database | POST /api/v1/exports/request | GET /api/v1/exports/:id | none | 365 days | none | REQ-20260710 row 1 |
| FD-002 | ExportRequest | requester_id | text | n/a | non-empty text | confidential | Auth Token | POST /api/v1/exports/request | Audit Log | none | 365 days | partial | REQ-20260710 row 1 |
| FD-003 | ExportRequest | status | text | n/a | pending, approved, rejected, completed | internal | Database | State Transition | API Response | enum validation | 365 days | none | REQ-20260710 row 1 |
| FD-004 | ExportRequest | approver_id | text | n/a | non-empty text | confidential | Auth Token | POST /api/v1/exports/:id/approve | Audit Log | none | 365 days | partial | REQ-20260710 row 1 |
| FD-005 | AuditLog | audit_id | uuid | n/a | UUIDv4 | internal | Database | Transaction Commit | Audit Query | none | 365 days | none | REQ-20260710 row 2 |
| FD-006 | AuditLog | request_id | uuid | n/a | UUIDv4 | internal | Database | Transaction Commit | Audit Query | FK validation | 365 days | none | REQ-20260710 row 2 |
| FD-007 | AuditLog | actor_id | text | n/a | non-empty text | confidential | Auth Token | Transaction Commit | Audit Query | none | 365 days | partial | REQ-20260710 row 2 |
| FD-008 | AuditLog | action | text | n/a | request_created, approved, rejected, downloaded | internal | Application | State Event | Audit Query | enum validation | 365 days | none | REQ-20260710 row 2 |
| FD-009 | AuditLog | timestamp | timestamp | n/a | ISO-8601 UTC | internal | Server Clock | Event Timestamp | Audit Query | UTC format | 365 days | none | REQ-20260710 row 2 |
