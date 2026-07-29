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
| Milestone 1 - Public Trust + Three-Minute Proof | Acceptance debt | Walkthrough and recording remain open |
| Milestone 2 - Developer Diagnostics | Delivered | Delivered in 1.1 |
| Milestone 2.5 - Engineering Handoff Readiness | Delivered | Delivered in 1.1.0; strengthened in 1.1.1 |
| Milestone 3 - Thin Local CLI | Delivered (Phase A) | Local CLI delivered; public npm package deferred |
| Milestone 3.5 - Runtime Portability | Next prerequisite | Must complete before Milestone 4 implementation |
| Milestone 4 - GitHub Action | Planned | Blocked by Milestone 1 acceptance and Milestone 3.5 |
| Milestone 5 - Superpowers Runtime Bridge | Blocked | Starts only after Milestone 4 human acceptance |
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
Milestone 1 acceptance
-> Milestone 2 (delivered)
-> Milestone 2.5 (delivered)
-> Milestone 3 (delivered)
-> Milestone 3.5
-> Milestone 4
-> Milestone 5
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

Status: **acceptance debt.** The validator, demo, hygiene tooling, quick start,
and CI exist. An independent clean-room walkthrough and a committed terminal
recording/GIF are still required. Issue #8 records this work and must be reopened
rather than replaced.

Deliverables:

- Public hygiene scan for stale internal references, local paths, private URLs,
  secret-like patterns, internal branch names, and broken documentation links.
- Sanitized historical archive with clear historical banners.
- Branding cleanup so public-facing workflow names and docs consistently use
  Axiom-PMO.
- `demo/broken-project/` and `demo/fixed-project/`.
- One-command demo through `scripts/demo.ps1` and `make demo`.
- README quick start near the top of the document.
- GIF or terminal recording showing a failing gate becoming a passing gate.
- One clean-room usability test with a developer unfamiliar with Axiom-PMO.
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

Status: **next prerequisite before Milestone 4.**

The runtime already resolves `AXIOM_PWSH`, the current host, `pwsh`,
`powershell`, and `powershell.exe`. This milestone promotes that runtime
flexibility into an explicit support and CI contract.

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

Status: **planned; implementation blocked by Milestone 1 acceptance and
Milestone 3.5.**

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

## Milestone 5 - Superpowers Bridge MVP

Objective: build one complete, tested integration instead of many shallow
compatibility claims.

Status: **blocked by Milestone 4 human acceptance.** Experimental schemas may
remain available for design review, but runtime export/import work must not
start before that acceptance.

Reference integration:

```text
Axiom-PMO = governance
Superpowers = execution
```

Target flow:

```text
Axiom work item
-> Export execution contract
-> Superpowers executes
-> Return execution result
-> Axiom validates
-> Build review
-> Human QA / release
```

Deliverables:

- `axiom export D-001 --format superpowers`
- `.execution/D-001/EXECUTION-CONTRACT.json`
- `.execution/D-001/EXECUTION-RESULT.json`
- `axiom import .execution/D-001/EXECUTION-RESULT.json`
- Schema validation.
- Work item and requirement matching.
- Allowed-path validation.
- Required-test validation.
- Evidence resolution checks.
- Scope deviation checks.
- Contract-to-result git authority validation.
- Agent self-approval blocking.
- Integration tests.

Git authority validation in the MVP means checking the execution contract
against the returned execution result. It should verify whether the result
reports commits or pushes, whether the contract allowed that action, whether
reported commit references are well-formed, and whether the result attempts to
claim an approval the agent cannot grant.

The MVP should not claim to detect every possible git side effect outside the
execution session. Broader local/remote state verification can be added later
when the bridge has enough runtime context to prove it safely.

Definition of done:

```text
Axiom-PMO can accept execution output as candidate evidence while blocking path
violations, missing tests, scope deviation, contract-to-result git authority
violations, and agent self-approval.
```

## Milestone 6 - Claude Code Integration Experience

Objective: make Axiom-PMO natural for Claude Code users without damaging
existing repository configuration.

Status: **planned; requires separate approval after Milestone 5.**

Do not assume the final shape is an installer. Prototype and evaluate:

- copyable integration block;
- Claude skill pack;
- command set;
- plugin;
- MCP command;
- hook;
- `axiom setup claude`.

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

### Acceptance debt

- Reopen Issue #8.
- Complete an independent clean-room walkthrough on Windows and macOS.
- Commit a deterministic terminal recording and README GIF.
- Record human acceptance of Milestone 1 after the evidence is verified.

### Next

- Milestone 3.5 required Windows PowerShell 7 and Ubuntu PowerShell 7 CI.
- Windows PowerShell 5.1 compatibility regression coverage.
- Non-blocking macOS PowerShell 7 evidence.
- Milestone 4 tracking issue and child issues for the reusable Action,
  Job Summary/report artifacts, safe annotations, consumer/privacy tests, and
  acceptance documentation.

### Blocked

- Milestone 4 implementation, until Milestone 1 and Milestone 3.5 are accepted.
- Superpowers export/import runtime, until Milestone 4 is accepted.
- Claude Code integration implementation, until separately approved after
  Milestone 5.

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
