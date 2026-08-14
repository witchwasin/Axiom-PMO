---
name: pmo-design
description: Use for product flows, UX and wireframes, creative direction, visual direction, art direction, brand conformance, distinctive or non-generic frontend direction, design systems, visual sheets, and design-ready acceptance criteria tied to scoped requirements.
---

# pmo-design

## Purpose

Turn scoped requirements into flows, a source-backed visual direction, and a buildable design contract without inventing scope or approval.

## Intents

| Intent | Use when | Read set |
|---|---|---|
| `flow` (default) | Map requirements to flow, wireframe, or acceptance wording | `PROJECT.md`, relevant `DESIGN/**` |
| `visual_direction` | Establish creative/art direction, avoid generic defaults, or choose how the product should feel | see Required Inputs |
| `design_system` | Turn a selected direction or existing brand into a developer contract and visual sheet | see Required Inputs |
| `system_design` | Define architecture, data/API boundaries, and early Test Strategy in `DESIGN/BUILD-SPEC.md` | `PROJECT.md`, `DESIGN/BUILD-SPEC.md` |

Read `docs/concepts/visual-direction.md` for creative-direction rules and `docs/concepts/design-system.md` for the artifact contract. Do not restate them here.

## Routing and Fallback

1. Route requests for creative, distinctive, premium, unconventional, art direction, visual direction, or "not generic" work to `visual_direction`, even when the user also says "design system".
2. For a new design system, consume `DESIGN/VISUAL-DIRECTION.md` when its `direction_status` is `selected` or `conformance`.
3. If no usable direction exists, use `visual_direction` first. An existing design system may be maintained without retroactively creating this artifact unless the direction is being reopened.
4. Never reopen a selected direction inside `design_system`; record a proposed change as an open question and return to `visual_direction`.

## Required Inputs

Always read `PROJECT.md`, relevant requirements and design files, and the configured context/artifact contracts.

- `visual_direction`: read `DESIGN/VISUAL-DIRECTION.md` if present, `DESIGN/WIREFRAME.md`, `DESIGN/BRAND/**`, `decision-log.md`, and only the configured source files needed for the brief.
- `design_system`: additionally read `DESIGN/VISUAL-DIRECTION.md`, `DESIGN/WIREFRAME.md`, `DESIGN/BRAND/**`, and `decision-log.md` if present. Read only the scoped set.

Avoid delivery and release documents unless checking impact. The design system and visual direction remain optional in every mode; no gate requires either artifact.

## Evidence and Authority

Use the repository evidence ladder exactly: `verified` = direct source plus human approval; `supported` = direct source without final approval; `inferred` = reasoned from partial source; `missing` = not found; `conflict` = sources disagree. Never use evidence status to describe tool availability or whether a render ran.

Only a human may declare `brand_starting_point: undecided | existing`, select an art direction, or approve Design Ready. Use `direction_status: pending | selected | conformance`; `selected` requires explicit human choice and a decision reference, while `conformance` requires a human-confirmed existing brand.

## Execution - flow

1. Map requirement IDs to user and system flow steps.
2. Create or update flow and wireframe artifacts only when the configured contract or confirmed impact requires them.
3. Record assumptions, open questions, and usable delivery references.

## Execution - system_design

1. Complete System Design and the mode-aware Test Strategy in BUILD-SPEC before detailed UI work.
2. Create flow/wireframe artifacts only for an active UI path and actual UI scope.
3. Record a technical/scope mismatch as a candidate governed Change Request; do not silently widen the approved contract.

## Execution - visual_direction

1. Read confirmed scope, decisions, wireframes, brand assets, and relevant sources before asking questions.
2. Fill `DESIGN/VISUAL-DIRECTION.md` from the template. Keep source facts and design judgements at their truthful evidence statuses.
3. Ask a human for `brand_starting_point` if it is not already human-confirmed. Do not infer or default it.
4. For `existing`, assess conformance and use `direction_status: conformance`; do not perform a theatrical multi-direction exercise.
5. For `undecided`, propose two or three directions that differ in geometry, typography, composition, density, colour role, imagery, surface/depth, or motion—not merely hex values. Set `direction_status: pending`, then stop for human selection.
6. After an explicit human choice, set `direction_status: selected`, record the decision reference, and carry the selected direction into `design_system`. Never select on the human's behalf.
7. If editing `decision-log.md`, first check whether it is semantic-review input; editing it can stale `HANDOFF-REVIEW.json`.

## Execution - design_system

1. List only screens already scoped in `PROJECT.md` and `DESIGN/WIREFRAME.md`.
2. Consume the selected/conformance direction and explain every presentation choice by pointing to a brief field. If that sentence cannot be written, the choice is an unexamined default.
3. Write brand assets when needed, then `DESIGN/DESIGN-SYSTEM.md` and the self-contained HTML sheet from their templates. Keep the first token block and required semantic anchors intact; rewrite the presentation layer to fit the direction.
4. Keep Markdown and HTML token values identical. Fill the Sample Data Register and measure every contrast ratio stated.
5. Render and show the sheet when tools permit. Report `tool_availability` and `render_status` separately; never claim a render or review that did not happen.
6. At Handoff, when `VISUAL-DIRECTION.md`, `DESIGN-SYSTEM.md`, and `DESIGN-SYSTEM.html` all exist, prepare honest desktop and mobile captures when rendering tools permit. A named human must review them and record `DESIGN/VISUAL-REVIEW.json`; an AI may draft notes but may not fabricate the reviewer, decision reference, or aesthetic outcome.
7. Report assumptions, open questions, scoped screens drawn, undrawn states, and meaningful decisions. Editing a semantic-review or Visual Proof input can stale its candidate evidence.

## Output Contract

Return changed design files, requirement coverage, evidence status, assumptions, unresolved questions, and any human decision still required. For visual work, also report selected/conformance direction, screens and states drawn or missing, `tool_availability`, `render_status`, and the rendered path when one exists. When Visual Proof applies at Handoff, report whether its capture and named-human review evidence are missing or stale; do not turn that report into approval.

## Prohibited Actions

Do not expand scope, remove source references, invent requirements or decision IDs, infer `brand_starting_point`, select a direction, mark approval, draw an unscoped screen, present an inference as confirmed, use real customer or personal data, claim an unavailable tool ran, or publish externally without explicit current-session instruction.

## Completion Criteria

- `flow`: every design-affecting item has a design reference or an allowed `not_required` sentinel.
- `visual_direction`: brief evidence is truthful; status is `pending`, `selected`, or `conformance` consistently; any selection has human evidence and a decision reference.
- `design_system`: the direction is traceable, `DESIGN-001` passes, no HTML placeholder remains, sample data is registered, every screen traces to a wireframe, and render/tool claims are honest. At Handoff, the conditional Visual Proof contract is complete only after a named human has recorded both committed captures and the review manifest.

## Validation

`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project> -Mode <mode> -Gate Design`

The artifact pair is candidate evidence only. Design Ready remains human-owned.

Visual Proof stays in the repository workflow: active instructions are under `.claude/skills/`, and
the generated `skills/` package is refreshed by its build command. Do not create or maintain a
separate `.agents/skills` mirror for this capability.
