# HANDOFF-005 - Required BUILD-SPEC section incomplete

| | |
|---|---|
| Level | FAIL |
| Gate | Handoff |
| Applies to | Standard, Strict |
| Artifacts | `DESIGN/BUILD-SPEC.md` |

## What this rule checks

For each section required by the project's mode (and by the handoff target, for demo-only sections):

1. The `### <heading>` exists.
2. It declares a `Status:` line whose value is `specified` or `not_required`.
3. `Status: specified` sections have content, and sections declared as tables have at least one row.
4. `Status: not_required` sections are permitted a waiver by policy **and** carry a `Rationale:` of at least four words.

The section list, which modes require which section, and which sections may be waived all live in `pmo-config/handoff-policy.json` under `build_spec.sections`.

## Why it blocks

An empty section is ambiguous in the worst possible way: the reader cannot tell whether the author decided it did not apply or never got to it. `not_required` plus a rationale converts that silence into a recorded decision someone can disagree with.

## What the validator does not do

It does not evaluate whether the content is correct, complete, or internally consistent. A data model with a `Status: specified` and one row passes this rule even if it is missing the quantity column the use case needs. That is the `data_cardinality_and_units` review lens.

## How to fix

```markdown
### Retention, Backup and Restore

Status: not_required
Rationale: Demo runs on ephemeral seed data that is regenerated on every reset; no retention obligation applies before pilot. See DEC-006.
```

## Related

`HANDOFF-006`, `HANDOFF-007` (acceptance cases), `HANDOFF-011` (data inventory), `HANDOFF-012` (runtime capabilities).
