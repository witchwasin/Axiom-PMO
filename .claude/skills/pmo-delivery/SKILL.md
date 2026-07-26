---
name: pmo-delivery
description: Use for delivery planning, handoff, task source of truth, engineering sequencing, and semantic handoff review.
---

# pmo-delivery

## Purpose
Translate approved scope/design into executable work items and handoff notes, and review whether the resulting contract is actually sufficient for a developer to start, integrate, and demonstrate.

## Trigger
Use when creating or reviewing `DELIVERY.md`, sequencing work, assigning owners, checking task-source consistency, or preparing/reviewing a handoff.

## Intents

| Intent | Use when | Read set |
|---|---|---|
| `delivery_planning` (default) | Creating or changing work items | `PROJECT.md`, `DELIVERY.md`, design context |
| `handoff_review` | Preparing for, or checking, the Handoff gate | see below |

## Required Inputs
`PROJECT.md`, task source of truth, relevant design context, and the context/artifact contract in `pmo-config/context-map.json` and `pmo-config/artifact-policy.json`.

For `handoff_review`, additionally: `HANDOFF.md`, `DESIGN/BUILD-SPEC.md`, `RAID-log.md` and `decision-log.md` if present, and `pmo-config/handoff-policy.json`. Read only these. Do not read release artifacts, and do not read `source/**` beyond the rows already cited in `PROJECT.md` unless a specific finding requires it.

## Allowed Context
Use the context router handoff set. Do not read release artifacts unless the user asks for release readiness.

## Mode Behavior
Use `pmo-config/policy.json` for mode, status, review-stage, task-source, strict-trigger, and sentinel values. Use `pmo-config/artifact-policy.json` to decide whether `DELIVERY.md` is required, conditional, or replaceable by GitHub Issues for the active mode and gate. Use `pmo-config/handoff-policy.json` for handoff artifacts, review lenses, blocking points, and owner policy.

## Execution Steps - delivery_planning

1. Confirm task source of truth: file or GitHub.
2. Create work items with mode, strict trigger, requirement ref, design ref, status, review stage, evidence, and labels.
3. Check enum values against runtime policy.
4. Flag missing blockers or client decisions.

## Execution Steps - handoff_review

The deterministic validator proves the contract is **complete**. It cannot prove it is **sensible**. This review is the part that reads for sense, and its output is structured so the validator can then check that the reading happened, covered everything, and is still current.

1. Run the gate first: `scripts/validate-project.ps1 -ProjectPath <project> -Mode <mode> -Gate Handoff`. Do not re-report anything it already caught. Structural gaps are its job; this review starts where it stops.
2. Read the artifacts listed above. Read them together, not one at a time — most real findings are contradictions *between* documents, each of which is defensible alone.
3. Walk **every** lens in `pmo-config/handoff-policy.json` `semantic_review.lenses`. Record each one in the output even when it found nothing; a lens with no entry is an unfinished review, and `HANDOFF-010` will say so.
4. Record findings in `HANDOFF-REVIEW.json` (see `templates/HANDOFF-REVIEW.json`).
5. Record **both** freshness digests. `scripts/handoff-digest.ps1 -ProjectPath <project>` prints them:
   - `source_snapshot.digest` — the material the requirements came from
   - `review_inputs.digest` — the governed artifacts you actually read

   A review that records only the first keeps reporting as current after
   someone rewrites the build sequence or waives a build-spec section.
6. Re-run the gate, then `scripts/assess-handoff.ps1` for stage verdicts.

### The twelve lenses

