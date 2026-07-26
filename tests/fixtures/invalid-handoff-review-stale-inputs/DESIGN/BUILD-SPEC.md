# BUILD-SPEC - HANDOFF-DEMO

> Technical specification for the 2026-08-05 demonstration slice.
> Every section declares a Status. See `docs/rules/HANDOFF-005.md`.

## Sections

### Technology Stack

Status: specified

TypeScript 5.x, Node 20 LTS, SQLite 3 via better-sqlite3. No ORM; hand-written
SQL in a single repository module.

### Runtime and Deployment Model

Status: specified

A single Node process serving a static bundle and a small JSON API from the same
origin. Runs on a workshop laptop on the site network. No container, no cloud
dependency, no outbound network calls.

### UI Framework

Status: specified

React 18 with Vite. No component library; four screens do not justify one.

### Target Devices and Runtime Capabilities

Status: specified

| Capability | Required By | Serving Model | Environment Decision |
|---|---|---|---|
| Rear camera | AC-001 scan flow | HTTPS from a local reverse proxy with a certificate trusted by the tablet | DEC-005 |
| Numeric keypad input | AC-002, AC-003 | Standard HTML input; no capability needed | DEC-005 |
| Local file picker | AC-005 photo attach | Standard file input; no camera capture in this slice | DEC-006 |

### Architecture Boundaries

Status: specified

Three modules with one-way dependencies: `ui` calls `api`, `api` calls
`repository`, `repository` owns all SQL. Nothing calls back upward, and the UI
never issues SQL.

### Data Model

Status: specified

| Entity | Attribute | Type | Unit | Cardinality | Constraint |
|---|---|---|---|---|---|
| Part | part_code | text | n/a | 1 per part, unique | non-empty, matches the printed label format |
| Part | description | text | n/a | 1 per part | non-empty |
| Part | on_hand | integer | pieces | 1 per part | >= 0, whole numbers only |
| StockMovement | movement_id | integer | n/a | 1 per movement | assigned by the database, monotonic |
| StockMovement | part_code | text | n/a | many movements per part | must reference an existing Part |
| StockMovement | direction | text | n/a | 1 per movement | one of consume, receive |
| StockMovement | quantity | integer | pieces | 1 per movement | > 0, whole numbers only |
| StockMovement | recorded_at | timestamp | n/a | 1 per movement | set by the server, never the client |
| PartPhoto | file_path | text | n/a | 0..1 per part | stored under the local data directory |

### API or Command Contract

Status: specified

| Operation | Input | Success | Failure |
|---|---|---|---|
| `GET /api/parts/:code` | part_code | part with on_hand | 404 when no part matches |
| `POST /api/parts/:code/movements` | direction, quantity | new on_hand | 400 on non-whole or non-positive quantity; 409 when a consume would take on_hand below zero |
| `POST /api/parts/:code/photo` | multipart file | stored path | 400 on unsupported type or oversized file |

Every movement is reversible by recording the opposite movement. There is no
delete operation; corrections are new rows.

### State Machine and Transition Guards

Status: not_required
Rationale: A part has no lifecycle in this slice; on_hand is a counter, not a state, and no screen transitions a record between named states.

### Transaction Boundaries

Status: specified

Reading the current on_hand, checking the floor, writing the StockMovement row,
and updating Part.on_hand happen inside one transaction. A failure at any point
leaves both tables unchanged.

### Concurrency, Idempotency and ID Allocation

Status: specified

Two users may adjust the same part at once. The transaction above takes a write
lock on the Part row, so the second writer re-reads on_hand after the first
commits and its floor check uses the updated value. `movement_id` is allocated
by the database inside the transaction, so two concurrent writers cannot receive
the same id. The client sends a request id with each movement; a repeated
request id within the same session returns the original result rather than
recording a second movement.

### Error, Empty and Loading States

Status: specified

Scan in progress shows a spinner over the camera preview. An unknown code shows
"part not found" with a manual entry field. A rejected movement keeps the
previous count on screen and states why it was rejected. A part with no photo
shows an empty thumbnail with the Attach control.

### File and Image Processing

Status: specified

JPEG and PNG only, up to 5 MB. Files are stored under the local data directory
and served from the same origin. EXIF metadata, including any location tag, is
stripped on upload.

### Security, Privacy and Data Inventory

Status: specified

| Data Element | Contains Sensitive Data | Classification Decision | Retention Decision |
|---|---|---|---|
| Part code and description | no | not applicable | retained with the record |
| On-hand count and movements | no | not applicable | retained with the record |
| Part photo file | yes | DEC-003 internal-only, stays on the site network | DEC-003 purged on demo reset |
| Photo EXIF metadata | yes | DEC-003 stripped on upload, never stored | DEC-003 never written to disk |

### Retention, Backup and Restore

Status: not_required
Rationale: The demo dataset is regenerated from seed on every reset, so nothing in this slice has a retention or restore obligation before pilot.

### Seed Data

Status: specified

`seed/parts-demo.sql` creates 40 parts with printed-label codes, on-hand counts
between 0 and 250 pieces, and one part deliberately at zero so the floor
constraint can be demonstrated. Ten of the 40 have a pre-attached photo.
Every acceptance case below is reachable from this dataset.

### Acceptance Cases

Status: specified

| Case ID | Requirement Ref | Given / When / Then | Execution | Fixture / Seed | Reset |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | Given a printed label, when it is scanned, then the matching part opens | manual | parts-demo, any of the 40 printed labels | reprint from seed |
| AC-002 | REQ-002 | Given on_hand of 12, when 5 are consumed, then on_hand is 7 | automated | parts-demo part P-0007 | scripts/reset-demo.sh |
| AC-003 | REQ-003 | Given on_hand of 7, when 3 are received, then on_hand is 10 | automated | parts-demo part P-0007 | scripts/reset-demo.sh |
| AC-004 | REQ-002 | Given on_hand of 0, when 1 is consumed, then the movement is rejected and on_hand stays 0 | automated | parts-demo part P-0040 at zero | scripts/reset-demo.sh |
| AC-005 | REQ-004 | Given a part with no photo, when a JPEG is attached, then it appears on the record with no EXIF location | automated | parts-demo part P-0011, fixture photo with a location tag | scripts/reset-demo.sh |
| AC-006 | REQ-002 | Given two concurrent consumes of 1 from on_hand 1, when both commit, then exactly one succeeds | automated | parts-demo part P-0020 seeded at 1 | scripts/reset-demo.sh |

### Demo Reset Procedure

Status: specified

`scripts/reset-demo.sh` drops the database file, re-runs the schema, applies
`seed/parts-demo.sql`, and clears the photo directory. Takes about 20 seconds.
Run it before the demo and between rehearsals.

### Known Limitations

Status: specified

Single site only. No supplier or purchase-order records. No camera capture for
photos in this slice; a file is attached from the tablet's gallery. No offline
mode: the tablet must be on the site network.

Added after the review was recorded.
