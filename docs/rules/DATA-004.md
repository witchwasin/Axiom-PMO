# DATA-004 - Foreign key field consistency with Data Model

| | |
|---|---|
| Level | FAIL |
| Gate | Handoff, Release |
| Applies to | Standard, Strict (when `Spec depth: full`) |
| Artifacts | `DESIGN/BUILD-SPEC.md` |

## What this rule checks

In `DESIGN/BUILD-SPEC.md`:
For every row in `### Entity Relationships` where `FK Field` is specified (not `none` or `n/a`), the FK attribute must exist on the `From Entity` in `### Data Model`.

## Why it blocks

Referencing non-existent foreign key fields leads to incorrect database migration scripts and ORM relationship errors.

## How to fix

Add the foreign key attribute (e.g. `location_id`, `user_id`) to the `From Entity` in the `Data Model` table.
