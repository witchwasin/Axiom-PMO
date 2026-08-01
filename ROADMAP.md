# Axiom-PMO Productization Roadmap

Status: roadmap of record
Current product version: 1.1.1
Last updated: 2026-07-29

Axiom-PMO is moving from an open-source governance framework into a developer
workflow tool for AI-assisted software delivery.

The goal is not to add more process. The goal is to make the value obvious,
fast, and actionable:

```text
AI can build.
Axiom-PMO verifies the source, scope, evidence, tests, and authority behind the
work.
```

## Product Positioning

Axiom-PMO should be presented as:

> The governance control plane for AI-assisted software delivery.
>
> **Axiom-PMO prepares and verifies development handoffs. It does not replace
> developers or execution frameworks.**

Axiom-PMO owns policy, evidence, traceability, approval gates, release
readiness, and agent authority. Execution frameworks such as Superpowers, BMAD,
GitHub spec-kit, OpenSpec, and Claude Code own planning, coding, testing, and
implementation mechanics.

Axiom-PMO should not compete with execution frameworks. It should define the
control layer they operate inside.

### Core product versus optional integration

Set by the Human Owner (Witchwasin K., 2026-07-31), recorded as `DEC-006`, and
binding on how this repository is documented and presented.

> **Milestones 1-5 are the core Axiom-PMO product: a governance and
> development-handoff framework. Milestone 6 is an optional bridge for users
> who later choose to continue implementation with Claude Code.**

| | Core product - Milestones 1 to 5 | Optional integration - Milestone 6 |
|---|---|---|
| What it is | Governance, handoff readiness, scope and evidence verification, a developer-ready delivery package | A bridge from a verified handoff to Claude Code |
| Who it serves | PM, Product Owner, or an AI acting as one, preparing work a developer can pick up | Teams who decide to continue implementation with an AI execution tool |
| Required to use Axiom-PMO | Yes | **No** |
| What it does *not* do | Write the system | Turn Axiom-PMO into a coding framework |

What the core exists to do:

- prepare a development handoff that is complete;
- let a PM, Product Owner, or AI hand a work package to a developer who can
  pick it up and build;
- check requirements, scope, design readiness, traceability, tests, evidence
  and authority;
- check that what an AI *reports* it did matches the evidence and the actual
  repository state.

Milestone 6 exists so that a verified handoff can be continued in Claude Code
without re-interpreting the documents or rebuilding an integration from
scratch. It is an execution integration, not a change of product.

This repository is **not** primarily a place for developers to come and write
the system. Documentation must not read that way.

## North Star User Journey

The product loop we are optimizing for is:

```text
Discover
-> Install
-> See a meaningful failure
-> Fix the issue
-> Integrate with workflow
-> Govern delivery
```

A new user should be able to see why Axiom-PMO matters before reading the full
framework documentation.

## Near-Term Strategy

The core validator is already strong enough to productize around. Near-term
work should focus on runtime portability, developer diagnostics, workflow
integration, and a single real execution-framework bridge.

Recommended effort allocation:

| Area | Allocation |
|---|---:|
| Core maintenance | 25% |
| Runtime and developer experience | 35% |
| Workflow integrations | 40% |

## Milestone Status

| Milestone | Status | Release / dependency |
|---|---|---|
| Milestone 1 - Public Trust + Three-Minute Proof | Delivered with deferred evidence | Walkthrough and recording are optional trust evidence, not a Milestone 4 blocker |
| Milestone 2 - Developer Diagnostics | Delivered | Delivered in 1.1 |
| Milestone 2.5 - Engineering Handoff Readiness | Delivered | Delivered in 1.1.0; strengthened in 1.1.1 |
| Milestone 3 - Thin Local CLI | Delivered (Phase A) | Local CLI delivered; public npm package deferred |
| Milestone 3.5 - Runtime Portability | Accepted | CI threshold met; branch protection deferred by human decision |
| Milestone 4 - GitHub Action | Delivered | Merged to `main` at `31d1e25`; child issues #12-#17 closed |
| Milestone 4.5 - SCOPE-DIFF | Delivered | Human Owner accepted 2026-07-30 after two independent AI review rounds; merged to `main` at `6b42643` |
| Milestone 5 - Execution Contract Verification MVP | **Delivered / CLOSED** -- Sol ACCEPT at round 5 after four REQUEST CHANGES rounds; Human Owner accepted and closed 2026-07-31 (`DEC-004`) | Core product. `docs/reference/execution-contract.md`; decisions `DEC-002`, `DEC-004`; commit `2888769`, CI run `30643605031` 7/7 |
| Milestone 6 - Claude Code Integration Experience | **Human Owner accepted (`DEC-005`); independent review returned REQUEST CHANGES (1 FATAL, 1 MAJOR) -- both fixed, re-review pending. Closure blocked.** Not released, not tagged, not published, not merged | Optional integration, not core product. Three known debts remain open -- see Deferred technical debt. `docs/guides/claude-code-integration.md`; `docs/architecture/m6-threat-model.md`; decisions `DEC-003` (shape), `DEC-006` (product boundary), `DEC-005` (acceptance) |

## Roadmap Governance

This roadmap should stay focused and executable. A milestone may enter active
development only after the preceding milestone:

- passes all CI gates;
- has no open P0 defects;
- has verified documentation;
- has at least one clean-room user walkthrough where relevant;
- has an approved release or acceptance record.

Each milestone should be broken into issues with this planning shape:

```text
Owner:
Dependencies:
Primary artifacts:
Test artifacts:
Risks:
Non-goals:
Release decision:
```

This keeps roadmap execution from expanding into unrelated product work.

Active dependency chain:

```text
Milestone 1 delivered, with walkthrough/recording evidence deferred
-> Milestone 2 (delivered)
-> Milestone 2.5 (delivered)
-> Milestone 3 (delivered)
-> Milestone 3.5 (accepted)
-> Milestone 4 (delivered)
-> Milestone 4.5 (delivered)
-> Milestone 5 (delivered -- closed 2026-07-31)     <- end of core product
-> Milestone 6 (optional integration; implemented, under review)
```

