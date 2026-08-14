# Master Plan — Axiom-PMO Upstream Orchestration, Design Provider, Research, Testability, and Controlled Change

> Status: Proposed implementation plan — ready for Human Owner approval and execution
>
> Prepared: 2026-08-14
>
> Repository: `witchwasin/Axiom-PMO`
>
> Verified baseline: `main` at `2dfcf7b` (`v2.0.0`)
>
> Working target: next-version candidate; exact version is deliberately TBD. `ROADMAP.md` already uses the v2.1 candidate label for separate deferred items, so this plan must not silently absorb or authorize those items. A version decision is part of finalization only after this plan is explicitly approved and implemented. A tag, GitHub Release, marketplace publication, deployment, or push is never implied by this document.

---

## 0. How to use this plan

This document is an execution contract for an implementation agent. It is deliberately self-contained so an agent unfamiliar with Axiom-PMO can understand the product boundary, the existing architecture, the proposed changes, and the order in which they must be implemented.

When the Human Owner hands this plan to an implementation agent with an instruction to execute it autonomously:

- the agent may inspect and edit the repository, create the in-scope artifacts, update tests, and run local validation;
- the agent should proceed milestone by milestone without waiting for review after every file or commit;
- the agent must stop only for a genuine blocker that cannot be resolved from this plan or repository evidence;
- "auto by pass/end to end" means implementation autonomy across the milestones; it never means bypassing Axiom-PMO's Human Scope, Design, risk, externalization, or Release authority boundaries;
- the agent must preserve unrelated working-tree changes and must not use destructive Git operations;
- this document alone authorizes no Git mutation; if the Human Owner's execution message explicitly says to execute this plan "auto by pass/end to end", the agent may create a dedicated local branch and local checkpoint commits as reversible implementation work, but push, tag, publish, deploy, GitHub Release, or external-repository mutation still requires separate explicit authorization;
- the agent must never represent its own semantic review as Human approval;
- the agent must not touch AxiomGuard. The L4 decision recorded by `DEC-024` remains closed and outside this plan.

This plan distinguishes three states:

| State | Meaning |
|---|---|
| **Current** | Implemented and verified on the v2.0.0 baseline |
| **In scope** | Authorized for design and implementation after plan approval |
| **Deferred** | Explicitly excluded from this implementation, even if architecturally related |

---

## 1. Product context

### 1.1 What Axiom-PMO is

Axiom-PMO is a repo-native governance control plane for AI-assisted software delivery. It converts Human-owned source material into governed requirements, approved scope, buildable technical contracts, traceable work items, test expectations, candidate evidence, and Human-controlled release decisions.

It governs four questions:

1. **What** may be built?
2. **Why** is it in scope?
3. **What evidence** is required before a claim is trusted?
4. **Who has authority** to approve or change the work?

### 1.2 What Axiom-PMO is not

Axiom-PMO is not:

- a coding agent;
- a UI design application;
- a research engine;
- a Jira, Azure DevOps, Linear, or portfolio-management replacement;
- an enterprise IAM/RBAC platform;
- an automated business, design, security, or release approver;
- a system that can prove semantic correctness, usability, market demand, or the absence of hallucination.

### 1.3 Core assurance model

```text
Human supplies source and authority
                │
                ▼
Axiom-PMO defines governed contracts
                │
                ▼
AI / Developer / External Provider creates candidate output
                │
                ▼
Deterministic checks verify structure, references, digests and Git facts
                │
                ▼
AI semantic review may raise candidate findings
                │
                ▼
Human makes decisions at authority boundaries
```

The framework reduces and constrains hallucination risk. It never claims to eliminate it.

---

## 2. Verified current baseline

At baseline commit `2dfcf7b`, the repository contains approximately 1,658 files, including approximately 1,305 files under `tests/`. This matters: every new rule can multiply fixtures, golden output, configuration mutation cases, documentation, and cross-platform test cost. Repository growth must therefore be treated as a design constraint.

### 2.1 Current core capabilities

- Human-owned `source/**` protection.
- Stable requirement IDs, source references, and evidence statuses.
- Governance modes: Lite, Standard, Strict.
- Execution paths: Development Handoff and Governed AI Execution.
- Gates: Draft, Scope, Design, Handoff, Release.
- Mode escalation from Strict triggers.
- `PROJECT.md`, `DELIVERY.md`, `DESIGN/BUILD-SPEC.md`, `HANDOFF.md`, `RELEASE.md`, `RTM.json`, RAID and decision artifacts.
- Deterministic Scope, Design, Handoff, Release and SCOPE-DIFF validation.
- Semantic Handoff Review as candidate evidence.
- Conditional Visual Direction, Design System, and Visual Proof.
- Execution Contract export, immutable digest, Git-ground-truth result verification, authority-claim binding, and test-evidence provenance.
- Adversarial execution review and the `AREV-007` semantic finding shape contract.
- CLI, GitHub Action, plugin packaging, clean-room tests, fixture matrix, goldens, and cross-host PowerShell support.

### 2.2 Existing architecture that must be reused

The implementation must extend the existing product instead of creating a parallel framework:

| Existing mechanism | Reuse decision |
|---|---|
| `DESIGN/BUILD-SPEC.md` | Becomes the earlier System Design and testability contract; do not create a second system-design package |
| `Acceptance Cases` in BUILD-SPEC | Used for initial and design-completed test cases; do not add a duplicate mandatory `TESTS.md` |
| `HANDOFF.md` and `HANDOFF-REVIEW.json` | Remain the final handoff contract and freshness evidence |
| Visual Proof digests | Reuse digest/freshness patterns; do not invent a second visual approval gate |
| `decision-log.md` | Remains Human decision evidence; new structured registries reference it |
| `SCOPE.json` and SCOPE-DIFF | Remain approved implementation-scope truth |
| Execution Contract digest | Re-export on an approved contract-affecting change; never mutate in place |
| Seven active PMO skills | Extend existing skills; do not add a new research, change-control, or Claude Design skill in this round |
| `pmo-config/context-map.json` | Extend routing and context budgets instead of hardcoding read sets in skills |
| `pmo-config/validation-rules.json` | Remains the diagnostic catalog |
| `scripts/validate-project.ps1` | Remains the thin project-validation orchestrator; no validation logic goes into the Node CLI |

---

## 3. Binding design decisions

The implementation agent must treat the following as binding unless repository evidence proves a direct contradiction and the Human Owner resolves it.

### D1 — Research is optional and shift-left

Research runs after preliminary requirements are understood and before final Scope approval. It may propose changes but may never silently rewrite requirements or approve Scope.

### D2 — Research automation is not authority

`auto` means automated planning/execution under a declared provider policy. It does not mean automatic acceptance of research conclusions.

### D3 — No automatic download or execution of Feyman

The provider resolution order is explicit configured path, configured environment path, approved web fallback, then actionable stop. Never search for, clone, install, or execute an arbitrary internet repository because a local Feyman path is missing.

### D4 — System Design precedes UI generation

System Design must establish architecture, data, API, permissions, runtime constraints, errors, and initial acceptance cases before Claude Design or a developer-guided UI path creates detailed screens.

### D5 — No duplicate Dev Handoff Base artifact

