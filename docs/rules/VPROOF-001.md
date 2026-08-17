# VPROOF-001 - Visual Proof evidence is incomplete

## What it checks

At the `Handoff` gate only, this rule activates when all three optional creative
artifacts exist:

- `DESIGN/VISUAL-DIRECTION.md`
- `DESIGN/DESIGN-SYSTEM.md`
- `DESIGN/DESIGN-SYSTEM.html`

It then verifies that `DESIGN/VISUAL-REVIEW.json` is structurally complete: it
names the project and selected direction correctly, records every configured
review criterion, has an accepted recommendation and a resolvable project
decision with a named owner, and binds the required committed desktop/mobile
PNG captures to their paths, hashes, dimensions, and viewports.

## Why it blocks

Once a team has asked to see a specific creative direction before handoff, a
developer should not receive a sheet with no durable record of what was viewed
or which version a human reviewed. A missing or malformed proof is absence of
evidence, not evidence that the visual work is ready.

## What it does not decide

This rule does not read pixels, prove that a PNG was rendered from the HTML,
judge accessibility or aesthetics, or approve Design Ready. It checks local
file identity and a traceable human decision record only. The review remains
candidate evidence; the existing human approval row remains the approval.

## How to fix it

Create the review from `templates/VISUAL-REVIEW.json`, capture the configured
desktop and mobile PNG files locally, calculate their SHA-256 values, complete
every rubric row honestly, and record the human review decision as a project
`DEC-###`. Run the `visualProofDigest` tool (`src/tools/digest-tools.ts`) after the artifacts are final.

Related: [Visual Proof architecture](../architecture/visual-proof.md).
