# JOURNEY-001 - End-to-end journey step declaration

| | |
|---|---|
| Level | FAIL |
| Gate | Design, Handoff, Release |
| Applies to | Standard, Strict (when `Spec depth: full`) |
| Artifacts | `DESIGN/DATA-FLOW.md` |

## What this rule checks

Under `Spec depth: full`:
The `End-to-End Journeys` table in `DESIGN/DATA-FLOW.md` must declare at least one verifiable journey step.

## Why it blocks

Without end-to-end journeys, isolated unit features cannot be demonstrated or validated as cohesive user flows.

## How to fix

Add user journey steps describing the trigger, actor action, system mutation, and observable result in `DESIGN/DATA-FLOW.md`.
