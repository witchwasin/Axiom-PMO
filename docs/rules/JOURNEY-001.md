# JOURNEY-001 - Journey step State Before/After resolution against State Machine

| | |
|---|---|
| Level | FAIL |
| Gate | Design, Handoff, Release |
| Applies to | Standard, Strict (when `Spec depth: full`) |
| Artifacts | `DESIGN/DATA-FLOW.md`, `DESIGN/BUILD-SPEC.md` |

## What this rule checks

Under `Spec depth: full`:
In `DESIGN/DATA-FLOW.md` `## End-to-End Journeys` table:
Every journey step's `State Before` and `State After` must resolve to declared states or transitions in `DESIGN/BUILD-SPEC.md` under `## State Machine and Transition Guards`.

## Why it blocks

Journey steps operating on undeclared or non-existent system states create gaps in technical implementation and test orchestration.

## How to fix

Ensure `State Before` and `State After` values in `DESIGN/DATA-FLOW.md` match states or transitions defined in `BUILD-SPEC.md`.
