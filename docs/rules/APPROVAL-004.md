# APPROVAL-004 - Approval evidence is an unverifiable external link

| | |
|---|---|
| Level | FAIL |
| Gate | Scope, Design, Release (any gate that resolves approval evidence) |
| Applies to | Standard, Strict |
| Artifacts | `PROJECT.md` Approvals table |

## What this rule checks

At Standard and Strict, the evidence behind an approval row must be a reference this validator can check against the project itself - a `DEC-###` from `decision-log.md` or a `FILE:` inside the project. An external link (`URL:`, `ISSUE:`, `CI:`) has a valid shape and resolves, but the validator cannot prove a human actually decided anything behind it.

This rule does **not** apply to Lite. Lite may use light evidence (including `ISSUE:`), surfaced as a blocking WARN by `APPROVAL-002` rather than a hard FAIL.

## Why it blocks

An approval is the moment accountability transfers from the work to a named human decision. A `URL:` to a wiki page or an `ISSUE:` number is shape without verification: it can exist, say anything, and be edited by anyone. Accepting it as approval evidence lets a release claim pass on a link nobody checked - exactly the false assurance the framework exists to remove.

The `ExternallyUnverified` flag was computed by the reference resolver all along; this rule is what makes it mean something at the approval gate.

## What the validator does not do

It does not open the URL, read the issue, or check who wrote it. It cannot - and pretending it could would be the same false assurance. It only refuses to treat an unverifiable external link as if it were a checked, in-project decision.

## How to fix

Record the decision in `decision-log.md` and reference the `DEC-###`, or attach an in-project `FILE:` that holds the approval record.

```markdown
| Release Approved | approved | R. Silva | Tech Lead | 2026-07-28 | DEC-014 |
```

## Related

`APPROVAL-002` (evidence missing or unresolvable), `REF-001` (reference resolution), `HANDOFF-010` (semantic review is evidence, not approval).
