# BRAND assets - DESIGN-SYSTEM-DEMO

Brand direction, usage rules, and ownership are in [BRAND.md](BRAND.md).
This file explains what belongs in this folder and how the files are named.

## Files

| File | What it is | Where it is used |
|---|---|---|
| [logo-primary.svg](logo-primary.svg) | Full lockup, mark plus wordmark | Application header, documents, slides |
| [logo-mark.svg](logo-mark.svg) | Mark on its own | Square and small placements down to 24px |
| [app-icon.svg](app-icon.svg) | Mark on the dark brand surface | Launcher, browser tab, home screen |

## Naming

Lower case, hyphen separated, no spaces. A file name with a space breaks the
relative links that the project validator checks at the Release gate.

Do not put the words `token`, `secret`, `password`, `api-key`, `pricing`, or
`quotation` in a file name anywhere under a project. The validator matches those
against the whole path and reports the file as potentially sensitive, whatever it
actually contains. Note that the word is fine in file *content*, which is why
this design system has a section called Design Tokens and no file called tokens.

## Format

SVG only, hand authored, no editor metadata. An export from a design tool often
carries the author's local file path inside the file, which the public hygiene
scan reports. Open any exported SVG in a text editor and strip everything that is
not geometry before committing it.

The wordmark in `logo-primary.svg` is live text, not outlines, so it renders with
whatever family is available. That is acceptable for an internal tool. A mark
intended for public or print use should have its wordmark converted to paths so it
cannot reflow on a machine that lacks the family.

## What does not belong here

- Raster exports. PNG and JPG copies are derived artifacts. Generate them when a
  channel needs one, and do not commit them.
- Screenshots of the design system sheet. The sheet itself is
  [../DESIGN-SYSTEM.html](../DESIGN-SYSTEM.html) and it is the canonical copy.
- Font binaries, unless the licence has been checked and recorded in the ownership
  table in [BRAND.md](BRAND.md).

## Sharing a brand across projects

This folder is scoped to one project, which is the right default. If the same
brand is later used by several projects, move these files to a shared location and
leave a pointer here. Do not copy them into each project, because a copied mark
drifts and nobody can tell which copy is current.
