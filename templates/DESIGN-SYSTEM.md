# DESIGN-SYSTEM - <PROJECT-CODE>

> Optional. Create when the team needs to see the product before prototype or handoff.
> This file is the contract a developer builds against. `DESIGN/DESIGN-SYSTEM.html` is
> the same contract rendered as one page a human can look at.
> `DESIGN/VISUAL-DIRECTION.md`, when present, is the upstream reason for its presentation.
> A design system is candidate evidence, never an approval. `Design Ready` stays human-owned.
> Concept and boundaries: `docs/concepts/design-system.md`.

## Artifact Authority

- Canonical: this file, `DESIGN/DESIGN-SYSTEM.html`, and the SVG files under `DESIGN/BRAND/`.
  These are the artifacts under version control and the ones a reviewer argues with.
- Derived: any screenshot, exported PDF, printed sheet, or image pasted into a chat or deck.
  A derived copy is a snapshot for conversation. It is never the source of a value, and a
  disagreement between a screenshot and this file is always resolved in favour of this file.
- The visual sheet is a **visual overview**, not a component workshop. It shows the agreed
  look on one page. It does not replace a running component library, and it is not the place
  to exercise every permutation of every control.

## Status

- Stage: draft / reviewed / design-ready
- visual_direction_reference: `DESIGN/VISUAL-DIRECTION.md`
- direction_status: pending / selected / conformance
- direction_decision_ref: DEC-<NNN> / pending / not applicable
- Brand reference: `DESIGN/BRAND/BRAND.md`
- Visual sheet: `DESIGN/DESIGN-SYSTEM.html`
- Wireframe reference: `DESIGN/WIREFRAME.md`
- Brand decision ref: DEC-<NNN>
- Sample data: every value rendered on the visual sheet is registered under `Sample Data Register`.
- Visual Proof at Handoff: conditional only when this file, the visual sheet, and
  `DESIGN/VISUAL-DIRECTION.md` all exist. Then record committed desktop/mobile captures and a
  named human review in `DESIGN/VISUAL-REVIEW.json`; it is candidate evidence, never approval.

For a new design system, do not begin the presentation layer while direction status is
`pending`. A selected direction requires a human decision reference; `conformance` requires
a human-confirmed existing brand. Existing design systems are not retroactively blocked.

## Presentation Rationale

The presentation layer is project-specific. Trace each major choice to the selected direction
or a supported brief field; if no honest rationale exists, it is an unexamined default.

| Dimension | Presentation Choice | Visual Direction Ref | Rationale | Evidence Status |
|---|---|---|---|---|
| Geometry | <shape and edge language> | <field or selected principle> | <why this choice fits the brief> | <status> |
| Typography | <type voice and pairing> | <field or selected principle> | <why this choice fits the brief> | <status> |
| Composition and density | <layout rhythm and information density> | <field or selected principle> | <why this choice fits the brief> | <status> |
| Colour role | <what colour does in the interface> | <field or selected principle> | <why this choice fits the brief> | <status> |
| Imagery and icons | <visual grammar> | <field or selected principle> | <why this choice fits the brief> | <status> |
| Surface, depth, and motion | <surface model and motion character> | <field or selected principle> | <why this choice fits the brief> | <status> |

## Design Tokens - Color

Token names here are the CSS custom property names used in `DESIGN-SYSTEM.html`.
Keep both files in step: one value, two readers.

| Token | Value | Role | Contrast Note |
|---|---|---|---|
| color-ink-900 | #111827 | <darkest surface and heading text> | <measured ratio against the light surface> |
| color-brand-500 | #2563EB | <primary action and brand accent> | <measured ratio against white> |
| color-surface-50 | #F9FAFB | <page background> | <not used for text> |
| color-surface-0 | #FFFFFF | <raised or contrasting surface> | <not used for text> |
| color-line | #E5E7EB | <separator and control border> | <measured where it conveys state> |

## Design Tokens - Typography

