# EXEC-001 - Execution result missing or malformed

| | |
|---|---|
| Level | FAIL (also the PASS row for a clean verification) |
| Runs when | `node cli/axiom.mjs verify` is invoked |
| Artifacts | `EXECUTION-RESULT.json` |

## What this rule checks

The result document exists, parses as JSON, and carries the fields verification needs: `contract_version`, `work_item_id`, `contract_sha256`, `base_sha`, and a valid `execution_status` (`completed`, `partial`, `blocked`, or `failed`).

This rule id also carries the **PASS** row emitted when a result verifies cleanly against its contract and observed git state, so a consumer filtering on `EXEC-001` sees both the "could not read it" and "read it, it checks out" outcomes in one place.

## Why it exists

Every other check in this family reads fields out of the result. A malformed or half-filled document has to fail here, once, with a message about the document — rather than producing eight confusing downstream failures about fields that were never there.

`contract_sha256` is shape-checked (64 lowercase hex characters) at this stage deliberately: a truncated or placeholder digest is a schema problem with a schema-shaped fix, and reporting it as a digest *mismatch* would send the reader looking for tampering that did not happen.

## How to fix

Produce `EXECUTION-RESULT.json` against the shape in [`docs/reference/execution-contract.md`](../reference/execution-contract.md). Minimum viable document:

```json
{
  "contract_version": "1.0",
  "work_item_id": "D-001",
  "contract_sha256": "<the digest printed by axiom export>",
  "base_sha": "<the contract's base_sha>",
  "head_sha": "<the commit the work ended at>",
  "execution_status": "completed"
}
```

## Related

`EXEC-002` (the contract side of the same pairing), `EXEC-008` (the result parses but its claims do not match observed git state).
