# SCOPE-DIFF dogfood fixture — pass case

This directory exists as CI data, not as something to run. The
`dogfood-scope-diff` job in `.github/workflows/pmo-checks.yml` validates it
with SCOPE-DIFF enabled, comparing `31d1e254216aaf1112a92c01fd3b42f12d3a2468`
(the commit `m4.5-scope-diff` branched from) against the commit CI is
currently running.

`SCOPE.json` declares `demo/scope-diff-dogfood-pass/**` as the approved
implementation scope — its own entire directory. Every file this fixture
ever needs is therefore always in scope by construction, so this case
proves the **pass** path: real SCOPE-DIFF evaluation, real git history, no
findings.

See `../scope-diff-dogfood-fail/` for the matching case that is expected to
fail.
