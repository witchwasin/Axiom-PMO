# EXEC-008 - Result cannot be reconciled with observed git state

| | |
|---|---|
| Level | FAIL |
| Runs when | `scripts/verify-execution-result.ps1` is invoked |
| Artifacts | `EXECUTION-RESULT.json`, or the undeclared changed file |

## What this rule checks

The result's claims against what the repository actually shows:

1. **`head_sha` is present** — without it nothing can be checked.
2. **Base and head both resolve** in this checkout.
3. **Head descends from the contract's base** (`git merge-base --is-ancestor`).
4. **Every file in the diff is declared** in the result's `changed_files`.

## Why it exists

This rule is where "execution output is a claim, not evidence" becomes mechanical. Each check turns a sentence the agent wrote into a question git can answer.

**Ancestry (check 3)** catches work that reports the approved base but was actually built somewhere else — an orphan branch, a different fork point, a reset. The commits are real and their SHAs resolve; they simply are not descended from what was approved. A digest match and a matching `base_sha` string both pass in that scenario; only ancestry catches it.

**Undeclared files (check 4)** is the interesting direction. `EXEC-004` already fails an out-of-scope file whether or not it was declared. This check adds the case where a changed file *is* in scope but was left out of the result — which is exactly what an omission would look like if a result were being economical with the truth. In-scope-ness does not excuse the omission.

Note that `.execution/**` is exempt (see `EXEC-004`), so the contract's own bookkeeping files do not have to be declared.

## Infrastructure failure vs. verdict

An unresolvable base or head produces verdict `git_error`, and the message says so. This is deliberately not reported as "the agent did something wrong": the comparison could not run, which is a different fact from the comparison failing. Most commonly it is a shallow clone that does not contain the base commit.

The same distinction `SCOPE-DIFF-003`/`004` draw against `SCOPE-DIFF-001`.

## How to fix

Report the actual base and head commits and the complete changed-file list:

```json
{
  "base_sha": "<the contract's base_sha, unchanged>",
  "head_sha": "<git rev-parse HEAD after the work>",
  "changed_files": ["src/payments/checkout.ts", "tests/payments/checkout.test.ts"]
}
```

For an unresolvable commit, fetch enough history for the base to be present (`fetch-depth: 0` in CI) and verify again.

For a failed ancestry check, the work needs rebasing onto the approved base — or a contract exported from the base it was actually built on.

## Related

`EXEC-004` (in the diff, outside approved paths), `EXEC-006` (git actions beyond the granted authority), `SCOPE-DIFF-004` (the equivalent infrastructure failure for pull-request scope checks).