Milestone 2.5 sits between diagnostics and the CLI deliberately. The CLI's
`handoff` verb and the GitHub Action's per-stage reporting both depend on the
structured diagnostics from Milestone 2 and the stage verdicts from Milestone
2.5; shipping either earlier would have meant a second, incompatible output
shape.

Planning issues may be opened for a blocked milestone, but implementation must
not begin until its preceding acceptance condition is satisfied.

## Milestone 1 - Public Trust + Three-Minute Proof

Objective: make the repository trustworthy and make the value visible within
three minutes.

Status: **delivered with deferred evidence.** The validator, demo, hygiene
tooling, quick start, and CI exist. On 2026-07-29, the human decision changed
the independent clean-room walkthrough and committed terminal recording/GIF
from required Milestone 4 blockers into optional trust evidence. Issue #8
remains the place to track that optional evidence if it is picked up later. Use
the [M1 walkthrough and recording evidence guide](docs/guides/m1-walkthrough-and-recording.md)
to capture evidence without fabricating it.

Deliverables:

- Public hygiene scan for stale internal references, local paths, private URLs,
  secret-like patterns, internal branch names, and broken documentation links.
- Sanitized historical archive with clear historical banners.
- Branding cleanup so public-facing workflow names and docs consistently use
  Axiom-PMO.
- `demo/broken-project/` and `demo/fixed-project/`.
- One-command demo through `scripts/demo.ps1` and `make demo`.
- README quick start near the top of the document.
- Optional GIF or terminal recording showing a failing gate becoming a passing
  gate.
- Optional clean-room usability test with a developer unfamiliar with Axiom-PMO.
- CI green.

Demo failures should only use behavior that exists today. Good first demo cases:

- requirement without a source reference;
- work item or release claim without resolvable evidence;
- test summary without linked test evidence;
- release without valid human approval;
- Strict-mode project without required review evidence.

Do not demo changed-file scope enforcement until diff-to-scope or allowed-path
validation exists. That belongs in the bridge or GitHub Action work.

Definition of done:

```text
A new user can clone the repo, run no more than three commands, and see both a
meaningful failure and a passing case within three minutes.
```

Clean-room metrics to capture:

- time to first command;
- time to first meaningful failure;
- where the user gets stuck;
- how many times the user opens documentation;
- whether the user can explain the value after the demo.

## Milestone 2 - Developer Diagnostics

Objective: make validator output feel like a developer tool, not only a PMO
report.

Status: **delivered in 1.1.**

Deliverables:

- Stable JSON result contract.
- Structured diagnostic fields for every actionable result:
  - `rule_id`
  - `level`
  - `artifact`
  - `item_id`
  - `field`
  - `message`
  - `suggestion`
  - `documentation_url`
- Contract tests for the JSON schema.
- Rule documentation under `docs/rules/` for critical failures.
- Human-readable output that is short, direct, and fix-oriented.
- Compatibility policy for the JSON result contract:
  - explicit `schema_version`;
  - backward compatibility rules;
  - deprecation policy;
  - unknown-field behavior;
  - exit-code mapping;
  - sensitive-data policy.

Example diagnostic:

```text
FAIL RTM-003
Artifact: RTM.json
Item: REQ-004
Field: test_ref

Requirement has no linked test evidence.
Fix: Add TEST-### evidence or declare a valid waiver.
```

Definition of done:

```text
Every failure tells a developer what failed, where it failed, why it matters,
and what to do next.
```

## Milestone 2.5 - Engineering Handoff Readiness

Objective: let the framework answer, with evidence, whether a documentation set
is sufficient for a developer to start building, integrate, and demonstrate.

Status: **delivered in 1.1.0.**

### Why this milestone exists

Milestones 1 and 2 make the validator trustworthy and its output actionable.
Neither addresses the question a delivery lead actually asks before a handoff:

```text
Is this enough for someone to start on Monday, and will it demo on time?
```

A project can satisfy every governance check in 1.0 and still hand a developer
a plan that cannot be executed: a shared prerequisite scheduled after the items
that consume it, a device capability whose serving model nobody decided, a
privacy commitment in one document contradicted by a feature in another, an
acceptance case unreachable from the seed data, a work item owned by a team
name. Each is invisible to a rule that checks whether a field is filled in, and
each costs days.

### The two-layer split

The failures above must not be encoded as validator rules. "Stock features need
a receive operation", "photos are PII", "QR scanning requires HTTPS" are true in
some domains and wrong in others, and a validator that guesses wrong teaches
people to ignore it.

| Layer | Owns | Mechanism |
|---|---|---|
| Deterministic validation | What is provable from the artifacts | `-Gate Handoff`, rules `HANDOFF-001` to `HANDOFF-014` |
| Semantic handoff review | Whether the complete contract makes sense | `pmo-delivery` intent `handoff_review`, recorded in `HANDOFF-REVIEW.json` |

The deterministic layer reads declarations the author wrote and checks that they
are complete, resolvable, and owned. It never infers domain meaning. The
semantic layer supplies judgement, and the deterministic layer's only interest
in it is mechanical: did a review happen, did it cover every lens, does every
finding have an owner and a blocking point, and is it still current.

**A semantic review is candidate evidence, not an approval.**

### Scope

- `Handoff` gate between `Design` and `Release`, reusing the existing
  `Design Ready` approval and introducing no new human sign-off.
- Canonical artifacts: `HANDOFF.md`, `DESIGN/BUILD-SPEC.md`,
  `HANDOFF-REVIEW.json`.
- Rules `HANDOFF-001` to `HANDOFF-014`, each with a `docs/rules/` page.
- Twelve semantic review lenses, config-driven in
  `pmo-config/handoff-policy.json`.
- Review freshness via a Source Snapshot digest: a review speaks only for the
  sources it read.
- Stage verdicts instead of one boolean: Contract Valid, Ready to Start
  Development, Ready to Integrate, Ready to Demo, Ready for UAT, Ready for
  Release.
- A capped readiness score that can never masquerade as an approval.

### Non-goals

- No new approval gate.
- No domain rules in the core validator.
- No change to how `Draft`, `Scope`, `Design`, or `Release` behave.
- No coding plan, implementation, or test execution. Those belong to an
  execution framework; see `docs/architecture/control-plane.md`.

