# BRAND - DESIGN-SYSTEM-DEMO

> Synthetic example. Every name in this file is a demo persona, not a real person.
> The SVG files in this folder are canonical. A PNG, a screenshot, or a copy pasted
> into a deck is derived, and never the artifact anyone edits or argues with.

## Brand Direction

The audience row is derivable from source. The rest are business decisions, and they
became `verified` when a human selected VD-01 "Live Room Field" in DEC-002
after comparing the directions in `DESIGN/VISUAL-DIRECTION.md` and before the sheet
was composed. The product name is still open, because DEC-002 accepted it as provisional.

| Field | Value | Evidence Status | Source Ref |
|---|---|---:|---|
| Primary audience | Any member of office staff, with no training | supported | PROJECT.md REQ-001 |
| Product name | RoomBook | inferred | Provisional in DEC-002, still open as Q-001 |
| Tagline | Find a room. Book it. Go. | verified | DEC-002 |
| Personality | Fast, plain, unceremonious | verified | DEC-002 |
| Tone of voice | Short statements. No congratulation for booking a room | verified | DEC-002 |

## Logo Concept

- Symbol: an outlined room field with one room filled solid.
- Meaning: the product is not a calendar; it is a picture of room status right now. One room is taken, the rest are not, and that is the live-state idea selected in VD-01. The mark does not promise floor location or navigation.
- Reads as: taken versus free is carried by **fill against outline**, not by hue. That was a deliberate correction. The first draft drew the free rooms as white shapes on a light floor, which measured 1.26 to 1 and disappeared, leaving a mark that read as one blue bar. Filled against unfilled survives 24px, a monochrome print, and colour blindness, which is the same principle the status pill follows.
- Approved down to 24px on that basis.

## Logo Assets

| Asset | File | Use | Minimum Width | Clear Space |
|---|---|---|---|---|
| Primary lockup | logo-primary.svg | Application header, documents, slides | 120px | Half the mark height on all four sides |
| Mark only | logo-mark.svg | Square and small placements, favicon | 24px | Half the mark height on all four sides |
| App icon | app-icon.svg | Launcher, browser tab, home screen | 48px | None, the icon supplies its own padding |

## Color Meaning

| Token | Value | Meaning |
|---|---|---|
| color-brand-600 | #4338CA | Taken, chosen, committed. The booked room in the mark, the selected slot, the primary action, and the focus ring. |
| color-ink-900 | #1A1B2E | The surface the plan sits on. Used for the app icon field and for headings. |
| color-accent-600 | #B45309 | The refusal, and only the refusal. Reserved so that seeing it always means a booking did not happen. |

## Typography Choice

- Primary family: Inter
- Why: designed for user interface text at small sizes, open licence, and a large enough x-height that a room name and a time stay legible inside a narrow card.
- Script coverage: the current demo artifacts use English sample copy, but no product-language requirement was found in source. The fallback stack carries Thai families so a later human language decision does not require changing token names.
- Fallback stack: Inter, IBM Plex Sans Thai, Noto Sans Thai, then the platform user interface family.

## Usage Rules - Do

- Keep the taken room solid and the surrounding room field outlined. The fill against the outline is what carries the meaning, and it must survive if the mark is printed in one colour.
- Use `color-accent-600` only for the overlap refusal. Reusing it anywhere else destroys its meaning at a glance.
- Place the lockup on white or on `color-surface-50`.

## Usage Rules - Do Not

- Do not recolour the mark to reflect availability. The mark is the product, not a status indicator.
- Do not place the lockup on `color-ink-900`. The wordmark loses contrast. Use the app icon instead.
- Do not rely on `color-line` to show that something is a control. It measures 1.26 to 1 against white, which is decorative and below the 3 to 1 minimum a meaningful boundary needs.

## Ownership and Licence

A logo is intellectual property. An AI cannot confirm ownership, so `Confirmed By`
stays empty until a human fills it. The mark must not be used anywhere public while
this table is unconfirmed.

| Item | Owner | Licence | Confirmed By | Date |
|---|---|---|---|---|
| Logo and mark | Not yet stated | Drawn for this project in this repository, ownership not yet stated | Not confirmed | Not confirmed |
| Typeface Inter | Rasmus Andersson | SIL Open Font License 1.1 | Not confirmed | Not confirmed |
| Iconography | Not applicable | No third party icon set is used, all shapes are drawn in this repository | Not confirmed | Not confirmed |

## Open Questions

| ID | Question | Impact | Owner | Status |
|---|---|---|---|---|
| Q-001 | Is "RoomBook" the name this tool ships under? DEC-002 accepted it as provisional only | The wordmark, the app title, and every document that names the tool | Demo PM | open |
| Q-004 | Who owns the mark, and is anyone permitted to use it outside this repository? | Blocks any public or customer-facing use of the logo | Demo PM | open |
