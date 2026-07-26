# HANDOFF-004 - Dependency or build sequence incomplete

| | |
|---|---|
| Level | FAIL |
| Gate | Handoff |
| Applies to | Lite, Standard, Strict |
| Artifacts | `HANDOFF.md` |

## What this rule checks

In `## Build Sequence and Dependencies`:

1. Every `Step` is a number, and no step number is reused.
2. Every `Work Item Ref` resolves to a work item in `DELIVERY.md`.
3. Every row declares `Depends On` - either a list of work items or the literal `none`. Blank is not an answer.
4. Every declared dependency is itself scheduled somewhere in the sequence.
5. **A dependency is scheduled at a lower step than the item that consumes it.**
6. Every `Build Now` item appears somewhere in the sequence.

## Why it blocks

Check 5 is the one that matters. Work-item numbering is not build order, and teams routinely write a plan where item D-003 needs the shared schema that D-005 creates. Nothing in the document is false; the plan is simply not executable in the order it declares. A developer discovers this on day one, not at planning time.

This is provable from the declared step numbers alone, which is why it belongs in the deterministic validator rather than in review.

## What the validator does not do

It does not estimate whether the sequence fits the horizon, and it does not detect a missing prerequisite that nobody wrote down. A dependency that exists in reality but not in the table is invisible here - that is the `dependencies_and_build_order` review lens.

## How to fix

Move shared prerequisites to an earlier step.

```markdown
| Step | Work Item Ref | Depends On | Owner | Notes |
|---|---|---|---|---|
| 1 | D-005 | none | R. Silva | Shared schema + part master (prerequisite) |
| 2 | D-003 | D-005 | K. Owusu | Consumes the part master |
```

## Related

`HANDOFF-002` (Build Now scope), `HANDOFF-003` (step owner).
