# Using Axiom-PMO with Claude Code frameworks

This page covers interoperability with Claude Code itself and with custom or
third-party Claude Code configurations — skills, subagents, hooks, MCP tools,
plugins, and bespoke `CLAUDE.md` / `AGENTS.md` systems — that are not covered by
a dedicated integration page.

> Described at the architecture/contract level. Because these configurations vary
> widely, this page defines the precedence and boundaries rather than specific
> commands.

## Configuration precedence

A repository may carry several sources of instruction at once. When they
conflict, resolve in this order (more restrictive safety rule wins):

1. Human instruction.
2. Axiom-PMO safety and approval policies.
3. The project-specific approved contract.
4. Repository `AGENTS.md` / `CLAUDE.md`.
5. External execution-framework instructions.
6. Individual skill instructions.
7. Agent defaults.

## Conflict handling

If two frameworks disagree, an agent must:

- choose the more restrictive rule;
- not expand scope;
- not weaken evidence requirements;
- not grant additional git authority;
- escalate the unresolved conflict to a human; and
- record the conflict as a decision or an open question.

## Practical setup

- Keep Axiom-PMO's `AGENTS.md` as the behavioral source of truth; let other
  frameworks' instructions layer *below* it.
- Axiom-PMO ships no hooks and requires none; its enforcement is the PowerShell
  validator, not settings hooks. If you add Claude Code hooks, they must not
  grant git authority or bypass approval gates.
- Skills load on demand (see [`AGENTS.md`](../../AGENTS.md)); a custom skill must
  not instruct the agent to commit, push, tag, deploy, or self-approve.

## Interoperability level

- **Level 0–1** today by convention: run your Claude Code setup and have it read
  Axiom-PMO's approved artifacts before acting.
- **Level 2–3** can use the framework-neutral contract and result shapes in
  [`integrations/superpowers/`](../../integrations/superpowers/).
- **Level 4** is roadmap.

See the [interoperability overview](overview.md) for the full model and level
definitions.
