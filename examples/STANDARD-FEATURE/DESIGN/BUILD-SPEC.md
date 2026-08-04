# BUILD-SPEC - STANDARD-FEATURE

> Technical specification for the ticket status board slice (D-001).
> Every section declares a Status. See `docs/rules/HANDOFF-005.md`.

## Sections

### Technology Stack

Status: specified

TypeScript 5.x, React 18, Node 20 LTS for the API. No ORM; a single
repository module talks to an in-memory/JSON store for this internal tool.

### Runtime and Deployment Model

Status: specified

A single Node process serves a static React bundle and a small JSON API
from the same origin. Runs on internal company infrastructure behind the
existing staff-only VPN; no public endpoint.

### UI Framework

Status: specified

React 18, no component library — four board columns and two simple
controls (move, filter) do not justify one.

### Target Devices and Runtime Capabilities

Status: specified

| Capability | Required By | Serving Model | Environment Decision |
|---|---|---|---|
| Desktop browser (staff workstation) | AC-001, AC-002 | Standard web app over the internal network; no special browser capability required | DEC-004 |

### Architecture Boundaries

Status: specified

Three modules with one-way dependencies: `ui` calls `api`, `api` calls
`repository`, `repository` owns all ticket reads/writes. The UI never
talks to the repository directly.

### Data Model

Status: specified

| Entity | Attribute | Type | Unit | Cardinality | Constraint |
|---|---|---|---|---|---|
| Ticket | id | text | n/a | 1 per ticket, unique | non-empty |
| Ticket | title | text | n/a | 1 per ticket | non-empty |
| Ticket | priority | text | n/a | 1 per ticket | one of low, medium, high |
| Ticket | owner | text | n/a | 1 per ticket | staff display name |
| Ticket | status | text | n/a | 1 per ticket | one of To Do, In Progress, Review / Test, Done |
| Ticket | review_notes | text | n/a | 0..1 per ticket | required non-empty before status may become Done |

### API or Command Contract

Status: specified

| Operation | Input | Success | Failure |
|---|---|---|---|
| `GET /api/tickets` | optional `priority`, `status` filters | list of matching tickets | none — an empty filter match returns an empty list, not an error |
| `POST /api/tickets/:id/status` | target status, review_notes (required when target is Done) | ticket with updated status | 400 when target is Done and review_notes is empty |

Every status move is reversible by issuing another move back to the prior
status; there is no destructive operation in this slice.

### State Machine and Transition Guards

Status: specified

States: To Do, In Progress, Review / Test, Done (all terminal-adjacent;
Done is the only terminal state). Any state may move to any other listed
state (support tickets are not assumed to move strictly left-to-right),
except: the transition into Done is guarded by `review_notes` — non-empty
required (BR-001). Reversal: a ticket in Done can be reopened by moving it
back to any prior status; this clears no data and requires no separate
confirmation.

### Transaction Boundaries

Status: specified

A single status move (read current status, check the Done guard, write
the new status) happens inside one request/transaction. A failed guard
check leaves the ticket unchanged.

### Concurrency, Idempotency and ID Allocation

Status: specified

Two staff may move the same ticket at once; the write takes a per-ticket
lock, so the second write re-reads the current status before applying its
own move. `id` is assigned by the repository at ticket creation (outside
this slice's scope) and is never reassigned. A repeated identical status
move (same ticket, same target status) is a no-op that returns the
current state rather than erroring.

### Error, Empty and Loading States

Status: specified

Board shows a loading skeleton while tickets load. An empty board (no
tickets) shows a plain "No tickets yet" message, not an error. Attempting
to move a ticket to Done with empty review notes shows the inline
validation message defined in `DESIGN/FLOW.puml`, and the ticket stays in
its prior column.

### File and Image Processing

Status: not_required
Rationale: This slice has no file or image upload; ticket fields are plain text only.

### Security, Privacy and Data Inventory

Status: specified

| Data Element | Contains Sensitive Data | Classification Decision | Retention Decision |
|---|---|---|---|
| Ticket title | no | not applicable | retained with the ticket record |
| Ticket priority | no | not applicable | retained with the ticket record |
| Ticket owner (staff display name) | no | DEC-005 — internal staff display name, visible only to authenticated staff on an internal-only tool, not treated as sensitive for this system | retained with the ticket record |
| Review notes | no | not applicable | retained with the ticket record |

### Retention, Backup and Restore

Status: not_required
Rationale: Standard mode does not require this section; ticket data follows the existing internal support-tool backup policy, unchanged by this feature.

### Seed Data

Status: specified

Board seeds with 5 tickets spanning all four statuses (2 To Do, 1 In
Progress, 1 Review / Test, 1 Done with review notes already filled),
covering at least one high-priority open ticket for the filter case.

### Acceptance Cases

Status: specified

| Case ID | Requirement Ref | Given / When / Then | Execution | Fixture / Seed | Reset |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | Given a ticket in To Do, when staff move it to In Progress, then the board shows it in the In Progress column | manual | seed set (5 tickets) | reload seed set |
| AC-002 | REQ-001 | Given a ticket with no review notes (BR-001), when staff attempt to move it to Done, then the move is blocked and the validation message from `DESIGN/FLOW.puml` is shown | manual | seed set (5 tickets) | reload seed set |

### Demo Reset Procedure

Status: not_required
Rationale: Handoff Target is internal, not demo or pilot, so no demo reset procedure is required.

### Known Limitations

Status: specified

- Priority filter (REQ-002 / D-002) is explicitly deferred — see `HANDOFF.md` Deferred / Do Not Build and `RELEASE.md` Release Scope.
- No customer-facing portal — internal staff tool only (`PROJECT.md` Out of Scope).
