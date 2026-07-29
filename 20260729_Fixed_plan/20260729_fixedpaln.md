# 20260729 Fixed Plan — Axiom-PMO Roadmap Alignment

Date: 2026-07-29
Plan ID: `20260729_fixedpaln`
Status: implementation plan with 2026-07-29 execution updates; no milestone
acceptance is implied

## Purpose

This document is a handoff plan for another AI agent or developer. The executor
must inspect the current repository state before changing anything and must not
invent walkthrough results, test evidence, approvals, owners, or release
decisions.

The intended outcome is to:

- align the roadmap and current documentation with Axiom-PMO `v1.1.1`;
- keep Milestone 1 walkthrough and recording evidence available as optional
  trust work;
- add Milestone 3.5 for portable PowerShell execution;
- plan and track Milestone 4 as a reusable GitHub Action;
- keep Milestone 5 blocked until Milestone 4 is accepted;
- remove Milestones 7 and 8 because they are not part of the owner's product
  priorities.

## Confirmed Current State

- Current product version is `1.1.1`.
- Milestone 2 developer diagnostics are implemented.
- Milestone 2.5 handoff readiness was delivered in `1.1.0` and strengthened by
  `HANDOFF-013` and `HANDOFF-014` in `1.1.1`.
- Milestone 3 local CLI Phase A is implemented. A public npm package is not.
- The runtime already discovers `AXIOM_PWSH`, the current PowerShell host,
  `pwsh`, `powershell`, and `powershell.exe`.