“Delivery Context Baseline” is a logical state composed from canonical files and their digests. It is not a copied folder or a second `HANDOFF.md`. Provider input manifests refer to canonical paths and hashes.

### D6 — Claude Design is an external Design Execution Provider

Claude Design is not an Axiom-PMO skill and has no approval authority. Axiom-PMO prepares a governed input manifest; the Human operates Claude Design; outputs return as candidate design evidence.

### D7 — Provider input, output, and review are separated

Claude Design work uses:

```text
DESIGN/CLAUDE-DESIGN/
├── INPUT-MANIFEST.json
├── OUTPUT/
└── REVIEW.json
```

This deliberately normalizes the earlier working name `output_system-design` to `OUTPUT/`: Claude Design produces candidate UI/design output, while `DESIGN/BUILD-SPEC.md` remains the canonical System Design. The separation prevents two folders from appearing to own the same technical contract.

Canonical project files are referenced, not copied. `OUTPUT/` contains provider-created deliverables. `REVIEW.json` records candidate findings, Human review identity, decision references, and freshness.

### D8 — Design preflight and candidate reconciliation precede Human review

The sequence is:

```text
Provider output
  -> deterministic preflight
  -> AI semantic candidate reconciliation
  -> Human design review
  -> revision loop when required
```

The deterministic layer never judges taste or usability. The AI semantic layer never approves Design Ready.

### D9 — UI discoveries may return to System Design

If UI work reveals missing APIs, data, permissions, states, or acceptance rules, the flow returns through controlled impact analysis. Claude Design may not edit the technical contract directly.

### D10 — Test design is risk-adaptive and uses one canonical table

- Lite uses the existing Delivery Test Checklist/Test Note.
- Standard writes Test Strategy and initial scenarios in BUILD-SPEC during Design, then completes Acceptance Cases after UI/design.
- Strict writes detailed requirement-based cases during Design, then adds design/interaction/security coverage before Handoff.

The same BUILD-SPEC Acceptance Cases table is refined; no mandatory second test-case document is created.

### D11 — Change Control is structured but not omniscient

The system requires a structured change registry and Human decision for governed changes. AI proposes impact; the validator checks declared references, decisions, states, and freshness. The MVP does not pretend to infer every dependency automatically.

### D12 — Externalization depends on data classification, not Mode alone

Standard work may contain confidential data and Strict work may use only public data. Externalization requirements depend on declared classification, provider trust, and purpose. Confidential or Restricted inputs require Human review regardless of governance mode.

### D13 — No new approval gate

Research, Externalization, Design Provider, Change Control, and testability checks are sub-checks of existing Scope, Design, Handoff, execution verification, and Release flows. The only Human project approvals remain Scope Approved, Design Ready, and Release Approved.

### D14 — Optional capabilities are silent by default

When Research or Claude Design is not selected, the framework creates no related project files, emits no warning, and adds no requirement.

### D15 — Extend existing skills; do not create an eighth PMO skill

- `pmo-intake`: preliminary requirements, research planning, research impact.
- `pmo-design`: system design, design-provider handoff, preflight and candidate review.
- `pmo-governance`: externalization and change control.
- `pmo-delivery`: final handoff assembly and readiness.
- `pmo-build-review`: implementation deviation detection.
- `pmo-quality-release`: test evidence and release reconciliation.
- `pmo-git-safety`: retain its current Git-safety authority; update only if new local provider commands need explicit safety guidance.

### D16 — README must explain the product before the details

README must present the two axes, actor/automation legend, high-level flow, optional branches, current-versus-proposed status, and quick start in that order. It must remain readable without prior Axiom-PMO knowledge.

---

## 4. Actors, responsibility, and automation

### 4.1 Actor legend

| Code | Actor | Meaning |
|---|---|---|
| `[H-IN]` | Human input | Human supplies source, answers, constraints, or corrections |
| `[AI-A]` | AI-assisted | AI drafts; Human collaborates or confirms content |
| `[AI-R]` | AI-run | AI performs a task automatically; output still needs governed review |
| `[EXT]` | External provider | Feyman, governed web research, Claude Design, execution framework |
| `[SYS]` | Deterministic system | Code checks file shape, references, digest, Git, enum, or policy |
| `[HG]` | Human gate | A named Human makes an authority-bearing decision |

### 4.2 Responsibility model

Each documented workflow step must identify:

- **Executor** — who performs the work;
- **Accountable Human** — who owns the decision or outcome;
- **Human touchpoint** — when a person must participate;
- **Output** — the canonical artifact or state transition.

Do not state that the PM personally performs research, design, coding, or every test. In the target model, automation performs most production work; Humans provide source, resolve ambiguity, accept or reject change, and approve authority gates.

The README uses the compact actor codes; the detailed workflow document must include a responsibility matrix materially equivalent to this one:

| Runtime steps | Work | Executor | Accountable Human | Required Human touchpoint | Canonical output/state |
|---|---|---|---|---|---|
| 01 | Source submission | Stakeholder, PM, or PO | Source owner | Supplies and corrects source | `source/**` |
| 02–03 | Intake and preliminary requirements | AI-run, with AI assistance for refinement | PM or PO | Resolves material ambiguity/conflict | Preliminary `PROJECT.md` |
| 04–05 | Project declarations and optional-track choice | System prompts; Human selects | PM or PO | Declares Mode, execution path, Research, and UI delivery | Project metadata |
| 06 | Externalization assessment | Deterministic system; AI may propose redaction | Data owner or authorized project owner | Reviews when classification/provider policy requires it | `EXTERNALIZATION.json` entry |
| 07–08 | Research and impact proposal | AI-run plus configured external provider | Product Owner | Confirms Guided focus when required; later disposes impacts | `RESEARCH/*` candidate evidence |
| 09–11 | Final Scope | AI-assisted refinement, then system validation | Product Owner or Project Manager | Named Human approves Scope | Approved requirements and `SCOPE.json` |
| 12–14 | System Design, initial testability, and baseline | AI-assisted plus deterministic digesting | Tech Lead or Architect | Resolves technical/security trade-offs; this is not a new approval gate | `DESIGN/BUILD-SPEC.md` and baseline digests |
| 16A | Dev-guided UI path | AI-assisted designer/analyst | Product/Design owner | Reviews only where project policy requires | Existing conditional design artifacts |
| 16B–22 | Claude Design path | System packages; Human operates provider; AI reconciles | Product/Design owner | Answers Claude Design questions and records accept/revise/reject | `DESIGN/CLAUDE-DESIGN/*` plus accepted baseline |
| 23 | Acceptance/Test Case completion | AI-run draft/refinement | QA Lead or Tech Lead | Confirms risk coverage when required by Mode; no separate gate | Canonical BUILD-SPEC Acceptance Cases |
| 24–26 | Final Handoff and readiness | AI-run assembly and review; deterministic validation | Product/Technical owner | Named authorized Human records Design Ready | `HANDOFF.md`, review, current evidence |
| 28A/28B | Implementation | Developer/vendor or governed AI executor | Tech Lead or delivery owner | Intervenes on ambiguity, risk, or deviation | Code/build result and execution evidence |
| 29 | Deviation and Change Control | AI proposes; system validates | Owner appropriate to Scope/technical/risk impact | Human classifies/accepts/rejects governed change | `CHANGE-REQUESTS.json` and rebaselined artifacts |
| 30–32 | Build, test, evidence, and release validation | Deterministic system plus QA/manual evidence providers | Release owner | Supplies manual/UAT/security evidence and accepts residual risk where required | Verified evidence and `RELEASE.md` |
| 33 | Release decision | Named authorized Human | Release authority | Approves or rejects Release | Release Approved decision |

