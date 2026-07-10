# Standard Process

Use Standard for normal feature delivery where PM, Dev, and QA need shared context.

## Flow

```text
Intake & Scope -> Flow & UX -> Plan & Handoff -> Build & Verify -> Release & Close
```

## Required Artifacts

- `PROJECT.md`
- `DESIGN/FLOW.puml` when actor flow, business logic, or status flow exists
- `DESIGN/WIREFRAME.md` or `.html` when UI exists
- `DELIVERY.md` or GitHub Issues
- `RAID-log.md` for meaningful risks/issues
- `RELEASE.md` for release/UAT

## Approval Gates

1. Scope Approved
2. Design Ready
3. Release Approved

## Rules

- Do not approve User Flow, Use Case, System Flow, and Wireframe in separate rounds unless the user asks.
- Use one design approval for flow, wireframe, and acceptance criteria.
- Use one task source of truth: `DELIVERY.md` or GitHub Issues.
- QA report can live in the delivery item, PR comment, or release notes.

## Exit Criteria

- Scope, design, and release decisions are logged when material.
- Requirements and test claims have `source_ref`.
- Validation passes with `scripts/validate-project.ps1`.
