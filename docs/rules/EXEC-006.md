# EXEC-006 - Execution exceeded the granted git authority

| | |
|---|---|
| Level | FAIL |
| Runs when | `node cli/axiom.mjs verify` is invoked |
| Artifacts | `EXECUTION-CONTRACT.json`, `EXECUTION-RESULT.json` |

## What this rule checks

Three ways an execution can exceed what the contract granted:

1. **Observed commits without commit authority.** `git rev-list base..head` returns commits, but `git_authority.commit` is `false`.
2. **Observed push without push authority.** The head commit is present on a remote-tracking ref, but `git_authority.push` is `false`.
3. **Self-reported ungranted actions.** The result's `git_actions_performed` names an action the contract did not grant.

`git_authority` defaults to `create_branch: true` and everything else `false`. An action is permitted only when the approved contract explicitly grants it; absent or `false` means not granted.

## Why it exists

Checks 1 and 2 are **observed**, not self-reported: commits existing between base and head is evidence a commit happened, whether or not the result admits to it. Check 3 catches the converse — a result honest enough to admit an action this checkout cannot independently see.

Together they mean an agent cannot escape the check by lying *or* by omission.

### The tri-state that matters

Push detection returns three states, not two:

| State | Meaning |
|---|---|
| `true` | a remote-tracking ref contains this commit — real evidence of a push |
| `false` | no remote-tracking ref contains it, in **this** checkout |
| `null` | cannot be determined; no remote-tracking refs exist here at all |

Only `true` raises this rule. `false` and `null` are both treated as "not observed", never as proof a push did not happen — collapsing them would let a remote-less or shallow checkout silently report a push as not-having-happened.

**This MVP does not prove the absence of git side effects.** A push to a remote this checkout does not know about, a force-moved remote ref, or a branch pushed then deleted cannot be disproven from local state. That limit is stated in `pmo-config/execution-contract-policy.json` and in [`docs/reference/execution-contract.md`](../reference/execution-contract.md) rather than left for a user to discover.

## How to fix

Grant the authority **before** the work runs, not after:

```bash
axiom export --project <path> --work-item D-001 --grant commit
```

`--grant` re-exports the whole contract and mints a new digest, so the grant is visible in the artifact a human reviews and in the file's identity. Editing `git_authority` in an exported contract instead is reported by `EXEC-002` as tampering.

If the action was genuinely not authorized, the finding is correct: reset the work, get the grant reviewed, and re-run.

## Related

`EXEC-002` (widening authority by editing the contract), `EXEC-007` (claiming approval authority rather than git authority).
