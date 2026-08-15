# Human Authority

Some decisions are not the agent's to make. Axiom-PMO draws a hard line between
what an agent may *do* and what only a human may *authorize*.

## What an agent may never do on its own

- Commit, push, tag, deploy, or otherwise mutate git without explicit,
  per-action human confirmation.
- Approve a production release.
- Approve business scope.
- Mark QA or security review as passed on its own authority.
- Move any approval row from `pending` to `approved`.
- Close a semantic review finding that needs a business, legal, security, or
  commercial decision.
- Present a readiness score as a decision.

An agent **may** recommend the next gate. It **may not** approve its own work.

## Design Ready authority

`pmo-config/policy.json` is the runtime source of truth for approval roles. A
named human acting as a `Product Owner`, `Project Manager`, `Tech Lead`, or
`Solution Architect` may approve `Design Ready`. This is an authority matrix for
that one approval row; it does not let an AI approve the row, alter the Scope
Approved or Release Approved matrices, or replace a required QA, security, or
privacy review.

## Recommendation is not approval

1.1 gives an agent a larger role: it can perform a semantic handoff review, raise
findings, and recommend that development start. That widens the space in which
recommendation could be mistaken for authorization, so the boundary is drawn
explicitly.

| Artifact | What it is | What it is not |
|---|---|---|
| `HANDOFF-REVIEW.json` | Candidate evidence: what a reader found, with locations and owners | An approval. The `Design Ready` row in `PROJECT.md` remains the only sign-off the Handoff gate relies on |
| Readiness score | A summary of declared evidence, capped when that evidence is thin | A decision. No gate may be passed on the strength of a number |
| Stage verdicts | What the recorded findings imply about each stage | A commitment. A human decides whether to act on them |

An AI reviewer may close a finding when the artifacts show it was fixed, and must
cite the change. It may not close findings under the lenses listed in
`pmo-config/handoff-policy.json` `semantic_review.human_only_close_lenses` —
privacy classification and environment constraints — because those turn on
judgements about a specific jurisdiction, contract, or device that no document
in the repository can settle.

## Why this is a first-class control

The framework exists partly because these boundaries were once left in prose and
crossed anyway. The lesson: authorization is part of the specification, and
technical correctness does not imply permission to ship.

## How it is encoded

- `pmo-config/policy.json` declares that `commit`, `push`, and `tag` require
  human confirmation, and that production release requires human confirmation as
  a separate gate.
- The `pmo-git-safety` skill defines the pre-commit checklist and the
  per-action confirmation requirement.
- [`AGENTS.md`](../../AGENTS.md) Rules 10 and 11 state the boundary in
  behavioral terms.
- Approval and release validators reject unsupported or self-asserted approvals.
- `pmo-config/handoff-policy.json` `authority` declares that the Handoff gate
  introduces no new approval and that a semantic review is not one.
- `HANDOFF-010` checks only that a review exists, is complete, and is current. It
  never evaluates whether the findings were correct, and passing it grants
  nothing.

Related: [release readiness](../governance/release-readiness.md),
[source ownership](../governance/source-ownership.md).
