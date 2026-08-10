# VISUAL-DIRECTION - DESIGN-SYSTEM-DEMO

> Synthetic example. This artifact records why RoomBook should look the way it does
> before the design-system sheet is composed. It is candidate design evidence, not
> an approval. The human selection is recorded in DEC-002.

## Status

```yaml
brand_starting_point: undecided
direction_status: selected
selected_direction: VD-01 - Live Room Field
decision_ref: DEC-002
```

| Field | Value | Evidence Status | Source Ref |
|---|---|---:|---|
| Stage | selected | verified | DEC-002 |
| Brand starting point | undecided | verified | DEC-002 |
| Direction status | selected | verified | DEC-002 |
| Selected direction | VD-01 - Live Room Field | verified | DEC-002 |
| Selection owner | Demo PO | verified | DEC-002 |
| Wireframe reference | `DESIGN/WIREFRAME.md` | supported | WF-001, WF-002 |
| Design-system handoff | `DESIGN/DESIGN-SYSTEM.md` | supported | DEC-002 |

`brand_starting_point: undecided` describes the state at the start of exploration.
It does not mean selection is still pending. `direction_status: selected` and
DEC-002 are the authority for the direction used by the brand and design system.

## Core Creative Brief

These fields materially change the presentation. Source-backed facts stay separate
from design hypotheses so a visual choice cannot quietly become a requirement.

| Field | Value | Evidence Status | Source Ref |
|---|---|---:|---|
| Purpose | Replace an out-of-date reception paper sheet with a current view of today's room availability and self-service booking | supported | MOM-20260805 item-1 |
| Primary audience | Any member of office staff; the first answer must not require training or asking another person | supported | REQ-20260805 row 1 |
| Primary moment | A person is at a shared browser view and needs to know what is free now | inferred | MOM-20260805 item-1 |
| Emotional target | Immediate orientation: calm, certain, and already moving toward a room | verified | DEC-002 |
| Personality | Fast, plain, unceremonious; operational rather than celebratory | verified | DEC-002 |
| Must feel like | A live operational room-status board | verified | DEC-002 |
| Must not feel like | A lifestyle calendar, a pastel productivity dashboard, or a collection of unrelated SaaS cards | verified | DEC-002 |
| Distinctive idea | Treat rooms as cells in one live status field; filled versus outlined space carries taken versus free before colour is read | verified | DEC-002 |
| Boldness | Assertive composition and large status signals, with conservative interaction behaviour | verified | DEC-002 |
| Accessibility | Status remains legible in words and fill/outline structure; focus and refusal cannot depend on hue alone | verified | DEC-002 |

## Conditional Creative Brief

| Field | Value | Evidence Status | Source Ref |
|---|---|---:|---|
| Language and culture | Current artifacts use English copy and retain Thai-capable fallbacks, but a product-language requirement was not found in source | missing | not found in MOM-20260805 or REQ-20260805 |
| Platform and viewing distance | Browser use is supported; desktop/tablet form factors and arm's-length viewing remain assumptions | inferred | MOM-20260805 item-1; form factor not found in source |
| Typography attitude | Compact operational labels paired with large, blunt room and time signals | verified | DEC-002 |
| Imagery and icon direction | No decorative photography; use structural room-cell outlines, status blocks, and signal lines drawn locally | verified | DEC-002 |
| Composition | A dark room-status field crossed by bright signal rails; light work surfaces appear only where reading or input needs them | verified | DEC-002 |
| Density | High information density at overview level, generous spacing at the booking decision point | verified | DEC-002 |
| Motion character | If implemented later, state changes should switch and snap like an operations board rather than float or bounce | inferred | DEC-002 |
| Surface and depth | Mostly flat status planes; elevation is reserved for the selected room | verified | DEC-002 |
| Existing brand assets at exploration start | None; logo, wordmark, colour meaning, and type treatment followed selection | verified | DEC-002 |
| Forbidden use | Amber cannot become a decorative highlight; it is reserved for the BR-001 overlap refusal | verified | DEC-002; REQ-20260805 row 3 |

## References and Anti-References

The references below are descriptive categories, not copied products or external
assets. No browser comparison or image-generation run was performed for this demo.

| Type | Reference | What To Learn or Avoid | Evidence Status | Source Ref |
|---|---|---|---:|---|
| reference | Departure and operations boards | One large status cue, stable row placement, and short labels that scan quickly | supported | DEC-002 |
| reference | Operations-room status board | Dense live state with clear exceptions and no decorative ambiguity | supported | DEC-002 |
| reference | Architectural drafting language | Line weight, fill, and outline distinguish states without implying real coordinates or navigation | supported | DEC-002 |
| anti-reference | Pastel productivity dashboard | Soft interchangeable cards weaken the difference between a place, a status, and an action | supported | DEC-002 |
| anti-reference | Lifestyle calendar | Month-grid imagery implies planning and scheduling depth that is outside today's scope | supported | DEC-002; MOM-20260805 item-4 |
| anti-reference | Hotel or property marketplace | Photography and promotional copy imply browsing venues rather than answering availability now | supported | DEC-002 |

