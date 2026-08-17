# HANDOFF - <PROJECT-CODE>

> The developer entry point. Someone who has read nothing else should be able to
> start from this page, know what to build first, know who to ask, and know what
> would stop the demo.
>
> Validated by `node cli/axiom.mjs validate --gate Handoff`. Rule reference:
> `docs/rules/HANDOFF-*.md`.

- Project: <PROJECT-CODE>
- Mode: <Lite | Standard | Strict>
- Handoff Target: <demo | pilot | production | internal>
- Horizon: <YYYY-MM-DD>
- Handoff Owner: <Name (Role)>
- Named Integrator: <Name (Role)>
- Build Spec Ref: DESIGN/BUILD-SPEC.md

## Build Now

> The slice being built in this handoff. Every `Work Item Ref` must exist in
> `DELIVERY.md`. Every row needs a named owner, not a team name.

| Item | Work Item Ref | Value Delivered | Owner |
|---|---|---|---|
| <what it is> | <D-001> | <why it matters to the target milestone> | <Name> |

## Deferred / Do Not Build

> Explicitly out of this slice. Write `none` on its own line when there is
> genuinely nothing - a blank section is silence, not a decision.

| Item | Decision | Reason | Decision Ref |
|---|---|---|---|
| <what it is> | <deferred / do-not-build> | <why> | <DEC-001> |

## Hard Constraints

> Things that are fixed and not negotiable by the build team: a device, a
> deadline, a protocol, a regulation. Write `none` if there are none.

| Constraint | Type | Source Ref |
|---|---|---|
| <constraint> | <technical / commercial / legal / operational> | <MOM-20260101 item 3> |

## Build Sequence and Dependencies

> Build order, which is not the same as work item numbering. A dependency must
> be scheduled at a lower step than the item that consumes it. Use `none` in
> `Depends On` when a step has no prerequisites.

| Step | Work Item Ref | Depends On | Owner | Notes |
|---|---|---|---|---|
| 1 | <D-001> | none | <Name> | <shared prerequisite> |
| 2 | <D-002> | <D-001> | <Name> | <consumer> |

## Environment and Device Matrix

> Where the code runs and how it is served. `Serving Model` may not be left
> undecided - browser capabilities depend on it. The tokens that count as
> undecided are listed in `pmo-config/handoff-policy.json` under
> `environment_capabilities.unresolved_tokens`.

| Environment | Target Device / Browser | Serving Model | Decision Ref |
|---|---|---|---|
| <dev / demo / pilot> | <device, OS, browser and version> | <how it is served: localhost, HTTPS via proxy, packaged app> | <DEC-001> |

## Demo Milestone

> Required when Handoff Target is `demo` or `pilot`.

| Field | Value |
|---|---|
| Demo Date | <YYYY-MM-DD> |
| Demo Device | <the actual hardware it runs on> |
| Integrator | <Name> |
| Capacity | <person-days available before the date> |
| Reset Path | <how to return to a clean demo state, and how long it takes> |
| Degraded Path | <what is shown if the primary path fails live> |

## Definition of Done

> What "done" means for this handoff, stated so someone else can check it.

| Criterion | Verification | Owner |
|---|---|---|
| <criterion> | <how it is verified> | <Name> |

## Open Actions

> Everything unresolved, each with an owner and the stage it blocks. Write
> `none` if there are none.
>
> Blocking Point must be one of: `before_build`, `before_integration`,
> `before_demo`, `before_uat`, `before_release`, `non_blocking`.

| Action ID | Description | Owner | Blocking Point | Status |
|---|---|---|---|---|
| OA-001 | <what is unresolved> | <Name> | <before_demo> | <open> |

## Blocking Points

> Narrative summary of the table above, grouped by stage. This section is for
> humans; `Open Actions` is the machine-checked source of truth.

- **Before build:** <nothing / list>
- **Before integration:** <nothing / list>
- **Before demo:** <nothing / list>
- **Before UAT:** <nothing / list>
- **Before release:** <nothing / list>

## Key Links

> Paths are relative to the project root. They are written as code spans rather
> than markdown links because this template lives in `templates/`, where the
> targets do not exist yet; turn them into links once the project is populated.

- Requirements: `PROJECT.md`
- Flow: `DESIGN/FLOW.puml`
- Technical spec: `DESIGN/BUILD-SPEC.md`
- Work items: `DELIVERY.md`
- Readiness evidence: `HANDOFF-REVIEW.json`
