# HANDOFF-008 - Demo milestone lacks capacity, integrator, device, or reset path

| | |
|---|---|
| Level | FAIL |
| Gate | Handoff |
| Applies to | Handoff Target `demo` or `pilot` |
| Artifacts | `HANDOFF.md` |

## What this rule checks

When the handoff target is `demo` or `pilot`, the `## Demo Milestone` table declares every field in `pmo-config/handoff-policy.json` `handoff_document.demo_milestone_fields`:

| Field | Meaning |
|---|---|
| Demo Date | When it happens |
| Demo Device | The actual hardware it runs on |
| Integrator | The named person who makes the streams work together |
| Capacity | Person-days available before the date |
| Reset Path | How to return to a clean demo state |
| Degraded Path | What is shown if the primary path fails live |

`Integrator` must be a name, not a generic token.

## Why it blocks

A demo has a device, a room, and a clock. Work that is "done" on a developer laptop and has never run on the demo tablet is not ready, and nobody owns finding that out. The degraded path matters for the same reason: the fallback has to be decided before the room is full, not during.

## What the validator does not do

It does not check that the stated capacity is sufficient, that the device is available, or that the reset path works. Those are the `ownership_and_capacity` and `demo_startup_reset_and_recovery` review lenses.

## How to fix

```markdown
## Demo Milestone

| Field | Value |
|---|---|
| Demo Date | 2026-08-05 |
| Demo Device | Client-supplied Android tablet, Chrome 126 |
| Integrator | R. Silva |
| Capacity | 6 person-days across 2 engineers |
| Reset Path | scripts/reset-demo.sh restores the seed dataset in under 30s |
| Degraded Path | Manual part entry replaces scanning if the camera is unavailable |
```

## Related

`HANDOFF-003` (named owner), `HANDOFF-012` (device capability decisions).
