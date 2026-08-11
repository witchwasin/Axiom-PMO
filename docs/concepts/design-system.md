# Design system

> "What is this actually going to look like, and is that what we all meant?"

Axiom-PMO could not answer that question. It could answer the structural version well — which screens exist, which requirement each one serves, which flow branch leads where — because `DESIGN/FLOW.puml` and `DESIGN/WIREFRAME.md` say so. But a wireframe is a list of boxes. Five people read the same list and picture five different products, and nobody discovers the gap until a developer has built one of the five.

Visual direction first explains why the product should have a particular visual voice. The
design system then turns that selected direction into an explicit, early, and arguable contract.

```text
Draft → Scope → [Visual Direction] → Design System → Design Ready → Handoff → Release
```

Visual direction is optional: a human-confirmed existing brand may use conformance instead of
multi-direction exploration. See [`visual-direction.md`](visual-direction.md).

---

## The failure this prevents

Two failures, pulling in opposite directions.

**The first is agreement that was never real.** A wireframe says "ticket card shows title, priority, and owner". Everyone approves it. Nobody notices that one person imagined a dense operational list and another imagined a spacious consumer app, that nobody decided what priority looks like, and that no one has thought about the empty state at all. The disagreement is discovered during build, which is the most expensive place to discover it.

**The second is a picture nobody can build from.** It is now easy to produce a beautiful product mockup in a minute. It is just as easy for that mockup to contain a score of 750 out of 1,000 that no requirement mentions, a screen that is not in scope, a font nobody has licensed, and a colour pair that fails contrast. It looks like progress and it is a liability, because everything in it reads as decided when none of it was.

A design system that only produces the picture causes the second failure. One that only produces the specification never prevents the first. So this produces both, from one set of values.

---

## One direction, two contract views

| Artifact | Audience | Question it answers |
|---|---|---|
| `DESIGN/VISUAL-DIRECTION.md` | human owner, designer, reviewer | Why should it look this way rather than like a default? |
| `DESIGN/DESIGN-SYSTEM.md` | developer, reviewer | What exactly do I build, in what states? |
| `DESIGN/DESIGN-SYSTEM.html` | anyone with an opinion | Is this what we meant? |
| `DESIGN/BRAND/` | brand owner, developer | What is the mark, who owns it, how is it used? |

The selected or conformance direction is upstream input. The token names in the markdown table
are the CSS custom property names in the HTML. One value, two readers. If they drift, the
markdown wins, and the drift is a defect.

The split matters because the two audiences need opposite things. A stakeholder cannot review a table of hex codes. A developer cannot build from a screenshot. Producing only one of them means someone is guessing.

---

## What this is not

**Not an approval.** A design system is candidate evidence, in the same sense that `HANDOFF-REVIEW.json` is candidate evidence. Producing a sheet does not make a project design-ready, and a stakeholder who has looked at a sheet has not approved it. `Design Ready` stays a human row in `PROJECT.md` that only a human may move.

**Not a component workshop.** The HTML is a visual overview. It shows the agreed look on one page so a human can react to it. It does not run, it does not exercise every permutation of every control, and once the product is under development it does not replace a live component library. It is the thing you look at before you commit, not the thing you develop against afterwards.

**Not a replacement for a design tool.** If the team has a designer and a design tool, use them. This exists for the far more common case: a small team that needs to see and agree on the product now, and would otherwise go straight from a wireframe to a build.

**Not a source of data.** Every value drawn on the sheet is illustrative unless it is traced to source. See below.

---

## Canonical and derived

- **Canonical**: `DESIGN/DESIGN-SYSTEM.md`, `DESIGN/DESIGN-SYSTEM.html`, and the SVG files under `DESIGN/BRAND/`. These are under version control, they diff, and they are what a reviewer argues with.
- **Derived**: any screenshot, exported PDF, printed sheet, or image pasted into a chat or a deck.

A derived copy is a snapshot for conversation. It is never the source of a value. When a screenshot and a canonical file disagree, the canonical file wins, without discussion — the screenshot is simply older.

This distinction is not pedantry. Screenshots are how design decisions actually travel through a team, and a screenshot has no version, no history, and no way to be wrong out loud. Naming it derived is what keeps a stale image from quietly becoming the specification.

When Visual Proof applies at Handoff, one committed desktop capture and one committed mobile
capture are still derived copies, but they become traceable **candidate evidence** of what a
named human reviewed. Their paths, hashes, viewports, and review-input digest live in
`DESIGN/VISUAL-REVIEW.json`. They do not become canonical sources and do not create a new
approval. See [`../architecture/visual-proof.md`](../architecture/visual-proof.md).

---

## The Sample Data Register

This is the part that makes a mockup safe to show.

A mockup is made of invented content. That is not a flaw — a screen with no content on it communicates nothing. The flaw is invented content that is indistinguishable from decided content. A score, a threshold, a rate, a date, a status label: each one reads as a requirement once it is drawn.

