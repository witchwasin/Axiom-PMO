# SCOPE-DIFF dogfood fixture — pass case

This directory exists as CI data, not as something to run. The
`dogfood-scope-diff` job in `.github/workflows/pmo-checks.yml` validates it
with SCOPE-DIFF enabled, comparing two fixed, hard-coded commit SHAs from
this branch's own history — not the branch point and not `HEAD` at CI
run time. Diffing all the way from the branch point would also pull in
every unrelated file M4.5's own implementation touched; diffing a
narrow, purpose-built delta commit keeps this fixture's proof isolated to
exactly the files it declares.

`SCOPE.json` declares `demo/scope-diff-dogfood-pass/**` as the approved
implementation scope — its own entire directory. The delta commit the
workflow diffs against only ever touches `src/app.ts` inside that
directory, so this case proves the **pass** path: real SCOPE-DIFF
evaluation, real git history, no findings.

`PROJECT.md` exists purely so this fixture passes Draft-gate structural
validation (`STRUCT-001`) on its own merits — the dogfood job's enforced
step has no `continue-on-error`, so an unrelated structural finding would
fail the job for the wrong reason and mask whether SCOPE-DIFF itself
behaved correctly.

See `../scope-diff-dogfood-fail/` for the matching case that is expected to
fail.
