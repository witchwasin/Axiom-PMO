# DATAFLOW-001 - Data flow and journey section completeness

| | |
|---|---|
| Level | FAIL |
| Gate | Design, Handoff, Release |
| Applies to | Strict (when `Spec depth: full`) |
| Artifacts | `DESIGN/DATA-FLOW.md` |

## What this rule checks

In Strict mode under full specification depth:
1. `DESIGN/DATA-FLOW.md` must exist.
2. The sections configured in `pmo-config/depth-policy.json` `dataflow_sections` must be present with valid `Status: specified` or `Status: not_required` declarations.

## Why it blocks

Strict governance requires explicit architectural understanding of trust boundaries, system context, and degradation paths before developer handoff.

## How to fix

Create `DESIGN/DATA-FLOW.md` from `templates/DATA-FLOW.md` and complete the declared sections.
