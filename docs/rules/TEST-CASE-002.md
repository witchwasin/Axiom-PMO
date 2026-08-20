# TEST-CASE-002 - Test case uniqueness, categories, and target linkage

| | |
|---|---|
| Level | FAIL |
| Gate | Design, Handoff, Release |
| Applies to | Standard, Strict (when `Spec depth: full`) |
| Artifacts | `TESTS/TEST-CASES.md` |

## What this rule checks

In `TESTS/TEST-CASES.md`:
1. Every `Case ID` is unique across the project.
2. `Category` belongs to the configured test categories: `happy`, `negative`, `boundary`, `security`, `concurrency`, `recovery`.
3. `Target ID` resolves against declared requirements (`REQ-###`), business rules, NFRs, constraints, operations, or state transitions.

## Why it blocks

Duplicate test IDs disrupt test run reporting, and unrecognized categories obscure the true multidimensional testing distribution.

## How to fix

Ensure all test case IDs are unique and link to valid declared project specification targets.
