# Visual proof at Handoff

Visual proof answers a deliberately narrow question:

> Did a named human review stable desktop and mobile captures of the selected visual direction before a developer handoff?

It does **not** answer whether the design is beautiful, whether it will perform well, or whether
the reviewer approved the product. Those are judgements that cannot be made honestly by a
deterministic validator. `Design Ready` remains the existing human-owned approval in
`PROJECT.md`.

---

## Conditional by artifact shape

Visual Proof applies only at the `Handoff` gate and only when all three optional artifacts exist:

```text
DESIGN/VISUAL-DIRECTION.md
DESIGN/DESIGN-SYSTEM.md
DESIGN/DESIGN-SYSTEM.html
```

When that set is absent, the project follows the normal Handoff contract unchanged. This avoids
turning an optional creative capability into documentation that every project has to manufacture.
When the set is present, `DESIGN/VISUAL-REVIEW.json` and its two committed captures become
conditional Handoff evidence.

```text
Selected/conformance direction
        ↓
Design-system contract + self-contained sheet
        ↓
Committed desktop and mobile captures
        ↓
Human visual review declaration
        ↓
Conditional Handoff evidence
```

The captures are evidence of what was reviewed at a particular revision, not canonical design
sources. The canonical sources remain the visual direction, design-system Markdown, HTML, and
brand assets. If a capture conflicts with a canonical file, the canonical file wins and the
capture must be regenerated before it is used as fresh evidence.

---

## Evidence contract

Use [`templates/VISUAL-REVIEW.json`](../../templates/VISUAL-REVIEW.json) as the project-local
manifest. It records:

- source-backed visual-direction references plus a digest of the final governed visual-review inputs;
- SHA-256 hashes and committed relative paths for one desktop and one mobile capture;
- coverage of every visual review lens;
- the named reviewer and a human review declaration; and
- the decision references for the selected/conformance direction and the human review declaration.

The declaration means only that the named human reviewed the captures against the named
direction. It is not an aesthetic score, a release decision, a substitute for `Design Ready`, or
proof of the reviewer's identity. Offline validation can verify file paths, hashes, field shape,
and freshness inputs; it cannot verify who looked at an image or what they thought of it.

An AI may prepare captures, draft notes, and report missing evidence. It must not fabricate a
human declaration, mark an approval row approved, or describe a manifest as proof that the
product is visually good.

---

## Review method

1. Confirm that `DESIGN/VISUAL-DIRECTION.md` is `selected` or `conformance` with its human
   direction decision reference.
2. Render the self-contained `DESIGN/DESIGN-SYSTEM.html` at the declared desktop and mobile
   viewports. Use realistic, registered sample data only.
3. Commit the two capture files inside the project, then record their repository-relative paths
   and SHA-256 hashes in `DESIGN/VISUAL-REVIEW.json`.
4. A human reviews every required lens against the selected direction and records concise notes
   or an open follow-up. A lens can be reviewed without pretending that every concern is closed.
5. Record the source/review-input digest after the final visual artifacts are in place, then run
   the Handoff gate. Regenerate the captures and manifest when any governed visual input changes.

The review should notice concept drift, but it must not redraw scope. An unscoped screen,
component, behaviour, or content value remains an open question rather than a design fix.

---

## Boundaries

- Visual Proof is not a new approval gate. It is conditional candidate evidence checked within
  the existing Handoff gate.
- It requires both viewport captures because responsive fit cannot be inferred from a desktop
  sheet alone.
- It does not make a browser, image model, or visual-comparison service mandatory. If the team
  cannot produce honest captures, the conditional evidence is missing and the Handoff result says
  so rather than substituting an AI claim.
- It does not create or rely on a `.agents/skills` mirror. The active workflow instructions stay
  under `.claude/skills/` and the generated `skills/` package is maintained by its packaging
  command.

See [`../concepts/visual-direction.md`](../concepts/visual-direction.md) for the creative brief
and rubric, and [`../concepts/handoff-readiness.md`](../concepts/handoff-readiness.md) for the
separate role of candidate evidence at Handoff.
