# EXEC-004 - Changed file outside the contract's approved paths

| | |
|---|---|
| Level | FAIL |
| Runs when | `scripts/verify-execution-result.ps1` is invoked |
| Artifacts | the offending changed file |

## What this rule checks

Every file changed between the contract's `base_sha` and the result's `head_sha` — as reported by `git diff`, not as claimed by the result — is either:

- inside `allowed_paths`, and
- not inside `prohibited_paths`.

A path matching `prohibited_paths` fails even when it also matches `allowed_paths`: the carve-out is the more specific, more recently reviewed decision.

## Why it exists

This is the execution-side twin of `SCOPE-DIFF-001`, and it reuses the same glob engine, the same precedence rules, and the same case-sensitivity behaviour (`scripts/lib/scope-diff-matcher.ps1`) rather than reimplementing them — one matching engine, one set of rules a reader has to learn.

Two properties worth knowing:

- **Paths come from the diff, not from the result.** A file the agent changed but did not declare is still checked. Self-reported file lists are a claim; the diff is evidence.
- **Matching is case-sensitive.** `SRC/PAYMENTS/x.ts` does not satisfy `src/payments/**`. On a case-sensitive checkout those are different files, and treating them as the same would be a scope bypass rather than a formatting nicety.

The contract's `allowed_paths` are derived from the project's approved `SCOPE.json` at export time, so a contract can never grant an agent broader path freedom than the reviewed scope declaration does.

## Exempt paths

`.execution/**` is excluded from this check, per `pmo-config/execution-contract-policy.json`'s `verification_exempt_paths`. The contract, its digest sidecar, and the result itself are governance bookkeeping committed for the audit trail — they necessarily appear in the diff being verified, and counting them as unapproved implementation would make every verification fail on its own artifacts.

They are **not** exempt from `EXEC-006`: committing a bookkeeping file is still a commit.

## How to fix

Either the change belongs to different work — move it to its own work item and contract — or the approved scope genuinely needs widening. In that case update `SCOPE.json`, get it reviewed, and re-export the contract.

Do not widen `allowed_paths` in an already-approved contract; `EXEC-002` reports that as tampering, correctly.

## Related

`SCOPE-DIFF-001` (the same question for a pull request), `EXEC-008` (changed file the result failed to declare), `EXEC-003` (right files, wrong work item).
