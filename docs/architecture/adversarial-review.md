# Adversarial Review Evidence — Milestone 8.0 research

> Status: **research complete; recommendation below, decision pending.** This
> document is Milestone 8.0's required output — a threat model, a provenance
> design, and a GO / GO WITH REFRAME / NO-GO recommendation — authorized for
> research only by the Human Owner, 2026-08-03 (`DEC-012`). Implementation
> (Milestone 8.1) is a separate decision this document does not make; per
> `research/m7-m9-proposal.md` and `DEC-012` itself, "no code, schema, or
> policy file for adversarial review may be written under this decision beyond
> the research report itself."

## 1. Objective

Milestone 8 asks whether Axiom-PMO can add independent, evidence-backed review
of AI-executed work as **candidate evidence**, for the defect classes
deterministic rules structurally cannot reach: behaviour changed inside an
approved file, a test that passes while testing the wrong thing, an
implementation that satisfies the letter of an acceptance criterion and not
its intent, a behaviour change hidden inside a refactor.

Milestone 8.0's job is narrower, matching the Milestone 5.0 and 6.0
precedent: decide whether a review artifact's **provenance** — who or what
actually produced it — can be bound tightly enough to be worth building, or
whether the achievable assurance is too weak to justify the machinery.

## 2. The primary question, and why it is not new

> A `check_run_id` proves a CI job ran. It does not prove that an independent
> adversarial review produced this artifact.

This is the Milestone 5 round-2 defect one level up. `pmo-config/
execution-contract-policy.json`'s own `review_history` field records it for
test evidence: a `runner-exit-record` and its `.sha256` sidecar both lived
under `.execution/**`, which the verified actor can write, so an actor could
author both and never invoke the runner. **A review artifact has the
identical shape.** `EXECUTION-REVIEW.json`, if written by the executing agent
into a path it controls, proves nothing about who — or what — actually
reviewed anything.

This is why `execution-contract-policy.json` already keeps
`structurally_checkable` and `provenance` as separate questions, with a
three-tier `evidence_provenance` model:

| Tier | Proves | Satisfies a required check alone |
|---|---|---|
| `agent-claimed` | Nothing — the actor being verified wrote it | No |
| `artifact-observed` | A file exists, its bytes match its declared digest, its contents report success. **Not** that the right process produced it | No — needs a human `test-evidence-accepted` claim |
| `externally-observed` | A third party the verified actor cannot impersonate confirmed it | Yes — the only tier that clears on its own |

**Finding 1: `AREV-*` should reuse this exact three-tier model, not invent a
parallel one.** `externally-observed` is the tier a CI-produced review
belongs to if it can be bound tightly enough (§3). `artifact-observed` is
where a self-written or unbound review artifact belongs, and per the existing
model it never satisfies Strict on its own. One genuinely new tier is needed:
**`human-attested`** — a named person, not an external system, is
accountable. It fits neither existing tier (not a system confirmation, not an
unverifiable artifact) and reuses the standing `handoff-policy.json` already
gives `reviewer_kind: human`.

## 3. What binds `externally-observed` tightly enough to mean something

### 3.1 What Milestone 5.5 already proved, reused directly

`Test-CiCheckEvidence` (`scripts/lib/execution-contract-evidence.ps1`),
hardened in Milestone 5.5, already binds, for a `ci-check` test-evidence
entry with an optional `check_run_id`:

```text
check_run_id -> queried live via `gh api repos/<owner>/<repo>/check-runs/<id>`
  -> run.head_sha    must equal the claimed commit_sha
  -> run.name        must equal the claimed name, case-sensitive
  -> run.status      must be "completed"
  -> run.conclusion  must be "success" (never the result's own claimed conclusion)
```

This closes exactly the gap the round-1 `ci-check` design left open (a
same-named sibling run, in either direction) and is proven in production:
`docs/rules/EXEC-005.md`, commit `ca6ae6a`. **An `AREV-*` `ci-observed`
sub-tier of `externally-observed` should reuse this code unchanged**, not
reimplement it — the same `check_run_id` binding, applied to a check run whose
`name` identifies the adversarial-review workflow instead of a test suite.

