# TEST-COVERAGE-001 - Specification depth test coverage matrix

| | |
|---|---|
| Level | FAIL |
| Gate | Design, Handoff, Release |
| Applies to | Lite, Standard, Strict (when `Spec depth: full`) |
| Artifacts | `TESTS/TEST-CASES.md`, `pmo-config/depth-policy.json` |

## What this rule checks

Under `Spec depth: full`:
Every declared specification element (`requirement`, `business_rule`, `nfr`, `data_constraint`, `api_operation`, `state_transition`, `journey_step`, `strict_trigger`) must have matching test cases covering all required categories defined in the active mode profile in `pmo-config/depth-policy.json`:
- **Lite (`delivery_checklist`)**: `requirement × [happy]`
- **Standard (`strategy_and_scenarios`)**: `requirement × [happy, negative]`, `business_rule × [happy, negative]`, `api_operation × [happy, negative]`, `state_transition × [happy, negative]`
- **Strict (`detailed_requirement_and_risk_cases`)**:
  - `requirement × [happy, negative, boundary, security]`
  - `business_rule × [happy, negative, boundary]`
  - `nfr × [happy, boundary]`
  - `data_constraint × [happy, negative]`
  - `api_operation × [happy, negative, security]`
  - `state_transition × [happy, negative, recovery]`
  - `journey_step × [happy]`
  - `strict_trigger × [security, negative]`

## Why it blocks

A high-risk project cannot be declared ready for engineering handoff with shallow test coverage. The test case matrix must cover every functional and architectural element across positive, negative, security, boundary, and recovery dimensions.

## How to fix

Add the missing `(Target ID, Category)` test case rows to `TESTS/TEST-CASES.md`.
