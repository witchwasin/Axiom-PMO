# Tutorial: Using Axiom-PMO with an AI Agent

Axiom-PMO is designed to be run *by* an AI agent, with a human holding authority.
This tutorial shows the intended loop.

## 1. Point the agent at the behavior rules

The agent should read [`AGENTS.md`](../../AGENTS.md) (behavioral rules) and
[`CLAUDE.md`](../../CLAUDE.md) (the intent router that maps a request to the right
skill and mode). Skills load on demand — never all at once.

## 2. Intake

Ask the agent to turn source material into scoped, referenced requirements
(`pmo-intake`). It should separate `Confirmed`, `Assumption`, and `Open
Question`, and never invent requirements, actors, dates, or approvals.

## 3. Design and delivery

For flows or UI, `pmo-design` produces design artifacts and design-ready
acceptance criteria. `pmo-delivery` breaks approved scope into work items with a
single declared task source of truth (`DELIVERY.md` or GitHub Issues, never
both).

## 4. Hand implementation to an execution framework (optional)

If you use an AI execution framework (Superpowers, BMAD, spec-kit, OpenSpec, or a
custom Claude Code setup), Axiom-PMO provides the approved work item, acceptance
criteria, out-of-scope list, allowed paths, and git authority as an execution
contract. The framework's output returns as **candidate evidence**. See the
[interoperability overview](../integrations/overview.md).

## 5. Validate, review, release

`pmo-build-review` and `pmo-quality-release` check that build and QA evidence are
real and resolvable. The agent may **recommend** the next gate but may not
approve its own work, and may not commit, push, tag, or deploy without explicit
human confirmation (`pmo-git-safety`). See
[human authority](../concepts/human-authority.md).

## The golden rule

The agent's job is to make the evidence and the recommendation clear. **The human
authorizes.** If an agent ever reports work as shipped or approved without a
human doing so, treat it exactly as the framework does — as an unverified claim.
See [the case study](../../case-studies/unauthorized-git-mutation.md).
