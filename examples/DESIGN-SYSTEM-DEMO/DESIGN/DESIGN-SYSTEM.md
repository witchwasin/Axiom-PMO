# DESIGN-SYSTEM - DESIGN-SYSTEM-DEMO

> Synthetic example. Optional artifact, required by no gate.
> This file is the contract a developer builds against. `DESIGN-SYSTEM.html` is the
> same contract rendered as one page a human can look at.
> A design system is candidate evidence, never an approval. It was input to DEC-003,
> it is not DEC-003.
> Concept and boundaries: `docs/concepts/design-system.md`.

## Artifact Authority

- Canonical: this file, `DESIGN/DESIGN-SYSTEM.html`, and the SVG files under `DESIGN/BRAND/`.
- Derived: any screenshot, exported PDF, printed sheet, or image pasted into a chat or deck.
  When a derived copy disagrees with a canonical file, the canonical file wins.
- The visual sheet is a visual overview, not a component workshop. It does not run and it
  does not replace a live component library once the product is under development.
- `DESIGN-001` checks that the token tables below and the sheet's `:root` block agree.
  It compares strings. It has no opinion on whether the design is any good.

## Status

- Stage: design-ready
- Visual direction reference: `DESIGN/VISUAL-DIRECTION.md`
- Selected direction: VD-01 - Live Room Field
- Direction decision ref: DEC-002
- Brand reference: `DESIGN/BRAND/BRAND.md`
- Visual sheet: `DESIGN/DESIGN-SYSTEM.html`
- Wireframe reference: `DESIGN/WIREFRAME.md`
- Brand decision ref: DEC-002
- Design Ready: DEC-003, which reviewed visual direction, brand, flow, wireframe,
  and this sheet in one round
- Sample data: every value rendered on the visual sheet is registered under `Sample Data Register`.
- Presentation-target assumption: browser layouts at desktop and tablet widths. Browser use
  is source-backed; form factor, viewing distance, and network model remain inferred and must
  not become implementation requirements without a human decision.

## Design Tokens - Color

Token names here are the CSS custom property names used in `DESIGN-SYSTEM.html`.
Keep both files in step: one value, two readers. `DESIGN-001` fails the build if they drift.

Contrast is measured against white and is a computed ratio, not an estimate.
Text needs 4.5 to 1 at normal size. A control boundary that carries meaning, such as
the focus ring, needs 3 to 1. A purely decorative hairline needs nothing, and this
table says so rather than implying a compliance it does not have.

| Token | Value | Role | Contrast Note |
|---|---|---|---|
| color-ink-900 | #1A1B2E | Headings and the dark brand surface | 16.93 to 1, passes AA and AAA for all text |
| color-ink-700 | #41456B | Body copy and room names | 9.18 to 1, passes AA and AAA for all text |
| color-ink-500 | #666A94 | Metadata, capacity, next free time | 5.18 to 1, passes AA for all text |
| color-brand-600 | #4338CA | Primary action and the focus ring | 7.90 to 1, and white text on it passes AA |
| color-brand-100 | #E6E4FB | Selected slot tint | 1.25 to 1, surface only, never carries text |
| color-accent-600 | #B45309 | The overlap refusal, and nothing else | 5.02 to 1, passes AA for all text |
| color-surface-50 | #F7F7FB | Page background behind the room list | 1.07 to 1, surface only, never carries text |
| color-line | #E4E4ED | Decorative hairline between surfaces | 1.26 to 1. Decorative only. It must never be the sole indicator of a control boundary or a state, because it does not meet the 3 to 1 non-text minimum and is not intended to |

## Design Tokens - Typography

| Token | Family | Size | Line Height | Weight | Use |
|---|---|---|---|---|---|
| type-display | Inter | 32px | 40px | 700 | Screen title, one per screen |
| type-title | Inter | 19px | 28px | 700 | Room name and dialog titles |
| type-body | Inter | 15px | 24px | 400 | Default copy |
| type-caption | Inter | 12px | 16px | 400 | Capacity, times, helper text |

## Design Tokens - Spacing and Radius

| Token | Value | Use |
|---|---|---|
| space-1 | 4px | Gap between a status pill and its label |
| space-2 | 8px | Tight grouping inside a room card |
| space-3 | 12px | Padding inside a room card |
| space-4 | 16px | Default gap between cards |
| space-6 | 24px | Page and panel padding |
| radius-sm | 8px | Buttons, inputs, time slots |
| radius-md | 12px | Room cards |
| radius-lg | 18px | Page level panels |

