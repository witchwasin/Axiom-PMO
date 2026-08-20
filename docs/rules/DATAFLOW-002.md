# DATAFLOW-002 - Data Dictionary sensitive classification agreement

| | |
|---|---|
| Level | FAIL |
| Gate | Design, Handoff, Release |
| Applies to | Standard, Strict (when `Spec depth: full`) |
| Artifacts | `DESIGN/DATA-DICTIONARY.md`, `DESIGN/BUILD-SPEC.md` |

## What this rule checks

In `DESIGN/DATA-DICTIONARY.md`:
Any field classified as sensitive (`confidential`, `restricted`, `sensitive`, `pii`, or `secret`) must agree with and be declared in `DESIGN/BUILD-SPEC.md` under `### Security, Privacy and Data Inventory`.

## Why it blocks

Discrepancies between field-level classifications and project-level privacy/security commitments lead to unmanaged compliance and data leakage risks.

## How to fix

Ensure all sensitive fields identified in `DESIGN/DATA-DICTIONARY.md` are documented in the Security, Privacy and Data Inventory table in `DESIGN/BUILD-SPEC.md`.
