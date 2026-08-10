# DESIGN-001 - Design system token drift

| | |
|---|---|
| Level | FAIL from the Design gate onward, WARN at Scope, INFO at Draft |
| Gate | All |
| Applies to | Lite, Standard, Strict |
| Artifacts | `DESIGN/DESIGN-SYSTEM.md`, `DESIGN/DESIGN-SYSTEM.html` |

## What this rule checks

Only when **both** files exist:

1. Every token declared in a `## Design Tokens` table in `DESIGN/DESIGN-SYSTEM.md` exists as a CSS custom property in the sheet's `:root` block.
2. Its value is the same in both files, after normalising whitespace and hex case, and after resolving one token that is defined in terms of another with `var(--other-token)`.

Token names compare case-sensitively, because CSS custom property names are case-sensitive: `--Brand` and `--brand` are two different tokens, so a case difference is real drift and not a typo worth absorbing.

## Why it blocks

The value is written twice on purpose. The markdown is the contract a developer builds from; the sheet is the page a stakeholder looked at and reacted to. That duplication is what makes the artifact pair useful, and it is also what makes it fragile: change one file and the other keeps making a claim that is no longer true.

Nothing else in the framework would notice. The sheet renders fine with the wrong colour. The markdown reads fine with the right one. The gap surfaces during build, when a developer implements the contract and someone asks why the screen does not look like the picture that was approved.

This is exactly the kind of defect deterministic validation exists for: two strings, both present in the repository, provably equal or provably not.

## What the validator does not do

It does not judge design. It has no opinion on whether a colour is right, whether contrast is adequate, whether a token should exist, or whether the palette is any good. Those are review questions and stay with a human.

It is deliberately **one-directional**. A custom property in the sheet that the markdown never mentions is not reported, because a working page always needs values the contract has no opinion about.

It skips tables that have no `Value` column. The typography table spreads one token across Family, Size, Line Height, and Weight, which is not a single comparable value, so the rule leaves it alone rather than guessing.

It never asks for the design system to exist. The artifact is optional in every mode, and a project with neither file, or with only the markdown, produces no finding at all.

## How to fix

Change the sheet to match the markdown, unless the markdown is the file that is wrong. The message names each token, the value the markdown declares, and the value the sheet carries:

```text
[FAIL] DESIGN-001 Design system token drift: color-brand-500 is '#1F6F5C' in
DESIGN/DESIGN-SYSTEM.md but '#FF0000' in the sheet; radius-lg is declared in
DESIGN/DESIGN-SYSTEM.md but no --radius-lg exists in the sheet
```

If a token in the sheet is composed from another with `var()`, fix the token it refers to. One wrong base value reports as drift on every token that resolves through it, which is the correct behaviour: they are all wrong.

## Related

`STRUCT-001`, `PLACEHOLDER-001`, `docs/concepts/design-system.md`
