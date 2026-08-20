# TEST-COVERAGE-001 - Derived test case count sufficiency

| | |
|---|---|
| Level | FAIL |
| Gate | Design, Handoff, Release |
| Applies to | Standard, Strict (when `Spec depth: full`) |
| Artifacts | `TESTS/TEST-CASES.md` |

## What this rule checks

Under `Spec depth: full`:
The total volume of declared test cases in `TESTS/TEST-CASES.md` must satisfy the derived mathematical minimum for the project's governance mode:
- Standard: at least 1 test case per scoped requirement.
- Strict: at least 2 test cases per scoped requirement (happy + negative/boundary) plus coverage across operational risk dimensions.

## Why it blocks

A high-risk project cannot be declared ready for engineering handoff with shallow test coverage. The test case inventory must match the complexity and risk profile of the specification.

## How to fix

Expand the test case inventory in `TESTS/TEST-CASES.md` to cover negative, boundary, security, and concurrency scenarios.
