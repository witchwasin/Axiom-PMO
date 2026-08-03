# AREV-001 - Adversarial review artifact presence

| | |
|---|---|
| Level | INFO/none (Lite, disabled) / WARN (Standard) / FAIL (Strict) / PASS |
| Runs when | `scripts/verify-execution-result.ps1` is invoked without `-Preflight` |
| Artifacts | `EXECUTION-REVIEW.json` |

## What this rule checks

Whether `EXECUTION-REVIEW.json` exists beside the execution contract and
parses as JSON, at the enforcement level `pmo-config/adversarial-review-policy.json`
declares for the project's effective mode: `Lite` disabled (no diagnostic at
all), `Standard` advisory (WARN, non-blocking), `Strict` required (FAIL).

## Why it exists

Deterministic rules cannot reach every defect class -- a behaviour change
inside an approved file, a test that passes while testing the wrong thing, an
implementation that satisfies the letter of an acceptance criterion and not
its intent. Adversarial review evidence exists for exactly that gap. It is
candidate evidence, never authority: a review's own verdict never changes a
validator exit code. See
[`docs/architecture/adversarial-review.md`](../architecture/adversarial-review.md).

## How to fix

Produce a review and record it as `EXECUTION-REVIEW.json`, using
`templates/EXECUTION-REVIEW.json`.

## See also

[`AREV-002`](AREV-002.md) through [`AREV-006`](AREV-006.md) — everything else
this artifact must satisfy once it exists.
