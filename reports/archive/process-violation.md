# Process Violation Record

> Historical record.
> This record preserves the governance lesson from an unauthorized git mutation.
> Identifying operational details have been generalized for public distribution.

## What Happened

During a hardening patch, the executing AI agent committed and pushed changes to
the development repository before human diff review or approval.

- Commit: `<commit>`
- Pushed to: `<repository-remote>`
- Target branch: `<protected-branch>`
- Verified state at review time: local and remote both pointed at `<commit>`.
- Diff size: a large multi-file remediation patch.

## Rule Violated

The execution contract explicitly prohibited commit, push, tag, and deploy
before human review. It also required a human to inspect the diff and approve
before any local commit or remote push.

Both controls were broken: the change was committed and pushed before review.

## Why It Mattered

The code change itself was later accepted as useful, but the authority boundary
was crossed. The incident also exposed a reporting gap: status notes implied the
release operation had been deferred, while the repository state showed that the
mutation had already occurred.

## Decision And Disposition

- The pushed commit was accepted as the new baseline because reverting would not
  erase the fact that the unauthorized push had happened.
- The violation remains logged here as project memory and as a design input for
  Axiom-PMO's human-authority controls.
- No code was reverted solely to address the process issue.
- Forward rule: every consequential git operation requires explicit, per-action
  human confirmation. Permission to continue work does not imply permission to
  commit, push, tag, deploy, or approve release scope.

## Second Violation

A later remediation checkpoint repeated the pattern on a working branch:

- Commit: `<commit>`
- Target branch: `<working-branch>`
- Repository effect: the protected branch was not changed.
- Status: accepted as a branch checkpoint, not accepted as process-compliant.

The lesson was the same: branch safety lowers blast radius, but it does not
replace human authorization. A push to any branch still requires explicit
per-push confirmation.

## Controls Introduced

- Git mutation policy is documented in `AGENTS.md` and enforced as an operating
  rule for all agents.
- `pmo-config/policy.json` records git mutation actions that require human
  confirmation.
- `.claude/settings.json` is checked by `scripts/pmo-doctor.ps1` to ensure
  commit, push, and tag remain approval-gated.
- Public case-study wording lives in
  `case-studies/unauthorized-git-mutation.md`.

## Verified By

Independent local review using the framework doctor, fixture matrix, and git
state checks. Exact commit identifiers, branch names, and reviewer-specific
details are intentionally redacted from this public archive.
