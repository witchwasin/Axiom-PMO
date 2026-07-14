# Using Axiom-PMO with the BMAD Method

The BMAD Method is an agentic software-development methodology with structured
roles and workflow phases. Axiom-PMO does not replace it; it governs the
requirements, scope, evidence, and release authority the methodology operates
within.

> Described at the architecture/contract level. This document does not assume a
> specific BMAD version or file layout — see BMAD's own documentation for its
> mechanics.

## Responsibility model

```
Axiom-PMO → source of truth for requirements, scope, risk, approvals, release authority
BMAD      → role-based planning and execution workflow
```

BMAD's planning and workflow structure map naturally onto Level 1 (policy
awareness): the methodology's roles read Axiom-PMO's approved scope, acceptance
criteria, mode, and prohibited actions before producing work, and return results
as candidate evidence for validation.

## Boundaries

BMAD roles **may** plan, decompose approved work, implement, and review. They
**may not** change approved scope, alter acceptance criteria without a change
request, downgrade risk mode, self-approve QA/security/release, or perform git
mutations or deployment without explicit human confirmation.

## Interoperability level

- **Level 0–1** are achievable today by convention: run both, and have the BMAD
  workflow read Axiom-PMO's artifacts.
- **Level 2–3** can use the framework-neutral contract and result shapes in
  [`integrations/superpowers/`](../../integrations/superpowers/) (named for the
  reference case, but not Superpowers-specific).
- **Level 4** (automated bridge) is roadmap.

See the [interoperability overview](overview.md) for the authority-precedence
order and the full level definitions.
