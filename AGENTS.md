# Axiom-PMO - Agent Behavioral Guide

> Shared rules for Claude, Codex, Cursor, Copilot, and other AI agents.
> Keep this file short. Detailed methods live in `.claude/skills/` and are loaded on demand.

---

## What This Repo Is

This repo is a lightweight PMO operating template for small teams. It helps AI agents turn meeting sources into scope, flow, delivery, QA, and release artifacts without creating unnecessary documentation overhead.

The operating core stays simple:

| Core | Purpose | Main Outputs |
|---|---|---|
| Core 1 - Discovery & Product Design | Understand source, confirm scope, design only what is needed | `PROJECT.md`, `DESIGN/FLOW.puml`, optional wireframe |
| Core 2 - Delivery & Engineering | Break work down, hand off, build, and review engineering readiness | `DELIVERY.md` or GitHub Issues |
| Core 3 - Quality & Release | Verify, test, approve, close, and release safely | `RELEASE.md`, `RAID-log.md`, `decision-log.md` |

Default project shape:

```text
projects/P01-CODE/
+-- PROJECT.md
+-- source/
|   +-- MOM/
|   +-- Transcript/
|   +-- REQ/
+-- DESIGN/
|   +-- FLOW.puml
|   +-- WIREFRAME.md or WIREFRAME.html
|   +-- BUILD-SPEC.md           <- technical spec, required at Handoff (Standard/Strict)
|   +-- SRS.md                  <- required under `Spec depth: full`; actors, NFRs, interfaces, constraints
|   +-- DATA-FLOW.md            <- required under `Spec depth: full`; End-to-End Journeys table
|   +-- DATA-DICTIONARY.md      <- required under `Spec depth: full`; field-level PII/classification join
|   +-- ERD.puml                <- required under `Spec depth: full`; entity relationship diagram
|   +-- API/openapi.yaml        <- Strict + `Spec depth: full`; only when the API contract is machine-checked
|   +-- VISUAL-DIRECTION.md     <- optional; creative brief, explored directions, human selection
|   +-- DESIGN-SYSTEM.md        <- optional; token/component contract a developer builds from
|   +-- DESIGN-SYSTEM.html      <- optional; the same contract as one visual page
|   +-- VISUAL-REVIEW.json      <- conditional Handoff evidence when all visual artifacts exist
|   +-- BRAND/                  <- optional; BRAND.md plus logo and icon SVG assets
+-- TESTS/
|   +-- TEST-CASES.md           <- required under `Spec depth: full`; one row per (spec element x category)
+-- DELIVERY.md
+-- HANDOFF.md                  <- required at the Handoff gate
+-- HANDOFF-REVIEW.json         <- semantic review evidence (Standard/Strict)
+-- RELEASE.md                  <- required when release/UAT exists
+-- RAID-log.md                 <- required for Strict or meaningful risks
+-- decision-log.md             <- required for Strict or meaningful decisions
```

`Spec depth: full` (declared in `PROJECT.md`) is what makes the five rows above
required rather than absent; a project that omits the declaration defaults to
`legacy` and is unaffected. See
[document-depth](docs/concepts/document-depth.md).

Legacy folders such as `MOM/`, `REQ/`, `SystemFlow/`, `Wireframe/`, and `TaskBreakdown/` are still acceptable for old projects. New projects should prefer the lightweight shape above.

Examples show the intended artifact weight by mode:

- `examples/LITE-BUGFIX`: minimal low-risk bug fix.
- `examples/STANDARD-FEATURE`: normal feature with flow, delivery, QA, and release.
- `examples/STRICT-HIGH-RISK`: high-risk permission/audit work with RTM and separate review.

---

## Operating Modes

Choose the smallest mode that controls the real risk. Mode is selected per work item, not only per project.

| Mode | Use When | Required Outputs |
|---|---|---|
| Lite | Low-risk bug fix or small feature | `PROJECT.md` section update, one delivery item or GitHub Issue, acceptance criteria, test note |
| Standard | Normal feature with flow, UI, handoff, or QA | `PROJECT.md`, `DESIGN/` when needed, `DELIVERY.md` or GitHub Issue, test checklist |
| Strict | Any strict trigger applies | Full source references, `RAID-log.md`, `decision-log.md`, release checklist, separate QA or human approval |

