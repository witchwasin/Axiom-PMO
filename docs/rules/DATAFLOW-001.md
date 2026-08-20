# DATAFLOW-001 - Data Dictionary completeness against BUILD-SPEC Data Model

| | |
|---|---|
| Level | FAIL |
| Gate | Design, Handoff, Release |
| Applies to | Standard, Strict (when `Spec depth: full`) |
| Artifacts | `DESIGN/DATA-DICTIONARY.md`, `DESIGN/BUILD-SPEC.md` |

## What this rule checks

Under full specification depth:
1. `DESIGN/DATA-DICTIONARY.md` must exist.
2. Every `(Entity, Attribute)` declared in `DESIGN/BUILD-SPEC.md` `## Data Model` must appear in `DESIGN/DATA-DICTIONARY.md`'s `## Field Inventory` table.

## Why it blocks

The data dictionary is the authoritative binding between technical data model attributes and their classification, lifecycle, and masking rules. Missing fields create unclassified data paths.

## How to fix

Add the missing `(Entity, Attribute)` entries to `DESIGN/DATA-DICTIONARY.md` using `templates/DATA-DICTIONARY.md`.
