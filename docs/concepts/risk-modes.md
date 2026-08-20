# Risk-Adaptive Modes

Axiom-PMO scales process to risk. Each project — and each individual work item —
declares a mode that decides how much process is *required*. You can always do
more; you cannot silently do less.

## The three modes

| Mode | Use for | Required outputs |
|---|---|---|
| **Lite** | Small, low-risk fixes and clarifications | `PROJECT.md` update, one delivery item (or GitHub Issue), acceptance criteria, a test note. |
| **Standard** | Normal feature delivery | `PROJECT.md`, a design artifact when there's a flow/UI, `DELIVERY.md` or GitHub Issues, a test checklist. |
| **Strict** | Any strict trigger applies | Everything Standard requires, plus full source references, `RAID-log.md`, `decision-log.md`, an `RTM.json` traceability matrix, and separate QA **and** security approval. |

Mode has always decided which *files* a project needs (the table above). Since
2.3.0 it also decides how much must be *inside* the ones both Standard and
Strict already require — an SRS with real NFRs, a derived test-case matrix
instead of a handful of examples, a data dictionary joining fields to their
classification. This is opt-in per project via `> Spec depth: full` in
`PROJECT.md` (the default for anything created with `axiom init`); it does not
change which files are required, only how complete they must be. See
[document-depth](document-depth.md).

## Strict triggers

A work item is Strict if it involves any of: payment or financial calculation;
PII or confidential customer data; authentication, authorization, permission, or
audit logs; an irreversible action; external system integration; a legal or
compliance requirement; production data migration; critical infrastructure; or
public-sector formal acceptance.

## Effective mode cannot be silently downgraded

If any work item carries a Strict trigger, the validator forces the whole
project's **effective mode** to Strict even if `-Mode Lite` is passed on the
command line. An agent may escalate Lite → Standard → Strict on its own; it may
**not** downgrade Strict without PM or Tech Lead approval.

This resolution is enforced by the mode resolver in the
[validation engine](../architecture/validation-engine.md); the trigger list and
mode enums live in `pmo-config/policy.json`.
