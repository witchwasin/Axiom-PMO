---
name: pmo-design
description: Use for flow, UX, wireframe, brand direction, design system, and design-ready acceptance criteria tied to scoped requirements.
---

# pmo-design

## Purpose
Turn scoped requirements into flow, wireframe, visual design direction, and design-ready decisions.

## Trigger
Use when UI, workflow, user journey, integration flow, acceptance wording, or the visual identity of the product needs design clarification.

## Intents

| Intent | Use when | Read set |
|---|---|---|
| `flow` (default) | Mapping requirements to flow, wireframe, or acceptance wording | `PROJECT.md`, `DESIGN/**` |
| `design_system` | The team needs to see the product before a prototype or a handoff | see Required Inputs |

Concept, boundaries, and the reasoning behind the design system rules:
`docs/concepts/design-system.md`. Do not restate them here.

## Required Inputs
`PROJECT.md`, applicable `DESIGN/**`, requirements with source references, and the context/artifact contract in `pmo-config/context-map.json` and `pmo-config/artifact-policy.json`.

For `design_system`, additionally: `DESIGN/WIREFRAME.md`, `DESIGN/BRAND/**` if present, and `decision-log.md`. Read only these.

## Allowed Context
Read only requirement rows and design files relevant to the requested flow. Avoid loading delivery or release docs unless checking impact.

## Mode Behavior
Use `pmo-config/policy.json` for mode, sentinel, evidence, and approval values, and `pmo-config/artifact-policy.json` for when design artifacts are required. Lite design is conditional and can use `not_required` only where the configured sentinel policy allows it. Standard and Strict design expectations follow the configured artifact and reference contracts.

The design system is optional in every mode. No gate requires it.

## Execution Steps - flow
1. Map requirement IDs to user and system flow steps.
2. Create or update `DESIGN/FLOW.puml` and `DESIGN/WIREFRAME.md` only when the configured artifact contract or confirmed design impact requires them.
3. Record design assumptions and open questions.
4. Confirm design references are usable by delivery work items.

## Execution Steps - design_system
1. List the screens already in scope from `PROJECT.md` and `DESIGN/WIREFRAME.md`. Only those may be drawn.
2. Read what has already been decided before asking anything: `decision-log.md`, `DESIGN/BRAND/BRAND.md` if present, and any brand direction in `PROJECT.md`. Carry those forward and do not reopen them.
3. Ask a human only for what step 2 did not answer: name, tagline, personality, audience, forbidden colours, and who owns the mark. Anything a human has not confirmed stays `inferred`.
4. Write `DESIGN/BRAND/BRAND.md` from `templates/BRAND.md`, plus hand-authored SVG assets with no editor metadata.
5. Write `DESIGN/DESIGN-SYSTEM.md` from `templates/DESIGN-SYSTEM.md`: colour, typography, spacing and radius, border and elevation tokens; components with variants and states; screens with states drawn and states not yet drawn.
6. Write `DESIGN/DESIGN-SYSTEM.html` from `templates/DESIGN-SYSTEM.html` using the same token values, and replace every `{{PLACEHOLDER}}`.
7. Fill the Sample Data Register. Every value rendered on the sheet gets a row.
8. Measure every contrast ratio you state. Do not estimate one and do not assert a threshold you have not computed.
9. Render the sheet, show it to the human, and report assumptions and open questions with it.
10. Record meaningful brand decisions in `decision-log.md`. Check first whether that file is a semantic-review input for this project; if it is, editing it invalidates an existing `HANDOFF-REVIEW.json`.

## Output Contract
Return design files changed, requirement coverage, assumptions, and unresolved design questions.

For `design_system`, additionally: which scoped screens were drawn and which were not, which screen states are still undrawn, which brand fields remain `inferred`, and the path to the rendered sheet.

## Approval Rules
Design Ready is human-owned and follows the configured artifact and approval contracts for the active mode and gate. A design system is candidate evidence for it, never the approval itself.

## Validation Command
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project> -Mode <mode> -Gate Design`

`DESIGN-001` fails when `DESIGN-SYSTEM.md` and `DESIGN-SYSTEM.html` declare different token values.

## Prohibited Actions
Do not expand scope, remove source references, hardcode artifact matrices, or mark design approval without human evidence.

For `design_system`: do not draw a screen that is not in the wireframe, present an `inferred` brand field as confirmed, invent an approval or a decision id, place real customer or personal data in a mockup, or publish the sheet to any external service without an explicit instruction in the current session.

## Completion Criteria
Each design-affecting work item has a design reference or an intentional `not_required` sentinel where allowed.

For `design_system`: `DESIGN-001` passes, no `{{PLACEHOLDER}}` remains, every rendered value appears in the Sample Data Register, every drawn screen traces to a wireframe screen, and every brand field's evidence status reflects whether a human actually confirmed it.
