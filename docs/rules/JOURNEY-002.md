# JOURNEY-002 - Journey step spec element traceability

| | |
|---|---|
| Level | FAIL |
| Gate | Design, Handoff, Release |
| Applies to | Standard, Strict (when `Spec depth: full`) |
| Artifacts | `DESIGN/DATA-FLOW.md` |

## What this rule checks

In `DESIGN/DATA-FLOW.md`:
Every `Spec Element Ref` in the `End-to-End Journeys` table must resolve to a declared `REQ-###` in `PROJECT.md` or a declared `Operation ID` in `DESIGN/BUILD-SPEC.md`.

## Why it blocks

Unresolvable journey step references decouple user workflows from governing scope requirements.

## How to fix

Ensure all `Spec Element Ref` entries reference valid requirement IDs or API operations.
