# Using Axiom-PMO with OpenSpec

OpenSpec is a spec/change-driven approach to coordinating work with AI agents,
organized around proposed changes. Axiom-PMO complements it by owning the
governance around those changes — provenance, scope approval, evidence, and
release authority.

> Described at the architecture/contract level. This document does not assume a
> specific OpenSpec version or file layout — see OpenSpec's own documentation.

## Responsibility model

```
Axiom-PMO → source of truth for requirements, scope, risk, approvals, release authority
OpenSpec  → change/spec proposal and execution flow
```

An OpenSpec change proposal maps cleanly onto Axiom-PMO's change discipline: a
proposed change should reference the approved requirement and source it derives
from, carry an evidence status, and pass through the approval and release gates
rather than shipping on the strength of the proposal alone.

## Boundaries

OpenSpec **may** propose changes, decompose approved work, implement, and
iterate. It **may not** approve its own scope changes, alter acceptance criteria
without a change request, downgrade risk mode, self-approve QA/security/release,
or perform git mutations or deployment without explicit human confirmation.

## Interoperability level

- **Level 0–1** today by convention.
- **Level 2–3** can use the framework-neutral contract and result shapes in
  [`integrations/superpowers/`](../../integrations/superpowers/).
- **Level 4** is roadmap.

See the [interoperability overview](overview.md) for the full model.
