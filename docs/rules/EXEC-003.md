# EXEC-003 - Result identity does not match the contract

| | |
|---|---|
| Level | FAIL |
| Runs when | `node cli/axiom.mjs verify` is invoked |
| Artifacts | `EXECUTION-RESULT.json` |

## What this rule checks

The result is about the same work the contract approved:

- `work_item_id` matches the contract's.
- `base_sha` matches the contract's.
- Every entry in the result's `requirement_refs` appears in the contract's `requirement_refs`.

## Why it exists

A digest match (`EXEC-002`) proves the result is answering *this contract file*. It does not prove the result is about *this work* — those are different questions, and a result can pass the first while failing the second.

**Requirement drift is deliberately asymmetric.** A result may satisfy *fewer* requirements than approved: partial work is a legitimate, declarable state (`execution_status: "partial"`), and reporting it honestly is exactly what the framework wants. A result may never introduce a requirement the contract does not list — that is scope expansion wearing a different label, and it is how "while I was in there, I also…" becomes unreviewed work.

A mismatched `base_sha` matters for the same reason the contract pins an exact commit rather than a branch name: work that did not start from the approved base is not the work that was approved, however similar it looks.

## How to fix

Correct the result to name the work item, base commit, and requirements the contract actually covers.

If the work genuinely grew — a new requirement really did need implementing — that is a scope change, not a reporting detail. Get the work item updated and approved, export a fresh contract, and run against that.

## Related

`EXEC-002` (result answers a different contract *version*), `EXEC-004` (right work item, wrong files), `EXEC-008` (base/head that git cannot reconcile).
