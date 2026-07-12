# PMO Template Personal

**Current version:** `0.5.0` · see [`CHANGELOG.md`](CHANGELOG.md) for release history.

## What this repo actually is

This is **not a software project**. It doesn't ship an app, a service, or a
library you `import`. It's an **operating template** — a set of documents,
folder conventions, config files, and PowerShell validation scripts — that
tells an AI coding agent (Claude, Codex, Cursor, Copilot, or similar) *how to
run project management for a small team*, and then **mechanically checks**
that the AI actually followed the rules instead of trusting its self-report.

Think of it as: "a PMO's SOP binder, written so an AI can follow it, with a
linter that catches the AI when it skips steps."

### The problem this solves

Left alone, an AI agent doing PM work tends to:
- invent requirements, acceptance criteria, or approvals that were never
  actually given,
- skip traceability between "what the client asked for" and "what got
  built and tested,"
- produce inconsistent documents from project to project,
- or claim a release is "ready" without real evidence.

This repo constrains that by making every important claim
(a requirement, a design decision, a test result, an approval) carry a
**source reference** and an **evidence status**, and by running those claims
through a **validator script** that fails the build if something is missing,
placeholder text, or unresolvable — the same way a linter fails a pull
request. Nothing here is enforced by asking the AI nicely; it's enforced by
`scripts/validate-project.ps1` exiting non-zero.

### Who it's for

Small teams (roughly ≤10 people) who want AI-assisted project delivery —
from a meeting transcript, through requirements and design, to a release —
without either (a) zero structure and made-up documentation, or (b)
enterprise-PMO paperwork that's too heavy for a 3-person team. The whole
template is built around choosing the **lightest process that still
controls the actual risk** of a given piece of work.

## The workflow

Every project this template manages follows the same pipeline:

```
Source → Requirement → Design → Delivery → Build Review → QA → Release
```

- **Source**: meeting notes, transcripts, requirement docs the client/team
  actually gave you (lives in `source/`, never edited or invented by the AI).
- **Requirement**: atomic, testable statements extracted from source, each
  tagged with where it came from and how solid the evidence is.
- **Design**: flow/UX/wireframe artifacts, only produced when the work
  actually needs them.
- **Delivery**: work items with owners, acceptance criteria, and a declared
  task source of truth (this repo's `DELIVERY.md` or GitHub Issues — never
  both at once).
- **Build Review / QA**: evidence that the work was actually reviewed and
  tested, in a real table the validator parses row by row — not a checkbox
  that says "done."
- **Release**: nothing ships without recorded approval, a real rollback
  plan (or an explicit, policy-allowed waiver), and — for regulated or
  high-risk work — full requirement-to-release traceability.

## The three modes

Every project (and every individual work item inside a project) declares a
mode. The mode decides how much process is *required*, not how much is
*allowed* — you can always do more.

| Mode | Use for | What's required |
|---|---|---|
| **Lite** | Small, low-risk fixes and clarifications | `PROJECT.md`, one delivery item, acceptance criteria, a test note. Nothing else unless the work needs it. |
| **Standard** | Normal feature delivery | `PROJECT.md`, a design artifact if there's a flow/UI, `DELIVERY.md` or GitHub Issue, a real test checklist, QA sign-off at release. |
| **Strict** | Payment, PII, auth, permissions, external integrations, compliance, production data migration, or anything else on the trigger list in `AGENTS.md` | Everything Standard requires, plus full source references on every claim, a RAID log, a decision log, a requirement-to-release traceability matrix (`RTM.json`), and QA **and** security sign-off. |

A project can never be silently downgraded — if a work item is tagged with
a Strict trigger, the validator forces the whole project's effective mode
to Strict even if you pass `-Mode Lite` on the command line.

## Repo layout — what's where and why

```
AGENTS.md, CLAUDE.md, CONTEXT-ROUTER.md   AI behavior rules and routing (read these first if you're an agent)
TESTING.md, SECURITY.md, MIGRATION.md     how to run the test suite, security rules, moving from a legacy layout
templates/                                blank PROJECT.md / DELIVERY.md / RELEASE.md / etc. for a brand-new project
examples/                                 4 fully worked example projects (Lite, Standard, Strict, and a demo)
scripts/                                  the validator, the framework "doctor," the project generator
  scripts/lib/                              the validator's 11 modules (config, parsing, per-rule checks, output)
pmo-config/                                runtime policy as JSON: enums, artifact requirements per mode/gate,
                                            reference-type regexes, the active skill list — this is the actual
                                            source of truth the scripts read, not a hardcoded fallback
.claude/skills/                            the 7 active AI skills (one per workflow stage — see below)
.claude-archive/                           43 older/experimental skills, kept for reference, not loaded by default
tests/                                     79 fixture cases + golden-master snapshots + generator-to-release
                                            end-to-end tests + config-mutation tests that prove the config
                                            files are real, not decorative
docs/                                      per-mode process guides and legacy UML diagrams
reports/                                   the audit trail of this template's own quality work — baseline
                                            scores, remediation plans, and what was found and fixed each round
```