Strict triggers:

- Payment or financial calculation
- PII, sensitive customer data, or confidential source
- Authentication, authorization, permission, or audit log
- Irreversible action
- External system integration
- Legal or compliance requirement
- Production data migration
- Critical infrastructure
- Public-sector formal acceptance

AI may escalate Lite -> Standard -> Strict. AI must not downgrade Strict without PM or Tech Lead approval.

Approval gates:

1. Scope Approved
2. Design Ready
3. Release Approved

For `Design Ready`, a named human recorded as `Product Owner`, `Project Manager`,
`Tech Lead`, or `Solution Architect` may approve. This changes neither the
other approval matrices nor the rule that an AI cannot approve its own work.
`pmo-config/policy.json` is the runtime source of truth.

Validation gates run in this order:

```text
Draft -> Scope -> Design -> Handoff -> Release
```

`Handoff` is a checking gate, not an approval gate. It reuses `Design Ready` and
asks whether the contract is complete enough for a developer to start,
integrate, and demonstrate. Handoff checks run only when `-Gate Handoff` is
requested; every other gate behaves as it did before. See
`docs/concepts/handoff-readiness.md`.

Work status:

```text
To Do -> In Progress -> Review / Test -> Done
```

Use labels for detail: `blocked`, `needs-client`, `bug`, `high-risk`, `ready-to-release`, `review:code`, `review:qa`, `review:business`, `test:failed`.

---

## Non-Negotiable Rules

1. Read the relevant source before producing PMO output. Use `CONTEXT-ROUTER.md` and `pmo-config/context-map.json` to keep the read set small.
2. Never invent requirements, actors, business rules, dates, acceptance criteria, or approvals.
3. Separate `Confirmed`, `Assumption`, and `Open Question` in every important output.
4. Do not add features outside scope. If something seems missing, flag it as an open question or gap.
5. Every important requirement, decision, risk, flow, or test claim needs a structured `source_ref`.
6. Evidence must be marked as `verified`, `supported`, `inferred`, `missing`, or `conflict`. `inferred`, `missing`, and `conflict` require review.
7. Use one source of truth for tasks: either `DELIVERY.md` or GitHub Issues. Declare it in `PROJECT.md` and `DELIVERY.md`; do not keep both as competing task boards. To use GitHub Issues, set `Task source: github` in `PROJECT.md` and fill `github_repository:` with the repo; validation then waives the `DELIVERY.md` requirement and records a non-blocking `TASK-003` note that the board state cannot be verified offline (verify it on GitHub / in CI).
8. Log only meaningful changes: requirement change, scope change, business decision, design approval, release approval, high-risk issue.
9. Treat `source/`, `MOM/`, `REQ/`, `Transcript/`, and `Others/` as user-owned inputs. Do not edit, create, or delete source files unless the user explicitly asks.
10. AI must not push, deploy, approve production, or approve business scope by itself. Commit requires explicit user instruction; push and production release require human confirmation.
11. Candidate handoff evidence is never an approval. An AI may record semantic findings and may close one when the artifacts show it was fixed. It must not close a finding that needs a business, legal, security, or human decision, must not move an approval row from pending to approved, and must not present a readiness score or Visual Proof manifest as a decision or automated aesthetic judgement.

---

## AI Guardrails

Use these fields in structured outputs when possible:

```yaml
id: REQ-001
statement: "User can reset password by verified email."
source_ref:
  - source_id: MOM-20260710
    locator: item-2.1
evidence_status: supported
acceptance_criteria:
  - "Given a registered email, when the user requests reset, then a reset link is sent."
```

Guardrail policy:

- `source_ref` is mandatory for requirements, design decisions, test cases, and release claims.
- `verified` means direct source plus human approval.
- `supported` means direct source exists but final approval is still pending.
- `inferred` means the item is reasoned from partial source and needs review.
- `missing` means not found in source and cannot become a requirement.
- `conflict` means sources disagree and must be resolved before final output.
- If the source does not contain the information, say "not found in source" and do not fabricate.
- Empty result is valid. Do not create fake issues just to fill a section.
- Sensitive sources stay local. For PII, financial data, customer confidential data, or restricted data, use Strict mode.

Strict handling means:

