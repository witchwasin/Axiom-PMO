# SCOPE-DIFF dogfood fixture — fail case

CI data, not something to run — see `../scope-diff-dogfood-pass/README.md`
for the full explanation of how the `dogfood-scope-diff` job uses this pair
of fixtures, including why the workflow diffs two fixed commit SHAs from
this branch's own history rather than the branch point or `HEAD`.

`SCOPE.json` here declares only `demo/scope-diff-dogfood-fail/src/**` as
approved — deliberately narrower than the whole directory. **This file
itself is the violation**: this edit to `README.md` sits outside `src/`,
so it is not covered by the approved scope. Its presence in the diff
between the workflow's two hard-coded fail-case SHAs is exactly what the
`dogfood-scope-diff` job expects to see flagged as `SCOPE-DIFF-001`,
proving the enforcement path actually blocks a real out-of-scope change
rather than a synthetic one.

`PROJECT.md` exists purely so this fixture passes Draft-gate structural
validation (`STRUCT-001`) on its own merits — without it, the enforced
step here would fail for a mix of reasons instead of exactly the one
SCOPE-DIFF-001 finding the job asserts on.

Edited to produce the fail-case delta commit referenced by the dogfood-scope-diff workflow job.
