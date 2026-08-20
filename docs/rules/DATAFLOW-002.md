# DATAFLOW-002 - Data flow table column structure

| | |
|---|---|
| Level | FAIL |
| Gate | Design, Handoff, Release |
| Applies to | Standard, Strict (when `Spec depth: full`) |
| Artifacts | `DESIGN/DATA-FLOW.md` |

## What this rule checks

In `DESIGN/DATA-FLOW.md`:
The table columns in `## End-to-End Journeys` must match the declared schema:
`Step ID`, `Journey`, `Actor`, `Trigger`, `Data In`, `System Action`, `Data Out`, `State Before`, `State After`, `Observable Result`, `Spec Element Ref`.

## Why it blocks

Inconsistent column formatting disrupts journey traceability across test case matrices and state models.

## How to fix

Format the table headers in `DESIGN/DATA-FLOW.md` to match `templates/DATA-FLOW.md`.
