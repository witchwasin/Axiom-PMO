# Axiom-PMO Productization Roadmap

Status: roadmap of record  
Last updated: 2026-07-14

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
-> Share result
-> Contribute
```

A new user should be able to see why Axiom-PMO matters before reading the full
framework documentation.

## Near-Term Strategy

The core validator is already strong enough to productize around. Near-term
work should focus on adoption, diagnostics, workflow integration, and a single
real execution-framework bridge.

Recommended effort allocation:

| Area | Allocation |
|---|---:|
| Core maintenance | 20% |
| Developer experience | 30% |
| Integrations | 25% |
| Community | 15% |
| Content and distribution | 10% |

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

## Milestone 1 - Public Trust + Three-Minute Proof

Objective: make the repository trustworthy and make the value visible within
three minutes.

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
- Basic feedback intake for early visitors:
  - `good first issue`;
  - `help wanted`;
  - bug report template;
  - feature request template;
  - demo feedback issue.
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

## Milestone 3 - Thin Local CLI

Objective: make Axiom-PMO usable without requiring users to understand the
PowerShell implementation.

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

## Milestone 4 - GitHub Action

Objective: make Axiom-PMO visible directly in pull requests.

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

## Milestone 7 - Community Launch

Objective: move from owner-driven development toward contributor-ready
development.

Deliverables:

- GitHub Discussions categories:
  - General
  - Help
  - Ideas
  - Integrations
  - Show and Tell
  - Governance Cases
- Labels:
  - `good first issue`
  - `help wanted`
  - `integration`
  - `validator`
  - `documentation`
  - `cross-platform`
  - `security`
  - `governance`
  - `claude-code`
  - `superpowers`
- At least five good first issues.
- At least five help wanted issues.
- `CONTRIBUTORS.md`.
- Contributor recognition in release notes.
- `integrations/_template/` with:
  - README template;
  - contract mapping;
  - authority matrix;
  - test fixture;
  - compatibility declaration.

Definition of done:

```text
A new contributor can identify useful work, understand the expected test path,
and start without asking the owner for every step.
```

## Milestone 8 - Content, Evidence, And Adoption

Objective: grow through proof, not claims.

Content assets:

- 60-90 second demo video.
- README GIF.
- Technical article: "Why Prompt-Level Safety Is Not Enough for AI Coding
  Agents".
- Comparison article: "Superpowers Builds the Code. Axiom-PMO Governs the
  Authority."
- Show HN post.
- GitHub social preview:

```text
AI Can Build.
Humans Still Approve.
```

Usage evidence to collect:

- unsupported requirements blocked;
- scope deviations blocked;
- missing evidence blocked;
- unauthorized actions detected;
- release gates failed before production;
- human approvals recorded;
- false positives;
- waivers;
- time to first successful validation;
- time to first detected failure.

Case study template:

```text
Project type:
Team size:
Execution framework:
Axiom mode:
Failure detected:
Impact prevented:
Process overhead:
Outcome:
```

Telemetry guardrail:

- no telemetry by default;
- any telemetry must be opt-in, anonymous, and documented;
- start with user-submitted diagnostic reports before automated telemetry.

Definition of done:

```text
External users can see real demonstrations, real failure modes, and real usage
evidence before adopting Axiom-PMO.
```

## Not Now

Do not spend near-term effort on:

- rewriting the core validator before there is a proven need;
- adding validation rules only to increase perceived coverage;
- supporting many frameworks superficially;
- claiming compatibility without integration tests;
- building a web dashboard before CLI and GitHub Action adoption;
- buying stars or using fake engagement;
- publishing benchmarks without methodology;
- using "first in the world" positioning;
- adding documentation that is not tied to user need.

## Priority Backlog

P0 - before heavy promotion:

- public hygiene scan;
- archive sanitation;
- branding cleanup;
- broken link audit;
- broken/fixed demo;
- one-command demo;
- README quick start;
- GIF.

P1 - make it usable:

- structured diagnostics;
- stable JSON result schema;
- rule documentation;
- local CLI;
- cross-platform CLI tests.

P2 - make it visible in workflow:

- GitHub Action;
- PR summary;
- annotations;
- report artifacts.

P3 - make it differentiated:

- Superpowers contract export;
- Superpowers result import;
- path, evidence, test, and authority checks;
- integration test suite.

P4 - make it contributor-ready:

- Claude Code integration experience;
- Discussions;
- contributor issues;
- integration template;
- public roadmap updates.

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

Milestone 7:

```text
External contributors can find, implement, test, and submit meaningful changes
without owner-led onboarding.
```

Milestone 8:

```text
External users and contributors can validate the product value from demos,
issues, case studies, and workflow evidence.
```
