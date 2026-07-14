# Using Axiom-PMO with Superpowers

[Superpowers](https://github.com/obra/superpowers) is an execution-focused
workflow for AI coding agents (planning, test-driven development, implementation,
self-review, and verification). Its strengths are complementary to Axiom-PMO's,
which makes it a useful reference integration.

> This document describes the integration at the responsibility and contract
> level. It does not assume a specific Superpowers version, install method, or
> internal file layout — consult Superpowers' own documentation for those.

## Responsibility model

```
Axiom-PMO   → source, requirements, scope, risk, approvals, evidence policy, release authority
Superpowers → implementation planning, TDD, coding, code review, engineering verification
```

## A safe workflow

```
Approved Axiom-PMO work item
  → Execution contract (what, refs, acceptance criteria, out-of-scope, allowed paths, git authority)
  → Superpowers planning
  → TDD and implementation
  → Superpowers self-review and verification
  → Structured result package (changed files, tests, reviews, deviations, evidence)
  → Axiom-PMO evidence validation
  → QA / security gate
  → Human release approval
```

## What Superpowers may do

- Clarify implementation details and identify technical risks.
- Propose alternative implementations.
- Break an approved work item into implementation subtasks.
- Write and run tests.
- Produce candidate evidence.

## What Superpowers may not do

- Change approved business scope.
- Modify acceptance criteria without a change request.
- Downgrade the risk mode.
- Mark QA, security, or release approved.
- Deploy or perform git mutations without explicit human permission.
- Treat its self-generated evidence as automatically trusted.

## Experimental contract package

A generic, framework-agnostic contract and result shape is provided under
[`integrations/superpowers/`](../../integrations/superpowers/):

- `EXECUTION-CONTRACT.template.json` — the work package Axiom-PMO hands to the
  execution framework (Level 2).
- `EXECUTION-RESULT.schema.json` — the structured result the framework returns
  (Level 3).
- `integration-policy.json` — the authority boundaries the bridge must enforce.

These are **experimental** and **not wired into the validator runtime**. They
document the intended shape so an integration can be built and reviewed. The name
"Superpowers" here marks the reference use case; the shapes themselves are
framework-neutral and apply equally to BMAD, spec-kit, OpenSpec, or a custom
Claude Code agent.