### 3.2 What that alone does NOT prove, demonstrated rather than assumed

A CI job satisfying the binding above proves *"a check run named X, at commit
Y, completed successfully."* It does not prove:

- that the job actually invoked a reviewer at all, rather than a script that
  echoes success;
- that the artifact `EXECUTION-REVIEW.json` the executor's result cites is
  the *same* artifact that check run produced, rather than one substituted
  afterward in a path the executor can still write;
- that the workflow definition which ran was the one anyone actually
  reviewed and approved as a real adversarial reviewer, rather than one the
  executor edited within the very commit range under verification.

Each of these is closable with a binding this framework already has the
pieces for. None requires new infrastructure — only wiring pieces that
already exist for a different purpose.

### 3.3 The additional bindings that make `ci-observed` mean something

1. **Artifact identity.** The check run's own machine-readable output (the
   Checks API's `output.summary`/`output.text`, or a custom `external_id`)
   must carry the SHA-256 digest of the exact `EXECUTION-REVIEW.json` bytes
   the job produced. Verification then requires that digest to equal the
   real digest of the file the execution result cites — the same
   "recompute and compare, never trust the claimed digest" discipline
   `Test-JUnitEvidence` already applies to JUnit artifacts. This is what
   stops the M5-round-2 substitution pattern from recurring here: the proof
   of the artifact's origin lives in GitHub's API response, a place the
   executor cannot write, not in a sidecar file the executor can.

