# AREV-002 - Review contract/commit identity

| | |
|---|---|
| Level | FAIL |
| Runs when | `EXECUTION-REVIEW.json` is present |
| Artifacts | `EXECUTION-REVIEW.json` |

## What this rule checks

That the review's `contract_sha256`, `base_sha`, and `head_sha` all match the
execution contract and commits under verification.

## Why it exists

Without this binding, a review of unrelated work — an old contract version, a
different commit range — could be cited as if it covered the execution
actually being verified. This is the same identity discipline `EXEC-002`
already applies to the contract itself and `EXEC-003` applies to the result.

## How to fix

Re-generate the review against the exact `contract_sha256` and commit range
being verified.

## See also

[`AREV-001`](AREV-001.md), [`docs/architecture/adversarial-review.md`](../architecture/adversarial-review.md)
