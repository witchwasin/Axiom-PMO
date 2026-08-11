# VISUAL DIRECTION - <PROJECT-CODE>

> Optional upstream input to `DESIGN-SYSTEM.md`. It records why the product should look
> this way before tokens and components are drawn. It is candidate evidence, not approval.
> Concept and boundaries: `docs/concepts/visual-direction.md`.

## Status

- stage: draft / awaiting-selection / selected / conformance
- brand_starting_point: <undecided or existing; human-declared>
- direction_status: <pending, selected, or conformance>
- selected_direction: <direction ID and name, or pending>
- direction_decision_ref: <DEC-NNN, or pending>
- wireframe_reference: `DESIGN/WIREFRAME.md`
- existing_brand_reference: <DESIGN/BRAND/BRAND.md or not applicable>

`brand_starting_point` and direction selection are human-owned. Do not infer either.

## Creative Brief - Core

Use `verified`, `supported`, `inferred`, `missing`, or `conflict` exactly as defined in
`AGENTS.md`. A direct source fact is `supported`; it does not start as `inferred` merely
because an AI drafted the file.

| Field | Value | Evidence Status | Source Ref |
|---|---|---|---|
| Purpose | <what this product enables> | <status> | <source reference> |
| Primary audience | <who actually uses it> | <status> | <source reference> |
| Emotional target | <what the experience should make them feel> | <status> | <source reference> |
| Personality | <three precise traits> | <status> | <source reference> |
| Must feel like | <positive experiential boundary> | <status> | <source reference> |
| Must not feel like | <negative experiential boundary> | <status> | <source reference> |
| Boldness | <conservative, balanced, bold, or experimental plus reason> | <status> | <source reference> |
| Platform and context | <device, environment, and usage conditions> | <status> | <source reference> |

## Creative Brief - Conditional

Use `not applicable` where a field cannot change this product's presentation. Do not invent
detail to fill the table.

| Field | Value | Evidence Status | Source Ref |
|---|---|---|---|
| Language and culture | <scripts, locale, and relevant cultural context> | <status> | <source reference> |
| Industry cliché | <default most likely to erase distinctiveness> | <status> | <source reference> |
| Visual metaphor | <unifying visual idea or not applicable> | <status> | <source reference> |
| Typography attitude | <the intended typographic voice> | <status> | <source reference> |
| Imagery and icon direction | <visual grammar and asset constraints> | <status> | <source reference> |
| Density and rhythm | <scanning speed, whitespace, and grouping> | <status> | <source reference> |
| Motion character | <feedback tempo or not applicable> | <status> | <source reference> |
| Accessibility constraints | <contrast, legibility, target, and motion needs> | <status> | <source reference> |
| Existing assets and owner | <assets, owner, and licence> | <status> | <source reference> |
| Forbidden colours or motifs | <restriction and reason, or none confirmed> | <status> | <source reference> |

## References

Record the transferable principle, not an instruction to copy the surface.

| Reference | Principle to Learn | Relevant Brief Field | Evidence Status | Source Ref |
|---|---|---|---|---|
| <reference name or location> | <specific principle> | <brief field> | <status> | <source reference> |

## Anti-References

| Anti-Reference | Quality to Avoid | Why It Conflicts | Evidence Status | Source Ref |
|---|---|---|---|---|
| <reference, cliché, or pattern> | <specific quality> | <brief-linked reason> | <status> | <source reference> |

## Art Directions

For an `undecided` starting point, propose two or three directions that differ across several
dimensions—not the same layout with different hex values. Keep status `pending` and stop for
human selection. For `existing`, document one conformance direction instead.

| ID | Concept Name | Brief-Linked Rationale | Cliché Avoided | How It Materially Differs |
|---|---|---|---|---|
| VD-01 | <concept name> | <rationale with brief field references> | <unchosen default avoided> | <geometry, type, composition, density, colour role, imagery, surface, or motion> |
| VD-02 | <concept name or not applicable for conformance> | <rationale> | <default avoided> | <material differences> |

## Selected or Conformance Direction

- Direction: <VD-NN and concept name, pending, or conformance name>
- Status: <pending, selected, or conformance>
- Human decision ref: <DEC-NNN or pending>
- Selection rationale: <why the human chose it, or why existing brand controls>
- Principles to preserve: <three to five implementation-facing principles>
- Permitted variation: <what may adapt across screens and breakpoints>
- Must not drift into: <specific failure modes>

## Presentation Decisions

Every choice must complete: "We chose this because `<brief field or selected principle>`."

| Dimension | Presentation Choice | Brief or Direction Ref | Rationale | Evidence Status |
|---|---|---|---|---|
| Geometry | <shape and edge language> | <field or principle> | <because statement> | <status> |
| Typography | <type voice and pairing> | <field or principle> | <because statement> | <status> |
| Composition | <hierarchy and layout logic> | <field or principle> | <because statement> | <status> |
| Density | <spacing and information rhythm> | <field or principle> | <because statement> | <status> |
| Colour role | <what colour does, not only its value> | <field or principle> | <because statement> | <status> |
| Imagery and icons | <visual grammar> | <field or principle> | <because statement> | <status> |
| Surface and depth | <flat, layered, tactile, or other model> | <field or principle> | <because statement> | <status> |
| Motion | <feedback and transition character or not applicable> | <field or principle> | <because statement> | <status> |

## Anti-Generic Constraints

Common patterns are allowed only when the brief justifies them. Name the project-specific
defaults that must not appear by accident.

| Constraint | Brief or Direction Ref | Exception Condition |
|---|---|---|
| <unchosen default to avoid> | <field or principle> | <when it would become justified> |

## Capability and Review Status

Tool and render status are operational facts, not evidence statuses.

- tool_availability: <available tools and unavailable capabilities>
- render_status: <not performed, rendered, or render failed>
- rendered_artifact: <path or not available>
- human_review_status: <not requested, pending, or reviewed>
- review_notes: <findings or not yet reviewed>

When this artifact and both design-system contract views exist, Visual Proof is conditional at
Handoff. Record the selected/conformance direction and source-backed brief here first; then use
`DESIGN/VISUAL-REVIEW.json` to record committed desktop/mobile captures and a named human review.
That manifest is candidate evidence, not a Design Ready or release approval.

## Open Questions

| ID | Question | Impact | Owner | Status |
|---|---|---|---|---|
| Q-001 | <unresolved visual-direction question> | <what it changes or blocks> | <owner> | open |