2. **Workflow identity and content.** The check run's associated workflow
   run (`gh api repos/<owner>/<repo>/actions/runs/<id>`, reached via the
   check run's `details_url` or check-suite) must resolve to a workflow file
   at a **pinned path** (e.g. `.github/workflows/adversarial-review.yml`).
   That file's content digest **at the commit being verified** — computed
   locally from git, no API call needed, exactly how `REF-002` resolves a
   `FILE:` reference — must equal a digest pinned in
   `pmo-config/adversarial-review-policy.json`. A workflow edited to weaken
   or bypass the review, even within the same commit under verification,
   changes this digest and fails the check.

3. **Scope protection for the pinned path, reusing an existing rule rather
   than adding one.** The pinned workflow path should be a default
   `prohibited_paths` entry `axiom export` writes into every
   `EXECUTION-CONTRACT.json` on the `governed_ai_execution` path. An
   executor that tries to edit the review workflow inside the verified
   commit range is then caught by `EXEC-004` (already implemented, already
   tested) — not a new mechanism, the existing one applied to a new path.
   This is the same idea Milestone 9's proposal made for
   `pmo-config/**`, applied here first because Milestone 8 needs it sooner.

4. **Contract identity.** The review artifact must carry the same
   `contract_sha256`, `base_sha`, and `head_sha` the execution result
   claims — otherwise a review of unrelated work could be cited.

With all four, `externally-observed` for a review artifact means: *"a
workflow, at a pinned path, whose content was not altered within the
verified commit range, running under GitHub Actions' isolation, produced an
artifact whose digest is attested in GitHub's own API response, for this
exact contract and commit."*

### 3.4 The honest ceiling — stated, not glossed over

Even with every binding in §3.3, this does **not** prove:

- that the *originally pinned* workflow is a good-faith adversarial
  reviewer rather than one authored to always pass — pinning a digest
  proves stability, not quality; whether the pinned workflow is trustworthy
  is a human decision made when that workflow is authored and approved, not
  something any per-execution verifier can establish;
- anything about GitHub Actions' own infrastructure integrity — the same
  trust boundary this framework already accepts for `gh api` itself in
  `Test-CiCheckEvidence`;
- that the model or prompt inside the job produced a good-faith review — a
  content-quality question, explicitly out of scope everywhere in this
  design (§5);
- safety against a workflow triggered by an untrusted fork
  (`pull_request_target`-style risk) — a GitHub Actions security concern
  external to Axiom-PMO's boundary, but one the policy documentation must
  warn operators about explicitly, the same way `docs/architecture/
  m6-threat-model.md` documents residual risk rather than pretending it
  away.

If §3.3's bindings are not implemented, `ci-observed` degrades to exactly the
weak claim §3.2 describes, and should not be allowed to satisfy Strict alone.

## 4. Finding-lifecycle authority

Revision 3 of the proposal fixed a real self-contradiction found by
independent review: the executor was said to be able to set `disputed`, and
in the same breath said to be barred from moving a finding out of `open`.
Corrected model, extending the four statuses `handoff-policy.json`'s
`closure_policy` already defines rather than replacing them:

| Status | Settable by | Meaning | Blocking |
|---|---|---|---|
| `open` | reviewer | Raised, unresolved | yes |
| `disputed` | executor | Contested with evidence. **Not a closure** | yes |
| `resolved` | reviewer only, on re-review | The reviewer re-checked and agrees | no |
| `false_positive` | human | The finding was wrong | no |
| `accepted_risk` | human | Understood and accepted | no |
| `deferred` | human | Deliberately later | no |

Authority attaches to **role** (reviewer / executor / human), never to
*kind* (ai / human) — a human executor is still an executor, and an AI
serving as human-attested reviewer's assistant still cannot self-close.
Security, legal, business, and privacy categories stay human-only to close,
mirroring `HANDOFF-010` exactly.

## 5. Evaluator isolation

The evaluator sees: the approved requirement, scope, acceptance criteria,
the execution contract, the diff, test artifacts, and relevant architecture
constraints. It does **not** see: the executor's chain of thought, its
persuasion, a prior reviewer's verdict, or — the one addition this research
makes over the original proposal — the narrative fields of
`EXECUTION-RESULT.json`, since those are written by the actor under review
and are a claim by this framework's own core principle.

Independence is a property of context, prompt, and authority, not of model
vendor. Stated explicitly in policy so it is never later read as "you must
use a different model": a `human-attested` review by someone other than the
executor satisfies Strict identically to a `ci-observed` one (`DEC-012`).

## 6. Deterministic preflight — scope, not a new gate

A review spent on a diff whose base does not resolve produces findings about
the wrong code. The preflight is **`axiom verify --preflight`**, a flag
selecting the subset of `EXEC-*` checks that do not require the review
artifact to exist yet (contract integrity, base/head resolvability, diff
availability, identity binding) — not a new verb, never a new gate. The full
`axiom verify` (all `EXEC-*` and, once Milestone 8.1 exists, `AREV-*`) is
unchanged and remains the only thing that produces a verdict.

## 7. Enforcement levels

Mapping onto the existing `severity_when_missing` pattern
(`handoff-policy.json semantic_review`):

| Mode | Level |
|---|---|
| Lite | Disabled |
| Standard | Advisory (`warn`, non-blocking) |
| Strict | Required Evidence (`fail` if absent; provenance tier below `externally-observed` or `human-attested` also fails, matching `artifact-observed`'s standing existing rule) |

## 8. Threat model

```text
Untrusted:
  The executing agent's own narrative, an agent-authored EXECUTION-REVIEW.json
  in a path the agent can write, an unbound review-workflow name search.

Observed but requires the §3.3 bindings to trust for a required check:
  A GitHub check run's conclusion and API-attested output digest, a workflow
  file's content digest at the commit under verification.

Trusted only under explicit policy:
  The pinned workflow path and digest in adversarial-review-policy.json, a
  human reviewer's decision-log-anchored attestation.

Out of scope, stated rather than silently assumed away:
  GitHub Actions platform integrity, the pinned workflow's original
  trustworthiness, review content quality, fork-triggered workflow risk.
```

## 9. Recommendation

**GO WITH REFRAME** — the same shape Milestone 5.0 reached, arrived at
independently. Plain GO is not honest: `ci-observed` provenance is only as
strong as §3.3's bindings, none of which exist yet, and the content-quality
question is unverifiable by design, permanently. NO-GO is not warranted
either: §3.3 shows a concrete, implementable binding set built almost
entirely from mechanisms this framework already has in production
(`Test-CiCheckEvidence`, `REF-002`-style digesting, `EXEC-004` scope
protection) — the reframe is *narrowing the claim to what is actually
provable*, not abandoning the capability.

Recommended for Milestone 8.1, pending the Human Owner's decision this
document does not make:

1. Reuse `evidence_provenance`'s three tiers (`artifact-observed`,
   `externally-observed`, plus new `human-attested`) rather than a parallel
   model.
2. Build `externally-observed` only with all four §3.3 bindings implemented
   together — a partial version that omits the workflow-digest or
   artifact-digest binding is `artifact-observed` wearing a stronger name,
   and should not be shipped as if it were the real thing.
3. Confirm `human-attested` satisfies Strict identically (`DEC-012` already
   settled this).
4. Ship the finding-lifecycle table in §4 and the evaluator-isolation rule
   in §5 as written — both were review findings against earlier drafts, not
   design choices with an live alternative.
5. State the §3.4 ceiling in the shipped policy file itself, not only in
   this research document.

## 10. What this document does not authorize

No `AREV-*` rule, `EXECUTION-REVIEW.json` schema, or
`pmo-config/adversarial-review-policy.json` file exists yet. This document is
the research and recommendation `DEC-012` asked for; Milestone 8.1
implementation requires a further, separate Human Owner decision.

> **Update, post-implementation:** the Human Owner authorized implementation
> on this recommendation (`DEC-014`). `AREV-001`..`AREV-006`,
> `pmo-config/adversarial-review-policy.json`, and
> `templates/EXECUTION-REVIEW.json` now exist. §11 below records the
> limitations Independent AI Reviewer's independent review confirmed as acceptable to close
> against, rather than requiring further implementation.

## 11. Known limitations (recorded, not blocking closure)

Independent AI Reviewer's independent review of the implementation (two rounds; round 1: 1
FATAL, 2 MAJOR, all fixed and regression-tested; round 2: one compatibility
fix) drew an explicit line between what a defect against the four §3.3
bindings would be — genuinely blocking — and what is a scoped, acceptable
limitation of this milestone's artifact model. The following are recorded
per that boundary, not implemented, because implementing them was
explicitly out of round 2's scope:

