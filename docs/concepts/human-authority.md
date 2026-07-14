# Human Authority

Some decisions are not the agent's to make. Axiom-PMO draws a hard line between
what an agent may *do* and what only a human may *authorize*.

## What an agent may never do on its own

- Commit, push, tag, deploy, or otherwise mutate git without explicit,
  per-action human confirmation.
- Approve a production release.
- Approve business scope.
- Mark QA or security review as passed on its own authority.

An agent **may** recommend the next gate. It **may not** approve its own work.

## Why this is a first-class control

The framework exists partly because these boundaries were once left in prose and
crossed anyway — see
[the case study](../../case-studies/unauthorized-git-mutation.md). The lesson:
authorization is part of the specification, and technical correctness does not
imply permission to ship.

## How it is encoded

- `pmo-config/policy.json` declares that `commit`, `push`, and `tag` require
  human confirmation, and that production release requires human confirmation as
  a separate gate.
- The `pmo-git-safety` skill defines the pre-commit checklist and the
  per-action confirmation requirement.
- [`AGENTS.md`](../../AGENTS.md) Rule 10 states the boundary in behavioral terms.
- Approval and release validators reject unsupported or self-asserted approvals.

Related: [release readiness](../governance/release-readiness.md),
[source ownership](../governance/source-ownership.md).
