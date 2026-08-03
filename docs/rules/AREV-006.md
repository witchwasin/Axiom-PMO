# AREV-006 - Finding decision-record binding

| | |
|---|---|
| Level | FAIL |
| Runs when | `EXECUTION-REVIEW.json` is present |
| Artifacts | `EXECUTION-REVIEW.json`, `decision-log.md` |

## What this rule checks

A finding whose status is `false_positive`, `accepted_risk`, or `deferred`
must cite a `decision_ref` that resolves to a real, unique row in
`decision-log.md` (`Resolve-DecisionRecord`, the same resolver `EXEC-007`
uses), and that row must not have been added or edited within the commit
range under verification.

## Why it exists

Accepting a risk or deferring work is a human judgement in every mode. A
finding closed under any of these statuses is a claim that someone decided
something; that claim needs a resolvable, independent decision reference —
not a citation to a decision the same execution's own commits could have
introduced, which would be the execution writing its own permission slip
(the identical reasoning `EXEC-007` applies to authority claims generally).

## How to fix

Record the decision in `decision-log.md` first, as a row that predates the
commit range under verification, then cite its `DEC-###` id.

## See also

[`AREV-005`](AREV-005.md), [`EXEC-007`](EXEC-007.md)
