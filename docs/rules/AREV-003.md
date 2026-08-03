# AREV-003 - Review provenance tier

| | |
|---|---|
| Level | FAIL (at an enforcement level requiring the tier to stand alone) / PASS |
| Runs when | `EXECUTION-REVIEW.json` is present |
| Artifacts | `EXECUTION-REVIEW.json`, `decision-log.md`, GitHub Checks API (for `externally-observed`) |

## What this rule checks

`provenance.tier` must be one of `artifact-observed`, `externally-observed`,
or `human-attested` (reusing `pmo-config/execution-contract-policy.json`'s
existing `evidence_provenance` vocabulary rather than a parallel one). At an
enforcement level where the tier must satisfy a required check on its own:

- **`artifact-observed`** never satisfies alone — the executing agent can
  write this file in a path it controls. It needs a human
  `review-evidence-accepted` authority claim, bound to this contract, citing
  a decision record that resolves in `decision-log.md` and was not itself
  edited within the commit range under verification (the same promotion
  pattern `EXEC-005`/`EXEC-007` already use for test evidence).
- **`externally-observed`** requires all four bindings in
  [`docs/architecture/adversarial-review.md`](../architecture/adversarial-review.md)
  §3.3 to resolve: the `check_run_id` binding (reusing `EXEC-005`'s
  `Test-CiCheckEvidence` unchanged), the check run's own API-attested output
  carrying the real artifact digest, the pinned review workflow's content
  digest at the commit being verified, and contract/commit identity.
- **`human-attested`** requires the named reviewer not be the same actor as
  the executor.

## Why it exists

A `check_run_id` alone proves a CI job ran, not that an independent review
produced the artifact — the Milestone 5 round-2 self-attestation defect one
level up. See the research document for the full reasoning.

## How to fix

Use `human-attested` (a named person who is not the executor) if no pinned
CI review workflow exists yet, or have a human record a
`review-evidence-accepted` claim for an `artifact-observed` review.

## See also

[`AREV-001`](AREV-001.md), [`AREV-002`](AREV-002.md),
[`docs/architecture/adversarial-review.md`](../architecture/adversarial-review.md)