| Token | Family | Size | Line Height | Weight | Use |
|---|---|---|---|---|---|
| type-display | <family name> | 32px | 40px | 700 | <screen titles> |
| type-body | <family name> | 15px | 24px | 400 | <default body copy> |
| type-caption | <family name> | 12px | 16px | 400 | <helper and metadata text> |

## Design Tokens - Spacing and Radius

| Token | Value | Use |
|---|---|---|
| space-2 | 8px | <tight grouping inside a control> |
| space-4 | 16px | <default gap between elements> |
| radius-md | 12px | <cards and inputs> |

## Design Tokens - Border and Elevation

Borders and shadows carry meaning. Declare them as tokens so a developer never
invents a one-off value to make something stand out.

| Token | Value | Role |
|---|---|---|
| border-hairline | 1px solid #E5E7EB | <default separation between surfaces> |
| border-focus | 2px solid #2563EB | <keyboard focus ring, never removed> |
| elevation-0 | none | <flat surfaces that sit on the page> |
| elevation-1 | 0 1px 2px rgba(17,24,39,.06) | <cards that group content> |
| elevation-2 | 0 8px 24px rgba(17,24,39,.12) | <layers above the page such as menus> |

## Component Inventory

Every component that a developer will build.

- `Variants` are the shapes the same component can take. They differ in intent and are
  chosen by the developer at the call site. Example: primary, secondary, tertiary.
- `States` are what one variant does over time in response to the user or the system.
  Example: default, hover, pressed, focus, disabled, loading, error.

List the states that must exist, not the ones that happen to be drawn on the sheet.

| Component ID | Name | Variants | States | Screen Ref | Requirement Ref | Evidence Status |
|---|---|---|---|---|---|---:|
| C-001 | <component name> | primary, secondary, tertiary | default, hover, pressed, disabled, loading | WF-001 | REQ-001 | supported |
| C-002 | <component name> | single line, multi line | default, focus, error, disabled | WF-001 | REQ-001 | supported |

## Component Details

### C-001 - <component name>

- Purpose: <the user problem this control solves, not what it looks like>
- Variants: <one line per variant, describing when to choose it over the others>
- States: <one line per state, describing the visible difference>
- Behaviour: <what happens on interaction, including the loading and failure path>
- Accessibility: <focus order, target size, contrast, screen reader label>
- Source ref: REQ-001

### C-002 - <component name>

- Purpose:
- Variants:
- States:
- Behaviour:
- Accessibility:
- Source ref:

## Screen Mockups

Only screens that already exist in `DESIGN/WIREFRAME.md` may appear on the sheet.
A screen the team wants but has not scoped belongs in `Open Questions`, not in a mockup.

`States Covered` is what the sheet actually draws for that screen. A screen drawn only
in its happy state is a known gap, not a finished design. Say so here rather than letting
a developer discover it during build.

| Screen ID | Name | Wireframe Ref | Sheet Section | States Covered | States Not Yet Drawn | Requirement Ref |
|---|---|---|---|---|---|---|
| WF-001 | <screen name> | DESIGN/WIREFRAME.md | screen-examples | populated | empty, loading, error | REQ-001 |

## Sample Data Register

Every number, name, date, and label rendered on the visual sheet gets a row here.
`Origin` is `illustrative` or `source-derived`. Real customer data, real names, and
real account identifiers must never appear, in any mode.

| Location | Value Shown | Origin | Note |
|---|---|---|---|
| <sheet section and component> | <the literal value on screen> | illustrative | <why this value was chosen> |

## Assumptions

| ID | Assumption | Validation Needed | Owner | Due | Status |
|---|---|---|---|---|---|
| A-001 | <design assumption not confirmed by a human> | <how to confirm it> | <owner> | YYYY-MM-DD | open |

## Open Questions

| ID | Question | Impact | Owner | Status |
|---|---|---|---|---|
| Q-001 | <question the sheet exposed> | <scope, design, or test impact> | <owner> | open |
