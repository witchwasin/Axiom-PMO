# HANDOFF-014 - Handoff artifact names a different project

| | |
|---|---|
| Level | FAIL |
| Gate | Handoff |
| Applies to | Lite, Standard, Strict |
| Artifacts | `HANDOFF.md`, `HANDOFF-REVIEW.json` |

## What this rule checks

`PROJECT.md`'s heading is the project's declaration of its own identity:

```markdown
# PROJECT - P02-WORKSHOP
```

Every handoff artifact that names a project must agree with it:

| Artifact | Field |
|---|---|
| `HANDOFF.md` | `Project` in the metadata block |
| `HANDOFF-REVIEW.json` | `project_code` |

Comparison is case-sensitive after trimming.

## Why it blocks

`HANDOFF-001` already requires `Project` to be present and non-placeholder. It
stopped there, which left this field the only one in the metadata block checked
against nothing:

| Field | Checked against |
|---|---|
| `Mode` | the effective mode resolved for the run |
| `Horizon` | ISO-8601 date validity |
| `Build Spec Ref` | a file that exists |
| `Project` | *(nothing, before this rule)* |

The exposure is a project started by copying another — which is exactly what the
handoff artifacts invite, since a filled-in `HANDOFF.md` is the most useful
starting point for the next one. The old project code comes along, every other
check passes, and the handoff sheet names a project that is not the one being
validated. A reader months later cannot tell which of the two documents is
wrong.

This rule found the defect in this repository's own `demo/` projects, which had
been copied from `examples/HANDOFF-DEMO` with only their headings changed.

## Why the heading and not the folder

A project can legitimately live in a differently named directory — a client
folder, a monorepo path, a temporary working copy. The heading is what the
project says about itself, so it is the authority. The folder name is not
consulted.

## What the validator does not do

It does not check that the project code is *well-formed*, follows a naming
convention, or matches an external registry. It checks only that the artifacts
agree with each other.

## How to fix

Make the handoff artifacts match `PROJECT.md`:

```markdown
- Project: P02-WORKSHOP
```

```json
"project_code": "P02-WORKSHOP"
```

If the heading is the thing that is wrong, fix that instead — but change one
place, then re-run, rather than editing until the error stops.

## Related

`HANDOFF-001` (metadata completeness), `HANDOFF-010` (the review is also checked
for freshness and closure authority).
