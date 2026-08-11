# SCOPE-DIFF dogfood fixture — pass case

This directory exists as CI data, not as something to run. The
`dogfood-scope-diff` job in `.github/workflows/pmo-checks.yml` validates it
with SCOPE-DIFF enabled, against a narrow delta commit the job builds in its
own checkout at run time — not the branch point and not `HEAD` as checked
out. Diffing all the way from the branch point would also pull in every
unrelated file a real change touched; a purpose-built delta commit keeps
this fixture's proof isolated to exactly the files it declares.

The job builds that commit itself rather than pointing at a fixed SHA. An
earlier version pinned three SHAs authored on a milestone branch; when those
branches stopped existing on `origin` the commits became unreachable and
every run failed with `SCOPE-DIFF-004`, because no `fetch-depth` can fetch a
commit that no ref points at. Building the delta in-job removes the
dependency on repository history while keeping what matters: SCOPE-DIFF still
evaluates a real `git diff` between two real commits, and the job asserts the
delta touches exactly the one file described below before using it.

`SCOPE.json` declares `demo/scope-diff-dogfood-pass/**` as the approved
implementation scope — its own entire directory. The delta commit the
workflow diffs against only ever touches `src/app.ts` inside that
directory, so this case proves the **pass** path: real SCOPE-DIFF
evaluation, real commits, no findings.

`PROJECT.md` exists purely so this fixture passes Draft-gate structural
validation (`STRUCT-001`) on its own merits — the dogfood job's enforced
step has no `continue-on-error`, so an unrelated structural finding would
fail the job for the wrong reason and mask whether SCOPE-DIFF itself
behaved correctly.

See `../scope-diff-dogfood-fail/` for the matching case that is expected to
fail.
