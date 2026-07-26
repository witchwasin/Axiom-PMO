# HANDOFF - DEMO-BROKEN

> Developer entry point for the 2026-08-05 demonstration slice.
> Validated by `scripts/validate-project.ps1 -Gate Handoff`.

- Project: HANDOFF-DEMO
- Mode: Standard
- Handoff Target: demo
- Horizon: 2026-08-05
- Handoff Owner: A. Nakamura (Delivery Lead)
- Named Integrator: R. Silva (Senior Engineer)
- Build Spec Ref: DESIGN/BUILD-SPEC.md

## Build Now

| Item | Work Item Ref | Value Delivered | Owner |
|---|---|---|---|
| Part master and stock schema | D-001 | Every other item reads and writes through it | R. Silva |
| Scan to find a part | D-002 | The moment the demo is built around | K. Owusu |
| Consume and receive stock | D-003 | Shows the count moving in both directions, which is the point | Dev Team |
| Attach a photo to a part | D-004 | Requested by the sponsor; lowest priority of the four | K. Owusu |

## Deferred / Do Not Build

| Item | Decision | Reason | Decision Ref |
|---|---|---|---|
| Multi-warehouse stock | deferred | The demo covers a single site | DEC-004 |
| In-app camera capture for photos | deferred | Keeps the camera dependency on the scanner path only | DEC-006 |
| Purchase orders and suppliers | do-not-build | Out of scope; would pull in a second domain | DEC-004 |

## Hard Constraints

| Constraint | Type | Source Ref |
|---|---|---|
| The demonstration is on 2026-08-05 and the date does not move | commercial | MOM-20260714 item 2 |
| It runs on the sponsor's Android tablet, not a laptop | technical | MOM-20260714 item 2 |
| Roughly six person-days across two engineers | operational | MOM-20260714 item 3 |
| Part photos stay on the site network | legal | MOM-20260714 item 5 |

## Build Sequence and Dependencies

> Note that this is not the work item order. D-001 is the shared prerequisite
> for both stock items and has to land before either of them.

| Step | Work Item Ref | Depends On | Owner | Notes |
|---|---|---|---|---|
| 4 | D-001 | none | R. Silva | Schema, part master, and the seed dataset |
| 2 | D-002 | D-001 | K. Owusu | Needs the part master to look anything up |
| 3 | D-003 | D-001 | R. Silva | Needs the stock tables and the transaction boundary |
| 1 | D-004 | D-001 | K. Owusu | Needs the part record to attach to |

## Environment and Device Matrix

| Environment | Target Device / Browser | Serving Model | Decision Ref |
|---|---|---|---|
| dev | Developer laptop, Chrome 126 | Vite dev server on localhost | DEC-005 |
| demo | Sponsor's Android tablet, Chrome 126 | HTTPS from a local reverse proxy with a certificate trusted by the tablet | DEC-005 |

## Demo Milestone

| Field | Value |
|---|---|
| Demo Date | 2026-08-05 |
| Demo Device | Sponsor-supplied Android tablet, Chrome 126 |
| Integrator | R. Silva |
| Capacity | 6 person-days across 2 engineers |
| Reset Path | scripts/reset-demo.sh restores the seed dataset in about 20 seconds |
| Degraded Path | Manual code entry replaces scanning if the camera is unavailable on the day |

## Definition of Done

| Criterion | Verification | Owner |
|---|---|---|
| All six acceptance cases pass on the demo device | AC-001 manually, AC-002 to AC-006 in CI | R. Silva |
| The reset path runs clean twice in a row | Rehearsal on 2026-08-04 | R. Silva |
| The tablet trusts the site certificate and the camera opens | Rehearsal on the sponsor's tablet | A. Nakamura |

## Open Actions

| Action ID | Description | Owner | Blocking Point | Status |
|---|---|---|---|---|
| OA-001 | Install the site certificate authority on the demo tablet | R. Silva | before_demo | open |
| OA-002 | Confirm in writing that the sponsor supplies the tablet by 2026-08-01 | A. Nakamura | before_demo | open |
| OA-003 | Decide whether the pilot needs multi-site stock | A. Nakamura | non_blocking | open |

## Blocking Points

- **Before build:** nothing. Both engineers can start on step 1 today.
- **Before integration:** nothing.
- **Before demo:** OA-001 and OA-002. Neither stops development; both stop the demonstration.
- **Before UAT:** not applicable to this handoff.
- **Before release:** not applicable to this handoff.

## Key Links

- Requirements: [PROJECT.md](PROJECT.md)
- Flow: [DESIGN/FLOW.puml](DESIGN/FLOW.puml)
- Technical spec: [DESIGN/BUILD-SPEC.md](DESIGN/BUILD-SPEC.md)
- Work items: [DELIVERY.md](DELIVERY.md)
