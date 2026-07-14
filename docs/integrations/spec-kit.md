# Using Axiom-PMO with GitHub spec-kit

[GitHub spec-kit](https://github.com/github/spec-kit) is a toolkit for
spec-driven development — turning a specification into implementation with AI
assistance. Axiom-PMO complements it by governing where the specification comes
from, whether it is in approved scope, what evidence supports it, and who may
release it.

> Described at the architecture/contract level. This document does not assume a
> specific spec-kit version or command set — see spec-kit's own documentation.

## Responsibility model

```
Axiom-PMO → requirement provenance, scope approval, evidence policy, release authority
spec-kit  → spec-to-implementation workflow
```

A spec-kit specification is an **implementation artifact**. In Axiom-PMO terms it
sits downstream of an approved requirement and its source reference: the spec
should trace back to a requirement Axiom-PMO recorded, not introduce scope of its
own. Implementation and tests produced from the spec return as candidate evidence
for validation.

## Boundaries

spec-kit **may** author specs, generate implementation and tests, and iterate.
It **may not** expand approved scope, invent requirements without a source
reference, downgrade risk mode, self-approve QA/security/release, or perform git
mutations or deployment without explicit human confirmation.

## Interoperability level

- **Level 0–1** today by convention.
- **Level 2** can pass an Axiom-PMO work item into a spec-kit flow using the
  framework-neutral contract shape in
  [`integrations/superpowers/`](../../integrations/superpowers/).
- **Level 3–4** are roadmap.

See the [interoperability overview](overview.md) for level definitions and
authority precedence.
