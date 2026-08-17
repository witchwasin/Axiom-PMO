# HANDOFF-009 - Open action has no owner or blocking point

| | |
|---|---|
| Level | FAIL |
| Gate | Handoff |
| Applies to | Lite, Standard, Strict |
| Artifacts | `HANDOFF.md` |

## What this rule checks

Every row in `## Open Actions` declares:

- an `Owner` that is a name, not a generic token
- a `Blocking Point` from the enum in `pmo-config/handoff-policy.json` `blocking_points`

| Blocking point | Meaning |
|---|---|
| `before_build` | Nobody can start coding until this is resolved |
| `before_integration` | Streams cannot be merged until this is resolved |
| `before_demo` | Coding can proceed; the demo cannot happen |
| `before_uat` | The demo can happen; UAT cannot start |
| `before_release` | Everything else can proceed; release cannot |
| `non_blocking` | Tracked, blocks nothing |

## Why it blocks

This enum is the reason the Handoff gate reports stages instead of a single pass/fail. An unresolved serving model for a QR scanner blocks the demo but does not stop a developer from writing the domain logic today. Collapsing that into "not ready" stalls a team that could be working; collapsing it into "ready" produces a demo-day surprise.

An open action with no owner is not tracked, it is merely written down.

## What the validator does not do

It does not judge whether the declared blocking point is the correct one. Mislabelling a `before_build` issue as `before_demo` is a review finding, not a validator finding.

## How to fix

```markdown
## Open Actions

| Action ID | Description | Owner | Blocking Point | Status |
|---|---|---|---|---|
| OA-001 | Decide how the scanner page is served to the tablet | A. Nakamura | before_demo | open |
| OA-002 | Confirm the client supplies the demo tablet | A. Nakamura | before_demo | open |
```

When there are none, write `none` under the heading.

## Open actions are real blockers

`axiom handoff` builds each stage's blocker list from **two** sources: open findings in `HANDOFF-REVIEW.json` and open rows in this table. Reading only the review would let a project close every finding, leave both demo actions open, and still be told it is ready to demo.

A finding whose `item_id` names an action is the same blocker seen from two documents; it is counted once.

## Related

`HANDOFF-003` (named owner), `HANDOFF-010` (review findings also carry blocking points), `axiom handoff` (turns blocking points into stage verdicts).
