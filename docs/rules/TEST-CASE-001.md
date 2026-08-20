# TEST-CASE-001 - Test cases completeness and criteria definition

| | |
|---|---|
| Level | FAIL |
| Gate | Design, Handoff, Release |
| Applies to | Standard, Strict (when `Spec depth: full`) |
| Artifacts | `TESTS/TEST-CASES.md` |

## What this rule checks

In `TESTS/TEST-CASES.md`:
1. The artifact exists and declares `### Test Cases Inventory`.
2. Every test case row declares non-empty `Case ID`, `Description`, `Expected Result`, and `Pass Criteria`.
3. No critical test fields contain `<placeholder>` or TBD markers.

## Why it blocks

Unspecified test cases with vague assertions (e.g. "it should work") prevent verifiable engineering validation and automated test execution.

## How to fix

Define explicit inputs, actions, expected system behaviors, and unambiguous pass criteria for each test case row in `TESTS/TEST-CASES.md`.
