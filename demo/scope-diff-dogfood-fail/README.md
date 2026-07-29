# SCOPE-DIFF dogfood fixture — fail case

CI data, not something to run — see `../scope-diff-dogfood-pass/README.md`
for the full explanation of how the `dogfood-scope-diff` job uses this pair
of fixtures.

`SCOPE.json` here declares only `demo/scope-diff-dogfood-fail/src/**` as
approved — deliberately narrower than the whole directory. **This file
itself is the violation**: `README.md` sits outside `src/`, so it is not
covered by the approved scope. Its presence in the diff between
`31d1e254216aaf1112a92c01fd3b42f12d3a2468` and the commit CI is running is
exactly what the `dogfood-scope-diff` job expects to see flagged as
`SCOPE-DIFF-001`, proving the enforcement path actually blocks a real
out-of-scope change rather than a synthetic one.