| Lens | The question it asks |
|---|---|
| `value_and_scope_slice` | Does the slice deliver the value the target milestone has to show? |
| `capability_lifecycle` | Is each capability complete across its lifecycle, or only the happy path? A count that can go down but never up cannot be demonstrated twice. |
| `data_cardinality_and_units` | Do entities, cardinality, quantities, and units support the declared use cases? A "stock" entity with no quantity and no unit is a name, not a model. |
| `state_transitions_and_rollback` | Does every state machine declare guards, terminal states, and how a transition is reversed? |
| `concurrency_and_idempotency` | Two users at once, a retried request, two callers allocating an id. Is any of that specified? |
| `dependencies_and_build_order` | Can the declared sequence actually be executed in that order? Work-item numbering is not build order. |
| `ownership_and_capacity` | Does every stream have a named owner, an integrator, and stated capacity that fits the horizon? |
| `acceptance_seed_reachability` | Can each acceptance case be reached from the declared seed data? |
| `automated_manual_test_split` | Is each case classified, and does the classification have a runner or a person behind it? |
| `privacy_and_data_classification` | Do declared data elements, free text, files, and metadata have classification decisions? Does a privacy commitment in one document contradict a feature in another? |
| `environment_and_device_constraints` | Does the serving model satisfy the declared device and runtime capabilities? |
| `demo_startup_reset_and_recovery` | Is there a declared startup, reset, degraded, and recovery path? |

### Rules for findings

- **Every finding cites evidence.** `evidence_refs` names the artifact rows the finding is derived from. A finding with no evidence is an opinion.
- **Every finding has a suggestion and an owner.** Naming a problem without naming the next action or who takes it is not a review outcome.
- **Never invent a requirement.** If a capability looks incomplete relative to what the source already asked for, that is a *completeness* finding against the existing requirement — not new scope. If it is genuinely new scope, it is an open question for a human, not a finding.
- **Separate blocking points.** `before_build` is a different claim from `before_demo`. Getting this wrong is the most damaging thing this review can do: mislabelling a demo blocker as a build blocker stalls a team that could be working, and the reverse produces a demo-day surprise.
- **Do not restate deterministic findings.** If `HANDOFF-004` already caught the inverted sequence, do not raise it again here.
- **Do not echo source content.** Findings are read in CI logs and dashboards. Cite the location; do not paste the row.

### What an AI reviewer may and may not close

May close a finding (`status: resolved`) when the artifacts now show it was fixed, and cite the change as evidence. Every non-`open` status needs a `decision_ref` that resolves.

These limits are **enforced by `HANDOFF-010`**, not merely requested here. An AI-authored review that sets `accepted_risk`, or that closes a privacy finding, fails the gate. A closure under a human-only lens additionally has to cite a `DEC-###` that exists in `decision-log.md` with a named decider.

**May not close**, regardless of how obvious the answer looks — these need a named human and a decision record:

- anything under `privacy_and_data_classification` or `environment_and_device_constraints` (configured in `semantic_review.human_only_close_lenses`)
- anything requiring a business, legal, security, commercial, or budget decision
- anything that would change scope, a deadline, or an accepted risk

Set `status: open` and name the human in `owner`.

## Output Contract

For `delivery_planning`: work-item changes, dependency notes, owner gaps, and validation result.

For `handoff_review`: a `HANDOFF-REVIEW.json` conforming to `templates/HANDOFF-REVIEW.json`, plus a short summary naming what blocks build, what blocks demo, and what needs a human decision.

## Approval Rules

Mode escalation and high-risk work require human confirmation before delivery starts.

**A handoff review is not an approval.** `HANDOFF-REVIEW.json` is candidate evidence produced by a reviewer. It never substitutes for the `Design Ready` approval row in `PROJECT.md`, and the Handoff gate introduces no new approval of its own — it reuses the one that already exists. An AI must never move an approval from pending to approved, and must never present a readiness score as a decision. See `docs/concepts/human-authority.md`.

## Validation Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project> -Mode <mode> -Gate Scope
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project> -Mode <mode> -Gate Handoff
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/assess-handoff.ps1 -ProjectPath <project> -Mode <mode>
```

## Prohibited Actions

Do not create hidden task systems, duplicate source of truth, hardcode mode/gate matrices, or add features outside scope. Do not hardcode review lenses, blocking points, or owner tokens — they come from `pmo-config/handoff-policy.json`. Do not record a review whose digests you did not recompute — both of them, after every other artifact is final.

## Completion Criteria

Every work item references an existing requirement/business rule and has valid mode, status, and review stage.

For `handoff_review`: every lens is recorded, every finding has evidence, a suggestion, an owner, and a blocking point, the digest is current, and every finding that needs a human decision is still `open` with that human named.