## Design Tokens - Border and Elevation

A raised card means the room is selected. Nothing else on this screen uses elevation-2.

| Token | Value | Role |
|---|---|---|
| border-hairline | 1px solid #E4E4ED | Decorative separation between surfaces |
| border-focus | 2px solid #4338CA | Keyboard focus ring, never removed, and the one border that carries meaning |
| elevation-0 | none | The page and the room list, which sit flat |
| elevation-1 | 0 1px 2px rgba(26,27,46,.06) | A room card at rest |
| elevation-2 | 0 8px 24px rgba(26,27,46,.12) | The selected room card, and only that |

## Component Inventory

- `Variants` are the shapes the same component can take, chosen by the developer at the call site.
- `States` are what one variant does over time in response to the user or the system.

The states listed are the ones that must exist, not the ones drawn on the sheet.
What the sheet actually draws is in `Screen Mockups`.

| Component ID | Name | Variants | States | Screen Ref | Requirement Ref | Evidence Status |
|---|---|---|---|---|---|---:|
| C-001 | Button | primary, secondary, tertiary | default, hover, pressed, focus, disabled, loading | WF-002 | REQ-002 | supported |
| C-002 | Room status pill | free, busy, free soon | default only, the pill is not interactive | WF-001 | REQ-001 | supported |
| C-003 | Room card | default, compact | default, hover, focus, selected, unavailable | WF-001 | REQ-001 | supported |
| C-004 | Time slot picker | hour, half hour | default, focus, selected, unavailable, disabled | WF-002 | REQ-002, BR-001 | supported |
| C-005 | Inline alert | success, warning, danger, info | default, dismissed | WF-002 | BR-001 | supported |

## Component Details

### C-001 - Button

- Purpose: commit a booking the user has already decided on. A button never discovers information, it only applies it.
- Variants: primary for the one action that completes a booking, at most one per view. Secondary for a reversible alternative such as cancel a booking. Tertiary for low weight actions such as close.
- States: hover darkens the fill by 8 percent, pressed by 18 percent. Focus shows border-focus and never removes the fill. Disabled drops to the neutral fill. Loading keeps the width fixed and replaces the label so the layout does not jump.
- Behaviour: a click that will be refused by BR-001 is not prevented. The button stays enabled and the refusal is reported by C-005, because a disabled button with no explanation sends the user to ask a human.
- Accessibility: minimum target 44 by 44 including padding. The loading state sets a busy attribute. Focus is never conveyed by colour alone.
- Source ref: REQ-20260805 row 2

### C-002 - Room status pill

- Purpose: let a person scan the list and find a free room without reading times.
- Variants: free, busy, and free soon. Only the refusal path uses the accent colour, so a coloured pill here never competes with it for attention.
- States: not interactive, so it has no states. It is listed to make that explicit rather than leaving a reader to assume it is a filter.
- Behaviour: none. It does not book when clicked. Booking is C-004 plus C-001.
- Accessibility: status is carried by the text label as well as the fill, so it survives a monochrome display and colour blindness.
- Source ref: REQ-20260805 row 1

### C-003 - Room card

- Purpose: carry the three things a person needs to decide: room name, capacity, and whether it is free.
- Variants: default shows name, capacity, status, and next free time. Compact drops the next free time and is used on a tablet in portrait.
- States: hover raises border contrast only. Focus shows border-focus. Selected is the only use of elevation-2. Unavailable dims the card but keeps it readable, because a user still needs to know the room exists.
- Behaviour: selecting a card opens WF-002 with that room preselected.
- Accessibility: the card is a single focusable control with an accessible name that includes the status, so a screen reader user does not have to infer it from the pill.
- Source ref: REQ-20260805 row 1

### C-004 - Time slot picker

- Purpose: choose a start and end without typing a time, which is where users make mistakes.
- Variants: hour for the default grid, half hour where a room is heavily used.
- States: default, focus, selected, unavailable when the slot overlaps an existing booking, disabled when the whole day is in the past.
- Behaviour: an unavailable slot is visible and explains why on focus. It is not hidden, because a hidden slot reads as a bug to a user who knows the room exists.
- Accessibility: the grid is keyboard navigable with arrow keys, and unavailable slots are announced as such rather than silently skipped.
- Source ref: REQ-20260805 row 2, row 3