Actual projects must record names and decision references where authority is required. A role label in this matrix is explanatory and is not approval evidence.

---

## 5. Target end-to-end workflow

### 5.1 Full numbered flow

```text
┌─────────────────────────────────────────────────────────────┐
│ 01 [H-IN] Human Source Input                               │
│ Brief / REQ / MOM / Transcript / policy / references      │
│ Executor: Stakeholder or PM                                │
│ Output: immutable Human-owned source/**                    │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 02 [AI-R] Source Analysis and Intake                       │
│ Separate fact / support / inference / missing / conflict   │
│ Accountable Human: PM or PO                                │
│ Output: preliminary PROJECT.md                             │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 03 [AI-A] Preliminary Requirements and Scope               │
│ Problem / users / REQ / initial AC / scope / risks         │
│ Output is preliminary, not Scope Approved                  │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 04 [H-IN + SYS] Project Declarations                       │
│ Execution path + Mode + optional Research + UI path        │
│ Strict triggers may escalate Mode; never silently downgrade│
└───────────────────────────┬─────────────────────────────────┘
                            ▼
                 ┌─────────────────────────┐
                 │ 05 Research selected?   │
                 └────────────┬────────────┘
                         no   │   yes
                    ┌─────────┘    └──────────┐
                    │                         ▼
                    │  ┌──────────────────────────────────────┐
                    │  │ 06 [SYS + HG] Externalization       │
                    │  │ Classification / minimization / scan│
                    │  │ Human review when policy requires   │
                    │  └───────────────────┬──────────────────┘
                    │                      ▼
                    │  ┌──────────────────────────────────────┐
                    │  │ 07 [AI-R + EXT] Research Execution  │
                    │  │ Feyman or approved web provider     │
                    │  │ Output: Research + provenance       │
                    │  └───────────────────┬──────────────────┘
                    │                      ▼
                    │  ┌──────────────────────────────────────┐
                    │  │ 08 [AI-R] Research Impact           │
                    │  │ Map findings to REQ/scope/AC/risk   │
                    │  │ Propose change; never apply silently│
                    │  └───────────────────┬──────────────────┘
                    └──────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 09 [AI-A] Requirements and Scope Refinement                │
│ Preserve stakeholder fact, research support and inference  │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 10 [SYS] Scope Validation                                  │
│ Structure / source refs / evidence / mode / policy         │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 11 [HG] Scope Approved                                     │
│ Executor/Authority: named Product Owner or Project Manager │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 12 [AI-A] System Design in DESIGN/BUILD-SPEC.md             │
│ Architecture / data / API / states / security / runtime    │
│ Do not generate final UI merely because System Design began│
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 13 [AI-R] Initial Testability Design                        │
│ Lite: checklist; Standard: strategy/scenarios; Strict: cases│
│ Output reuses DELIVERY + BUILD-SPEC Acceptance Cases       │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 14 [SYS] Delivery Context Baseline                          │
│ Logical set of canonical paths + digests; no copied package │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
                    ┌────────────────────┐
                    │ 15 UI delivery path│
                    └─────────┬──────────┘
                none/dev      │       claude_design
              ┌───────────────┘             └───────────────┐
              ▼                                             ▼
┌──────────────────────────────┐        ┌──────────────────────────────┐
│ 16A [AI-A] Dev-guided UI    │        │ 16B [SYS + HG] Externalize  │
│ Existing flow/wireframe/     │        │ only minimum design context │
│ direction/system artifacts  │        └──────────────┬───────────────┘
└──────────────┬───────────────┘                       ▼
               │                       ┌──────────────────────────────┐
               │                       │ 17 [AI-R] Input Manifest    │
               │                       │ Paths + digests + purpose   │
               │                       └──────────────┬───────────────┘
               │                                      ▼
               │                       ┌──────────────────────────────┐
               │                       │ 18 [EXT + H-IN] Claude Design│
               │                       │ Human steers and answers     │
               │                       │ Output remains candidate     │
               │                       └──────────────┬───────────────┘
               │                                      ▼
               │                       ┌──────────────────────────────┐
               │                       │ 19 [SYS] Design Preflight   │
               │                       │ Manifest, refs, state, scope│
               │                       └──────────────┬───────────────┘
               │                                      ▼
               │                       ┌──────────────────────────────┐
               │                       │ 20 [AI-R] Semantic Reconcile│
               │                       │ REQ/API/data/scope findings │
               │                       │ remain candidate evidence   │
               │                       └──────────────┬───────────────┘
               │                                      ▼
               │                       ┌──────────────────────────────┐
               │                       │ 21 [HG] Human Design Review │
               │                       │ Accept / revise / reject    │
               │                       └───────┬───────────┬──────────┘
               │                         revise│           │accept
               │                              └──> Step 18 │
               └───────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 22 [SYS + HG] Accepted Design Baseline and Change Routing  │
│ Bind accepted output to current input/review digests       │
│ Human feedback with technical impact opens Change Control  │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 23 [AI-R] Complete Acceptance/Test Cases                   │
│ Add UI, interaction, error, responsive and accessibility   │
│ coverage to the same canonical BUILD-SPEC table            │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 24 [AI-R] Final Developer Handoff                          │
│ HANDOFF + BUILD-SPEC + DELIVERY + approved design evidence │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 25 [SYS + AI-R] Handoff Validation and Semantic Review     │
│ Deterministic completeness first; candidate sense-check next│
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 26 [HG] Design Ready                                      │
│ Named authorized Human; no new Handoff approval gate       │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
                    ┌─────────────────────┐
                    │ 27 Execution path   │
                    └─────────┬───────────┘
                 developer    │      governed AI
               ┌──────────────┘           └───────────────┐
               ▼                                          ▼
┌──────────────────────────────┐       ┌──────────────────────────────┐
│ 28A Human/Vendor build       │       │ 28B Execution Contract      │
│ under final handoff          │       │ export -> AI build -> result│
└──────────────┬───────────────┘       └──────────────┬───────────────┘
               └──────────────────────┬───────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 29 [AI-A + SYS + HG] Deviation and Change Control          │
│ Classify -> impact -> Human decision -> rebaseline         │
│ Major changes loop to Scope/System/UI/Test as applicable   │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 30 [SYS] Build/Execution Verification                      │
│ Git ground truth / scope / authority / required evidence   │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 31 [SYS + H-IN] Test Execution and Evidence                │
│ CI / reports / manual evidence / QA / security / UAT       │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 32 [SYS] Release Validation                                │
│ Completion / evidence freshness / rollback / traceability  │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 33 [HG] Human Release Approved                             │
│ Only an authorized named Human may authorize release       │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Change-control return paths

| Change classification | Example | Required return path |
|---|---|---|
| `patch` | Copy, spacing, non-behavioral text | Affected design capture/review only |
| `minor` | Interaction/state change within approved behavior | Design review + affected cases + Handoff freshness |
| `major` | API, data, permission, architecture, or behavior change | System Design + cases + Handoff + execution contract |
| `scope` | New or removed requirement/AC | Scope approval and every affected downstream contract |
| `emergency` | Production hotfix | Minimum safe path plus mandatory retrospective evidence |

AI may propose classification. Human confirms any classification that changes Scope, authority, security, risk acceptance, or an approved contract.

---

## 6. Target project declarations

Newly generated projects should declare optional workflow choices in `PROJECT.md` near the existing Mode and Execution path metadata:

```text
> Research mode: off / guided / auto
> Research depth: quick / standard / deep
> Research provider: none / feyman / web / auto
> UI delivery: not_applicable / dev_guided / claude_design
```

Compatibility rules:

- An existing project without `Research mode` behaves as `off` without warning.
- An existing project without `UI delivery` retains legacy behavior and receives no new requirement.
- New interactive projects must ask for UI delivery only after asking whether the work has a user-facing UI.
- `research=off` and non-Claude UI projects must not receive optional folders or diagnostics.
- Provider selection is a declaration, not detection.
- Data classification is recorded per externalization entry, not inferred from governance Mode.

---

## 7. Lean artifact model

### 7.1 Core artifacts retained

```text
PROJECT.md
SCOPE.json
DELIVERY.md
DESIGN/BUILD-SPEC.md
HANDOFF.md
HANDOFF-REVIEW.json
RELEASE.md
RAID-log.md
decision-log.md
RTM.json
```

### 7.2 Conditional new artifacts

```text
EXTERNALIZATION.json                 # only when data leaves the governed project boundary
CHANGE-REQUESTS.json                 # only after the first governed change/deviation