## Art Directions Explored

These are different systems, not recolours of one layout. Geometry, type behaviour,
composition, density, colour role, imagery language, motion, and depth all change.

| ID | Concept Name | Rationale | Geometry and Composition | Type and Density | Colour, Imagery, Motion, and Depth | Cliche Avoided |
|---|---|---|---|---|---|---|
| VD-01 | Live Room Field | Turn room availability into a readable instrument: the page answers what is free before asking the user to read a list | Orthogonal room-status cells, signal rails, and an asymmetric control-board composition | Large room/time signals with compact uppercase operational labels; dense overview, quiet booking focus | Indigo marks committed/selected space, amber appears only on refusal; line-drawn status fields; state changes switch and snap; mostly flat with selected-room lift only | White cards floating independently on a pale dashboard |
| VD-02 | Corridor Placards | Make every room feel like a physical sign mounted outside a door, prioritising recognition and legibility at distance | Tall plaque modules, hard vertical rhythm, oversized room codes, one action rail | Wide humanist headings, sparse metadata, one room per visual beat | Warm off-white, black, and one industrial safety colour; engraved symbols; mechanical slide transitions; no shadows | Cute office illustrations and rounded productivity widgets |
| VD-03 | Dispatch Ledger | Treat the day as a shared operational record, making conflicts and ownership auditable at a glance | Horizontal timetable bands, ruled columns, stamped exceptions, editorial page composition | Condensed numeric rhythm with serif-like display contrast; highest density of the three | Paper-neutral field, indigo ink, amber rejection stamp; no pictorial imagery; cursor-like movement; entirely flat | Generic calendar grid and decorative gradient hero |

## Selected Direction

### VD-01 - Live Room Field

Demo PO selected VD-01 in DEC-002 before the brand files and visual sheet were
finalised. It answers REQ-001 most directly: rooms are perceived as one live status
field, not as appointments. It also gives BR-001 a disciplined exception
language: amber is absent until a booking is refused, so it cannot cry wolf.

"Live Room Field" is a visual metaphor only. It does not add room coordinates,
floor locations, routes, navigation guidance, or any other product field not present
in `DESIGN/WIREFRAME.md`.

The decision carried these presentation choices into the design system:

- Use a dark live-status field as the orienting canvas, with light surfaces only for
  detailed reading and input.
- Arrange room states as one connected field, not an interchangeable card collection.
- Let fill versus outline distinguish committed versus open space before colour.
- Use status labels, signal rails, blunt numerals, and terse operational copy.
- Reserve elevation for the selected room and amber for the overlap refusal.
- Keep all assets local and draw status/icon language as inline SVG or CSS.

## Anti-Generic Constraints

These patterns are not universally forbidden. They are forbidden as unexamined
defaults for RoomBook; any exception needs a brief-linked reason and human review.

| Constraint | Why It Conflicts Here | Allowed Exception |
|---|---|---|
| Do not make white rounded cards on pale grey the dominant composition | It turns room states into unrelated content tiles and hides the live-field metaphor | Light panels may contain forms or detailed copy where readability needs them |
| Do not add a purple-to-blue gradient hero | A promotional hero delays the one-glance availability answer and gives colour no operational meaning | None in the two scoped screens |
| Do not place a pill badge above a marketing headline | RoomBook is an internal instrument, not a launch page | Status pills inside room state components remain required and text-labelled |
| Do not use three pastel circular icons as value propositions | The product's promise is immediate state awareness; generic icon benefits do not prove it | Inline status glyphs may explain the selected metaphor |
| Do not use colour as the only difference between free, busy, selected, or refused | The state must survive monochrome output and colour-vision differences | Colour may reinforce text plus fill, outline, or pattern |
| Do not decorate with people, offices, or stock-room photography | It adds atmosphere while weakening the live operational reading | No exception without a new human decision |

## Capability and Review Honesty

- `render_status: not_performed` at the point this direction was selected.
- `browser_comparison_status: not_performed`.
- `image_generation_status: not_performed`.
- The HTML sheet is self-contained and uses no external font, script, or image request.
- DEC-002 records human direction selection. DEC-003 separately records Design Ready
  after the canonical artifacts were reviewed together.

## Open Questions

| ID | Question | Impact | Owner | Status |
|---|---|---|---|---|
| Q-001 | Is "RoomBook" the name this tool ships under? | Wordmark and every artifact that names the tool | Demo PM | open |
| Q-004 | Who owns the mark, and may it be used outside this repository? | Blocks public or customer-facing use of the logo | Demo PM | open |
