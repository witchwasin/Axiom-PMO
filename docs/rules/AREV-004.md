# AREV-004 - Finding schema validity

| | |
|---|---|
| Level | FAIL |
| Runs when | `EXECUTION-REVIEW.json` is present |
| Artifacts | `EXECUTION-REVIEW.json` |

## What this rule checks

Every entry in `findings[]` carries a non-empty `finding_id`, a `severity`
and `category` and `status` from the enums in
`pmo-config/adversarial-review-policy.json`, and a non-empty `description`
and `suggestion`.

## Why it exists

A finding a later stage cannot parse or locate is not actionable — the same
reasoning `WORKITEM-001` applies to `DELIVERY.md` rows.

## How to fix

Fill every required field on every finding.

## See also

[`AREV-005`](AREV-005.md), [`AREV-006`](AREV-006.md) — what happens to a
finding's `status` after it is well-formed.
