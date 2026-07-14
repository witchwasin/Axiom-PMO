# Experimental: Execution-Contract Integration

> **Status: experimental. Not wired into the validator runtime.**
> These files document the *shape* of a governance ↔ execution handoff so an
> integration can be built and reviewed. Nothing in `scripts/` or `pmo-config/`
> reads them, and no validator rule depends on them. Do not treat their presence
> as a shipped Level 3/4 bridge — see
> [`docs/integrations/overview.md`](../../docs/integrations/overview.md).

The directory is named for Superpowers as the reference use case, but the shapes
are **framework-neutral**: they apply equally to BMAD, spec-kit, OpenSpec, or a
custom Claude Code agent.

## Files

| File | Purpose | Interop level |
|---|---|---|
| `EXECUTION-CONTRACT.template.json` | The approved work package Axiom-PMO hands to an execution framework. | Level 2 |
| `EXECUTION-RESULT.schema.json` | JSON Schema for the structured result the framework returns. | Level 3 |
| `integration-policy.json` | The authority boundaries a bridge must enforce. | Levels 2–4 |

## Intended flow

```
Approved Axiom-PMO work item
  → fill EXECUTION-CONTRACT.template.json (what, refs, acceptance, out-of-scope, allowed paths, git authority)
  → hand to the execution framework
  → framework returns a document conforming to EXECUTION-RESULT.schema.json
  → a (future) validator checks it against integration-policy.json before any Axiom-PMO artifact is updated
```

## Rules an implementing bridge must honor

- The result is **candidate evidence**, not trusted truth, until validated.
- The execution framework may not change approved scope, alter acceptance
  criteria, downgrade risk mode, or mark QA/security/release approved.
- Git authority is only what the contract explicitly grants; `commit`, `push`,
  `merge`, and `deploy` default to `false` and require human confirmation.
- Any deviation or unresolved issue in the result must block auto-promotion and
  surface to a human.