RESEARCH/                            # only when research != off
├── RESEARCH.md                      # brief, findings, comparison, standards, impact, proposals
└── PROVENANCE.json                  # structured source/claim provenance and freshness

DESIGN/CLAUDE-DESIGN/                # only when ui_delivery = claude_design
├── INPUT-MANIFEST.json              # canonical paths, digests, classification, purpose
├── OUTPUT/                          # provider-created assets/prototype/screens
└── REVIEW.json                      # candidate findings, reviewer, decision, input/output digest
```

### 7.3 Artifacts explicitly not added

- No copied `DEV-HANDOFF-BASE/` directory.
- No mandatory `TESTS.md` in this increment.
- No separate `RESEARCH-IMPACT.md`; impact is a required section of `RESEARCH.md`.
- No `VISUAL-REVIEW-2.json`; existing Visual Proof remains canonical for final visual evidence when activated.
- No `.agents/skills` mirror.
- No eighth PMO skill.
- No repository-wide auto-generated dependency graph in the MVP.

---

## 8. Policy and validation design

### 8.1 One orchestration policy file

Add `pmo-config/orchestration-policy.json` rather than four small policy files. It owns only the new optional orchestration vocabulary:

- research modes, depths, providers, activation and fallback;
- UI delivery paths and provider artifact paths;
- externalization classifications and Human-review requirements;
- change classifications, statuses and blocking behavior;
- mode-specific testability expectations using the existing BUILD-SPEC;
- compatibility defaults for missing legacy declarations.

It must not duplicate:

- Strict triggers from `policy.json`;
- artifact matrices from `artifact-policy.json`;
- approval roles from `policy.json`;
- Handoff review lenses from `handoff-policy.json`;
- reference shapes from `reference-types.json`.

`pmo-doctor` must detect missing keys, invalid enum relationships, undocumented rule IDs, and drift between new config, templates, skills, and docs.

### 8.2 Proposed deterministic rule families

Exact numbering may be adjusted after reading the current catalog, but IDs must be stable before fixtures are written.

| Family | Purpose |
|---|---|
| `RESEARCH-*` | Activated research artifacts, provenance, impact, Human scope decision |
| `EXT-*` | Externalization registry, classification, required Human review, secret-pattern block |
| `CHANGE-*` | Change registry structure, authority, unresolved blocking change, affected references |
| `DPROV-*` | Design-provider input digest, output declaration, review freshness and Human decision |
| `TEST-DESIGN-*` | Mode-specific testability and Acceptance Case coverage in BUILD-SPEC |

Recommended minimum rules:

| Rule | Deterministic question |
|---|---|
| `RESEARCH-001` | When research is enabled, are `RESEARCH.md` and `PROVENANCE.json` present and structurally valid? |
| `RESEARCH-002` | Do material claims reference resolvable provenance entries with retrieval dates? |
| `RESEARCH-003` | Before Scope approval, does research contain an impact disposition and Human-owned decision for proposed scope changes? |
| `EXT-001` | Does each external transfer have purpose, provider, input refs and declared classification? |
| `EXT-002` | Does Confidential/Restricted externalization carry required named-Human decision evidence? |
| `EXT-003` | Did deterministic secret patterns detect a credential-like value in a declared outgoing artifact? Diagnostics must identify location without echoing the value. |
| `CHANGE-001` | Is the change registry structurally valid and are affected refs resolvable? |
| `CHANGE-002` | Does an approved major/scope/emergency change cite a valid Human decision? |
| `CHANGE-003` | Is a blocking open change still unresolved at Handoff or Release? |
| `DPROV-001` | When Claude Design is selected, do the manifest, output declaration and review artifact exist? |
| `DPROV-002` | Do current canonical input/output digests match the reviewed provider package? |
| `DPROV-003` | Is the final provider review tied to a named Human and resolving decision reference? |
| `TEST-DESIGN-001` | Does BUILD-SPEC contain the testability content required for the effective Mode and gate? |
| `TEST-DESIGN-002` | At Handoff, do Acceptance Cases cover the applicable scoped requirements and design/UI states? |

### 8.3 Honest validation limits

Validators may check:

- file existence and location;
- schema and table shape;
- IDs and references;
- declared classifications;
- hashes and freshness;
- Git SHAs and changed files;
- configured secret patterns;
- whether a named decision exists;
- whether required sections and cases are present.

Validators must not claim to determine:

- whether market research is correct or complete;
- whether a source is truthful merely because it is cited;
- whether proprietary information was semantically detected;
- whether architecture supports a stated throughput without real evidence;
- whether UI is usable, beautiful, accessible in practice, or aligned with user expectations;
- whether a Human actually read an artifact before approving it;
- whether every downstream impact was discovered.

---

## 9. Milestone execution plan

The milestone order below is an implementation dependency order, not a replacement for the runtime workflow in Section 5. For example, Research belongs before Scope at runtime, but its implementation follows the shared Change Control and Externalization primitives so those contracts are built once and reused.

## M0 — Baseline, decision record, and change budget

### Objective

Prove the starting point and freeze the implementation boundary before changing behavior.

### Work

1. Read `AGENTS.md`, `CLAUDE.md`, `CONTEXT-ROUTER.md`, current configs, active skills, templates, README, ROADMAP, TESTING, and the most recent decision entries.
2. Confirm current branch, head SHA, worktree status, and unrelated changes. If the live head is no longer `2dfcf7b`, do not reset it: compare the newer head to this baseline, record plan drift, and adapt only where the newer repository has already superseded a planned change.
3. Run baseline:
   - `scripts/pmo-doctor.ps1`
   - `scripts/check-public-hygiene.ps1`
   - `scripts/run-validation-tests.ps1 -VerifyGolden`
   - `scripts/run-all-checks.ps1`
4. Record baseline results in a temporary implementation report, not a permanent new framework artifact.
5. Append the next available Human decision entry only after the Human Owner explicitly approves this plan for execution. Record the scope and explicit exclusions; do not fabricate authorization.
6. Establish the repository growth budget:
   - no new active skill;
   - one orchestration policy;
   - conditional project artifacts only;
   - one canonical worked example at most;
   - favor programmatic temporary mutations over dozens of committed fixture directories;
   - every new rule needs a reproduced failure case.

### Done when

- Baseline is reproducible.
- Dirty or unrelated files are documented and untouched.
- Scope/exclusions are recorded.
- No implementation has started before baseline is known.

---

## M1 — Workflow vocabulary, routing, and readable product story

### Objective

Make the target model explicit without yet claiming unimplemented enforcement.

### Files

- `pmo-config/orchestration-policy.json` (new)
- `pmo-config/context-map.json`
- `pmo-config/skill-manifest.json` only if purpose wording changes; do not add a skill
- `templates/PROJECT.md`
- `scripts/new-project.ps1`
- `cli/axiom.mjs`
- `scripts/pmo-status.ps1`
- `pmo-config/onboarding-questions.json` only for presentation wording owned by current enums
- `docs/concepts/end-to-end-workflow.md` (new)
- `README.md`
- `CONTEXT-ROUTER.md`

### Work

1. Add policy enums and compatibility defaults for Research and UI delivery.
2. Add explicit declarations to newly generated `PROJECT.md` files.
3. Keep existing projects valid when declarations are absent.
4. Extend interactive init:
   - ask whether the work has a user-facing UI;
   - if yes, ask `dev_guided` or `claude_design`;
   - ask Research `off`, `guided`, or `auto` after core Mode/path questions;
   - explain that these are Human declarations, not detections;
   - keep non-interactive defaults backward compatible.
5. Extend `axiom status` to display optional paths and the next relevant action without creating files.
6. Add actor codes and the compact end-to-end flow to README using the exact content principles in Section 10.
7. Place the detailed owner matrix and full flow in `docs/concepts/end-to-end-workflow.md`.
8. Mark Research/Claude Design as proposed or experimental until later milestones implement them. Do not list them as shipped early.

### Tests

- Existing CLI tests stay green.
- New interactive and non-interactive declaration cases.
- Missing fields on legacy projects do not warn or fail.
- Invalid explicit enum values fail with actionable diagnostics.
- Context-map config-mutation and doctor tests cover every new intent.

### Done when

- A new reader can explain the two axes, actors, gates, and optional branches from README alone.
- Existing projects and commands behave as before unless a new capability is explicitly selected.

---

## M2 — Structured Change Control MVP

### Objective

Close the implementation feedback-loop gap without building an unreliable automatic dependency engine.

### Files

- `templates/CHANGE-REQUESTS.json` (new)
- `scripts/lib/change-control-validator.ps1` (new)
- `scripts/validate-project.ps1`
- `pmo-config/orchestration-policy.json`
- `pmo-config/validation-rules.json`
- `pmo-config/context-map.json`
- `.claude/skills/pmo-governance/SKILL.md`
- `.claude/skills/pmo-build-review/SKILL.md`
- `.claude/skills/pmo-delivery/SKILL.md`
- matching generated `skills/` mirror through the existing build command
- `docs/concepts/change-control.md` (new)
- `docs/rules/CHANGE-*.md` (new only for implemented rules)

### Registry contract

Each entry must contain at least:

```json
{
  "id": "CR-001",
  "detected_at": "2026-08-14T00:00:00Z",
  "source": "implementation",
  "classification": "major",
  "summary": "Existing API cannot support the approved interaction",
  "reason": "Observed technical limitation",
  "affected_requirements": ["REQ-004"],
  "affected_artifacts": ["DESIGN/BUILD-SPEC.md"],
  "scope_impact": false,
  "acceptance_impact": true,
  "mode_impact": "none",
  "status": "approved",
  "owner": "Named Person",
  "decision_ref": "<DEC-###>"
}
```

The template must use placeholders and must never ship a fabricated approved example.

### Work

1. Define classifications, statuses, blocking points and Human-only decisions in policy.
2. Validate structure, resolvable affected refs, named owner and decision evidence.
3. Block Handoff/Release for an unresolved blocking change according to classification and Mode.
4. Reuse existing digest systems for actual freshness where possible.
5. Require execution-contract re-export when an approved change alters allowed paths, AC, required tests, authority, or base assumptions.
6. Let AI propose affected artifacts; do not claim the list is complete.
7. Add semantic review instruction to identify possible omitted impacts as candidate findings.
8. Do not create `CHANGE-REQUESTS.json` until the first real change exists.

### Tests

- valid patch/minor/major/scope/emergency examples;
- missing/unresolvable decision;
- generic owner;
- unresolved blocking change;
- harmless patch does not invalidate unrelated System Design;
- approved scope change requires new downstream validation;
- execution contract cannot be silently edited to absorb a change;
- diagnostics contain no sensitive content.

### Done when

- A developer-discovered limitation has a deterministic, Human-authorized path back to affected contracts.
- The MVP makes no claim of exhaustive automated impact discovery.

---

## M3 — Earlier System Design and risk-adaptive testability

### Objective

Stop generating detailed UI as an automatic consequence of starting Design, and make testability visible before final Handoff without duplicating test artifacts.

### Files

- `templates/BUILD-SPEC.md`
- `templates/DELIVERY.md` only if wording/reference guidance changes without changing the canonical column schema unnecessarily
- `scripts/new-project.ps1`
- `pmo-config/artifact-policy.json`
- `pmo-config/handoff-policy.json`
- `pmo-config/orchestration-policy.json`
- `scripts/lib/handoff-validator.ps1`
- `.claude/skills/pmo-design/SKILL.md`
- `.claude/skills/pmo-delivery/SKILL.md`
- `docs/concepts/end-to-end-workflow.md`
- affected rule pages and tests

### Work

1. Treat BUILD-SPEC as the System Design contract and create it for new Standard/Strict projects early enough for Design work, not only when `--handoff` happens.
2. Stop using `DESIGN/FLOW.puml` as the universal initial Design Ref for every Standard project. Use BUILD-SPEC or an explicit unresolved design reference until the UI path is selected.
3. Keep `WIREFRAME.md` and flow artifacts conditional on the selected UI path and actual UI scope.
4. Extend BUILD-SPEC with a Test Strategy section while retaining the canonical Acceptance Cases table.
5. Apply Mode behavior:
   - Lite: Delivery Test Checklist only unless risk escalates.
   - Standard at Design: strategy and scenarios; at Handoff: completed relevant Acceptance Cases.
   - Strict at Design: detailed requirement/risk cases; at Handoff: completed design/UI/security cases.
6. Revisit the same table after design; do not create a second set of cases or require duplicate Human review.
7. Preserve `TEST-###` as the existing test reference vocabulary where IDs are needed; do not create a competing prefix.
8. Update Handoff semantic lenses to detect testability gaps without restating deterministic missing-section findings.

