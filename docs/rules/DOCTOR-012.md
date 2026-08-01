# DOCTOR-012 - Duplicate decision id

| | |
|---|---|
| Level | FAIL |
| Runs when | `scripts/pmo-doctor.ps1` is invoked |
| Artifacts | `decision-log.md` |

## What this rule checks

Every `DEC-###` in the framework's own `decision-log.md` appears in exactly one
table row.

Only table rows count. Prose that mentions a decision id is a citation, not a
second declaration of it.

## Why it exists

A decision id is a reference target, not a label. `ROADMAP.md` and
`CHANGELOG.md` cite them, and — more consequentially —
[`EXEC-007`](EXEC-007.md) resolves `decision_ref` against this file at
verification time and treats **more than one match as ambiguous**, refusing the
claim.

So a duplicate id does not merely look untidy. It makes every citation of that
id unresolvable, and it can make a legitimate human approval fail to resolve.

**This happened.** `DEC-003` was used twice: once for the Milestone 6.0
integration-shape decision, and again for the product-scope-boundary decision.
A review found it. Nothing in the framework noticed, because nothing was
looking — the same gap that
[`DOCTOR-010`](DOCTOR-010.md) and [`DOCTOR-011`](DOCTOR-011.md) exist to close
for their own classes of defect.

## How to fix

Give the newer decision an unused id, then update references **semantically** —
each citation should point at the decision it actually meant. A global
find-and-replace will move citations that were correct.

Do not change either row's content, decider, date, or approval state. The
decisions themselves were real; only the identifier was wrong.

## Related

[`EXEC-007`](EXEC-007.md) (resolves `decision_ref`, rejects ambiguity),
[`APPROVAL-004`](APPROVAL-004.md).
