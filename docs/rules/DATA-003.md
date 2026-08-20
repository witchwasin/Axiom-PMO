# DATA-003 - Entity Relationships consistency with Data Model

| | |
|---|---|
| Level | FAIL |
| Gate | Handoff, Release |
| Applies to | Standard, Strict (when `Spec depth: full`) |
| Artifacts | `DESIGN/BUILD-SPEC.md` |

## What this rule checks

In `DESIGN/BUILD-SPEC.md`:
For every row in `### Entity Relationships`, the declared `From Entity` and `To Entity` must exist as declared entities in `### Data Model`.

## Why it blocks

Declaring relationships involving undefined entities creates schema ambiguity. Engineering contracts must have an internally consistent domain model.

## How to fix

Ensure all entities cited in `Entity Relationships` are declared with attributes in the `Data Model` table.