### Tests

- new Lite project creates no heavy test artifact;
- Standard Design fails only when required strategy/scenarios are incomplete;
- Strict Design requires detailed cases appropriate to triggers;
- Handoff detects scoped requirements with no applicable acceptance case;
- headless/not-applicable UI work does not require UI cases;
- legacy examples and projects remain valid;
- generator, golden, E2E and Handoff tests are updated intentionally.

### Done when

- System/API/data constraints exist before detailed UI work.
- Test design is early enough to challenge requirements and light enough not to burden Lite work.

---

## M4 — Externalization Gate MVP

### Objective

Create an honest, provider-neutral record of data leaving the governed project boundary without pretending to be an enterprise DLP system.

### Files

- `templates/EXTERNALIZATION.json` (new)
- `scripts/lib/externalization-validator.ps1` (new)
- `pmo-config/orchestration-policy.json`
- `pmo-config/validation-rules.json`
- `pmo-config/context-map.json`
- `scripts/validate-project.ps1`
- `.claude/skills/pmo-governance/SKILL.md`
- `docs/concepts/externalization.md` (new)
- `docs/rules/EXT-*.md`

### Contract

Each transfer entry records:

- stable ID;
- purpose;
- provider and provider type;
- exact outgoing artifact refs/digests;
- declared classification: Public, Internal, Confidential, Restricted;
- minimization/redaction statement;
- deterministic scan result;
- whether Human review is required;
- named reviewer and decision reference when required;
- status and timestamp.

