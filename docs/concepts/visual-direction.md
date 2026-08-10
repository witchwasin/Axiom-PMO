# Visual direction

> "Why should this product look like this product—and not like the model's default UI?"

A wireframe establishes scope and structure. A design system establishes tokens, components, and states. Neither explains the creative idea that should govern typography, composition, imagery, density, colour, and motion. Without that idea, phrases such as "modern, clean, professional" usually produce the same white-card SaaS interface with a new accent colour.

Visual direction supplies that missing reason before the design system is drawn.

```text
Scope → creative brief → art direction → human choice → design system → Design Ready
```

The artifact is optional. It adds no gate, rule, validator, or required-artifact matrix entry. It is useful when visual distinction matters or when an existing brand must be translated into a product interface.

---

## State and authority

Two fields describe different facts and must not be collapsed:

| Field | Values | Meaning |
|---|---|---|
| `brand_starting_point` | `undecided`, `existing` | Whether the work begins without a human-approved brand or must conform to one |
| `direction_status` | `pending`, `selected`, `conformance` | Whether alternatives await a choice, a human selected one, or the work follows an existing brand |

Only a human may declare the brand starting point or select a direction.

- `undecided` begins as `pending`. Produce two or three materially different directions, then stop for a human choice. A choice becomes `selected` only with human evidence and a decision reference.
- `existing` uses `conformance`. Read the approved brand assets and constraints; do not manufacture three alternatives to simulate exploration.
- A selected direction is upstream input to `design_system`. That intent applies it; it does not quietly reopen it.

`Design Ready` remains a separate human-owned approval.

---

## The brief changes the output

Collect only fields that can materially affect the work. Core fields establish the concept; conditional fields are used when relevant to the product, platform, or risk. `not applicable` is better than invented detail.

| Field | Weight | What it changes |
|---|---|---|
| Purpose | core | The central visual idea and what deserves emphasis |
| Primary audience | core | Familiarity, readability, tone, and interaction expectations |
| Emotional target | core | Tension, warmth, energy, trust, calm, or urgency |
| Personality | core | Shape language, type voice, pacing, and copy tone |
| Must feel like | core | Positive boundary for the whole composition |
| Must not feel like | core | Negative boundary and failure test |
| Boldness | core | How far the direction may depart from category norms |
| Platform and context | core | Density, input model, responsive priorities, and environment |
| Language and culture | conditional | Script coverage, type pairing, hierarchy, and local meaning |
| References | conditional | Transferable principles worth learning from—not surfaces to copy |
| Anti-references | conditional | Specific qualities to avoid and why |
| Industry cliché | conditional | Defaults that would make the product indistinguishable |
| Visual metaphor | conditional | A concept that can unify geometry, imagery, and interaction |
| Typography attitude | conditional | Editorial, technical, civic, expressive, quiet, or another justified voice |
| Imagery and icon direction | conditional | Illustration, photography, diagrams, icon grammar, and licensing needs |
| Density and rhythm | conditional | Information per view, whitespace, grouping, and scanning speed |
| Motion character | conditional | Feedback tempo and transition personality when motion is in scope |
| Accessibility constraints | conditional | Contrast, target size, reduced motion, legibility, and assistive use |
| Existing assets and owner | conditional | What must be reused, who can approve it, and licensing boundaries |
| Forbidden colours or motifs | conditional | Legal, cultural, competitive, or stakeholder restrictions |

The evidence ladder still applies: `verified` is direct source plus human approval; `supported` is direct source without final approval; `inferred` is reasoned from partial source; `missing` is not found; `conflict` means sources disagree. A field is not automatically `inferred` merely because an AI wrote the first draft.

Tool availability is separate evidence. Use fields such as `tool_availability` and `render_status`; never turn "no browser" or "not rendered" into `evidence_status: missing`.

---

## Directions must differ in kind

Changing only hex values produces one direction shown several times. Alternatives should differ across several of these dimensions:

- geometry and silhouette;
- typography and type pairing;
- composition and hierarchy;
- information density and rhythm;
- the role of colour, not just the colour value;
- imagery or icon language;
- surface and depth model;
- motion character and interaction feedback.

Each direction needs a concept name, a brief-linked rationale, the cliché it avoids, and a concrete statement of how it differs from the others.

---

## Anti-default check

These are examples of common defaults, not forbidden patterns:

- white cards floating on a pale grey canvas;
- a purple-to-blue gradient used as "innovation";
- a small pill badge above every hero headline;
- three pastel circular icons in a feature row;
- the same neutral grotesk typeface for every personality;
- dark mode made by mechanically inverting the light palette;
- dashboard components added because a template contained them rather than because scope requires them.

The prohibition is not "never use this pattern". It is "never arrive here without choosing it". A default is valid when the brief supports it and the rationale names that support.

For every presentation choice, complete this sentence:

> We chose `<presentation choice>` because `<brief field or selected-direction principle>`.

If the sentence cannot be completed honestly, the choice is an unexamined default. Change it or mark the rationale unresolved.

---

## Capability honesty

Missing tools do not grant permission to pretend. If image generation, font inspection, browser rendering, responsive capture, or visual comparison is unavailable:

- keep the corresponding design claim provisional;
- report `tool_availability` and `render_status` explicitly;
- do not say the sheet was rendered, compared, or reviewed;
- leave a human review step open.

The same rule applies when the tool exists but was not run.

---

## Human review rubric

Use the rubric as review guidance, not an automated score or approval:

| Lens | Review question |
|---|---|
| Concept fit | Can the major choices be explained from the brief? |
| Distinctiveness | Does it avoid unchosen category and model defaults? |
| Typography | Does the type voice fit the product and required scripts? |
| Hierarchy | Is attention directed to the right information and actions? |
| Composition | Does the page have intentional rhythm, balance, and tension? |
| Component coherence | Do components look like one visual language across states? |
| Cross-screen consistency | Does the direction survive every scoped screen? |
| State completeness | Are missing empty, loading, error, and disabled states declared? |
| Responsive fit | Does the concept adapt rather than merely shrink? |
| Accessibility | Are contrast, focus, target size, legibility, and motion considered? |
| Content realism | Is sample content useful, labelled, and free of real customer data? |
| Buildability | Can a developer reproduce the result from the declared contract? |
| Scope alignment | Does every drawn screen and behaviour trace to confirmed scope? |

Record findings and open questions. Do not convert a rubric result into Design Ready.

---

## Relationship to the design system

`DESIGN/VISUAL-DIRECTION.md` explains why the presentation looks the way it does. `DESIGN/DESIGN-SYSTEM.md` defines what a developer builds. `DESIGN/DESIGN-SYSTEM.html` makes that contract visible.

The design-system contract keeps its token agreement, provenance, sample-data notice, semantic section anchors, scoped screens, responsive behaviour, and print behaviour. Its presentation layer is deliberately replaceable and must be rewritten to express the selected direction rather than treated as a visual starter theme.

`DESIGN-001` remains deliberately narrow: it compares token values between Markdown and HTML. It does not judge creativity, concept fit, or review quality. Those remain visible human decisions.
