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

Axiom-PMO owns policy, evidence, traceability, approval gates, release
readiness, and agent authority. Execution frameworks such as Superpowers, BMAD,
GitHub spec-kit, OpenSpec, and Claude Code own planning, coding, testing, and
implementation mechanics.

Axiom-PMO should not compete with execution frameworks. It should define the
control layer they operate inside.

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
| Milestone 5 - Execution Contract Verification MVP | Delivered (5.0 decided GO WITH REFRAME; 5.1-5.4 built and tested) | `docs/reference/execution-contract.md`; decision `DEC-002` |
| Milestone 6 - Claude Code Integration Experience | Planned | Requires separate approval after Milestone 5 |

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
-> Milestone 5 (delivered)
-> Milestone 6
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
two independent AI review rounds (Independent AI Reviewer). The first round found two MAJOR
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

Status: **delivered 2026-07-30**, against the "GO WITH REFRAME" design in
`docs/architecture/execution-contract-verification.md` §4. User-facing
reference: [`docs/reference/execution-contract.md`](docs/reference/execution-contract.md).

| Phase | Delivered |
|---|---|
| 5.1 contract export | `axiom export --project <p> --work-item D-### [--grant commit,push]` -> `.execution/D-###/EXECUTION-CONTRACT.json` plus a `.sha256` digest sidecar. Contract fields are derived from the approved `DELIVERY.md` row and `SCOPE.json`; a project without an approved scope cannot be exported from. |
| 5.2 result import | `axiom verify --project <p> --result <path>`: schema validation, contract-digest immutability (three-way agreement between the contract's live hash, the sidecar, and the result's `contract_sha256`), work-item/base/requirement matching with asymmetric requirement drift. |
| 5.3 authority + scope + evidence | Git ground-truth adapter (ancestry, commit range, remote containment as a tri-state), allowed-path validation reusing M4.5's glob engine and case-sensitivity, three machine-verifiable test-evidence adapters, typed authority-claim records blocking agent self-approval. |
| 5.4 integration tests | `tests/helpers/execution-contract-tests.ps1`, 57 cases against disposable real-git fixtures, wired into `run-all-checks.ps1`. Written adversarially: tampered contracts, orphan-branch ancestry, undeclared changes, hollow evidence, self-approval, unknown actors. |

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

Objective: make Axiom-PMO natural for Claude Code users without damaging
existing repository configuration.

Status: **Milestone 6.0 decided 2026-07-30 (HYBRID); 6.1+ still requires
separate human approval before implementation.**

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

Adopted: **plugin** (framework), **copyable integration block** (the honest
minimum for the repo files), **`axiom setup claude`** (a thin convenience
wrapper over those two, not a large installer). The **skill pack** was not a
separate option -- it already exists and already conforms. **Command set**
deferred as unverified; **MCP** rejected for now as a delivery mechanism for a
validator the CLI and Action already expose.

The **hook** -- a `PreToolUse` guard that would make governance preventive
rather than detective -- is carved out as a separate, later, opt-in milestone.
It is genuine new capability, but it is also the only option that can make a
user's editor feel broken, so it must ship report-only by default like
SCOPE-DIFF and the GitHub Action did, with its own acceptance.

### Milestone 6.1+ (requires separate approval)

If an installer is built, it must:

- detect existing `AGENTS.md`, `CLAUDE.md`, skills, commands, and framework
  setup;
- create backups before modification;
- append namespaced Axiom-PMO sections instead of overwriting;
- report conflicts;
- ask before destructive changes;
- support uninstall.

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
- Milestone 5.1-5.4 Execution Contract Verification MVP: `axiom export` /
  `axiom verify`, rules `EXEC-001` to `EXEC-008`, contract-digest
  immutability, git ground-truth validation, three machine-verifiable
  test-evidence adapters, typed authority claims, and 57 adversarial
  integration tests.

### Deferred trust evidence

- Optional independent clean-room walkthrough on Windows and macOS.
- Optional deterministic terminal recording and README GIF.
- Issue #8 remains available if the deferred evidence is picked up later.

### Next

- Milestone 6 prototyping (copyable integration block, skill pack, command
  set, plugin, MCP command, or hook -- shape not yet decided).
- External-user validation of the v1.2.0 GitHub Action and SCOPE-DIFF. This
  needs the Human Owner personally and cannot be delegated; it is the main
  source of independent signal about whether the shipped features are usable
  by anyone who did not build them.

### Blocked

- Claude Code integration implementation (Milestone 6), until separately
  approved after Milestone 5.

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
