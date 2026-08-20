# TEST-CASE-003 - Test case source traceability and evidence status

| | |
|---|---|
| Level | FAIL |
| Gate | Design, Handoff, Release |
| Applies to | Standard, Strict (when `Spec depth: full`) |
| Artifacts | `TESTS/TEST-CASES.md` |

## What this rule checks

In `TESTS/TEST-CASES.md`:
1. Every test case row contains a `Source Ref` matching the source reference pattern.
2. Every test case row declares a valid `Evidence Status` from `pmo-config/policy.json` `enums.evidence_statuses`.

## Why it blocks

Unanchored test cases risk validating synthetic assumptions rather than stakeholder-approved business requirements.

## How to fix

Add authentic source references and declare evidence statuses for each test case row.
