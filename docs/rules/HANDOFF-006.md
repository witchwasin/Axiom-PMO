# HANDOFF-006 - Acceptance case has no execution classification

| | |
|---|---|
| Level | FAIL |
| Gate | Handoff |
| Applies to | Standard, Strict |
| Artifacts | `DESIGN/BUILD-SPEC.md` |

## What this rule checks

Every row in the `### Acceptance Cases` table declares an `Execution` value from `pmo-config/handoff-policy.json` `acceptance_cases.execution_classes` - by default `automated`, `manual`, or `exploratory`.

## Why it blocks

Unclassified acceptance cases silently become nobody's job. The engineer assumes CI covers them; QA assumes they are automated; on demo day they have never been run. Classification is also what makes a test count as evidence later: an `automated` case must name a runner, a `manual` case must name a person.

## What the validator does not do

It does not check that an automated case is actually automated, that the runner exists, or that the split between automated and manual is sensible. That is the `automated_manual_test_split` review lens.

## How to fix

```markdown
### Acceptance Cases

Status: specified

| Case ID | Requirement Ref | Given / When / Then | Execution | Fixture / Seed | Reset |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | Given stock of 5, when 2 are consumed, then 3 remain | automated | seed-stock-basic | reset-demo.sql |
| AC-002 | REQ-002 | Given a printed label, when scanned, then the part opens | manual | seed-labels-10 | reprint from seed |
```

## Related

`HANDOFF-007` (seed and reset), `TEST-SUMMARY-001` (release-time test evidence).
