# Governance: Release Readiness

A release is not "ready" because an agent says so. It is ready when the recorded
evidence satisfies the release gate and a human has approved it.

## What the release gate checks

- **No open blockers** on in-scope work.
- **Work-item completion**: every in-scope item is `Done`, reviewed, and has
  resolvable test/evidence proof. Items intentionally left out must appear in the
  Release Scope table with a reason — silent omission is not allowed.
- **Test evidence**: Test Summary rows must be `passed` (or explicitly skipped
  with a reason), and their evidence must resolve.
- **QA / security review**: a structured review table, not the mere presence of
  the word "qa" somewhere in a file. Strict work requires QA **and** security.
- **Rollback**: a real rollback plan, or an explicit, policy-allowed waiver for
  eligible change types.
- **Traceability** (Strict): the `RTM.json` chain is complete.
- **Human approval**: recorded release approval from an authorized role.

## What an agent may and may not do

An agent may prepare all of the above and **recommend** that the work is ready.
It may **not** mark QA, security, or release approved on its own, and it may not
commit, push, tag, or deploy without explicit human confirmation. See
[human authority](../concepts/human-authority.md).

## Release readiness is not handoff readiness

These are different questions asked at different times, and conflating them is a
common way to arrive at a release gate with surprises in it.

| | Handoff gate | Release gate |
|---|---|---|
| Asks | Can a developer start, integrate, and demonstrate this? | Is the built thing tested, reviewed, approved, and reversible? |
| Timing | Before the work is built | After it is built |
| Approval | None of its own; reuses `Design Ready` | `Release Approved`, plus QA and (Strict) security |
| Evidence | Declared contract plus a semantic review | Executed tests, reviews, and rollback |

The Handoff gate can report `Ready for Release: NO` while a project is still
weeks from release — that verdict reflects *recorded findings blocking that
stage*, not the outcome of the release gate. Only the Release gate decides
release. See [handoff readiness](../concepts/handoff-readiness.md).

## Enforcement

The release validator raises `BLOCKER-*`, `RELEASE-*`, `TEST-*`,
`QA-REVIEW-*`, `SECURITY-REVIEW-*`, and (for Strict) aggregate guardrail rules;
`fail_release` severities block the Release gate. The Handoff gate raises
`HANDOFF-*` and is never a substitute for any of them. See the
[validation engine](../architecture/validation-engine.md).