- Windows PowerShell 5.1 is still treated as the reference platform.
- CI run
  [#30432327317](https://github.com/witchwasin/Axiom-PMO/actions/runs/30432327317)
  passed on Windows PowerShell 5.1, Windows PowerShell 7, Ubuntu PowerShell 7,
  and macOS PowerShell 7 at commit `eb50c29`.
- Local documentation commit `aaa5e6b` records the current M3.5 status and
  PowerShell runtime setup guidance.
- Workflow promotion commit `24d8b99` renames the Ubuntu job to
  `pmo-checks-linux-pwsh7`, removes `continue-on-error`, and makes the Ubuntu
  PowerShell 7 path a blocking workflow job.
- CI run
  [#30434956117](https://github.com/witchwasin/Axiom-PMO/actions/runs/30434956117)
  passed on `main` at commit `24d8b99` after the Ubuntu promotion. This is
  Ubuntu promoted green run 1 of 2.
- CI run
  [#30436344213](https://github.com/witchwasin/Axiom-PMO/actions/runs/30436344213)
  passed on `main` at commit `016f1d9` after the Ubuntu promotion. This is
  Ubuntu promoted green run 2 of 2; the CI threshold is met.
- Ubuntu PowerShell 7 promotion threshold is human-approved: after
  `continue-on-error` is removed, it must pass two consecutive full CI runs on
  `main` before M3.5 acceptance.
- Human acceptance for M3.5 was recorded on 2026-07-29 in Codex chat, with
  `main` branch protection deferred and not required for this milestone
  acceptance.
- Milestone 1 walkthrough and recording evidence is deferred by human decision
  on 2026-07-29 and is not a blocker before M4 implementation.
- GitHub Issue #8 tracks the optional walkthrough and recording evidence and is
  open.
- GitHub Issue #12 tracks Milestone 4. M3.5 is accepted and M1 evidence is
  deferred, so M4 may move into implementation planning.
- The Superpowers schemas are experimental and are not connected to the
  validator runtime.

## Target Roadmap

| Milestone | Target status |
|---|---|
| M1 — Public Trust and Three-Minute Proof | Delivered with deferred optional trust evidence |
| M2 — Developer Diagnostics | Delivered |
| M2.5 — Engineering Handoff Readiness | Delivered in 1.1.0; strengthened in 1.1.1 |
| M3 — Thin Local CLI | Phase A delivered; npm Phase B deferred |
| M3.5 — Runtime Portability | Accepted on 2026-07-29 |
| M4 — GitHub Action | Planned; ready for implementation planning |
| M5 — Superpowers Runtime Bridge | Blocked by M4 acceptance |
| M6 — Claude Code Integration Experience | Planned |
| M7 — Community Launch | Remove from roadmap |
| M8 — Content, Evidence, and Adoption | Remove from roadmap |

The active dependency chain must become:

```text
M1 delivered, with walkthrough/recording evidence deferred
-> M2 delivered
-> M2.5 delivered
-> M3 delivered
-> M3.5 runtime portability
-> M4 GitHub Action
-> M5 Superpowers runtime bridge
-> M6 Claude Code integration
```

Opening planning issues for a blocked milestone is allowed. Starting its
implementation is not.

## Workstream 1 — Documentation Alignment

### Required changes

1. Update `ROADMAP.md`:
   - set `Last updated` to `2026-07-29`;
   - identify the current product version as `1.1.1`;
   - add the milestone status table above;
   - add explicit statuses to the milestone sections;
   - add Milestone 3.5 between M3 and M4;
   - make M4 depend on accepted M1 and completed M3.5;
   - make M5 depend on accepted M4;
   - remove the complete M7 and M8 sections;
   - remove M7/M8 priority items, success signals, and dependency references.
2. Replace current-document references to `HANDOFF-001` through
   `HANDOFF-012` with `HANDOFF-001` through `HANDOFF-014`.
3. Do not change the v1.1.0 release notes when they describe the historical
   v1.1.0 rule set.
4. Update the README roadmap summary so it states:
   - what was delivered in v1.1;
   - that M1 walkthrough/recording evidence is deferred optional trust work;
   - that M3.5 is accepted;
   - that M4 follows M3.5 and may move into implementation planning;
   - that M5 remains blocked by M4.
5. Split the roadmap backlog into:
   - `Done`;
   - `Deferred trust evidence`;
   - `Next`;
   - `Blocked`.

### Documentation acceptance

- Current documents do not incorrectly stop the Handoff rule range at
  `HANDOFF-012`.
- Historical release documents remain historically accurate.
- M7 and M8 no longer appear as active roadmap milestones or backlog work.
- README and ROADMAP describe the same milestone order and status.

## Workstream 2 — Milestone 1 Walkthrough and Recording

Status: **deferred optional trust evidence.** This workstream was originally a
Milestone 4 blocker. On 2026-07-29, the human decision removed it from the
blocker chain. Keep the evidence packet and Issue #8 available if the work is
picked up later, but do not block M4 on it.

### Issue handling

GitHub Issue #8 is open. Do not create a duplicate issue. Add a comment that
records the deferred-evidence decision and preserves the existing history.

### Optional human walkthrough

If picked up later, the walkthrough should be performed by a developer who is
unfamiliar with this repository. An AI may prepare the environment and record
observations but may not impersonate the human participant.

Recommended environments:

- Windows reference environment;
- clean macOS environment.

Recommended path:

```text
clone repository
-> follow README from the top
-> run the three-minute demo
-> initialize a Standard project with handoff scaffolding
-> run the Handoff gate and readiness assessment
```

Capture:

- time to first command;
- time to first meaningful failure;
- every missing, incorrect, or assumed instruction;
- documents opened to recover from confusion;
- whether the participant can explain Axiom-PMO's value afterward.

Every confirmed documentation problem must either be fixed or remain in an
open issue with an owner. Do not close M1 while a blocking walkthrough finding
is unresolved.

### Optional recording

After walkthrough findings are fixed, record the deterministic demo using:

```powershell
pwsh -NoProfile -File scripts/demo.ps1 -Plain -NoPause
```

Produce:

- an asciinema-compatible `.cast` as the reproducible source recording;
- a GIF generated from that recording for README display.

Store both under:

```text
docs/assets/demo/
```

Link the GIF near the README quick-start/demo section and link the `.cast` as
the source recording. Add a local check that fails if README references a
missing recording asset.

### Optional evidence completeness

If the deferred evidence is picked up later, treat the evidence package as
complete only when:

- the human walkthrough evidence identifies participant role and platforms;
- results and timings are recorded without fabrication;
- confirmed documentation findings are resolved or tracked;
- the `.cast` and GIF exist and open correctly;
- the README links resolve;
- required CI checks pass;
- a human records the acceptance decision that relies on this optional
  evidence.

## Workstream 3 — Milestone 3.5 Runtime Portability

### Objective

Make PowerShell 7 the primary portable runtime without dropping compatibility
with Windows PowerShell 5.1. Do not rewrite the validator in another language.

### Host resolution contract

Preserve the existing host-resolution behavior:

1. `AXIOM_PWSH` explicit override;
2. current host executable where available;
3. `pwsh`;
4. `powershell`;
5. `powershell.exe`.

The CLI and PowerShell child-process helper must continue to agree on this
contract. Missing PowerShell remains exit code `127`.

### Required support matrix

| Environment | Target CI policy |
|---|---|
| Windows + PowerShell 7 | Required |
| Ubuntu + PowerShell 7 | Required |
| Windows PowerShell 5.1 | Required compatibility regression |
| macOS + PowerShell 7 | Non-blocking smoke test until promotion evidence exists |

### CI changes

1. Keep the Windows PowerShell 5.1 full-suite job.
2. Add a required Windows PowerShell 7 full-suite job.
3. Promote the Ubuntu PowerShell 7 full-suite job by renaming it to
   `pmo-checks-linux-pwsh7`, removing `continue-on-error`, and keeping the same
   full-suite contract as the Windows required jobs.
4. Add a non-blocking macOS PowerShell 7 smoke/full-suite job, depending on
   available runner time.
5. Pin third-party Actions to reviewed commit SHAs.
6. Ensure fault injection, public hygiene, golden verification, CLI tests, and
   end-to-end checks are not accidentally omitted from required platforms.

### Compatibility verification

Compare across supported hosts:

- diagnostic schema and field values;
- diagnostic ordering;
- summary counts and exit codes;
- Source Snapshot and review-input digests;
- golden-master results;
- line-ending behavior;
- JSON encoding and null handling;
- CLI host detection and `AXIOM_PWSH` override behavior.

Host-specific formatting must be normalized only at the comparison boundary.
Do not weaken validator behavior to make platforms agree.

### Documentation changes

Update the README, tutorials, bug-report template, Makefile comments, wrapper
comments, and validation-engine documentation so that:

- PowerShell 7 is the recommended portable runtime;
- Windows PowerShell 5.1 is supported compatibility, not the only primary
  experience;
- experimental wording matches the actual required/non-blocking CI matrix;
- commands use `pwsh` where portability is intended.

### M3.5 exit criteria

- Windows PowerShell 7 and Ubuntu PowerShell 7 full-suite jobs are required and
  green.
- Windows PowerShell 5.1 regression coverage remains green.
- macOS results are recorded honestly as smoke/non-blocking until promoted.
- Cross-host output and exit-code contracts match.
- Required documentation describes the real support matrix.
- Ubuntu PowerShell 7 has passed two consecutive full CI runs on `main` after
  `continue-on-error` was removed.
- Human acceptance is recorded.

## Workstream 4 — Milestone 4 GitHub Action Planning

Open one tracking issue:

```text
[roadmap]: Milestone 4 — GitHub Action
```

Do not assign an owner unless a human has named one. Record that M3.5 is
accepted and that M1 walkthrough/recording evidence was deferred by human
decision before implementation.

Create these child issues and link them from the parent checklist.

### M4-1 — Reusable Action and interface

Title:

```text
[M4-1] Package Axiom-PMO as a reusable GitHub Action
```

Required inputs:

- `project` — required;
- `mode` — default `Standard`;
- `gate` — default `Release`;
- `fail-on-warning` — default `true`.

Required outputs:

- `exit-code`;
- `outcome`;
- `json-report`;
- `markdown-report`.

The Action must call the existing CLI/PowerShell validator. It must contain no
duplicate validation rules.

### M4-2 — Job Summary and reports

Title:

```text
[M4-2] Render diagnostics as Job Summary and report artifacts
```

Required behavior:

- create `axiom-report.json`;
- create `axiom-report.md`;
- write a concise GitHub Job Summary;
- include Handoff stage verdicts when the Handoff envelope is available;
- retain the validator exit code;
- upload reports even when validation fails, then return the original result.

### M4-3 — Safe PR annotations

Title:

```text
[M4-3] Emit safe PR annotations from structured diagnostics
```

Mapping:

- `FAIL` becomes an error annotation;
- `WARN` becomes a warning annotation;
- `PASS` and `INFO` do not create annotations.

Use `artifact`, `item_id`, `field`, and `rule_id` when present. If no safe file
location exists, create an annotation without a file target. Escape workflow
command control characters.

Never copy requirement prose, source contents, PII, approval evidence, customer
data, credentials, or confidential material into annotations or summaries.

### M4-4 — Consumer, failure-path, and privacy tests

Title:

```text
[M4-4] Add GitHub Action consumer, failure-path, and privacy tests
```

Required cases:

- passing Release gate;
- failing Release gate;
- blocking warning with `fail-on-warning`;
- mixed Handoff stage verdicts;
- missing PowerShell exit `127`;
- malformed JSON;
- report creation/upload on validator failure;
- null diagnostic location;
- path outside the repository;
- workflow-command escaping;
- source-sensitive content exclusion;
- Windows and Ubuntu required runner coverage.

A consumer repository must be able to add the Action in no more than ten
workflow lines.

### M4-5 — Documentation and acceptance

Title:

```text
[M4-5] Document and accept Milestone 4
```

Required outputs:

- installation and usage example;
- input/output reference;
- required permissions;
- privacy and log-safety statement;
- troubleshooting and exit-code guide;
- consumer test evidence;
- release/acceptance record.

The parent M4 issue may close only when all child issues close, required CI is
green, no P0 defect is open, documentation is verified, and a human accepts the
milestone.

Use existing repository labels only. Recommended existing labels should be
verified before use; do not invent label names.

## Workstream 5 — Milestone 5 Sequencing

Keep `integrations/superpowers/` explicitly experimental and not wired into the
runtime.

Do not open M5 implementation issues and do not begin implementation until M4
has passed human acceptance.

After M4 closes, split M5 into:

- execution-contract export;
- execution-result import and schema validation;
- work-item and requirement matching;
- allowed-path checks;
- required-test and evidence checks;
- scope-deviation checks;
- contract-to-result git-authority checks;
- agent self-approval blocking;
- integration end-to-end tests;
- documentation and acceptance evidence.

Do not claim Level 3 or Level 4 interoperability until an actual runtime
consumer and integration tests exist.

## Validation Plan

Before presenting local changes as ready:

1. Confirm version consistency across `VERSION`, README, and
   `pmo-config/*.json`.
2. Search current documents for stale `HANDOFF-012` range references.
3. Confirm M7/M8 and their backlog/success-signal entries are removed from the
   active roadmap.
4. Run:
   - `scripts/pmo-doctor.ps1`;
   - fixture matrix and golden verification;
   - config-mutation tests;
   - diagnostics-contract tests;
   - line-ending tests;
   - handoff-assessment tests;
   - CLI tests;
   - generator-to-gate E2E tests;
   - demo smoke test;
   - public-hygiene check.
5. Compare required results on Windows PowerShell 5.1, Windows PowerShell 7,
   and Ubuntu PowerShell 7.
6. Record macOS results without promoting the platform unless its acceptance
   criteria are satisfied.
7. Verify Markdown links and recording assets.

If the local environment lacks PowerShell, report the check as not run and use
identified CI evidence. Do not describe a missing local runtime as a product
test failure or as a passing result.

## Authority and Safety

- Do not edit user-owned `source/`, `MOM/`, `REQ/`, `Transcript/`, or `Others/`
  content.
- Do not fabricate test, walkthrough, recording, approval, or CI evidence.
- Do not weaken validation or privacy controls to make a check pass.
- AI findings and readiness scores are candidate evidence, not approvals.
- Do not commit without explicit user instruction.
- Do not push, merge, deploy, close a human approval gate, or approve a
  milestone without human confirmation.

## Execution Order

```text
1. Align roadmap and documentation
2. Promote Ubuntu PowerShell 7 from experimental to blocking workflow job
3. Record the two consecutive green main CI runs after Ubuntu promotion
4. Record branch protection as deferred for M3.5 acceptance
5. Record Issue #8 as optional deferred trust evidence
6. Start M4 planning after the deferred-evidence decision is recorded
7. Keep M4 acceptance human-gated
8. Open and implement M5 only after M4 human acceptance
9. Continue to M6 only when separately approved
```

The executor must stop at any human approval, walkthrough, release, push, or
milestone-acceptance boundary and request the required human action.
