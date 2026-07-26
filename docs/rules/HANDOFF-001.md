# HANDOFF-001 - Required handoff artifact missing

| | |
|---|---|
| Level | FAIL |
| Gate | Handoff |
| Applies to | Lite, Standard, Strict |
| Artifacts | `HANDOFF.md`, `DESIGN/BUILD-SPEC.md` |

## What this rule checks

1. `HANDOFF.md` exists. Without it there is no developer entry point and no other handoff rule can run.
2. Its metadata block declares every field required for the project's mode: project, mode, handoff target, horizon, handoff owner, named integrator, and (Standard/Strict) a build-spec reference.
3. `Handoff Target` is one of the values in `pmo-config/handoff-policy.json` `handoff_targets`.
4. `DESIGN/BUILD-SPEC.md` exists when the mode requires it.

## Why it blocks

A handoff without a target and a horizon is a wish, not a commitment. "Build this" and "build this so it can be demonstrated on a borrowed tablet in three days" produce different engineering decisions, and the developer cannot infer which one applies.

## What the validator does not do

It does not judge whether the horizon is realistic, whether the named owner has capacity, or whether the target is the right one. Those are review questions - see `HANDOFF-010`.

## How to fix

Copy `templates/HANDOFF.md` into the project root and fill the metadata block. Leave nothing as `<placeholder>`, `TBD`, or blank.

```markdown
- Project: P01-DEMO
- Mode: Standard
- Handoff Target: demo
- Horizon: 2026-08-05
- Handoff Owner: A. Nakamura (Delivery Lead)
- Named Integrator: R. Silva (Senior Engineer)
- Build Spec Ref: DESIGN/BUILD-SPEC.md
```

## Related

`HANDOFF-002` (scope contract), `HANDOFF-005` (build-spec sections), `STRUCT-001` (generic artifact presence).
