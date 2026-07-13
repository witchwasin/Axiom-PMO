# Pending Issues

> Issues found but deliberately deferred. Fix these before (or when) merging the affected PR.

## PI-001: PR #3 CI fails — golden-master fixture file missing on CI checkout

- **Date found:** 2026-07-13
- **Status:** RESOLVED 2026-07-13 in commit `71305b5` (gitignore negation + tracked the fixture placeholder)
- **PR:** https://github.com/witchwasin/PMO-Template-Personal/pull/3 (branch `hardening/0.5.x`)

### Symptom

The `Verify golden master` CI step fails with exactly 1 mismatch:

```
Golden master verification FAILED (1 mismatch(es)):
  - others-and-sensitive-source-do-not-fail-release: output differs from golden master
```

### Root cause (confirmed)

`tests/fixtures/valid-source-others-and-sensitive/source/Quotation.xlsx` exists locally
but is **not tracked by git** — it is excluded by `.gitignore:84` (`**/*Quotation*.xlsx`,
a sensitive-file protection pattern). On a fresh CI checkout the file is therefore
missing, so the validator's `SENSITIVE-001` informational result
("Potential sensitive filenames in user-owned source ... source\Quotation.xlsx")
does not appear, and the output no longer matches the golden master captured locally.

The file itself is a synthetic 29-byte ASCII placeholder ("fake spreadsheet
placeholder"), not a real spreadsheet — the fixture's purpose is to prove that
sensitive-looking files in user-owned source do not block release.

### Fix already identified (not applied — owner deferred)

1. Append a scoped negation to `.gitignore` (must come after the `**/*Quotation*.xlsx` pattern):
   ```
   # Test fixture exception: synthetic 29-byte placeholder, not a real spreadsheet.
   # The sensitive-source fixture needs this file present on CI checkouts.
   !tests/fixtures/valid-source-others-and-sensitive/source/Quotation.xlsx
   ```
2. `git add tests/fixtures/valid-source-others-and-sensitive/source/Quotation.xlsx`
3. Commit, push to `hardening/0.5.x`, confirm CI green on PR #3, then merge.
4. Sanity-check `pmo-doctor.ps1` still passes PERMISSION-007 (gitignore pattern check)
   after the negation — it passed locally before the change was reverted, and the
   negation only affects a test-fixture path.

### Context / history

- First CI failure on PR #3 (86/86 mismatches) was a different bug: the validator's
  JSON output embeds the absolute repo path, which differs between local clones and
  GitHub runners. Fixed in commit `da8d835` (`<REPO_ROOT>` placeholder normalization).
- After `da8d835`, CI improved to 85/86 matching; this fixture-file issue is the
  only remaining failure.
- All checks pass locally (full suite PASS=29 WARN=0 FAIL=0, golden 86/86,
  doctor PASS=52) because the untracked file exists on the local machine.
