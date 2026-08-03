# AREV-005 - Finding closure authority

| | |
|---|---|
| Level | FAIL |
| Runs when | `EXECUTION-REVIEW.json` is present |
| Artifacts | `EXECUTION-REVIEW.json`, `EXECUTION-RESULT.json` |

## What this rule checks

Two authority violations:

1. A finding under a **human-only category** (`security`, `legal`,
   `business`, `privacy`) was set to `resolved` by a non-human reviewer
   (`reviewer_kind` is not `human`). An AI reviewer may never close a
   human-only-category finding under any status, whatever a cited decision
   reference says — mirrors [`HANDOFF-010`](HANDOFF-010.md) exactly.
2. `EXECUTION-RESULT.json` itself claims (via `review_finding_dispositions`)
   that the executor set a finding to any status other than `open` or
   `disputed`. The executor may only move a finding to `disputed`, with
   evidence — `disputed` is not a closure and remains blocking. It may never
   set `resolved`, `false_positive`, `accepted_risk`, `deferred`, or any
   other closure or acceptance state.

## Why it exists

Authority attaches to **role** (reviewer / executor / human), never to
*kind* (ai / human): a human executor is still an executor, and an AI
serving as a human-attested reviewer's assistant still cannot self-close. An
actor that can close the findings raised against its own work is not being
reviewed.

## How to fix

Route a human-only-category finding to a human reviewer for closure. Have
the executor record disagreement only as `disputed`, with evidence, and let
a reviewer or human decide the outcome.

## See also

[`AREV-004`](AREV-004.md), [`AREV-006`](AREV-006.md)
