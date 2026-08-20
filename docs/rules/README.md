# Rule reference

One page per rule that a person can act on. Every page answers the same four questions: what is checked, why it blocks, what the validator deliberately does *not* decide, and how to fix it.

These pages are linked automatically. A rule's `documentation` path in `pmo-config/validation-rules.json` is joined to `documentation_base_url` and emitted as `documentation_url` on every WARN and FAIL diagnostic for that rule. `pmo-doctor` check `DOCTOR-009` fails the build if a referenced page does not exist, so a diagnostic can never advertise a dead link.

## Handoff gate

| Rule | Summary |
|---|---|
| [HANDOFF-001](HANDOFF-001.md) | Required handoff artifact missing |
| [HANDOFF-002](HANDOFF-002.md) | Scope contract incomplete |
| [HANDOFF-003](HANDOFF-003.md) | Work item has no named owner |
| [HANDOFF-004](HANDOFF-004.md) | Dependency or build sequence incomplete |
| [HANDOFF-005](HANDOFF-005.md) | Required BUILD-SPEC section incomplete |
| [HANDOFF-006](HANDOFF-006.md) | Acceptance case has no execution classification |
| [HANDOFF-007](HANDOFF-007.md) | Acceptance case has no seed or fixture strategy |
| [HANDOFF-008](HANDOFF-008.md) | Demo milestone lacks capacity, integrator, device, or reset path |
| [HANDOFF-009](HANDOFF-009.md) | Open action has no owner or blocking point |
| [HANDOFF-010](HANDOFF-010.md) | Semantic review missing, incomplete, or stale |
| [HANDOFF-011](HANDOFF-011.md) | Declared sensitive-data capability lacks a decision |
| [HANDOFF-012](HANDOFF-012.md) | Declared device or runtime capability lacks an environment decision |
| [HANDOFF-013](HANDOFF-013.md) | Table header does not match the declared columns |
| [HANDOFF-014](HANDOFF-014.md) | Handoff artifact names a different project |

## Visual Proof sub-check

| Rule | Summary |
|---|---|
| [VPROOF-001](VPROOF-001.md) | Conditional Visual Proof record or capture evidence is incomplete |
| [VPROOF-002](VPROOF-002.md) | Conditional Visual Proof evidence is stale |

## Specification depth (`> Spec depth: full`)

Gated on `PROJECT.md`'s `Spec depth` declaration; a `legacy` project (the
default before this declaration existed) never triggers any of these. See
[document-depth](../concepts/document-depth.md).

| Rule | Summary |
|---|---|
| [REQ-TYPE-001](REQ-TYPE-001.md) | Requirement type validation |
| [SRS-001](SRS-001.md) | Software Requirements Specification section presence and status |
| [SRS-002](SRS-002.md) | Non-Functional Requirements measurement completeness |
| [SRS-003](SRS-003.md) | Non-Functional Requirements traceability and evidence |
| [SRS-004](SRS-004.md) | Mandatory NFR categories in Strict mode |
| [ARCH-001](ARCH-001.md) | Technology Decisions completeness and decision log linkage |
| [DATA-003](DATA-003.md) | Entity Relationships consistency with Data Model |
| [DATA-004](DATA-004.md) | Foreign key field consistency with Data Model |
| [DATAFLOW-001](DATAFLOW-001.md) | Data Dictionary completeness against BUILD-SPEC Data Model |
| [DATAFLOW-002](DATAFLOW-002.md) | Data Dictionary sensitive classification agreement |
| [JOURNEY-001](JOURNEY-001.md) | Journey step State Before/After resolution against State Machine |
| [JOURNEY-002](JOURNEY-002.md) | Scoped requirement journey coverage |
| [TEST-CASE-001](TEST-CASE-001.md) | Test cases completeness and criteria definition |
| [TEST-CASE-002](TEST-CASE-002.md) | Test case uniqueness, categories, and target linkage |
| [TEST-CASE-003](TEST-CASE-003.md) | Test case source traceability and evidence status |
| [TEST-COVERAGE-001](TEST-COVERAGE-001.md) | Specification depth test coverage matrix |
| [TEST-COVERAGE-002](TEST-COVERAGE-002.md) | Scoped requirements coverage completeness |
| [API-001](API-001.md) | OpenAPI specification presence and version header |
| [API-002](API-002.md) | OpenAPI operationId correspondence with BUILD-SPEC |
| [RTM-011](RTM-011.md) | Anti-forged verified status in RTM |

## Framework doctor

| Rule | Summary |
|---|---|
| [DOCTOR-015](DOCTOR-015.md) | Template BUILD-SPEC sections and table columns match policy |

## Other rules

Rules outside the tables above carry a `suggestion` in the catalog but do not yet have a dedicated page. The catalog entry in `pmo-config/validation-rules.json` is the reference for those.