- **Non-closure transitions are not fully actor-attributed.** The artifact
  model can prove who authored `EXECUTION-REVIEW.json` as a whole
  (`reviewer_kind`) and can prove the executor never set a closure status
  (`AREV-005`, via `EXECUTION-RESULT.json`'s `review_finding_dispositions`).
  It cannot prove, at the level of an individual finding, which specific
  actor set a *non-closure* status such as `disputed` inside a
  reviewer-authored review file — policy conceptually assigns that
  transition to the executor, but the file format has no per-transition
  actor record. This does not weaken any authority guarantee already
  enforced: `disputed` remains blocking, is never treated as a pass, the
  executor still cannot reach any closure or acceptance state, human-only
  statuses remain human-only (`AREV-005`), and a non-human reviewer still
  cannot resolve a human-only-category finding. A transition ledger or a
  separate actor-history artifact would close this gap; out of scope for
  M8.1, and not required to close it.
- **`workflow_id` binding is optional future hardening, not required.** The
  round-1 fix binds a check run to its workflow run's `path`, normalized
  against a trailing `@ref` (round 2). A workflow's stable numeric
  `workflow_id` would bind slightly more precisely against a workflow that
  was renamed or moved, but path-based binding is sufficient to close the
  FATAL gap round 1 found and is not required to be strengthened further to
  close this milestone.
- **No enterprise identity proof, reusable-workflow model, additional CI
  provider abstraction, or broader CI provenance hardening** is implemented.
  Each would be real work with its own design and review; none is required
  by anything this milestone's threat model demonstrated.

These are recorded here so they stay visible rather than silently
forgotten, in the same spirit `ROADMAP.md`'s Deferred technical debt table
already keeps Milestone 6's open items visible. None is a precondition for
Independent AI Reviewer's final review or Human Owner closure.
