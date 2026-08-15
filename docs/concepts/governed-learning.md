# Governed Learning

Milestone 9 gives Axiom-PMO organizational memory over diagnostics the
validator already emits — recurring findings clustered, disposed, and
surfaced as human-reviewed improvement candidates. It is deliberately small:
an aggregator over existing JSON, not a new engine, and the entire mechanism
sits inside one hard boundary stated plainly rather than assumed:

> **Nothing offline can prevent an agent with write access from editing
> `pmo-config/*.json`.** What is real is detection and visibility, never
> prevention. An AI may **observe → aggregate → propose → supply evidence.**
> Only a human may **review → authorize → promote → accept risk.**

See [Permanent Non-Goals](../../ROADMAP.md#permanent-non-goals) in
`ROADMAP.md` — this is that section's concrete implementation.

## The pipeline

```text
scripts/validate-project.ps1 -Format Json
        |
        v
scripts/aggregate-diagnostics.ps1
        |
        +--> .axiom/learning/events/<utc-timestamp>-<run-id>.jsonl
        |    one immutable file per run, written once, never reopened --
        |    two runs cannot collide because they never share a file
        |
        +--> .axiom/learning/FAILURE-PATTERNS.json
        |    rebuilt from EVERY event file, every time -- never itself the
        |    source of truth. A corrupted or deleted registry is a re-run
        |    of this step, not a data-loss event: axiom aggregate-diagnostics -RebuildOnly
        |
        +--> .axiom/learning/candidates/IMP-<rule-id>.json
             only for a cluster crossing the multi-dimensional threshold in
             pmo-config/learning-policy.json clustering.candidate_threshold --
             never a raw occurrence count
```

## Local and opt-in

No network call exists anywhere in `aggregate-diagnostics.ps1`. Raw events
are git-ignored by default (`.axiom/learning/events/`, `.axiom/learning/salt`)
— they are per-run local observations, and committing them by default would
push that into shared history without anyone choosing to. A team that wants
shared memory commits the **derived** registry,
`.axiom/learning/FAILURE-PATTERNS.json`, instead. Any future external or
cross-organization aggregation is a separate, explicitly authorized
milestone (`DEC-013`, `DEC-015`) — not a configuration change to this one.

## "Metadata-only" is not a privacy guarantee

A bare artifact path can disclose a subject without a byte of file content —
`customers/acme/fraud-investigation.md` says enough on its own. Every field
in an event record carries an explicit, auditable disposition
(`pmo-config/learning-policy.json field_disposition`):

| Disposition | Fields |
|---|---|
| Retained verbatim (closed enums) | `rule_id`, `level`, `blocking`, `mode`, `gate`, `execution_path` |
| Retained only if on the governed-artifact allowlist, else `"other"` | `artifact` |
| Normalized to its id pattern (`D-###`, never the literal id) | `item_id` |
| Hashed with a per-repository salt | the project's path |
| Dropped always | `message`, `suggestion`, `field`, `documentation_url` |

## Clustering is multi-dimensional, never a raw count

Twenty reruns against one unfixed defect in one project is one problem, not
twenty. A cluster only crosses the improvement-candidate threshold when it
spans enough *distinct* projects, commits, and a wide enough time span —
`pmo-config/learning-policy.json clustering.candidate_threshold` — asserted
by a test that reruns the same fixture twenty times and confirms zero
candidates result.

## Improvement candidates default to nothing

An `IMPROVEMENT-CANDIDATE.json` must weigh the full remedy set —
documentation, onboarding, wording, a changed default, a validator defect,
false-positive reduction — before ever proposing a new rule. This is the
same prohibition `ROADMAP.md`'s `Not Now` already states: "adding validation
rules only to increase perceived coverage." An AI-authored candidate's
`status` can only ever be `proposed`; any other value requires a `DEC-###`.

## The rule lifecycle ceiling

A catalog rule may optionally carry `lifecycle: experimental`. Enforced by
[`DOCTOR-014`](../rules/DOCTOR-014.md): an experimental rule may be `info` or
`warn` — never `fail` or `fail_release`. Promotion to `enforced` requires a
`DEC-###` and a `ROADMAP.md` entry; this is what keeps the experimental stage
from being theatre, since an unreviewed rule can never exert the authority a
reviewed one has.

## See also

- `pmo-config/learning-policy.json` — the runtime policy this page describes.
- [`docs/architecture/adversarial-review.md`](../architecture/adversarial-review.md) —
  Milestone 8, sequenced ahead of this one so its review-disposition data
  could inform this event schema.