Definition of done:

```text
The framework can say "ready to build, not ready to demo" and show which
declared evidence supports each half of that sentence.
```

## Milestone 3 - Thin Local CLI

Objective: make Axiom-PMO usable without requiring users to understand the
PowerShell implementation.

Status: **Phase A delivered in 1.1.** Public npm packaging (Phase B) is
deferred and is not required for the local CLI milestone to remain delivered.

Start local before publishing to npm.

Phase A:

```bash
node cli/axiom.mjs demo
node cli/axiom.mjs check
node cli/axiom.mjs doctor
node cli/axiom.mjs init
```

Phase B:

```bash
npx @axiom-pmo/cli demo
npx @axiom-pmo/cli check
```

CLI responsibilities:

- detect PowerShell Core availability;
- call the existing PowerShell validator;
- forward arguments;
- preserve exit codes;
- surface dependency problems with clear remediation;
- avoid duplicating validation logic outside the core validator.

Do not rewrite the core validator in TypeScript during this milestone.

Definition of done:

```text
The local CLI works on Windows and through pwsh on macOS/Linux, preserves exit
codes, and is covered by CI before any public npm release.
```

## Milestone 3.5 - Runtime Portability

Objective: make PowerShell 7 the primary portable runtime without dropping
Windows PowerShell 5.1 compatibility or creating a second validator
implementation.

Status: **accepted on 2026-07-29.**

The runtime already resolves `AXIOM_PWSH`, the current host, `pwsh`,
`powershell`, and `powershell.exe`. This milestone promotes that runtime
flexibility into an explicit support and CI contract.

Current evidence and gaps:

