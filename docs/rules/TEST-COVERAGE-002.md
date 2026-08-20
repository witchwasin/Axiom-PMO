# TEST-COVERAGE-002 - Scoped requirements coverage completeness

| | |
|---|---|
| Level | FAIL |
| Gate | Design, Handoff, Release |
| Applies to | Standard, Strict (when `Spec depth: full`) |
| Artifacts | `TESTS/TEST-CASES.md`, `PROJECT.md` |

## What this rule checks

Under `Spec depth: full`:
Every requirement (`REQ-###`) declared in the `In Scope` table of `PROJECT.md` must be targeted by at least one test case in `TESTS/TEST-CASES.md`.

## Why it blocks

Uncovered requirements leave functional gaps unverified, increasing defect escape rates to production.

## How to fix

Add test cases in `TESTS/TEST-CASES.md` targeting the uncovered `REQ-###` IDs.