So `DESIGN-SYSTEM.md` carries a register, and every value rendered on the sheet gets a row in it with an origin of `illustrative` or `source-derived`. The rendered page carries a visible notice saying the same thing, so that a screenshot taken out of context still says it.

Two rules have no exceptions, in every mode:

- Real customer data, real names, and real account identifiers never appear in a mockup.
- A screen that is not in `DESIGN/WIREFRAME.md` is not drawn. A screen the team wants but has not scoped is an open question, not a mockup.

Strict mode adds nothing here, because these are not risk-proportionate rules. They are the same rules at every level of risk.

---

## Undrawn states are declared, not hidden

The screen table records the states actually drawn and the states not yet drawn. A screen drawn only in its populated state is a known gap: nobody has designed the empty state, the loading state, or what happens when the request fails.

That gap is fine at design time and expensive at build time. Declaring it means a developer meets it in a table instead of discovering it at 4pm on a Thursday, and it gives the `Error/Empty and Loading States` section of `DESIGN/BUILD-SPEC.md` something concrete to resolve.

---

## Relationship to BUILD-SPEC

They answer different questions and neither replaces the other.

| | Design system | `DESIGN/BUILD-SPEC.md` |
|---|---|---|
| Question | What does it look like, and what states exist? | How is it built, deployed, and accepted? |
| Gate | Design | Handoff, required for Standard and Strict |
| Required | never | by the artifact contract |

The design system feeds the build spec. Its component inventory is what the `UI Framework` section has to be able to render, and its undrawn-states column is an input to `Error/Empty and Loading States`. A build spec written without one tends to describe a stack rather than a product.

---

## What is enforced, and what is not

One rule, and it is deliberately narrow.

**`DESIGN-001` checks that the two files agree on token values.** When both exist, every token declared in a `## Design Tokens` table must appear in the sheet's `:root` with the same value. That is a comparison of two strings that are both in the repository — provable, binary, no domain judgement — which is exactly what deterministic validation is for. See [`docs/rules/DESIGN-001.md`](../rules/DESIGN-001.md).

The duplication is the point of the artifact pair and also its weak spot. A developer reads the markdown, a stakeholder reacts to the sheet, and if the two drift then one of them is being lied to with no symptom until build. Nothing else would catch it.

**Nothing requires the design system to exist.** The artifact contract in `pmo-config/artifact-policy.json` does not mention it and no gate blocks on its absence. A rule that failed a build for a missing design system would produce sheets written to satisfy the rule, which is the documentation overhead this framework exists to avoid.

**Visual Proof is conditional, not a reason to create a sheet.** At the Handoff gate, the
framework checks Visual Proof only when this Markdown contract, the HTML sheet, and
`DESIGN/VISUAL-DIRECTION.md` already exist together. In that situation, a missing or stale
`DESIGN/VISUAL-REVIEW.json` says the human-visible presentation has not been evidenced for
handoff. The check verifies the evidence contract, not whether the UI is aesthetically good.

**The Sample Data Register is not enforced, and you should know that.** It is the mechanism that makes a mockup safe to show, and it lives in skill prose, which is advisory. An AI can produce a sheet with twenty invented numbers and an empty register, and every gate stays green. Checking it would mean extracting rendered text from HTML and matching it against table rows — doable, but a guess-heavy comparison of a kind this framework has been careful to avoid. So it is honest to say plainly: this is the weakest joint in the artifact, and the discipline depends on the skill and on review, not on the validator.

Same for out-of-scope screens and for whether a brand field marked `supported` really was confirmed by a human. Those are review questions today.

---

## Using it

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project> -Mode <mode> -Gate Design
```

Load `pmo-design` and ask for a design system. For new work, the skill first consumes a visual
direction with status `selected` or `conformance`; when none exists, it routes through
`visual_direction` before drawing the presentation. It reads decided facts before asking,
uses the repository evidence ladder (`verified`, `supported`, `inferred`, `missing`, `conflict`),
and fills both contract views from one set of token values. It reports tool and render status
separately from evidence status. At Handoff, when Visual Proof applies, a named human reviews
committed desktop and mobile captures and records candidate evidence using
[`templates/VISUAL-REVIEW.json`](../../templates/VISUAL-REVIEW.json). The review does not move
the `Design Ready` approval row.

A worked example is in [`examples/DESIGN-SYSTEM-DEMO/`](../../examples/DESIGN-SYSTEM-DEMO/). Open `DESIGN/DESIGN-SYSTEM.html` in a browser.

That example deliberately stops at the Design gate. It has a `PROJECT.md`, a flow, a wireframe, a design system, and a `decision-log.md` — and no `HANDOFF.md` and no `RELEASE.md`, because it has not reached either. A design system produced after a project ships is a retrofit; this one is what the artifact looks like when it is doing its job, as input to the `Design Ready` decision rather than a decoration added afterwards.
