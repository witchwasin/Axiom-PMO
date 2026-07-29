# PROJECT - SCOPE-DIFF-DOGFOOD-FAIL

> Status: draft
> Default mode: Standard
> Task source: file
> Owner: Axiom-PMO maintainers
> Last updated: 2026-07-29

## Source Snapshot

| Source ID | Version / Date | Last Synced At |
|---|---|---|
| N/A | n/a | 2026-07-29T00:00:00+07:00 |

## Summary

CI fixture data for the `dogfood-scope-diff` job in
`.github/workflows/pmo-checks.yml`. Not a real project — this file exists
only so the fixture has valid Draft-gate structure independent of
SCOPE-DIFF, so the dogfood job's enforced-and-failing case fails for
exactly one reason: a real SCOPE-DIFF violation, not this fixture's
paperwork. See `README.md` for what this fixture actually proves.

## Scope

### In Scope

Not applicable — this directory is CI test data with no requirements.

### Out of Scope

- Everything except serving as a SCOPE-DIFF dogfood fixture.