### Work

1. Create a registry, not a copy of outgoing content.
2. Use existing sensitive-path patterns and add narrowly scoped secret patterns through policy.
3. Never echo a detected value in diagnostics.
4. Public may proceed under policy; Internal follows configured provider policy; Confidential/Restricted requires Human decision or is blocked.
5. AI may propose classification and redactions but may not declare Confidential/Restricted content safe on its own.
6. Research and Claude Design manifests must cite an approved externalization entry whenever they use an external provider.
7. Local provider execution is still external to the Axiom-PMO authority model; whether network transfer occurs must be recorded truthfully.

### Non-goals

- No semantic trade-secret detection guarantee.
- No enterprise DLP replacement.
- No automatic credential rotation.
- No provider-account or retention-policy enforcement beyond declared evidence.

### Done when

- External provider packages cannot be presented as governed without classification and required Human evidence.
- The docs clearly state what the check cannot detect.

---

## M5 — Claude Design optional workflow

### Objective

Prepare a high-quality, governed Design Handoff for Human-operated Claude Design, validate returned artifacts before Human review, and reconcile accepted output into Final Handoff.

### Files

- `templates/DESIGN-PROVIDER-INPUT.json` (new)
- `templates/DESIGN-PROVIDER-REVIEW.json` (new)
- `scripts/design-provider-digest.ps1` (new; follow existing digest conventions)
- `scripts/lib/design-provider-validator.ps1` (new)
- `pmo-config/orchestration-policy.json`
- `pmo-config/context-map.json`
- `pmo-config/validation-rules.json`
- `scripts/validate-project.ps1`
- `.claude/skills/pmo-design/SKILL.md`
- `.claude/skills/pmo-delivery/SKILL.md`
- `docs/concepts/claude-design-workflow.md` (new)
- `docs/rules/DPROV-*.md`

The template filenames are repository source names. Project generation must materialize them as `DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json` and `DESIGN/CLAUDE-DESIGN/REVIEW.json`; it must not expose two competing names for either contract.

### Input manifest

The manifest contains references and digests for the minimum necessary canonical inputs, for example:

- `PROJECT.md` scoped summary and requirements;
- `SCOPE.json` where present;
- `DESIGN/BUILD-SPEC.md`;
- selected/conformance Visual Direction and brand assets when present;
- relevant Acceptance Cases;
- approved externalization reference;
- provider and purpose;
- generated timestamp and combined digest.

Do not copy `source/**` by default. Include only a specific source artifact when the Design Brief cannot be resolved from governed summaries and externalization policy permits it.

### Output/review flow

1. Axiom-PMO prepares `INPUT-MANIFEST.json` and prints the work-location folder.
2. Human opens/selects that folder in Claude Design and answers questions.
3. Claude Design writes/exports candidate deliverables under `OUTPUT/`.
4. Deterministic preflight checks paths, manifest, declared screens/states, digests and scope references.
5. `pmo-design` performs semantic candidate reconciliation for business/API/data/permission mismatches before Human review.
6. Human reviews UX/UI/business fit and records accept/revise/reject in `REVIEW.json` with a decision reference.
7. Revision returns to provider output and recomputes all digests.
8. Technical or Scope impact found by preflight, semantic reconciliation, or Human feedback creates a Change Request and returns to the relevant upstream contract before the accepted design baseline is finalized.
9. Existing Visual Proof remains the final conditional render/capture evidence when its activation conditions are present.

### Important boundary

No API or automated Claude Design invocation is required in this milestone. This is a governed handoff and return workflow around the Human-operated product. Do not invent a provider API that the repository has not verified.

### Tests

- inactive projects produce no files or warnings;
- manifest references/digests valid and stale;
- missing externalization when required;
- output missing/outside allowed folder;
- review before preflight is rejected;
- AI reviewer cannot mark Human acceptance;
- revision invalidates prior digest/review;
- technical finding routes to Change Control;
- existing Visual Proof behavior is unchanged when Claude Design is not selected.

### Done when

- A Human can point Claude Design at one governed folder, receive output in a separate subfolder, review it, and merge only current accepted output into Handoff.

---

## M6 — Guided Research MVP, then optional automation

### Objective

Add evidence-backed Product/Business/Standards research before Scope approval without allowing research to become authority.

### Files

- `templates/RESEARCH.md` (new)
- `templates/RESEARCH-PROVENANCE.json` (new)
- `scripts/lib/research-validator.ps1` (new)
- `pmo-config/orchestration-policy.json`
- `pmo-config/context-map.json`
- `pmo-config/validation-rules.json`
- `scripts/validate-project.ps1`
- `.claude/skills/pmo-intake/SKILL.md`
- `.claude/skills/pmo-governance/SKILL.md`
- `docs/concepts/research-workflow.md` (new)
- `docs/rules/RESEARCH-*.md`
- `integrations/feyman/README.md` only after the local provider interface is inspected

### `RESEARCH.md` required sections

- Research status and scope.
- Problem and research questions.
- Existing solutions.
- Feature parity.
- Relevant standards/regulations.
- Differentiation and value implications.
- Risks and unknowns.
- Impact Assessment mapping findings to REQ/scope/AC/risk.
- Change proposals with status and Human owner.
- Explicit limits and unanswered questions.

### `PROVENANCE.json`

Each material claim maps to one or more sources with:

