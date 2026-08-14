# BUILD-SPEC - <PROJECT-CODE>

> The technical specification a developer builds against. `PROJECT.md` says what
> the system must do; this says what will be built and how it behaves at the
> boundaries.
>
> **Every section declares a `Status:` line.** Use `specified` and write the
> content, or `not_required` with a `Rationale:` of at least four words where
> policy allows a waiver. A blank section is never valid - the reader cannot
> tell whether you decided it did not apply or never got to it.
>
> Which sections are required per mode, and which may be waived, is in
> `pmo-config/handoff-policy.json` under `build_spec.sections`.

## Sections

### Technology Stack

Status: specified

<Languages, frameworks, and versions. Pin what matters; say what is free choice.>

### Runtime and Deployment Model

Status: specified

<Where this runs and how it gets there. Process model, hosting, build output.>

### UI Framework

Status: specified

<UI library and version, or `not_required` with a rationale for a headless component.>

### Target Devices and Runtime Capabilities

Status: specified

> One row per capability the build depends on. `Serving Model` may not be left
> undecided or blank - a capability whose delivery nobody has settled is a
> demo-day failure waiting to happen. The rejected tokens are listed in
> `pmo-config/handoff-policy.json` under
> `environment_capabilities.unresolved_tokens`.

| Capability | Required By | Serving Model | Environment Decision |
|---|---|---|---|
| <rear camera / offline read / file export> | <AC-002> | <how it is actually served> | <DEC-001> |

### Architecture Boundaries

Status: specified

<Modules and the lines between them. What may call what.>

### Data Model

Status: specified

> Cardinality and unit are separate columns for a reason: "stock" without a
> quantity and a unit is a name, not a model.

| Entity | Attribute | Type | Unit | Cardinality | Constraint |
|---|---|---|---|---|---|
| <Part> | <quantity_on_hand> | <integer> | <pieces> | <1 per part per location> | <>= 0> |

### API or Command Contract

Status: specified

<Operations, inputs, outputs, errors. Include the reverse of every mutation.>

### State Machine and Transition Guards

Status: specified

<States, allowed transitions, the guard on each, terminal states, and how a
transition is reversed.>

### Transaction Boundaries

Status: specified

<What commits together and what does not.>

### Concurrency, Idempotency and ID Allocation

Status: specified

<Two users acting at once. Retried requests. Where ids come from and why two
concurrent callers cannot receive the same one.>

### Error, Empty and Loading States

Status: specified

<What the user sees before data arrives, when there is none, and when it fails.>

### File and Image Processing

Status: specified

<Accepted formats, size limits, resizing, storage location, and what happens to
metadata such as EXIF location.>

### Security, Privacy and Data Inventory

Status: specified

> One row per data element. `Contains Sensitive Data` is **your** declaration -
> the validator does not guess. When you mark a row `yes`, both decision columns
> become required.

| Data Element | Contains Sensitive Data | Classification Decision | Retention Decision |
|---|---|---|---|
| <element> | <yes / no> | <DEC-001 or 'not applicable'> | <DEC-002 or 'retained with the record'> |

### Retention, Backup and Restore

Status: specified

<How long data lives, how it is backed up, and how a restore is verified.>

### Seed Data

Status: specified

<The dataset the system starts from. Name it, say where it lives, and say what
it contains - every acceptance case has to be reachable from it.>

### Test Strategy

Status: specified

> Defined during Design and revisited in the same contract at Handoff. Do not
> create a second test-plan artifact. `Execution` is `automated`, `manual`, or
> `exploratory`.

| Test Area | Requirement / Risk Ref | Level | Execution | Environment | Owner |
|---|---|---|---|---|---|
| <area> | <REQ-001 or R-001> | <unit / integration / system / security / usability> | <automated> | <environment> | <named owner> |

### Acceptance Cases

Status: specified

> `Execution` must be `automated`, `manual`, or `exploratory`.
> `Fixture / Seed` and `Reset` may not be blank; use `none` when a case
> genuinely needs no seed.

| Case ID | Requirement Ref | Given / When / Then | Execution | Fixture / Seed | Reset |
|---|---|---|---|---|---|
| AC-001 | <REQ-001> | <Given ..., when ..., then ...> | <automated> | <seed name> | <how to reset> |

### Demo Reset Procedure

Status: specified

<The exact steps to return to a clean demo state, and how long they take.
Required when the handoff target is demo or pilot.>

### Known Limitations

Status: specified

<What this build deliberately does not handle, so nobody reports it as a bug.>