- Do not send raw PII, credentials, or confidential customer data to web search or external MCP services.
- Do not copy real customer data into examples.
- Use redacted identifiers in summaries.
- Do not commit confidential source files unless the user explicitly confirms they are allowed.
- Human approval is required before external service use.
- Release requires security/privacy review.

---

## Logging Policy

Do not log every small AI action. Use these files only for meaningful project memory:

- `decision-log.md`: scope, business, design, risk acceptance, release decisions. Required for Strict; optional for Lite/Standard unless meaningful decisions exist.
- `RAID-log.md`: risks, assumptions, issues, dependencies. Required for Strict; optional for Lite/Standard unless meaningful risks exist.
- `PROJECT.md`: current source-backed project summary.
- `RELEASE.md`: final release scope, UAT status, deployment and rollback notes.

If the user says "record", "log", "track", or "จดไว้" without a target, default to `decision-log.md` for decisions and `RAID-log.md` for risks/issues.

---

## Skill Loading

Load skills on demand only. Never load all `.claude/skills/*` at once.

Active skill groups are defined in `pmo-config/skill-manifest.json`:

- Intake: `pmo-intake`
- Design: `pmo-design`
- Delivery: `pmo-delivery`
- Build review: `pmo-build-review`
- QA / Release: `pmo-quality-release`
- Governance: `pmo-governance`
- Git safety: `pmo-git-safety`

`pmo-delivery` carries two intents: `delivery_planning` (default) and
`handoff_review`. The review intent reads `HANDOFF.md` and
`DESIGN/BUILD-SPEC.md` in addition to the normal delivery set, and walks the
twelve lenses configured in `pmo-config/handoff-policy.json`. If the visual-direction
and design-system artifact triple exists, it also checks the conditional Visual Proof
evidence: named-human review, committed desktop/mobile captures, and freshness inputs.

`pmo-design` carries three intents: `flow` (default), `visual_direction`, and
`design_system`. Visual direction turns a source-backed creative brief into a
human-selected direction; design system carries that selection forward and
additionally reads `DESIGN/WIREFRAME.md`, `DESIGN/BRAND/**`, and `decision-log.md`.
Both are optional and are described in `docs/concepts/visual-direction.md` and
`docs/concepts/design-system.md`. Their outputs are candidate evidence for
`Design Ready`, never the approval itself. Conditional Visual Proof at Handoff is described
in `docs/architecture/visual-proof.md`; it verifies evidence shape and freshness, not taste.

Only active skills under `.claude/skills/` are shipped and loaded by default.
Do not create a separate `.agents/skills` mirror for Visual Proof; generated `skills/` remains
the only package mirror and is refreshed through the repository build command.

---

## Validation

Before treating a project as ready, run (`examples/P01-DEMO` is intentionally left at `design-ready` and will not pass a Release gate -- point `<project-folder>` at your own project, or use `examples/STANDARD-FEATURE` to see a passing run):

```bash
node cli/axiom.mjs validate --project <project-folder> --mode Standard --gate Release --fail-on-warning
node cli/axiom.mjs doctor
node dist/tools/run-ci-suite-cli.js -Suite validation-fixtures -RepoPath .
```

Before handing work to a developer:

```bash
node cli/axiom.mjs validate --project <project> --mode <mode> --gate Handoff
node cli/axiom.mjs handoff --project <project> --mode <mode>
```

Validation checks structure, placeholders, source references, approval authenticity, task source consistency, blockers, sensitive file pre-checks, basic local links, negative fixtures, and -- at the Handoff gate -- scope contract, build order, ownership, build-spec completeness, acceptance testability, declared data classification, declared runtime capabilities, semantic review freshness, and conditional Visual Proof evidence when all visual artifacts exist.

### Before changing the engine under `src/`

The engine is TypeScript compiled to `dist/` (`npm run build`) and run
in-process by `cli/axiom.mjs` — there is no separate runtime host. The
historical PowerShell reference was deleted in Phase 9; its recorded pitfalls
are preserved in
[`docs/architecture/powershell-portability.md`](docs/architecture/powershell-portability.md)
as a historical record.

When a check fails only on a platform you cannot run, read the CI log rather
than guessing a fix. If the log is not conclusive, push a diagnostic that
prints the real state first -- a wrong guess costs a full CI round-trip.
