# HANDOFF - STANDARD-FEATURE

> The developer entry point. Someone who has read nothing else should be able to
> start from this page, know what to build first, know who to ask, and know what
> would stop the demo.
>
> Validated by `scripts/validate-project.ps1 -Gate Handoff`.

- Project: STANDARD-FEATURE
- Mode: Standard
- Handoff Target: internal
- Horizon: 2026-07-10
- Handoff Owner: Demo PM
- Named Integrator: Demo Dev
- Build Spec Ref: DESIGN/BUILD-SPEC.md

## Build Now

| Item | Work Item Ref | Value Delivered | Owner |
|---|---|---|---|
| Ticket status board (4-column move, Done review-notes guard) | D-001 | Lets support staff track and move tickets through the delivery pipeline, replacing the previous ticket list with no status visibility | Demo Dev |

## Deferred / Do Not Build

| Item | Decision | Reason | Decision Ref |
|---|---|---|---|
| Priority filter for open high-priority tickets | deferred | Filter UX needs more validation with PM before build | RELEASE.md Release Scope (D-002) |

## Hard Constraints

| Constraint | Type | Source Ref |
|---|---|---|
| A ticket cannot move to Done without review notes | technical | REQ-20260710 row 2, BR-001 |
| Internal staff tool only — no customer-facing portal | commercial | PROJECT.md Out of Scope |

## Build Sequence and Dependencies

| Step | Work Item Ref | Depends On | Owner | Notes |
|---|---|---|---|---|
| 1 | D-001 | none | Demo Dev | Status board is the entire scope of this handoff; D-002 is deferred and out of sequence |

## Environment and Device Matrix

| Environment | Target Device / Browser | Serving Model | Decision Ref |
|---|---|---|---|
| internal | Staff desktop workstation, current browser | Standard web app over the internal network, same-origin static bundle + JSON API | DEC-004 |

## Definition of Done

| Criterion | Verification | Owner |
|---|---|---|
| TEST-001, TEST-002 (status move happy path, Done guard exception path) pass | `RELEASE.md` Test Summary | Demo QA Lead |
| Board shows all four columns and cards render title, priority, owner | Manual review against `DESIGN/WIREFRAME.md` WF-001 | Demo Dev |

## Open Actions

none

## Blocking Points

- **Before build:** none.
- **Before integration:** none.
- **Before demo:** not applicable — Handoff Target is `internal`, no demo scheduled.
- **Before UAT:** not applicable to this handoff.
- **Before release:** none — this handoff documents the slice already shipped as D-001 (see `RELEASE.md`).

## Key Links

- Requirements: `PROJECT.md`
- Flow: `DESIGN/FLOW.puml`
- Wireframe: `DESIGN/WIREFRAME.md`
- Technical spec: `DESIGN/BUILD-SPEC.md`
- Work items: `DELIVERY.md`
- RAID: `RAID-log.md`
- Decisions: `decision-log.md`
- Release: `RELEASE.md`
