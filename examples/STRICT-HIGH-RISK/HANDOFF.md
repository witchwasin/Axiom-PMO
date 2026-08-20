# HANDOFF - STRICT-HIGH-RISK

> The developer entry point for the STRICT-HIGH-RISK export approval subsystem.

- Project: STRICT-HIGH-RISK
- Mode: Strict
- Handoff Target: internal
- Horizon: 2026-08-15
- Handoff Owner: Demo Tech Lead
- Named Integrator: Demo Senior Engineer
- Build Spec Ref: DESIGN/BUILD-SPEC.md

## Build Now

| Item | Work Item Ref | Value Delivered | Owner |
|---|---|---|---|
| Role-based Export Authorization | D-001 | Restrict export approvals to verified approver roles | Demo Tech Lead |
| Immutable Audit Logging | D-002 | Ensure all export actions are immutably logged | Demo Senior Engineer |

## Deferred / Do Not Build

none

## Hard Constraints

| Constraint | Type | Source Ref |
|---|---|---|
| Strict Role Separation | legal | REQ-20260710 row 1 |

## Build Sequence and Dependencies

| Step | Work Item Ref | Depends On | Owner | Notes |
|---|---|---|---|---|
| 1 | D-001 | none | Demo Tech Lead | Core authorization hook |
| 2 | D-002 | D-001 | Demo Senior Engineer | Synchronous audit persistence |

## Environment and Device Matrix

| Environment | Target Device / Browser | Serving Model | Decision Ref |
|---|---|---|---|
| dev | Linux Node.js 20 Server | localhost | DEC-002 |

## Definition of Done

| Criterion | Verification | Owner |
|---|---|---|
| All tests in TESTS/TEST-CASES.md pass | automated test suite execution | Demo Tech Lead |
| Audit records committed atomically | database integration tests | Demo Senior Engineer |

## Open Actions

none

## Blocking Points

- **Before build:** nothing
- **Before integration:** nothing
- **Before demo:** nothing
- **Before UAT:** nothing
- **Before release:** nothing

## Key Links

- Requirements: `PROJECT.md`
- Flow: `DESIGN/FLOW.puml`
- Technical spec: `DESIGN/BUILD-SPEC.md`
- Work items: `DELIVERY.md`
