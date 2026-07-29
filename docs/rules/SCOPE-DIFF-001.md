# SCOPE-DIFF-001 - Changed file outside approved implementation scope

| | |
|---|---|
| Level | FAIL (violation) / PASS (all changed files in scope) |
| Runs when | `-ScopeDiffBase` and `-ScopeDiffHead` are both supplied to `scripts/validate-project.ps1` |
| Artifacts | `SCOPE.json`, and every out-of-scope changed file individually |

## What this rule checks

Compares every file changed between the supplied base and head commits against the project's `SCOPE.json` `implementation_scope.include` patterns. A changed file that matches no include pattern (and is not a repo-wide exempt path — see `pmo-config/scope-diff-policy.json`) is a FAIL, one row per file, with `artifact` set to that file's path.

If every changed file matches an include pattern (or is exempt), the rule emits a single PASS row instead.

For a renamed file, both the old and new path are checked; if either is out of scope, the rename itself is the violation (see `docs/reference/scope-declaration.md` for the exact rename policy).

## Why it exists

An AI coding agent (or a human, for that matter) asked to implement one requirement can end up touching files that have nothing to do with it — a config file it didn't need to change, another team's module, a file it edited by mistake while exploring the codebase. SCOPE-DIFF makes that visible and, when `enforce: true`, blocking: the check compares a *pre-approved* list of paths against what the diff actually touched, deterministically, with no model in the loop deciding whether a file "seems related."

## This does not judge correctness

SCOPE-DIFF-001 says nothing about whether the code inside an in-scope file is right. It only answers: did this change stay inside the paths that were approved for it? A change can pass this rule and still be wrong; a change can fail this rule while being technically excellent. They are different questions.

## How to fix

- If the file genuinely belongs to this change, get `SCOPE.json`'s `implementation_scope.include` reviewed and widened to cover it — before merging, not as a reaction to the FAIL.
- If it does not belong, revert that file from this change and put it in the PR/requirement it actually belongs to.

## Related

`SCOPE-DIFF-002` (scope declaration missing), `SCOPE-DIFF-005` (excluded path changed), `docs/reference/scope-declaration.md`.
