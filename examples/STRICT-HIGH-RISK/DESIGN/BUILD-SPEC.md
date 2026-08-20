# BUILD-SPEC - STRICT-HIGH-RISK

> Status: specified
> Mode: Strict
> Handoff Target: internal
> Horizon: 2026-08-15
> Handoff Owner: Demo Tech Lead
> Named Integrator: Demo Senior Engineer

## Sections

### Technology Stack

Status: specified

- Runtime: Node.js 20 LTS (TypeScript)
- Framework: Fastify
- Database: PostgreSQL 16
- Testing: node:test with native assertions

### Runtime and Deployment Model

Status: specified

Node.js container deployed onto Kubernetes within private cluster VPC with container health probes on port 8080.

### UI Framework

Status: not_required
Rationale: This deliverable is a pure backend API slice; user interface components are delivered in a separate sprint.

### Technology Decisions

Status: specified

| Decision ID | Area | Chosen | Alternatives Considered | Rationale | Trade-offs Accepted | Decision Ref | Source Ref |
|---|---|---|---|---|---|---|---|
| TD-001 | Authorization | Fastify PreHandler Hook with JWT Role Claim | OPA sidecar, CASL library | Zero external latency, native Fastify lifecycle integration | Coupled to Fastify router | DEC-002 | REQ-20260710 row 1 |
| TD-002 | Audit Storage | PostgreSQL Append-Only Audit Table | Kafka stream, ElasticSearch | ACID consistency with export state mutations in a single transaction | Database storage growth requires archival partitioning | DEC-002 | REQ-20260710 row 2 |

### Target Devices and Runtime Capabilities

Status: specified

| Capability | Required By | Serving Model | Environment Decision |
|---|---|---|---|
| Postgres Transaction | AC-001 | localhost | DEC-002 |

### Architecture Boundaries

Status: specified

The service runs behind the API Gateway on the internal private VPC. All traffic requires valid TLS 1.3 with internal mutual authentication headers.

### Data Model

Status: specified

| Constraint ID | Entity | Attribute | Type | Unit | Cardinality | Constraint |
|---|---|---|---|---|---|---|
| C-001 | ExportRequest | request_id | uuid | n/a | 1 per request | primary key, monotonic |
| C-002 | ExportRequest | requester_id | text | n/a | 1 per request | non-empty user identifier |
| C-003 | ExportRequest | status | text | n/a | 1 per request | enum: pending, approved, rejected, completed |
| C-004 | ExportRequest | approver_id | text | n/a | 0..1 per request | non-empty when status is approved |
| C-005 | AuditLog | audit_id | uuid | n/a | 1 per audit | primary key, auto-generated |
| C-006 | AuditLog | request_id | uuid | n/a | 1 per audit | references ExportRequest |
| C-007 | AuditLog | actor_id | text | n/a | 1 per audit | non-empty user identifier |
| C-008 | AuditLog | action | text | n/a | 1 per audit | enum: request_created, approved, rejected, downloaded |
| C-009 | AuditLog | timestamp | timestamp | n/a | 1 per audit | server timestamp, immutable |

### Entity Relationships

Status: specified

| Relationship ID | From Entity | To Entity | Cardinality | FK Field | Required | On Delete |
|---|---|---|---|---|---|---|
| REL-001 | AuditLog | ExportRequest | many-to-one | request_id | yes | restrict |

### API or Command Contract

Status: specified

| Operation ID | Operation | Input | Success | Failure Modes | Idempotent | Auth / Role |
|---|---|---|---|---|---|---|
| approveExport | `POST /api/v1/exports/:id/approve` | request_id | 200 OK + updated ExportRequest | 401 Unauthorized, 403 Forbidden, 404 Not Found, 409 Conflict | yes | Export Approver |
| listAuditLogs | `GET /api/v1/exports/:id/audit` | request_id | 200 OK + array of AuditLog | 401 Unauthorized, 403 Forbidden, 404 Not Found | yes | Security Auditor |

### State Machine and Transition Guards

Status: specified

| Transition ID | From | To | Guard | Reverse | Terminal |
|---|---|---|---|---|---|
| TR-001 | pending | approved | Actor has Export Approver role | no | no |
| TR-002 | pending | rejected | Actor has Export Approver role | no | yes |
| TR-003 | approved | completed | Export file generated and stored | no | yes |

### Transaction Boundaries

Status: specified

Updating the `ExportRequest.status` to `approved` and inserting the corresponding `AuditLog` entry happen atomically inside a single database transaction. If either operation fails, the transaction is rolled back completely.

### Concurrency, Idempotency and ID Allocation

Status: specified

Export approval uses optimistic locking on the `ExportRequest` record. Simultaneous approval attempts by multiple approvers result in a 409 Conflict for the later transaction. `request_id` and `audit_id` are UUIDv4 generated server-side.

### Error, Empty and Loading States

Status: specified

Standard RFC 7807 problem details JSON payload returned for all 4xx/5xx HTTP errors with unambiguous error codes.

### File and Image Processing

Status: not_required
Rationale: Export data generation outputs structured CSV/JSON archives; no image processing or media transformation is involved.

### Security, Privacy and Data Inventory

Status: specified

| Data Element | Contains Sensitive Data | Classification Decision | Retention Decision |
|---|---|---|---|
| User Identity and Email | yes | DEC-002 | DEC-002 |
| Ticket Audit Stream | no | not applicable | retained with the record |

### Performance, Capacity and Availability

Status: specified

The approval endpoint is provisioned to support up to 200 requests per minute with p99 latency < 50ms. Audit log tables use monthly partitioning by timestamp to ensure consistent query performance.

### Integration Contracts

Status: specified

Integrates with the internal Identity Provider via verified JWT claims containing the `roles` array.

### Audit and Logging

Status: specified

All authentication failures, approval decisions, and data download operations write structured JSON log records to stdout and synchronous rows to the PostgreSQL `AuditLog` table.

### Retention, Backup and Restore

Status: specified

PostgreSQL daily automated snapshots with 30-day point-in-time recovery; audit logs replicated continuously to offsite storage.

### Seed Data

Status: specified

Migration scripts seed test tenant with sample export requests and approver user accounts.

### Test Strategy

Status: specified

| Test Area | Requirement / Risk Ref | Level | Execution | Environment | Owner |
|---|---|---|---|---|---|
| Export Role Authorization | REQ-001 | unit | automated | localhost | Demo Tech Lead |
| Audit Trail Persistence | REQ-002 | integration | automated | localhost | Demo Senior Engineer |

### Acceptance Cases

Status: specified

| Case ID | Requirement Ref | Given / When / Then | Execution | Fixture / Seed | Reset |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | Given an Export Approver, when approving a pending export, then status becomes approved | automated | seed-users | truncate tables |
| AC-002 | REQ-002 | Given an export approval, when committed, then an audit row is created | automated | seed-users | truncate tables |

### Demo Reset Procedure

Status: not_required
Rationale: This backend component uses transient integration test containers; state resets automatically upon test runner container teardown.

### Known Limitations

Status: specified

Bulk export file streaming is deferred to phase 2; current release delivers authorization and audit logging.
