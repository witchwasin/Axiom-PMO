# VPROOF-002 - Visual Proof evidence is stale

## What it checks

`DESIGN/VISUAL-REVIEW.json` records one digest over the project summary, visual
direction, design-system Markdown and HTML, brand assets, and committed
desktop/mobile captures. The rule recomputes that digest at the `Handoff` gate.

## Why it blocks

A review only speaks for the files the reviewer saw. A new brand asset, token,
layout, or capture can make a previously accurate review obsolete even when the
review JSON itself was not edited.

## What it does not decide

It cannot tell whether a changed design is better or worse, and it cannot prove
pixel provenance. It only says that the recorded evidence no longer names the
current files and must not be presented as current.

## How to fix it

Review the current artifacts, update or recreate the required local captures,
then run:

```bash
node -e "import('./dist/tools/digest-tools.js').then(m=>process.stdout.write(m.visualProofDigest('.', '<project>').output))"
```

Put the returned value in `review_inputs.digest` and record any new human
decision before re-running the Handoff gate.

Related: [Visual Proof architecture](../architecture/visual-proof.md).
