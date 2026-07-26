# HANDOFF-003 - Work item has no named owner

| | |
|---|---|
| Level | FAIL (Standard, Strict) / WARN (Lite) |
| Gate | Handoff |
| Applies to | Lite, Standard, Strict |
| Artifacts | `HANDOFF.md`, `DELIVERY.md` |

## What this rule checks

Every owner field in the handoff scope holds a name rather than a generic token:

- `Handoff Owner` and `Named Integrator` in the metadata block
- `Owner` on each `Build Now` row
- `Owner` on each build-sequence step
- `Owner` in `DELIVERY.md` for every work item the handoff pulls in
- `Integrator` in the demo milestone

Generic tokens are configured in `pmo-config/handoff-policy.json` under `owner_policy.generic_tokens` - by default `TBD`, `Unassigned`, `Dev Team`, `Team`, `N/A`, and similar. Comparison is case-insensitive and trimmed.

## Why it blocks

"Dev Team" is an answer that survives a status meeting and dies on Monday morning. When two streams have to converge before a demo, the integration itself needs an owner; otherwise each stream owner reasonably assumes the other is handling it.

## What the validator does not do

It does not check that the named person exists, is available, has the right skills, or has capacity. It only distinguishes a name from a placeholder. Capacity is the `ownership_and_capacity` review lens.

## How to fix

Replace the token with a person.

```markdown
| Step | Work Item Ref | Depends On | Owner | Notes |
|---|---|---|---|---|
| 1 | D-001 | none | R. Silva | Shared schema and part master |
```

To adjust which tokens count as generic, edit `owner_policy.generic_tokens`. Do not edit it to make a failing project pass.

## Related

`HANDOFF-008` (demo integrator), `HANDOFF-009` (open action owner), `WORKITEM-001` (owner column present at all).