A **project** built with this template (e.g. `projects/P01-ABC/`, or one of
the `examples/`) looks like:

```
PROJECT.md          scope, requirements, approvals — the source of truth for "what" and "why"
source/              client-owned inputs (MOM, REQ, Transcript, Others) — never edited by the AI
DESIGN/              flow diagrams, wireframes (Standard/Strict, when there's a UI or flow)
DELIVERY.md          work items — the source of truth for "who's building what," unless GitHub Issues is used
RELEASE.md           release scope, test summary, QA/security review, rollback plan, release approval
RAID-log.md          risks/assumptions/issues/dependencies (Strict, or when something meaningful exists)
decision-log.md      logged decisions (Strict, or when something meaningful exists)
RTM.json             requirement → design → delivery → test → evidence → release traceability (Strict)
```

## The AI skill system

An AI agent using this template loads only the skill relevant to the task at
hand — never all of them at once, to keep context small and focused:

| Skill | Stage |
|---|---|
| `pmo-intake` | Turning source material into scoped, referenced requirements |
| `pmo-design` | Flow, UX, wireframes, design-ready acceptance criteria |
| `pmo-delivery` | Delivery planning, handoff, task-source-of-truth, sequencing |
| `pmo-build-review` | Build completion evidence, code review readiness |
| `pmo-quality-release` | QA evidence, release readiness, rollback review |
| `pmo-governance` | RAID, decisions, traceability, risk, Strict-mode guardrails |
| `pmo-git-safety` | Branch/diff/sensitive-file checks before commit, push, or tag |

`CLAUDE.md` is the router that maps what a user is asking for to which skill
and which mode to load.

## Getting started

1. Copy `templates/` into a new folder (e.g. `projects/P01-ABC/`), or start
   from the closest example (`examples/LITE-BUGFIX`,
   `examples/STANDARD-FEATURE`, `examples/STRICT-HIGH-RISK`) — or generate a
   fresh skeleton:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts/new-project.ps1 -ProjectCode P02-MYPROJECT -Mode Standard
   ```
2. Put real source material under `source/MOM/`, `source/REQ/`,
   `source/Transcript/`.
3. Fill in `PROJECT.md` from that source — every requirement needs a
   `source_ref` and an `evidence_status`.
4. Choose a mode per work item in `DELIVERY.md`.
5. Validate before every gate:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project-folder> -Mode Standard -Gate Release -FailOnWarning
   ```

## Validating the template itself

Besides validating individual *projects*, the template validates *itself* —
proving its own scripts, configs, and skills are internally consistent:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pmo-doctor.ps1        # framework health (structure, config, skills, permissions)
powershell -ExecutionPolicy Bypass -File scripts/run-validation-tests.ps1  # 79-case positive/negative fixture matrix
powershell -ExecutionPolicy Bypass -File scripts/run-all-checks.ps1    # everything above + config-mutation + end-to-end tests
```

See [`TESTING.md`](TESTING.md) for the full test-tooling breakdown (golden
master, config mutation, generator-to-release E2E).

## AI guardrails (the non-negotiables)

- The AI never invents requirements, actors, dates, or approvals.
- Every important claim is tagged `Confirmed`, `Assumption`, or
  `Open Question`, and every requirement/decision/test/release claim needs a
  `source_ref` and an `evidence_status`.
- `source/`, `MOM/`, `REQ/`, `Transcript/`, `Others/` are user-owned — the AI
  never edits, creates, or deletes files there.
- The AI never commits, pushes, tags, deploys, or approves a production
  release or business scope by itself — those require explicit human
  confirmation every time, not a standing permission.

Full rules: [`AGENTS.md`](AGENTS.md). Security-specific rules:
[`SECURITY.md`](SECURITY.md). Moving from a legacy PM folder structure into
this template: [`MIGRATION.md`](MIGRATION.md).
