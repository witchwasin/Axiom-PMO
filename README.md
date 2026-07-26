<!-- markdownlint-disable MD033 MD041 -->
<div align="center">

# Axiom-PMO

### The Anti-Hallucination Framework for AI Agents

A deterministic governance layer that keeps AI coding agents inside **verified
requirements, approved scope, traceable evidence, and human-controlled release
gates.**

[![Axiom-PMO Checks](https://github.com/witchwasin/Axiom-PMO/actions/workflows/pmo-checks.yml/badge.svg)](https://github.com/witchwasin/Axiom-PMO/actions/workflows/pmo-checks.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](CHANGELOG.md)

<sub>Version <code>1.1.0</code> · MIT License · Windows PowerShell reference implementation (Linux/macOS via <code>pwsh</code>, experimental)</sub>

</div>

---

> **AI agents can write code. They should not invent the project.**

## See it in three minutes

```bash
node cli/axiom.mjs demo          # or: make demo
```

Two synthetic projects. Both have requirements traced to source, an approved
design, and a work-item board. Both pass every gate Axiom-PMO 1.0 could run.
One of them cannot be built on Monday morning — its shared schema is scheduled
after the items that consume it, its camera feature has no serving model, and a
data element it marked sensitive has no classification decision.

The demo shows the failures, shows them fixed, and then shows the part people
miss: the fixed project passes every deterministic check and *still* reports
`READY TO BUILD, NOT READY TO DEMO`. See [`demo/`](demo).

AI coding frameworks help agents build faster. Axiom-PMO exists to make sure
they build the *right* thing — from requirements that trace back to real source
material, within a scope a human approved, with evidence for every claim, and
with releases that no agent can authorize on its own.

Axiom-PMO is **not** an execution framework and does not try to replace one. It
is the **governance control plane** those frameworks can operate inside.

---

## The problem

Left unconstrained, an AI agent doing project or delivery work tends to:

- **invent** requirements, acceptance criteria, actors, or approvals that were
  never actually given;
- **silently expand scope** — adding "helpful" features nobody asked for;
- **claim evidence** ("tests pass", "QA approved") that it generated itself and
  that no one verified;
- **lose traceability** between what a stakeholder asked for and what was built
  and tested; and
- **cross authority boundaries** — committing, pushing, or "releasing" without a
  human ever saying yes.

A prompt that politely asks the agent not to do these things is not a control.
Axiom-PMO turns each of them into a **machine-verifiable contract** enforced by a
validator that exits non-zero when the contract is broken — the same way a
linter fails a pull request.

> See [`case-studies/unauthorized-git-mutation.md`](case-studies/unauthorized-git-mutation.md)
> — *"The Agent That Shipped Without Permission"* — for the incident that shaped
> these controls. The code may have been fine. The authorization was part of the
> specification, and it was missing.

## What Axiom-PMO does

Every important claim — a requirement, a design decision, a test result, an
approval — must carry a **source reference** and an **evidence status**
(`verified`, `supported`, `inferred`, `missing`, or `conflict`). Those claims
are then run through a **deterministic PowerShell validator** that fails the gate
if something is missing, placeholder text, unresolvable, or unapproved. Nothing
is enforced by asking the agent nicely.

- **Source-of-truth protection** — `source/` inputs are user-owned; the agent
  never edits, creates, or deletes them.
- **Requirement traceability** — source → requirement → design → delivery →
  test → evidence → release, checked row by row (full chain in Strict mode via
  `RTM.json`).
- **Risk-adaptive modes** — Lite / Standard / Strict decide *how much* process
  is required for a given piece of work.
- **Human authority boundaries** — the agent may recommend the next gate but may
  not approve its own work, and may not commit, push, tag, deploy, or approve a
  release by itself.

## Architecture: control plane + execution plane

Axiom-PMO governs *what and why*; an execution framework handles *how*. Output
from the execution framework is **candidate evidence**, not automatically trusted
truth — Axiom-PMO validates it before it becomes release-ready.

```mermaid
flowchart TD
    H["Human / PM / Product Owner"] --> A
    subgraph A["Axiom-PMO — Governance & Control Plane"]
        A1["Source-of-truth protection"]
        A2["Requirement traceability"]
        A3["Lite / Standard / Strict modes"]
        A4["Scope & design approval"]
        A5["Evidence requirements"]
        A6["QA / security / release gates"]
        A7["Human authority boundaries"]
    end
    A -->|"Approved execution contract"| E
    subgraph E["AI Execution Framework"]
        E1["Superpowers / BMAD / spec-kit /<br/>OpenSpec / custom Claude Code"]
        E2["Planning · TDD · Implementation<br/>Code review · Verification"]
    end
    E -->|"Candidate result + evidence"| V
    subgraph V["Axiom-PMO Validation"]
        V1["Scope compliance"]
        V2["Evidence verification"]
        V3["Traceability update"]
        V4["QA / security review"]
        V5["Human release approval"]
    end
    V -->|"Release readiness"| H
```

**Responsibility split**

| Axiom-PMO owns | An execution framework owns |
|---|---|
| Source, requirements, scope, risk | Implementation planning |
| Approvals and evidence policy | TDD and coding |
| Release authority | Code review and engineering verification |

The execution framework **may not** change approved scope, alter acceptance
criteria without a change request, downgrade risk mode, mark QA/security/release
approved, or deploy without human permission.

## Works alongside your AI framework

Axiom-PMO is framework-agnostic. It defines *what may be built and when it is
safe to release*; your execution framework defines *how it gets built*.

| Capability | Axiom-PMO | Execution frameworks (Superpowers / BMAD / spec-kit / OpenSpec) |
|---|---|---|
| Requirement & scope governance | Primary | Limited / partial |
| Human approval gates | Strong | Limited / partial |
| Source-ownership boundary | Strong | Not primary |
| Machine-tested process rules | Strong | Engineering / workflow / spec-focused |
| Release evidence governance | Strong | Verification-focused |
| Planning · TDD · implementation | Delegated | Strong |
| Governance control plane | Primary | Not primary |

> Axiom-PMO does not attempt to replace these frameworks. It provides the
> governance layer they can operate inside. Individual elements here have prior
> art; the differentiation is combining risk-adaptive PM governance, source
> protection, human authority boundaries, full-chain traceability, and
> deterministic validation into one lightweight control plane for small
> AI-assisted teams.

See [`docs/integrations/overview.md`](docs/integrations/overview.md) for the
Level 0–4 interoperability model and authority-precedence order.

## The three modes

Every project — and every individual work item inside it — declares a mode. The
mode decides how much process is *required*, not how much is *allowed*.

| Mode | Use for | What's required |
|---|---|---|
| **Lite** | Small, low-risk fixes and clarifications | `PROJECT.md`, one delivery item, acceptance criteria, a test note. |
| **Standard** | Normal feature delivery | Above, plus a design artifact when there's a flow/UI, `DELIVERY.md` or GitHub Issues, a real test checklist, QA sign-off at release. |
| **Strict** | Payment, PII, auth, permissions, external integrations, compliance, production data migration, or any other trigger in [`AGENTS.md`](AGENTS.md) | Everything Standard requires, plus full source references on every claim, a RAID log, a decision log, a requirement-to-release traceability matrix (`RTM.json`), and QA **and** security sign-off. |

A project can never be silently downgraded: if a work item carries a Strict
trigger, the validator forces the whole project's effective mode to Strict even
if you pass `-Mode Lite` on the command line.

## Quick start

Requires PowerShell (Windows PowerShell 5.1 or PowerShell 7 / `pwsh`). The CLI
additionally needs Node.js; everything it does is also available by calling the
scripts directly.

```bash
# See the framework catch something real
node cli/axiom.mjs demo

# Start a project, with handoff scaffolding
node cli/axiom.mjs init --code P02-MYPROJECT --mode Standard --handoff --target demo

# Put real source under source/MOM, source/REQ, source/Transcript
# (user-owned; the agent never edits these), then fill PROJECT.md.
# Every requirement needs a source_ref and an evidence_status.

# Ask whether a developer can start
node cli/axiom.mjs handoff --project projects/P02-MYPROJECT --mode Standard

# Validate at any gate
node cli/axiom.mjs validate --project projects/P02-MYPROJECT --gate Release --fail-on-warning
```

Without Node, the same things through PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/new-project.ps1 -ProjectCode P02-MYPROJECT -Mode Standard -IncludeHandoff -Target demo
powershell -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath projects/P02-MYPROJECT -Mode Standard -Gate Handoff
powershell -ExecutionPolicy Bypass -File scripts/assess-handoff.ps1 -ProjectPath projects/P02-MYPROJECT -Mode Standard
powershell -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath projects/P02-MYPROJECT -Mode Standard -Gate Release -FailOnWarning
```

### The gates

```text
Draft → Scope → Design → Handoff → Build/QA → Release
```

| Gate | Asks |
|---|---|
| `Draft` | Does the project exist in a usable shape? |
| `Scope` | Is every requirement sourced and approved? |
| `Design` | Is the design ready and approved? |
| `Handoff` | **Can a developer start, integrate, and demonstrate this?** |
| `Release` | Is it tested, reviewed, approved, and reversible? |

`Handoff` is new in 1.1 and introduces no new human approval — it reuses the
existing `Design Ready` sign-off and checks whether the contract is complete
enough to act on. See [handoff readiness](docs/concepts/handoff-readiness.md).

Or start from a worked example: [`examples/LITE-BUGFIX`](examples/LITE-BUGFIX),
[`examples/STANDARD-FEATURE`](examples/STANDARD-FEATURE),
[`examples/STRICT-HIGH-RISK`](examples/STRICT-HIGH-RISK),
[`examples/HANDOFF-DEMO`](examples/HANDOFF-DEMO) (a demo handoff), or the fuller
[`examples/P01-DEMO`](examples/P01-DEMO).

On Linux/macOS or with `make` installed, the same checks are available through
convenience wrappers (experimental — they call the PowerShell reference
implementation via `pwsh`):

```bash
make check      # doctor + validation + mutation + e2e
./scripts/check.sh   # equivalent wrapper
```

## Validate the framework itself

Beyond validating individual *projects*, Axiom-PMO validates *itself* — proving
its scripts, configs, and skills are internally consistent:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pmo-doctor.ps1            # framework health
powershell -ExecutionPolicy Bypass -File scripts/run-validation-tests.ps1  # positive/negative fixture matrix + golden master
powershell -ExecutionPolicy Bypass -File scripts/run-all-checks.ps1        # everything + config-mutation + end-to-end
```

The test suite includes a positive/negative fixture matrix, golden masters,
config-mutation tests (which prove the JSON policy files are load-bearing, not
decorative), a structured-diagnostics contract test, a demo smoke test, CLI
exit-code tests, and generator-to-release end-to-end flows including the Handoff
gate. See [`TESTING.md`](TESTING.md).

## Repository layout

```
AGENTS.md, CLAUDE.md, CONTEXT-ROUTER.md   Agent behavior rules and routing (read first if you're an agent)
TESTING.md, SECURITY.md, MIGRATION.md     Test tooling, security rules, legacy-layout migration
templates/                                Blank PROJECT.md / DELIVERY.md / HANDOFF.md / BUILD-SPEC.md / RELEASE.md / RTM.json / etc.
examples/                                 Worked example projects (Lite, Standard, Strict, handoff, and a demo)
demo/                                     The three-minute proof: a broken handoff and a fixed one
cli/                                      Thin Node wrapper over the PowerShell scripts (no validation logic)
scripts/                                  The validator, framework doctor, and project generator
  scripts/lib/                              The validator's modules (config, parsing, per-rule checks, output)
pmo-config/                               Runtime policy as JSON — the source of truth the scripts read
.claude/skills/                           The 7 active AI skills (one per workflow stage)
docs/                                     Concepts, architecture, governance, integrations, tutorials, per-mode guides
integrations/                             Experimental execution-contract schemas (framework interop)
case-studies/                             Governance lessons (e.g. the unauthorized-git-mutation incident)
tests/                                    Fixture matrix + golden masters + config-mutation + end-to-end tests
reports/                                  Public release baseline and sanitized project-history archive
```

A project built with this template looks like:

```
PROJECT.md          Scope, requirements, approvals — the "what" and "why"
source/             Client-owned inputs (MOM, REQ, Transcript, Others) — never edited by the AI
DESIGN/             Flow diagrams, wireframes (Standard/Strict, when there's a UI or flow)
DELIVERY.md         Work items — the "who's building what", unless GitHub Issues is the declared source
DESIGN/BUILD-SPEC.md  Technical specification — stack, data model, concurrency, acceptance cases (Handoff)
HANDOFF.md          Developer entry point — build order, owners, constraints, blocking points (Handoff)
HANDOFF-REVIEW.json Semantic review findings — candidate evidence, never an approval (Handoff)
RELEASE.md          Release scope, test summary, QA/security review, rollback plan, release approval
RAID-log.md         Risks/assumptions/issues/dependencies (Strict, or when meaningful)
decision-log.md     Logged decisions (Strict, or when meaningful)
RTM.json            Requirement → design → delivery → test → evidence → release traceability (Strict)
```

## The AI skill system

An agent loads only the skill relevant to the task at hand — never all of them —
to keep context small and focused. `CLAUDE.md` routes user intent to the right
skill and mode.

| Skill | Stage |
|---|---|
| `pmo-intake` | Turning source material into scoped, referenced requirements |
| `pmo-design` | Flow, UX, wireframes, design-ready acceptance criteria |
| `pmo-delivery` | Delivery planning, handoff, task-source-of-truth, sequencing |
| `pmo-build-review` | Build completion evidence, code-review readiness |
| `pmo-quality-release` | QA evidence, release readiness, rollback review |
| `pmo-governance` | RAID, decisions, traceability, risk, Strict-mode guardrails |
| `pmo-git-safety` | Branch/diff/sensitive-file checks before commit, push, or tag |

## Human authority model

- The AI never invents requirements, actors, dates, or approvals.
- Every important claim is tagged `Confirmed`, `Assumption`, or `Open Question`,
  and carries a `source_ref` and an `evidence_status`.
- `source/`, `MOM/`, `REQ/`, `Transcript/`, `Others/` are user-owned — never
  edited, created, or deleted by the AI.
- The AI never commits, pushes, tags, deploys, or approves a production release
  or business scope by itself. Those require explicit human confirmation every
  time — not a standing permission.

Full rules: [`AGENTS.md`](AGENTS.md). Security specifics: [`SECURITY.md`](SECURITY.md).

## Security

Sensitive source (PII, financial data, customer-confidential data) stays local
and triggers Strict mode. The framework does a sensitive-file pre-check, not a
full secret scan. Report vulnerabilities per [`SECURITY.md`](SECURITY.md).

## Contributing

Contributions are welcome — especially validation rules, fixtures, and
interoperability docs. The one hard rule: **do not weaken governance to make
tests pass.** See [`CONTRIBUTING.md`](CONTRIBUTING.md) and
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md). AI-assisted contributions are welcome
but must be disclosed and human-reviewed.

## Documentation

| | |
|---|---|
| **Concepts** | [handoff readiness](docs/concepts/handoff-readiness.md) · [anti-hallucination](docs/concepts/anti-hallucination.md) · [evidence-based execution](docs/concepts/evidence-based-execution.md) · [risk modes](docs/concepts/risk-modes.md) · [human authority](docs/concepts/human-authority.md) |
| **Guides** | [artifact map](docs/guides/artifact-map.md) · [three-day demo handoff](docs/guides/three-day-demo-handoff.md) |
| **Reference** | [diagnostics contract](docs/reference/diagnostics-contract.md) · [rule reference](docs/rules/) |
| **Architecture** | [control plane](docs/architecture/control-plane.md) · [validation engine](docs/architecture/validation-engine.md) |
| **Governance** | [release readiness](docs/governance/release-readiness.md) · [source ownership](docs/governance/source-ownership.md) |
| **Process** | [Lite](docs/process/lite.md) · [Standard](docs/process/standard.md) · [Strict](docs/process/strict.md) |
| **Tutorials** | [your first project](docs/tutorials/first-project.md) · [using it with an AI agent](docs/tutorials/using-with-an-ai-agent.md) |
| **Integrations** | [overview](docs/integrations/overview.md) · [Superpowers](docs/integrations/superpowers.md) · [BMAD](docs/integrations/bmad.md) · [spec-kit](docs/integrations/spec-kit.md) · [OpenSpec](docs/integrations/openspec.md) |
| **Releases** | [1.1.0](docs/releases/v1.1.0.md) · [1.0.0](docs/releases/v1.0.0.md) · [changelog](CHANGELOG.md) |

If you are an AI agent working in this repository, start with
[`AGENTS.md`](AGENTS.md), [`CLAUDE.md`](CLAUDE.md), and
[`CONTEXT-ROUTER.md`](CONTEXT-ROUTER.md).

## Roadmap

The productization roadmap is tracked in [`ROADMAP.md`](ROADMAP.md). It is the
current roadmap of record for turning Axiom-PMO from a governance framework into
a developer workflow tool for AI-assisted software delivery.

Delivered in 1.1:

- a three-minute demo that shows a real failure and its fix;
- structured developer diagnostics with a versioned, additive JSON contract;
- engineering handoff readiness (Milestone 2.5);
- a thin local CLI — deliberately before any public npm package.

Next:

- a GitHub Action that reports governance failures directly in pull requests;
- one complete Superpowers bridge before broader ecosystem expansion.

The roadmap is intended to be reviewed weekly. Suitable community issues,
integration requests, and developer feedback may be accepted into the roadmap
when they strengthen the product direction without weakening governance.

## License

[MIT](LICENSE) © 2026 WITCHWASIN K.

## Project status

Version `1.1.0` — *Handoff-Ready*. The validation engine, governance model, and
diagnostic contract are stable. 1.1 adds the `Handoff` gate between `Design` and
`Release`, so the framework can say — with evidence — whether documentation is
sufficient for a developer to start, integrate, and demonstrate. Interoperability
automation remains on the [roadmap](ROADMAP.md).

Upgrading from 1.0 requires no migration: projects that do not request the new
gate validate exactly as before. Migrating from the previous private layout? See
[`docs/migration/from-pmo-template-personal.md`](docs/migration/from-pmo-template-personal.md).
