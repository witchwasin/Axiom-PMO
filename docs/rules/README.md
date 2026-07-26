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

## Other rules

Rules outside the Handoff gate carry a `suggestion` in the catalog but do not yet have a dedicated page. The catalog entry in `pmo-config/validation-rules.json` is the reference for those.
