# Interoperability Overview

Axiom-PMO is a **governance control plane**. It is deliberately framework-
agnostic: it defines *what may be built, why, with what evidence, under whose
authority, and when it is safe to release* — and leaves *how it gets built* to an
AI execution framework such as Superpowers, BMAD, GitHub spec-kit, OpenSpec, or a
custom Claude Code setup.

This document describes how the two layers coexist. It describes interoperability
at the **contract and architecture level**. Where a specific framework's install
method or file layout is not verified here, that is intentional — see each
framework's own documentation for its mechanics.

## Responsibility split

| Axiom-PMO owns | The execution framework owns |
|---|---|
| Source-of-truth protection | Implementation planning |
| Requirements, scope, risk | Test-driven development |
| Approvals and evidence policy | Coding |
| Traceability | Code review |
| QA / security / release gates | Engineering verification |
| Human authority boundaries | Producing candidate evidence |

Output from an execution framework is **candidate evidence**, not automatically
trusted truth. Axiom-PMO validates it before it becomes release-ready.

## The compatibility levels

Interoperability is described as a ladder. Higher levels build on lower ones.

### Level 0 — Coexistence *(available today)*
Both systems are installed and used independently in the same repository.
Axiom-PMO governs the PMO artifacts; the execution framework runs its own
workflow. Nothing is wired together beyond a human moving between them.

### Level 1 — Policy awareness *(available today, by convention)*
The execution framework (or the agent driving it) reads Axiom-PMO's declared
context before acting: [`AGENTS.md`](../../AGENTS.md), the project mode, the
approved scope, the acceptance criteria, and the prohibited actions. This is
achievable now because those artifacts are plain, readable files.

### Level 2 — Execution contract *(experimental schema provided)*
Axiom-PMO produces a structured **work package** for the execution framework: a
single approved work item, its requirement/design references, acceptance
criteria, out-of-scope list, required tests, allowed paths, prohibited actions,
and explicit git authority. A generic, framework-agnostic contract shape is
provided experimentally under
[`integrations/superpowers/`](../../integrations/superpowers/). It is **not**
wired into the validator runtime.

### Level 3 — Evidence return *(roadmap)*
The execution framework returns a structured result — changed files, test
results, review results, commit references, deviations, risks, unresolved
questions, and a recommended next gate. A result **schema** is provided
experimentally, but automated consumption is not yet implemented.

### Level 4 — Automated bridge *(roadmap)*
A validator imports and verifies execution output before updating Axiom-PMO
artifacts, closing the loop. This is a design goal, not a shipped feature. Do not
rely on Level 4 behavior; no code or tests implement it yet.

> **Implemented today:** Levels 0 and 1. **Provided as experimental schemas:**
> Levels 2–3 shapes. **Roadmap:** automated Level 3 consumption and Level 4.

## Authority precedence

When instructions conflict, the more restrictive safety rule wins. The order of
authority is:

1. **Human instruction** (in the chat / review interface).
2. **Axiom-PMO safety and approval policies.**
3. **The project-specific approved contract.**
4. **Repository `AGENTS.md` / `CLAUDE.md`.**
5. **External execution-framework instructions.**
6. **Individual skill instructions.**
7. **Agent defaults.**

If two frameworks conflict, an agent must: choose the more restrictive rule, not
expand scope, not weaken evidence requirements, not grant additional git
authority, and escalate the unresolved conflict to a human — recording it as a
decision or open question.

## What an execution framework may and may not do

**May:** clarify implementation details, identify technical risks, propose
alternatives, break an approved work item into implementation subtasks, create
tests, and produce candidate evidence.

**May not:** change approved business scope, alter acceptance criteria without a
change request, downgrade the risk mode, mark QA / security / release approved,
deploy without human permission, or treat its own generated evidence as
automatically trusted.

## Per-framework notes

- [Superpowers](superpowers.md)
- [BMAD Method](bmad.md)
- [GitHub spec-kit](spec-kit.md)
- [OpenSpec](openspec.md)
- [Claude Code frameworks (custom / other)](claude-code-frameworks.md)
