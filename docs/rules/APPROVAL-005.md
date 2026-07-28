# APPROVAL-005 - Approval approver is a generic group

| | |
|---|---|
| Level | FAIL (Standard, Strict) / WARN-blocking (Lite) |
| Gate | Scope, Design, Release (any gate with an approval row) |
| Applies to | Lite, Standard, Strict |
| Artifacts | `PROJECT.md` Approvals table |

## What this rule checks

The `Approver` cell of an approval row must name a person, not a generic group. The same `owner_policy.generic_tokens` that `HANDOFF-003` uses for handoff owners applies here: `Dev Team`, `Engineering`, `Team`, `Unassigned`, `N/A`, `-`, and the rest configured in `pmo-config/handoff-policy.json`. Comparison is case-insensitive and trimmed.

Severity follows `owner_policy.severity_by_mode`: WARN-blocking at Lite, FAIL at Standard and Strict.

## Why it blocks

"Approved by Engineering" answers the question "was this approved?" with a noun that cannot be asked a follow-up. When a release goes wrong, the name in the approval row is who gets asked why. A group name makes the approval untraceable - the same failure `HANDOFF-003` prevents on the delivery side, now closed on the approval side where the accountability actually lands.

## What the validator does not do

It does not check that the named person has authority for that gate, that they were the right person, or that they are available. `APPROVAL-003` covers the *role* matrix; this rule only distinguishes a name from a placeholder.

## How to fix

Replace the group with the person who approved.

```markdown
| Release Approved | approved | R. Silva | Tech Lead | 2026-07-28 | DEC-014 |
```

To adjust which tokens count as generic, edit `owner_policy.generic_tokens`. Do not edit it to make a failing project pass.

## Related

`HANDOFF-003` (named owners in the handoff scope), `APPROVAL-002` (placeholder fields), `APPROVAL-003` (approver role matrix).