- claim ID;
- source URL/file reference;
- title/issuer;
- retrieved/published date when known;
- primary/secondary classification;
- evidence status;
- exact report section using the claim;
- freshness or unresolved-verification status.

### Guided first

Implement the contract and Guided workflow first:

1. AI drafts Research Brief from preliminary REQ and unknowns.
2. Externalization produces a sanitized/minimized brief.
3. Human confirms focus/provider when policy requires.
4. Configured Research Provider produces candidate research.
5. Validator checks structure/provenance/freshness.
6. AI drafts Impact Assessment.
7. Human accepts/rejects proposed changes at Scope.

### Auto provider behavior

After Guided behavior is green, `auto` may orchestrate provider selection in this order:

1. explicit project/provider configuration;
2. explicit CLI/session Feyman path;
3. `AXIOM_FEYMAN_PATH` or documented user config;
4. approved governed web fallback;
5. actionable stop.

The executor must inspect the actual Feyman repository and its commands before writing an adapter. Until the Human supplies the path and the interface is verified, implement only the provider contract and truthful unavailable/fallback behavior. Never guess a command.

### Tests

- research off is silent;
- guided/auto activation;
- missing provenance;
- unresolvable material claim;
- research finding cannot rewrite Requirement automatically;
- Scope cannot be approved with an unresolved accepted-impact proposal;
- provider unavailable has truthful fallback/stop behavior;
- no automatic clone/install;
- confidential brief requires Human externalization evidence;
- dates/freshness remain deterministic and host-independent.

### Done when

- Research can influence Scope through a traceable Human decision, never through an AI-authored conclusion alone.
- Feyman integration is implemented only if its real local interface is available and verified.

---

## M7 — Cross-capability routing, ownership, and status

### Objective

Make the combined workflow coherent rather than a collection of optional features.

### Work

1. Extend `CONTEXT-ROUTER.md` and `context-map.json` with minimal read sets for:
   - research plan/impact;
   - externalization;
   - system design;
   - design provider handoff/review;
   - change control;
   - mode-specific testability.
2. Add executor/accountable/Human touchpoint/output guidance to the detailed workflow doc.
3. Extend `axiom status` to report:
   - current gate/state;
   - Mode and execution path;
   - Research path/state;
   - UI delivery path/state;
   - open governed changes;
   - stale provider/review evidence;
   - next Human gate or automated action.
4. Ensure status reports state; it must not create artifacts or approve anything.
5. Regenerate the `skills/` mirror with the existing build command and prove drift check passes.
6. Keep provider-specific instructions out of unrelated skills.

### Done when

- A new user can tell what automation is active, what Human action is next, and why a gate is blocked without reading every file.

---

## M8 — README, examples, migration, verification, and release preparation

### Objective

Finish the product story only after behavior is real, then verify clean-room compatibility.

### README work

1. Preserve the current truthful product boundary and shipped-status table.
2. Put the two axes before the full workflow.
3. Add the actor legend.
4. Add the compact flow from Section 10.
5. Explain optional Research and UI branches without presenting them as required.
6. Explain “candidate evidence” and Human gates once, clearly, instead of repeating it in every section.
7. Update “What is shipped today” only for milestones actually complete and tested.
8. Link the detailed workflow, research, externalization, change-control and Claude Design concept pages.
9. Keep Quick Start near the top after the mental model.
10. Avoid turning README into the full operator manual.

### Example strategy

- Add at most one canonical worked example covering Standard + Guided Research + Claude Design manifest + one controlled change.
- Do not add separate copied examples for every permutation.
- Generate negative mutations in temporary test directories.
- Existing examples must remain readable and valid.

### Migration

- Update `MIGRATION.md` with compatibility defaults.
- No bulk migration of existing projects is required.
- Offer an explicit migration helper only if repeated manual edits are proven necessary; do not build one pre-emptively.
- Missing optional declarations on legacy projects must not fail.

### Full verification

Run at minimum:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/pmo-doctor.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-public-hygiene.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-validation-tests.ps1 -VerifyGolden
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-all-checks.ps1
```

Also run:

- new domain helper suites;
- config-mutation tests proving `orchestration-policy.json` is load-bearing;
- CLI tests;
- generator E2E for Lite/Standard/Strict;
- legacy clean-room project with no new declarations;
- optional-track clean-room projects;
- Windows PowerShell 5.1 and PowerShell 7 where the current CI matrix requires them;
- generated plugin skill drift check;
- line-ending and UTF-8 tests for every new digest-bearing artifact.

### Version finalization

Only after all tests pass and the Human Owner accepts the implementation:

1. choose the version according to repository policy;
2. update `VERSION`, CHANGELOG and version-checked configs atomically;
3. write release notes that distinguish shipped, experimental and deferred capability;
4. rerun `pmo-doctor` against the real working-tree files;
5. do not tag, push, publish or create a release without separate authorization.

---

## 10. Required README flow block

README should contain a compact block materially equivalent to the following. Wording may be polished, but the order, actor boundaries and optional branches must remain.

```text
Actor legend
[H-IN] Human input     [AI-A] AI-assisted     [AI-R] AI-run
[EXT] External tool   [SYS] Deterministic    [HG] Human gate

[H-IN] Source: Brief / REQ / MOM / Transcript
                    │
                    ▼
[AI-R] Intake: facts / assumptions / gaps / preliminary requirements
                    │
                    ▼
[H-IN + SYS] Choose two independent axes
  Who builds?  Development Handoff | Governed AI Execution
  Governance?  Lite | Standard | Strict
                    │
                    ▼
            Optional Research?
             │ no          │ yes
             │             ▼
             │     [SYS/HG] Externalization
             │             ▼
             │     [AI-R/EXT] Feyman or governed web research
             │             ▼
             │     [AI-R] Impact proposal — never automatic Scope
             └─────────────┬
                           ▼
[SYS] Scope validation -> [HG] Scope Approved
                           │
                           ▼
[AI-A] System Design + initial testability in BUILD-SPEC
                           │
                           ▼
                   UI delivery choice
             ┌─────────────┴─────────────┐
             ▼                           ▼
    Dev-guided UI                  Claude Design
    existing design flow       input -> output -> preflight
                                      -> AI review -> Human review
             └─────────────┬─────────────┘
                           ▼
[AI-R] Complete Acceptance Cases and Final Handoff
                           │
                           ▼
[SYS/AI-R] Handoff validation -> [HG] Design Ready
                           │
                           ▼
            Developer build | Governed AI contract
                           │
                           ▼
[AI-A/SYS/HG] Controlled Change Loop when reality differs
                           │
                           ▼
[SYS] Git/evidence/test/release validation
                           │
                           ▼
