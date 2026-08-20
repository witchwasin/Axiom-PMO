# TEST-PLAN - STRICT-HIGH-RISK

> Status: specified
> Mode: Strict
> Strategy: detailed_requirement_and_risk_cases

## Objectives

- Verify role-based authorization rules for REQ-001 under positive, negative, and permission-bypass conditions.
- Validate immutable audit log creation for REQ-002 under normal and rollback transactions.
- Test non-functional latency and reliability limits for export authorization.

## Scope of Testing

### In Scope
- JWT role verification on `/api/v1/exports/:id/approve`
- Transactional integrity between `ExportRequest` and `AuditLog` tables
- Concurrency conflict handling (409 Conflict) on race conditions

### Out of Scope
- Downstream bulk data archiving beyond CSV generation
