# HANDOFF-007 - Acceptance case has no seed or fixture strategy

| | |
|---|---|
| Level | FAIL |
| Gate | Handoff |
| Applies to | Standard, Strict |
| Artifacts | `DESIGN/BUILD-SPEC.md` |

## What this rule checks

Every row in `### Acceptance Cases` declares:

- `Fixture / Seed` - the data the case starts from
- `Reset` - how to return to that starting state

Neither may be blank or a placeholder.

## Why it blocks

A demo is a sequence of states, and the second run of a demo starts from wherever the first one ended. Without a declared reset path the presenter is improvising against a database they have already mutated.

The related trap is an acceptance case that cannot be reached from the seed data at all - a case that asserts behaviour on a record type the seed never creates. Declaring the seed per case is what makes that mismatch visible.

## What the validator does not do

It does not verify that the named fixture exists, contains what the case needs, or that the case is actually reachable from it. Reachability is the `acceptance_seed_reachability` review lens.

## How to fix

Name the fixture and the reset path per case. When a case genuinely needs no seed, write `none` - that is a declaration, unlike a blank cell.

## Related

`HANDOFF-006` (execution class), `HANDOFF-008` (demo reset path).