[HG] Human Release Approved
```

README must immediately explain:

- Humans do not create every artifact manually.
- AI performs most drafting, research orchestration, analysis, and package preparation.
- deterministic validators check what code can prove;
- Humans answer ambiguity and own approvals;
- Research and Claude Design are optional;
- `auto` never means automatic Scope, Design, risk, or Release approval.

---

## 11. Anti-bloat constraints

These constraints are part of Definition of Done, not optional advice.

1. **No new gate when an existing gate can host a sub-check.**
2. **No new project artifact when an existing canonical artifact can hold the contract without ambiguity.**
3. **No copied canonical context.** Use path + digest manifests.
4. **No optional artifact for inactive projects.**
5. **No new skill in this plan.** Extend the seven active skills.
6. **No rule without a concrete failing case and remediation.**
7. **No one-fixture-directory-per-variation by default.** Prefer temporary programmatic mutations.
8. **No duplicate Human approval.** Reuse Scope Approved, Design Ready and Release Approved.
9. **No automatic semantic authority.** AI output remains candidate evidence.
10. **No enterprise DLP, IAM, RBAC, portfolio dashboard, or workflow-engine expansion in this release.**
11. **No provider-specific runtime dependency in Core.** Optional provider absence cannot break Core validation.
12. **No hardcoded local path.** Feyman location is configuration, never repository identity.
13. **No automatic web clone or execution.**
14. **No new reference prefix unless the existing vocabulary cannot express the contract.**
15. **No README claim before tests prove the capability.**

Before adding any file, the executor must answer:

```text
Which concrete failure does this file prevent or make auditable?
Why can the contract not live in an existing canonical artifact?
Is it created only when the capability is active?
Which test proves it is load-bearing rather than decorative?
```

---

## 12. Test strategy and repository-growth budget

### 12.1 Required test layers

| Layer | Purpose |
|---|---|
| Positive contract | Valid optional track passes |
| Negative mutation | Each rule catches the defect it claims to catch |
| Config mutation | Policy changes alter behavior and invalid config fails closed |
| Diagnostics contract | Every result retains canonical machine-readable shape |
| Legacy compatibility | v2.0 project without new declarations remains unchanged |
| Cross-mode | Lite/Standard/Strict requirements differ intentionally |
| Cross-path | Developer Handoff and Governed AI Execution remain independent |
| Freshness | Input change stales research/design/review evidence |
| Authority | AI cannot grant Human decisions |
| Clean room | Packaged/install context works outside writable repository assumptions |
| Host portability | Windows PowerShell 5.1 and PowerShell 7 produce equivalent governed results |

### 12.2 Growth budget

Targets, not excuses:

- one new orchestration config;
- four focused validator modules maximum for the new domains;
- conditional templates only;
- one worked example maximum;
- new negative cases generated in helper suites where practical;
- golden files only for stable user-visible output, not every internal branch;
- any proposal to exceed this budget must document why reuse or programmatic mutation is insufficient.

---

## 13. Deferred work

The following is explicitly deferred:

- Enterprise IAM, RBAC, SSO and cryptographic Human identity.
- Portfolio dashboard and cross-project dependency management.
- Jira/Azure DevOps/Linear deep synchronization.
- Enterprise DLP and data-residency enforcement.
- Fully automatic dependency-graph inference from Markdown.
- Automatic complete change-impact discovery.
- Automated Claude Design API integration unless a real supported interface is independently verified later.
- Automatic Feyman install/clone or guessed command invocation.
- Multiple research providers normalized behind a large intermediate representation.
- A new approval gate.
- A new PMO skill.
- Changes to AxiomGuard or reopening L4.
- Existing `ROADMAP.md` v2.1 candidates such as Formal Studio, GitHub Action exposure of Release-diff refs, skipped-row reconciliation, and npm manifest work; none is implicitly authorized by this plan.
- Push, tag, GitHub Release, deployment, marketplace or npm publication. Local checkpoint commits are allowed only when the Human execution instruction explicitly authorizes end-to-end implementation as described in Section 0.

Deferred means deliberately out of scope, not forgotten.

---

## 14. Definition of Done

The plan is complete only when all of the following are true:

### Product behavior

- A first-time reader can understand Axiom-PMO from README without prior context.
- Every major workflow step identifies automation/actor responsibility.
- Research is optional, happens before Scope approval, and cannot silently change Scope.
- Externalized input has a governed, honest classification record.
- System Design and initial testability precede detailed UI work.
- Claude Design receives a digest-bound minimum input manifest and returns output to a separated folder.
- Deterministic design preflight and candidate semantic review happen before Human design acceptance.
- UI discoveries can return through controlled System/Scope change.
- Test design follows Mode without duplicate mandatory documents.
- Final Handoff contains current accepted design and testability evidence when applicable.
- Implementation deviations use Human-authorized Change Control.
- Governed AI execution still verifies against Git ground truth.
- Existing Human approval boundaries remain unchanged.

### Compatibility

- Existing v2.0 projects without new declarations remain valid and silent.
- Research-off and non-Claude projects create no optional artifacts.
- Existing Visual Proof, Handoff, SCOPE-DIFF and Execution Contract behavior remains green.
- No provider is required to use Core Axiom-PMO.

### Engineering quality

- New policy is schema-checked and load-bearing.
- Every new FAIL/WARN has a documented rule, remediation and negative test.
- Diagnostics do not leak source or secret values.
- Input/output digests are stable across supported hosts and line endings.
- Skills source and generated mirror are in sync.
- Full framework checks pass from a clean worktree.
- Public hygiene passes.
- README shipped-status claims match implemented behavior.

### Authority

- AI has not fabricated a Human name, decision, review, approval, or provider run.
- No local commit occurred unless the Human execution instruction explicitly authorized end-to-end implementation; no push/tag/release/deployment occurred without separate explicit authorization.

---

## 15. Final implementation report required from the execution agent

At completion, the agent must return one concise but evidence-based report containing:

1. baseline SHA and final working-tree SHA/state;
2. milestones completed, deferred, or blocked;
3. exact files added/changed grouped by capability;
4. rule IDs added and the defect each catches;
5. compatibility decisions;
6. Feyman interface result: integrated, unavailable, or deferred — never implied;
7. test commands and exact pass/fail counts;
8. any golden changes and why user-visible behavior changed;
9. repository file-count growth, including test-file growth;
10. remaining risks and honest assurance limits;
11. confirmation that no unauthorized Git or external release action occurred;
12. the exact review entry point for the independent verifier.

The independent verifier should then inspect source and tests rather than relying on this report alone.

---

## 16. Recommended independent review sequence

After the implementation agent finishes, the reviewing AI should:

1. compare the final tree to baseline `2dfcf7b`;
2. verify every claimed new file and behavior directly;
3. run `pmo-doctor` before reading the implementation report in depth;
4. inspect policy/config coupling and mutation tests;
5. test inactive optional tracks for silence;
6. test legacy compatibility;
7. adversarially forge Research provenance, externalization approval, design review, and change approval;
8. change canonical inputs after review to verify stale detection;
9. attempt an AI self-approval in every new artifact family;
10. test minor versus major change invalidation;
11. confirm no Source content or detected secret is echoed in diagnostics;
12. verify README claims against actual commands and results;
13. report findings by severity with file/rule evidence;
14. recommend acceptance only when full checks are green and no authority boundary was weakened.

---

## Closing principle

The goal is not to make Axiom-PMO larger. The goal is to extend its control plane to the upstream work that determines whether the right product is being researched, designed, tested, handed off, changed, and released — while preserving the framework’s strongest property:

> AI may do most of the work, deterministic systems may verify what is observable, but only governed Human authority may decide what becomes approved truth.
