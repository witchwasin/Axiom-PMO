# HANDOFF-002 - Scope contract incomplete

| | |
|---|---|
| Level | FAIL |
| Gate | Handoff |
| Applies to | Lite, Standard, Strict |
| Artifacts | `HANDOFF.md`, `DELIVERY.md` |

## What this rule checks

1. `## Build Now` has at least one row, and every `Work Item Ref` resolves to a work item that exists in `DELIVERY.md`.
2. `## Deferred / Do Not Build` exists and either has rows or explicitly says `none`.
3. `## Hard Constraints` exists and either has rows or explicitly says `none`.
4. `## Definition of Done` has at least one row.

## Why it blocks

The expensive failure in a short handoff is not building the wrong thing - it is building the *extra* thing. A developer with an ambiguous scope will fill the gap with reasonable assumptions, and reasonable assumptions cost days.

An empty section is not the same as a decision. "Nothing is deferred" is a claim someone made; a blank heading is a question nobody asked. That is why the explicit `none` token is required.

## What the validator does not do

It does not judge whether the slice delivers the value the milestone needs. A scope can be perfectly declared and still be the wrong scope - that is the `value_and_scope_slice` review lens.

## How to fix

```markdown
## Deferred / Do Not Build

| Item | Decision | Reason | Decision Ref |
|---|---|---|---|
| Multi-warehouse stock | deferred | Single site only for the demo | DEC-004 |
```

Or, when there genuinely is nothing:

```markdown
## Deferred / Do Not Build

none
```

## Related

`HANDOFF-004` (build order), `HANDOFF-010` (is the slice the right slice).