### C-005 - Inline alert

- Purpose: report the result of an action next to the action.
- Variants: success, warning, danger, info.
- States: default and dismissed. Danger is never auto dismissed.
- Behaviour: the overlap refusal names the conflicting booking and its time, so the user can pick a different slot without hunting.
- Accessibility: a live region. Danger announces assertively, everything else politely.
- Source ref: REQ-20260805 row 3

## Screen Mockups

Only screens that already exist in `DESIGN/WIREFRAME.md` may appear on the sheet.
A screen the team wants but has not scoped belongs in `Open Questions`, not in a mockup.

`States Covered` is what the sheet actually draws. The undrawn states below were
accepted as known gaps by DEC-003 and are the input to the
`Error/Empty and Loading States` section of the build spec, which this project has
not written yet.

| Screen ID | Name | Wireframe Ref | Sheet Section | States Covered | States Not Yet Drawn | Requirement Ref |
|---|---|---|---|---|---|---|
| WF-001 | Today availability | DESIGN/WIREFRAME.md | screen-examples, frames 1 and 2 | populated, empty | loading, offline, room unavailable all day | REQ-001 |
| WF-002 | Booking form | DESIGN/WIREFRAME.md | screen-examples, frame 3 | overlap refusal | happy path confirmation, cancel confirmation, past day disabled | REQ-002, REQ-003 |

## Sample Data Register

Every number, name, date, and label rendered on the visual sheet has a row here.
`Origin` is `illustrative` or `source-derived`. Real customer data, real names, and
real account identifiers do not appear, in any mode.

| Location | Value Shown | Origin | Note |
|---|---|---|---|
| Frames 1 and 3, room names | Room A, Room B, Room C | illustrative | Deliberately not building specific, so no reader mistakes them for the real office |
| Hero and frame 3, state prefixes | STATUS / FREE, STATUS / BUSY, STATUS / FREE SOON, STATUS / SELECTED | illustrative | Presentation copy restating already scoped status/component states; it adds no room-location field |
| Frames 1 and 3, capacities | 4, 8, 12 | illustrative | Chosen to span the range a small office actually has |
| Frame 1, room count | 03 | illustrative | Count derived from the three illustrative rooms shown in the same frame |
| Frame 1, status pills | Free, Busy, Free soon | source-derived | The three states REQ-001 requires a person to distinguish |
| Frame 1, next free time | 14:30 | illustrative | No time source exists in scope |
| Frame 2, empty list body | No rooms configured yet | illustrative | Copy is a first draft, open as Q-002 |
| Frame 3, booking owner | Staff A | illustrative | Deliberately not person shaped |
| Frame 3, refusal message | Room B is already booked from 14:00 to 15:00 | source-derived | The BR-001 refusal, with an illustrative time |
| Component library, slot times | 13:00, 13:30, 14:00, 14:30 | illustrative | Chosen so one slot is unavailable and adjacent to a selected one |
| Component library, success message | Room A is booked for you, 13:30 to 14:00 | illustrative | Demonstrates the successful booking state with registered room and time values |
| Component library, informational message | Showing today only | source-derived | REQ-002 limits the booking slice to the current day |
| Component and screen actions | Book this slot, Cancel booking, Close | source-derived | Booking and self-cancellation trace to REQ-002 and REQ-003; Close is illustrative control copy |
| Product promise rail | Read the status. Keep moving.; Answer in one glance; Book it yourself; Never double booked; Colour means one thing | source-derived | Summarises REQ-001, REQ-002, BR-001, and DEC-002 without adding behaviour |

## Assumptions

| ID | Assumption | Validation Needed | Owner | Due | Status |
|---|---|---|---|---|---|
| A-001 | Staff decide from name, capacity, and status alone, without needing to see equipment | Watch three people pick a room | Demo PM | 2026-08-21 | open |
| A-002 | A tablet in portrait is the narrowest real screen, so the room list never needs a single column layout | Confirm against the office device list | Demo Tech Lead | 2026-08-14 | open |

## Open Questions

| ID | Question | Impact | Owner | Status |
|---|---|---|---|---|
| Q-002 | What should the empty room list say? The current copy states the fact but offers no next step | Microcopy on WF-001 | Demo PM | open |
| Q-003 | Should an unavailable slot show who booked it, or only that it is taken? | Whether the booking list is readable by everyone, which is a privacy question, not a design one | Demo PO | open |
