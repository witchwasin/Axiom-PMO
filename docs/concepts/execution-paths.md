# Execution Paths

Axiom-PMO answers two independent questions about a piece of work, not one:

```text
Axis 1 -- who builds it?               Development Handoff | Governed AI Execution
Axis 2 -- how strictly is it governed?  Lite | Standard | Strict
```

They are kept independent because they are not the same decision. A vendor
handoff can be Strict. A governed AI execution can be Lite. A team's own
developers might work Standard. Collapsing the two into one choice would
produce the wrong mental model from the first minute of using the framework.

## The two paths

Both already exist as working engines; this milestone names them, makes the
choice explicit, and stops asking a new user to infer either from scratch.

| Path | What it is | The mechanism |
|---|---|---|
| **Development Handoff** (`development_handoff`) | Prepare requirements, scope, design, and a work package a human developer or vendor can pick up and build | The Handoff gate: `HANDOFF-001`..`HANDOFF-014`, `scripts/assess-handoff.ps1` |
| **Governed AI Execution** (`governed_ai_execution`) | Hand an approved work item to an AI execution agent under a contract, then verify what it actually did against git ground truth | `axiom export` -> agent implements -> `axiom run` -> `axiom verify`; `EXEC-001`..`EXEC-008` |

Neither path is required to use Axiom-PMO's core governance -- source,
requirements, scope, evidence, and approval gates apply the same way regardless
of which path builds the work.

## Declaring it

`PROJECT.md` carries `Execution path: development_handoff | governed_ai_execution`,
next to `Default mode:` and `Task source:` -- the same place other
project-level declarations that change validation already live. Missing is not
an error: it defaults to `development_handoff`, the core product's own
default, so every project created before this field existed keeps validating
exactly as it did. See [`PATH-001`](../rules/PATH-001.md).

`axiom init` asks for it directly, as an interactive question when running on
a TTY: *"Who will build this?"*

## Current strategy, not project identity

The declared path is what the project is doing **now**, not a permanent
label. Real projects switch: a vendor withdraws and the work moves to a
governed AI execution; an AI-built item is handed outward for a developer to
finish; a verified handoff is picked up by an execution framework partway
through. Changing the declaration is an ordinary edit to `PROJECT.md` -- no
special command, no migration.

Two invariants hold regardless of how many times a project switches:

- **A path may add required artifacts. It must never remove any.** Whatever
  the Mode x Gate matrix in `pmo-config/artifact-policy.json` already requires
  stays required no matter which path is declared -- a path cannot become an
  escape hatch from governance.
- **[`PATH-002`](../rules/PATH-002.md) only warns about an *active, unresolved*
  execution package.** Archived or completed execution evidence never
  triggers it, so switching back to Development Handoff after a finished AI
  execution does not warn forever.

## What this is not

- Not a new approval, gate, or authority. Neither path bypasses Scope
  Approved, Design Ready, or Release Approved.
- Not risk detection. The framework never claims to have found anything about
  a project's data or risk profile -- see the strict-trigger questionnaire in
  `axiom init`'s "Help me decide" path, which records a **human declaration**,
  never a detected fact.
- Not a restructuring of `pmo-config/artifact-policy.json`. The path-artifact
  delta is empty as of Milestone 7; it gains its first real entry when a later
  milestone defines a path-specific required artifact (for example,
  `EXECUTION-REVIEW.json` on the Governed AI Execution path in Strict mode).

## Declaring a strict trigger during onboarding

`axiom init`'s "Help me decide" path asks one question per entry in
`pmo-config/policy.json`'s `enums.strict_triggers`, with wording from
`pmo-config/onboarding-questions.json` (kept in sync by
[`DOCTOR-013`](../rules/DOCTOR-013.md)). The answer is a **declaration**, not a
detection -- at `init` time there is no source material to detect anything
from. It is written into the generated work item's existing `Strict Trigger`,
`Mode Reason`, and `Mode Approved By` columns
(`pmo-config/policy.json table_schemas.delivery_work_items`, shipped in
`templates/DELIVERY.md`) -- not a new artifact, and nothing under `source/`,
which stays user-owned (`AGENTS.md` rule 9). `Mode Approved By` is **attested**
(confirmed by the person named), the same standing `handoff-policy.json`
already gives `reviewer_kind`: no offline validator can prove who typed a
name, and claiming otherwise would be false assurance.

Once written, the existing mode resolver
(`scripts/lib/mode-resolver.ps1`) does the rest: a declared strict trigger
escalates the project's effective mode to Strict (`MODE-003`) exactly as it
would if the trigger had been added by hand later.

## See also

- [`docs/concepts/risk-modes.md`](risk-modes.md) -- the Lite/Standard/Strict
  axis this one stays independent of.
- [`docs/concepts/handoff-readiness.md`](handoff-readiness.md) -- the
  Development Handoff path's own gate.
- `research/m7-m9-proposal.md` -- full design history and rejected
  alternatives for this milestone.
