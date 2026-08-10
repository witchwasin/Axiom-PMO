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
- `HANDOFF.md` and `DESIGN/BUILD-SPEC.md` when the work is handed to a developer
- `RAID-log.md` for meaningful risks/issues
- `RELEASE.md` for release/UAT

## Optional Artifacts

- `DESIGN/DESIGN-SYSTEM.md` plus `DESIGN/DESIGN-SYSTEM.html` and `DESIGN/BRAND/` when the
  team needs to see the product before a prototype or a handoff. No gate requires it and no
  rule blocks on it. It is candidate evidence for `Design Ready`, never the approval itself.
  See [design system](../concepts/design-system.md).

## Approval Gates

1. Scope Approved
2. Design Ready
3. Release Approved

## Validation Gates

```text
Draft -> Scope -> Design -> Handoff -> Release
```

`Handoff` is a checking gate, not an approval gate: it reuses `Design Ready` and
asks whether the contract is complete enough for a developer to start,
integrate, and demonstrate. Run it before handing work over; skip it for work
that is not being handed to anyone. See
[handoff readiness](../concepts/handoff-readiness.md).

## Rules

- Do not approve User Flow, Use Case, System Flow, and Wireframe in separate rounds unless the user asks.
- Use one design approval for flow, wireframe, and acceptance criteria.
- Use one task source of truth: `DELIVERY.md` or GitHub Issues.
- QA report can live in the delivery item, PR comment, or release notes.

## Exit Criteria

- Scope, design, and release decisions are logged when material.
- Requirements and test claims have `source_ref`.
- Validation passes with `scripts/validate-project.ps1`.
- Before a developer handoff: `-Gate Handoff` passes and
  `scripts/assess-handoff.ps1` reports which stages are ready.