- **Confirmed:** CI run
  [#30432327317](https://github.com/witchwasin/Axiom-PMO/actions/runs/30432327317)
  passed on Windows PowerShell 5.1, Windows PowerShell 7, Ubuntu PowerShell 7,
  and macOS PowerShell 7 at commit `eb50c29`.
- **Confirmed:** Windows PowerShell 7 is a blocking workflow job, but `main`
  branch protection has not yet made it a required status check.
- **Confirmed:** Ubuntu PowerShell 7 passed the full suite in the first matrix
  run. The workflow is being promoted from `continue-on-error` to a blocking
  job named `pmo-checks-linux-pwsh7`.
- **Confirmed:** CI run
  [#30434956117](https://github.com/witchwasin/Axiom-PMO/actions/runs/30434956117)
  passed on `main` at commit `24d8b99` after the Ubuntu job was promoted. This
  is Ubuntu promoted green run 1 of 2 for the M3.5 threshold.
- **Confirmed:** CI run
  [#30436344213](https://github.com/witchwasin/Axiom-PMO/actions/runs/30436344213)
  passed on `main` at commit `016f1d9` after the Ubuntu promotion. This is
  Ubuntu promoted green run 2 of 2; the CI threshold is met.
- **Confirmed:** Human-approved threshold: Ubuntu PowerShell 7 must pass two
  consecutive full CI runs on `main` after `continue-on-error` is removed before
  M3.5 can be accepted.
- **Confirmed:** Human acceptance recorded on 2026-07-29 in Codex chat. The
  human decision accepts M3.5 with branch protection deferred and not required
  for this milestone acceptance.

Target support matrix:

| Environment | Target policy |
|---|---|
| Windows + PowerShell 7 | Required |
| Ubuntu + PowerShell 7 | Required |
| Windows PowerShell 5.1 | Required compatibility regression |
| macOS + PowerShell 7 | Non-blocking smoke until promotion evidence exists |

Deliverables:

- Required full-suite jobs for Windows PowerShell 7 and Ubuntu PowerShell 7.
- Continued Windows PowerShell 5.1 regression coverage.
- A macOS PowerShell 7 smoke/full-suite job, initially non-blocking.
- Identical diagnostic fields, ordering, summary counts, exit codes, digests,
  golden results, and line-ending behavior across required hosts.
- Consistent host selection between the Node CLI and PowerShell child-process
  helper, including `AXIOM_PWSH` and missing-host exit code `127`.
- Documentation and issue templates that describe the actual support matrix.

Non-goals:

- Rewriting the validator in TypeScript or another language.
- Dropping Windows PowerShell 5.1 before compatibility evidence supports it.
- Promoting macOS to required based on a single successful run.

Definition of done:

```text
Windows PowerShell 7 and Ubuntu PowerShell 7 are required green jobs, Windows
PowerShell 5.1 remains green as a compatibility regression, cross-host output
contracts match, and the support documentation reflects the evidence.
```

## Milestone 4 - GitHub Action

Objective: make Axiom-PMO visible directly in pull requests.

Status: **delivered.** Parent tracking issue #12 and child issues #13
([M4-1] reusable Action), #14 ([M4-2] Job Summary and reports), #15
([M4-3] safe PR annotations), #16 ([M4-4] consumer/failure-path/privacy
tests), and #17 ([M4-5] documentation and acceptance) are all closed.
Merged to `main` in commit `31d1e254216aaf1112a92c01fd3b42f12d3a2468`.

Dependency:

```text
Structured diagnostics
-> JSON report contract
-> CLI
-> GitHub Action
```

Deliverables:

- GitHub Action usable in no more than ten workflow lines.
- PR check failure when release or validation gates fail.
- GitHub Job Summary.
- `axiom-report.json` and `axiom-report.md` artifacts.
- PR annotations mapped to file, item, field, and rule id.
- Logs that avoid leaking source-sensitive content.

Example PR summary:

```text
Axiom-PMO Governance Report

PASS 4 requirements trace to sources
PASS 3 work items are complete
FAIL REQ-004 has no test evidence
FAIL Release approval is missing

Release gate: BLOCKED
```

Definition of done:

```text
A repository can add Axiom-PMO to CI quickly and see actionable governance
failures inside a pull request.
```

## Milestone 4.5 - SCOPE-DIFF

Objective: let the GitHub Action answer, deterministically, whether a pull
request's changed files stayed inside a project's pre-approved
implementation scope -- the "changed-file scope enforcement" explicitly
deferred out of Milestone 1's demo and out of Milestone 4's own deliverable
list into "the bridge or GitHub Action work."

Status: **delivered.** Human Owner acceptance recorded 2026-07-30, after
two independent AI review rounds (Sol). The first round found two MAJOR
issues -- case-insensitive path matching (a real scope bypass on a
case-sensitive checkout) and rename detection that depended on ambient git
configuration instead of being pinned explicitly -- both fixed and
re-reviewed as ACCEPT before acceptance. Merged to `main` in commit
`6b42643`; final reviewed branch commit was
`7d2358b89882871b1300d2c711315f2217a8ddbb`.

Deliverables:

- `SCOPE.json`: one approved `implementation_scope` (`include`/`exclude`)
  per project, a small deterministic glob grammar, no LLM interpretation.
- `pmo-config/scope-diff-policy.json`: a reviewable, explicit, narrow
  repo-wide exemption list (lockfiles, `CHANGELOG.md`), validated against
  empty/duplicate/overly-broad entries.
- Deterministic `git diff --name-status` comparison, opt-in
  (`-ScopeDiffBase`/`-ScopeDiffHead`, or `enable-scope-diff: true` on the
  Action), with explicit rename-detection configuration so the same change
  is never reported differently across machines or CI images.
- A missing `SCOPE.json` always fails closed (`SCOPE-DIFF-002`) -- never
  treated as "everything is approved."
- `scope_diff` envelope field (JSON report), Job Summary section, and
  safe PR annotations, following the same infra-failure-vs-governance-verdict
  and privacy rules as Milestone 4.
- `dogfood-scope-diff` CI job exercising the real Action (`uses: ./`)
  against real fixtures: in-scope, out-of-scope, report-only, and enforced.

See `docs/reference/scope-declaration.md` for the full contract.

Definition of done:

```text
A pull request that touches a file outside its project's approved
implementation scope is reported, deterministically and without leaking
source content, and can optionally block the workflow.
```

## Milestone 5 - Execution Contract Verification MVP

Objective: verify that an AI agent's execution output stayed inside an
approved contract, using observable ground truth wherever possible instead
of trusting the agent's own report of what it did.

Renamed from "Superpowers Runtime Bridge" (see decision record below). The
capability is a contract-verification engine, not a technical integration
with one execution framework. Superpowers remains the reference execution
workflow used to design and test it, referenced as a
**Superpowers-compatible execution workflow**, never as a native runtime
integration -- inspection of the real `superpowers` plugin found skills and
a `SessionStart` hook only, no contract-ingestion or result-emission surface
Axiom-PMO could treat as a trusted boundary.

Status: **unblocked; open for planning.** Milestone 4 and Milestone 4.5
both received Human Owner acceptance on 2026-07-30. Per Roadmap Governance,
"unblocked" means planning issues may now be opened -- it is not itself an
approval to start implementation. Runtime export/import work still needs
its own scoped plan and, per the Non-Negotiable Rules, still needs the
AI to stop at every human-approval, push, or milestone-acceptance boundary
the same as every earlier milestone did.

Reference framing:

```text
Axiom-PMO   = governance: contract, scope, evidence policy, human authority
Execution   = planning, coding, testing (Superpowers today; any workflow that
              can consume the same contract shape tomorrow)
```

### Core principle: execution output is a claim, not evidence

An agent-authored `EXECUTION-RESULT.json` is written by the same actor being
verified. It cannot be trusted as evidence by default. Every field carries an
explicit provenance:

```text
Agent claim -> Axiom-observed evidence -> Human authority
```

| Data | Status |
|---|---|
| Agent states a test ran | Claim |
| A test tool produced a real artifact (JUnit XML, checked CI run) | Observed evidence |
| A CI check tied to the exact commit SHA passed | Stronger observed evidence |
| A human states the work is accepted | Human authority |

`evidence_origin` (`agent-claimed` vs. `git-observed` or equivalent) and
`verification_status` (`unverified` vs. `verified`) are attached per field,
not assumed at the envelope level. Unverified claims may be recorded; they
must never satisfy a required check on their own.

### Threat model (required output of Milestone 5.0)

```text
Untrusted:
  Agent-generated execution result, agent-authored summaries, agent-declared
  test outcomes, agent-declared approval state.

Observed but context-limited:
  Local Git repository, available remote refs, CI artifacts, workflow check
  conclusions.

Trusted only under explicit policy:
  Framework configuration, the approved execution contract, human authority
  records.
```

### Contract immutability

A contract and result that can both be edited by the same actor prove
nothing. The result must reference the contract it claims to satisfy by
content digest, not by filename:

```json
{ "contract_sha256": "...", "base_sha": "...", "head_sha": "..." }
```

Axiom-PMO validates the result against the contract version that was
actually approved, never a version the agent could have modified afterward.
Validation compares exact SHAs (contract base SHA, result head SHA), never a
moving branch name -- the same time-of-check/time-of-use discipline
Milestone 4.5 already applies to pull-request base/head resolution.

### Deliverables

- `axiom export D-001 --format superpowers` (name kept for continuity;
  format is not Superpowers-specific).
- `.execution/D-001/EXECUTION-CONTRACT.json`, carrying its own content digest.
- `.execution/D-001/EXECUTION-RESULT.json`, referencing that digest and the
  base/head SHAs it claims to satisfy.
- `axiom import .execution/D-001/EXECUTION-RESULT.json`.
- Schema validation; work item and requirement matching; allowed-path
  validation (reusing Milestone 4.5's glob engine, precedence rules, and
  git-diff adapter rather than a new scope engine); required-test validation
  against a small set of machine-verifiable evidence adapters (JUnit
  artifact with a checksum, a CI check tied to the exact commit SHA, or an
  exit record Axiom's own runner produced -- not free-text agent claims
  alone); scope deviation checks; contract-to-result git authority
  validation; agent self-approval blocking via typed authority-claim
  records, not a single boolean; integration tests, including a clean case
  and a deviation/malicious case.

Git authority validation means checking the execution contract against the
returned execution result: whether the result reports commits or pushes,
whether the contract allowed that action, whether reported commit references
resolve to real, well-formed commits, and whether the result attempts to
claim an approval the agent cannot grant. Approval claims are validated as
typed authority events (`actor`, `claim type`) so a validator can reject any
claim whose actor type lacks the authority to grant it, rather than trusting
an `approval_claimed: false` field the same actor could set.

The MVP does not claim to prove the absence of every possible git side
effect outside the execution session (for example, a push to a remote the
current checkout does not know about, or a force-moved remote ref cannot be
disproven from local state alone). It verifies observable Git claims within
the available repository and remote context; it does not prove a negative
about state entirely outside that context. Broader remote-state verification
can be added later when the bridge has enough runtime context to prove it
safely.

### Milestone 5.0 - Research and go/no-go gate

Status: **decided, 2026-07-30 -- GO WITH REFRAME.** Full research, threat
model, target schema design, and reasoning are in
[`docs/architecture/execution-contract-verification.md`](docs/architecture/execution-contract-verification.md);
the decision itself is recorded as `DEC-002` in `decision-log.md`.

Verified directly against a real local clone of the reference execution
workflow (`superpowers`, commit `44c9b2d6`, plugin version `6.2.0`) rather
than assumed: it registers only a `SessionStart` hook that injects a static
skill file as context, and its own porting guide states "the bootstrap is
the entire integration" as intentional design. No contract-ingestion or
result-emission surface exists to bridge to. Milestone 5 therefore proceeds
as a **git-ground-truth execution-contract verifier** -- Axiom-PMO validates
an `EXECUTION-RESULT.json` an agent writes into the repo against an
approved contract and against what git actually shows happened, rather than
a native runtime handshake. No change to Superpowers itself is required or
proposed.

Milestone 5.0 must inspect: the experimental schemas already in
`integrations/superpowers/`; the current work item and requirement
structures; `SCOPE.json` and Milestone 4.5's diagnostic contract; the real
execution workflow's actual hook/event surface (not an assumed one); and
what data that workflow can actually receive and return. Output is a schema
and threat model, not production code. Do not build a large normalized
intermediate representation to make this milestone's design feel more
general -- one schema, one reference integration, described precisely
enough that a second integration could reuse it later without a rewrite.

### Milestone 5.1 - 5.4

Status: **CLOSED.** Implemented; reviewed by Sol across five rounds (verdict
ACCEPT at round 5, 2026-07-31); CI green 7/7 including Windows PowerShell 5.1;
**accepted and closed by the Human Owner (Witchwasin K.) on 2026-07-31**,
recorded as `DEC-004`. Certified at commit
`288876994f856310ab4f694ec0768703ed48beef`, CI run `30643605031`.

Both records are required and neither substitutes for the other: Sol's ACCEPT
is independent review evidence, and the Human Owner confirmation is the
approval (`AGENTS.md` rule 11).

Milestone 5 is part of the **core product**. Milestones 1-5 together are the
core Axiom-PMO governance and development-handoff framework; see
[Core product versus optional integration](#core-product-versus-optional-integration).

It took five rounds and four REQUEST CHANGES to get here. The findings below
are kept in full rather than summarized away, because the sequence is the
useful part.

**Round 2 (2026-07-30) found the round-1 FATAL fix incomplete**, and the
finding is worth stating plainly because it is the most important thing this
milestone learned. The new `runner-exit-record` check did real work --
containment, digest recomputation against a `.sha256` sidecar, contract and
work-item binding, exit code -- but the record and its sidecar both live
under `.execution/**`, which the verified actor can write and which is
exempt from scope analysis. A reviewer demonstrated a **fully hand-forged
record with a genuinely matching sidecar passing verification, with `axiom
run` never invoked.** The FATAL had been moved from `EXECUTION-RESULT.json`
into the run record, not closed.

The correction is not a stronger check on the file. **No check on a file the
verified actor can write establishes who wrote it** -- a digest proves
integrity from the moment it was taken, never provenance, and `sealed_by:
"axiom-runner"` is a string a forger types. Evidence now carries an explicit
provenance tier: `externally-observed` (`ci-check`) satisfies a required test
alone; `artifact-observed` (`junit-artifact`, `runner-exit-record`) does not,
and is promoted only by a human accepting it on the record via a
`test-evidence-accepted` claim citing a resolving `DEC-###`;
`agent-claimed` never does.

Sol's review (against the real `main` checkout, not just green CI) found
1 FATAL and 2 MAJOR gaps between what the design/docs claimed and what the
implementation actually checked. Each is fixed, with tests reproducing the
original gap and confirming the fix, plus one MINOR:

- **FATAL, fixed:** test-evidence adapters checked field presence only. Now
  `scripts/lib/execution-contract-evidence.ps1` performs the real checks --
  JUnit: repo-root containment, real `Get-FileHash` compared against the
  claimed digest, DTD-prohibited safe XML parse, `failures+errors == 0`.
  CI-check: a live `gh api .../check-runs` query matched by name, never the
  result's own claimed `conclusion`; no `gh`/auth/remote means *unverified*,
  never a pass. Runner: `scripts/run-execution-command.ps1` actually
  executes the command as a real child process (not `Invoke-Expression`,
  which runs in-process and would let a command's own `exit` kill the
  runner -- found by testing, not reasoned about) and seals a record via the
  same file+sidecar digest pattern the contract already uses.
- **MAJOR, fixed:** the contract digest sidecar is now mandatory --
  `EXEC-002` fails closed (`contract_digest_missing` /
  `contract_digest_malformed`) instead of skipping the tamper check when the
  sidecar is absent. `EXEC-007`'s human-authority check now resolves
  `decision_ref` against a real `Resolve-DecisionRecord` parse of
  `decision-log.md` -- exists, unique, and **not itself added or edited
  within the commit range under verification** (the self-forged-approval
  case), not merely non-empty.
- **MINOR, fixed:** `EXEC-008` now checks both directions -- a file the
  result claims changed that git shows no evidence of is reported, not only
  the reverse.

120 adversarial cases (`tests/helpers/execution-contract-tests.ps1`, up from
57) reproduce each gap across all five rounds and confirm each fix: fabricated
JUnit hash, missing/traversal path, real failures with a correct hash,
tampered and mismatched-work-item run records, no-remote `ci-check`,
deleted/empty/malformed sidecars, fake and ambiguous `DEC-###` references,
and the self-forged-decision attack.

The decisive three, from round 2: a **hand-forged run record with a
genuinely matching sidecar** (the demonstrated bypass) must fail; a
**legitimately produced record without a vouch** must also fail, because
Axiom-PMO cannot tell the two apart; and an **agent vouching for its own
evidence** must fail on actor authority -- the obvious next forgery once a
human vouch becomes the way through.

**Round 4 (2026-07-31)** found the decision-row anchor itself was still too
weak, in two places, and both were reproduced here before being fixed.

The anchor searched the decision row for the artifact digest as a
**substring**. That answers "does this row mention these bytes", not "did a
human approve *this artifact* for *this test*" -- so a row approving a JUnit
report for `unit tests` was reusable for `integration tests` simply by
relabelling the evidence entry and the claim, both of which the verified
actor writes. Verdict `pass`, no rule raised. Separately, the binding check
ran **only** for `test-evidence-accepted`; every other human-only claim
(`release-approval`, `qa-approval`, `security-approval`, `scope-change`,
`risk-mode-downgrade`) still resolved on `decision_ref` alone, so any
`DEC-###` in the log satisfied any of them.

A substring is not a statement. The row must now carry a structured
`axiom-authority: type=...; work_item=...; contract=...; test=...;
evidence=...` token, parsed field by field, per table cell -- required on
every human-only claim, with `test` and `evidence` additionally required for
a test vouch. A digest sitting in the row's prose authorizes nothing; a row
with no token fails closed.

Worth recording as a pattern: three of the four rounds found the *same
class* of mistake -- a check that was real, did work, and answered a
slightly different question than the one that mattered. Field presence
instead of ground truth (round 1); integrity instead of provenance (round
2); resolvability instead of relevance (rounds 3 and 4).

**Round 5 (2026-07-31): ACCEPT.** No security finding. One non-blocking
documentation/runtime mismatch: the docs said a decision row could carry
several `axiom-authority` tokens, while the parser matched greedily to
end-of-cell and read two tokens sharing a cell as one malformed payload.
Fixed in the parser rather than the docs -- a token now runs until the next
`axiom-authority:` or the end of its cell -- with two cases added: two
bindings in one cell both resolving, and two near-miss bindings not combining
into an authorization.

Still open and unchanged, non-blocking by reviewer agreement: `ci-check`
matches a check run by *name*, so a check that failed and was later re-run
green produces a permanent false negative.

| Phase | Status |
|---|---|
| 5.1 contract export | Built |
| 5.2 result import | Fixed: mandatory sidecar |
| 5.3 authority + scope + evidence | Fixed: provenance tiers (artifact-observed evidence no longer satisfies a required test alone), real decision resolution |
| 5.4 integration tests | Expanded: 120 cases, including the forged-record bypass (round 2), the unbound-vouch bypass (round 3), the substring-anchor and unbound-non-test-claim bypasses (round 4), and multi-token decision rows (round 5, non-blocking) |

Rules `EXEC-001` to `EXEC-008`, each with a `docs/rules/` page. Policy lives
in `pmo-config/execution-contract-policy.json`.

`integrations/superpowers/*.json` remain experimental and unmodified: the
shipped schema supersedes them, and rewriting them now would imply a native
integration that 5.0 established does not exist.

Not built, deliberately: no normalized intermediate representation, no
per-workflow dialects (`--format` is accepted and recorded but does not change
output), and no attempt to prove the absence of git side effects -- the
verification limits are stated in the policy config and the user-facing
reference rather than discovered by a user.

Definition of done:

```text
Axiom-PMO can accept execution output as candidate evidence while blocking
path violations, missing required-test evidence, scope deviation,
contract-to-result git authority violations, and agent self-approval -- and
states plainly, in its own documentation, what it cannot verify from local
repository state alone.
```

## Milestone 6 - Claude Code Integration Experience

> **Optional integration. Not part of the core product.**
>
> Milestones 1-5 are the core Axiom-PMO product. A team can adopt Axiom-PMO,
> run every gate, and hand verified work to a developer without ever touching
> Milestone 6. This milestone exists only for teams who then choose to
> continue implementation with Claude Code, so that a verified handoff can be
> picked up directly instead of re-interpreted.

Objective: let a verified Axiom-PMO handoff be continued in Claude Code
without re-interpreting the documents or rebuilding an integration -- without
damaging existing repository configuration, and without turning Axiom-PMO into
a coding framework.

Non-goals, stated because the framing is easy to lose:

- Milestone 6 does not make Axiom-PMO a development framework or a repo
  developers come to in order to write systems.
- It is not a requirement for using Axiom-PMO.
- It does not move any authority, evidence, or approval logic out of the core.

Status, split out rather than collapsed into one word, because these are
genuinely different things:

| | |
|---|---|
| Implementation | complete, remediation applied |
| Hardening | complete (before the review findings) |
| Human Owner testing | complete |
| Human Owner acceptance | accepted (`DEC-005`) |
| Independent Sol review | **completed — REQUEST CHANGES** |
| Blocking findings | **1 FATAL, 1 MAJOR — both now fixed, awaiting re-review** |
| Milestone closure | **blocked pending re-review** |
| Release / tag / publish / merge | **not authorized** |

Milestone 6 is **not closed.** Independent review returned **REQUEST CHANGES**
with one FATAL and one MAJOR, both in the user-file write path:

- **FATAL — ownership was decided by a self-declared, unkeyed digest.** Anyone
  could write arbitrary content into the markers, compute the matching SHA-256,
  and have setup or uninstall treat it as framework-generated. Reproduced, then
  fixed: ownership is now anchored to the canonical body the framework
  generates, and a self-consistent forgery fails closed.
- **MAJOR — removal mutated content outside the markers.** `TrimEnd`/`Trim`
  around the block collapsed blank lines the user owned. Fixed: removal takes
  the exact marker span plus only the separator and trailer the marker itself
  records, and installation no longer trims the file it appends to.

Both are fixed and awaiting re-review. The Human Owner's acceptance remains
valid but closes neither these findings nor the three debts below.

Authorized by the Human Owner on 2026-07-31 after the 6.1 spike was accepted.

| Phase | Status |
|---|---|
| 6.0 integration shape decision | Decided (HYBRID); Sol: ACCEPT WITH MINOR REVISIONS, applied |
| 6.1 packaging spike | **Accepted** by the Human Owner, 2026-07-31 |
| 6.2 plugin packaging + drift gate | Implemented |
| 6.3 setup / uninstall / rollback | Implemented |
| 6.4 clean-room compatibility | Implemented, with a real plugin-load transcript |
| 6.5 optional advisory hook | Implemented, report-only and off by default |

What it does: packages the seven skills, the validators, the config and the
templates as a Claude Code plugin (installed outside the user's repository),
and appends one fenced, namespaced block to the repository's `AGENTS.md`.

What it does **not** do, stated because this is the easiest thing to
misrepresent:

> Claude Code receives the approved scope and authority as governed context.
> Axiom-PMO verifies afterwards whether the implementation remained within
> them. Nothing in Milestone 6 prevents an out-of-scope edit.

Detection stays where it was -- SCOPE-DIFF and the `EXEC-*` rules, after
execution. No authority, evidence, or approval logic moved out of Milestones
1-5, and `tests/helpers/clean-room-tests.ps1` asserts that rather than leaving
it as prose.

The layout deviates from the shape this milestone was authorized with, on
evidence. The authorization proposed a `plugin/` subdirectory installed via
`git-subdir`; building it that way would have required copying `scripts/`,
`cli/`, `pmo-config/` and `templates/` into that subdirectory, because a
`git-subdir` install fetches only that subdirectory -- which is duplicating the
validator, and the same authorization forbids it. The plugin root is therefore
the repository root (`source: "./"`), nothing moves, and the only generated
directory is `skills/`, gated against drift in CI.

Known limitations are listed in
[`docs/guides/claude-code-integration.md`](docs/guides/claude-code-integration.md#known-limitations),
residual risks in
[`docs/architecture/m6-threat-model.md`](docs/architecture/m6-threat-model.md).
Three are acknowledged by the Human Owner and remain **open** -- see
[Deferred technical debt](#deferred-technical-debt).

### Milestone 6.0 - Integration shape decision

Research and reasoning:
[`docs/architecture/claude-code-integration.md`](docs/architecture/claude-code-integration.md).
Decision recorded as `DEC-003` in `decision-log.md`.

The seven candidate shapes were evaluated against a real clone of the
`superpowers` plugin (commit `44c9b2d6`, v6.2.0) rather than assumed. The
decisive finding: "install Axiom-PMO" is six kinds of content, and only two
of them must live in the user's repository.

```text
Claude Code plugin  (installed once, outside the user's repo)
  skills/pmo-*            the 7 existing skills, already in conforming shape
  scripts/, cli/          the validator, invoked via ${CLAUDE_PLUGIN_ROOT}
  pmo-config/*.json       framework runtime config
  templates/              scaffolding source

User's repository  (created or appended, always reviewably)
  CLAUDE.md / AGENTS.md   one short namespaced Axiom-PMO section
  PROJECT.md, DELIVERY.md, SCOPE.json, ...   the user's governed artifacts
```

The behavioural rules cannot move into the plugin: `AGENTS.md` targets Codex,
Cursor, and Copilot as well as Claude, and a Claude-only plugin would quietly
narrow a multi-agent framework into a single-vendor one.

Adopted: **plugin** (framework), **copyable integration block** appended to
the repository-level `AGENTS.md` -- the intended cross-agent governance
source, which harness-specific files like `CLAUDE.md` may reference or
supplement -- (the honest minimum for the repo files), **`axiom setup
claude`** (a thin convenience wrapper over those two, not a large installer).
The **skill pack** was not a separate option -- it already exists and already
conforms. **Command set** deferred as unverified; **MCP deferred** -- no
proven need for the M6 MVP, not rejected permanently -- as a delivery
mechanism for a validator the CLI and Action already expose.

A file's presence in a repository does not by itself prove every harness
reads and obeys it; each harness's own discovery/precedence rules are a
separate, unverified question the architecture doc explicitly flags rather
than claiming universal compatibility from file presence alone.

The **hook** -- a `PreToolUse` guard that would make governance preventive
rather than detective -- is carved out as a separate, later, opt-in milestone
(M6.5, below). It is genuine new capability, but it is also the only option
that can make a user's editor feel broken, so it must ship report-only by
default like SCOPE-DIFF and the GitHub Action did, with its own acceptance.

### Milestone 6.1-6.5 (requires separate approval)

Sequenced as separately acceptable steps, not one milestone, so a packaging
spike finding cannot get built on top of before it is checked. Full detail:
[`docs/architecture/claude-code-integration.md`](docs/architecture/claude-code-integration.md) §8.

0. **M6.1 spike -- DONE.** Report:
   [`docs/architecture/plugin-packaging-spike.md`](docs/architecture/plugin-packaging-spike.md).
   15 cases in `tests/helpers/plugin-install-spike-tests.ps1`, wired into
   `run-all-checks.ps1`. Result: the user-facing surface works from a
   non-checkout, non-cwd, read-only install root, and the full M5 loop reaches
   a real verdict from there; **no directory move is required** (`git-subdir`
   sources are verified and widely used); the approved fallback was **not**
   needed. One finding: the framework's own maintainer tools correctly do not
   work from a plugin install, but fail with a raw exception instead of a
   diagnostic -- an M6.2 item. Implementation stopped here pending a Human
   Owner decision.
1. **M6.1 Plugin packaging** -- starts with a spike proving this framework's
   multi-file PowerShell validator actually runs from inside a plugin
   (executable invocation permission, `pwsh` host resolution, dot-sourcing,
   framework-root/project-root distinction, update/version drift, Windows
   path quoting) before any real directory restructuring.
2. **M6.2 Namespaced repo integration** -- the copyable `AGENTS.md` block:
   fenced markers, idempotent append, backup before touching an existing
   file, conflict report.
3. **M6.3 Setup/uninstall safety** -- `axiom setup claude` wrapping 1 and 2,
   with `--dry-run`, refusal on an unclean working tree, and uninstall that
   removes exactly what was added.
4. **M6.4 Clean-room compatibility** -- install into a repository that
   already has its own `CLAUDE.md`, skills, and Superpowers, and prove
   nothing of theirs was lost. This is the packaging work's definition of
   done; it cannot be satisfied by unit tests alone.
5. **M6.5 Optional preventive hook pilot** -- only after Human Owner
   acceptance of M6.1-6.4. Report-only by default, its own acceptance,
   transparent bypass/disable path.

Definition of done:

```text
Claude Code users can add Axiom-PMO to a real repository without losing existing
Claude, Superpowers, BMAD, or custom agent configuration.
```

## Not Now

Do not spend near-term effort on:

- rewriting the core validator before there is a proven need;
- adding validation rules only to increase perceived coverage;
- supporting many frameworks superficially;
- claiming compatibility without integration tests;
- building a web dashboard before the CLI and GitHub Action are mature;
- buying stars or using fake engagement;
- publishing benchmarks without methodology;
- using "first in the world" positioning;
- adding documentation that is not tied to user need.

## Priority Backlog

### Done

- Public hygiene scan, archive sanitation, branding cleanup, and broken-link
  checks.
- Broken/fixed demo, one-command demo, and README quick start.
- Structured diagnostics, stable JSON result schema, and rule documentation.
- Engineering Handoff Readiness and the local CLI.
- Milestone 3.5 Runtime Portability: Windows PowerShell 7 and Ubuntu
  PowerShell 7 are blocking workflow jobs, Ubuntu passed two promoted `main`
  runs, Windows PowerShell 5.1 remains green, and human acceptance was recorded
  on 2026-07-29 with branch protection deferred.
- Milestone 4 (reusable GitHub Action) and Milestone 4.5 (SCOPE-DIFF): both
  merged to `main`, Human Owner accepted 2026-07-30, released together as
  `v1.2.0`.
- Milestone 5.0 research and go/no-go decision (GO WITH REFRAME), recorded
  2026-07-30.
- Milestone 5.1-5.4 Execution Contract Verification: five review rounds,
  Human Owner accepted and closed 2026-07-31 (`DEC-004`). **This completes
  the core product** -- Milestones 1-5.
- Milestone 6.0 research: integration shape decided (HYBRID), reviewed and
  revised 2026-07-30.

### Deferred technical debt

Open, acknowledged, and deliberately not hidden. Nothing here was closed by
Milestone 6's Human Owner acceptance (`DEC-005`), and none of it may be
described as fixed until it is.

| # | Debt | Milestone | Status |
|---|---|---|---|
| 1 | **Plugin update / version drift is untested.** Marketplace entries can pin a `sha`, but nothing verifies that an update cannot replace a pinned install mid-session. | M6 | Open. Non-blocking. |
| 2 | **Cross-plugin hook ordering is unproven.** What *is* verified is that the advisory returns nothing that could override another plugin's hook; Claude Code's ordering and merge behaviour was not inspected. | M6 | Open. Non-blocking. |
| 3 | **A git-source plugin install carries the whole repository** -- roughly 10 MB, of which ~6.7 MB is `tests/`. Only `skills/`, `hooks/` and the manifests are loaded; the rest is inert. | M6 | Open. Non-blocking. **Must not be resolved by duplicating the validator or by a large restructure without a separate milestone and decision.** |
| 4 | **`ci-check` matches a check run by name, not `check_run_id`.** A check that failed and was later re-run green can produce a permanent false negative. | M5 | Open. Non-blocking per Sol's earlier review. Not fixed. |

### Deferred trust evidence

- Optional independent clean-room walkthrough on Windows and macOS (Milestone
  1). Deferred from the start; not a blocker for the core product or for
  Milestone 6.
- Optional deterministic terminal recording and README GIF (Milestone 1). Same
  status.
- Issue #8 remains available if the deferred evidence is picked up later.
- **Milestone 3 Phase B: the public npm package is deferred and has NOT been
  published.** Nothing may describe Axiom-PMO as having an npm distribution.

### Next

- **Milestone 6.1 packaging spike** -- authorized by the Human Owner
  2026-07-31. Prove what a Claude Code plugin can actually do with this
  framework before any restructuring: executable invocation under the current
  permission model, `pwsh` host resolution from a plugin install location,
  dot-sourcing, framework-root versus project-root separation, and the
  required skills layout. Directory moves are **not** authorized on
  assumption; an approved fallback exists if native validator invocation does
  not hold. Ends with an evidence packet and a stop for a Human Owner
  decision -- M6.2-M6.4 do not begin without it.
- External-user validation of the v1.2.0 GitHub Action and SCOPE-DIFF. This
  needs the Human Owner personally and cannot be delegated; it is the main
  source of independent signal about whether the shipped features are usable
  by anyone who did not build them.

### Blocked

- **Milestone 6 closure**, until independent re-review passes. The first review
  returned REQUEST CHANGES; the findings are fixed and re-review is pending.
- Publishing the plugin to a public marketplace, tagging a release, and merging
  Milestone 6 to `main` -- all behind that same re-review.
- Any enforcement mode for the advisory hook. It ships report-only; making it
  block would be a separate proposal with its own acceptance, not a
  configuration change.

## Success Signals

Milestone 1:

```text
Users see Axiom-PMO's value within three minutes.
```

Milestone 2:

```text
Users understand failures without reading the whole framework.
```

Milestone 3:

```text
Users can run Axiom-PMO through a developer-friendly command surface.
```

Milestone 3.5:

```text
Required Windows and Ubuntu PowerShell 7 runs produce the same governed output
as the Windows PowerShell 5.1 compatibility run.
```

Milestone 4:

```text
Axiom-PMO blocks governance failures inside pull requests.
```

Milestone 5:

```text
Axiom-PMO controls execution-framework output with real validation, not only
architecture documentation.
```

Milestone 6:

```text
Claude Code users can integrate Axiom-PMO without overwriting or breaking
existing agent configurations.
```
