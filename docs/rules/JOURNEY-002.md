# JOURNEY-002 - Scoped requirement journey coverage

| | |
|---|---|
| Level | FAIL |
| Gate | Design, Handoff, Release |
| Applies to | Strict (when `Spec depth: full`) |
| Artifacts | `DESIGN/DATA-FLOW.md`, `PROJECT.md` |

## What this rule checks

In Strict mode under `Spec depth: full`:
Every scoped requirement (`REQ-###`) in `PROJECT.md` must be referenced in at least one journey step's `Spec Element Ref` in `DESIGN/DATA-FLOW.md` `## End-to-End Journeys`.

## Why it blocks

Strict governance requires every functional requirement to be validated through a concrete end-to-end user or system journey.

## How to fix

Add or update journey steps in `DESIGN/DATA-FLOW.md` to reference all declared scoped requirements in `Spec Element Ref`.
