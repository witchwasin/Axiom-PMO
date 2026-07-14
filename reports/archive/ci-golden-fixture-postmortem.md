# CI Golden Fixture Postmortem

> Historical record.
> This incident was resolved before the public 1.0.0 release.

## Fixture File Missing On CI Checkout

- **Date found:** 2026-07-13
- **Status:** RESOLVED 2026-07-13 in commit `<commit>` (gitignore negation + tracked the fixture placeholder)

### Symptom

The `Verify golden master` CI step fails with exactly 1 mismatch:

```
Golden master verification FAILED (1 mismatch(es)):
  - others-and-sensitive-source-do-not-fail-release: output differs from golden master
```

### Root cause (confirmed)

A synthetic sensitive-source fixture existed locally but was not tracked by git.
It matched the repository's sensitive-file `.gitignore` pattern, so it was absent
on a fresh CI checkout. The validator's `SENSITIVE-001` informational result did
not appear, and the output no longer matched the golden master captured locally.

The file itself was a synthetic placeholder, not a real spreadsheet. The
fixture's purpose was to prove that sensitive-looking files in user-owned source
do not block release.

### Root Cause

The fixture intentionally looked sensitive, but the repository needed one scoped
exception so that CI could check out the synthetic placeholder. Local checks
passed because the untracked local file existed; CI failed because a clean
checkout correctly omitted it.

### Resolution

- Added a scoped `.gitignore` negation for the one synthetic fixture path.
- Tracked the placeholder fixture.
- Confirmed the framework doctor still accepted the sensitive-file protection
  patterns after the scoped exception.
- Re-ran golden-master verification.

### Regression Protection

- Golden-master verification runs in CI.
- `PERMISSION-007` verifies that sensitive-file ignore patterns remain precise.
- The fixture proves that sensitive-looking files in user-owned source are
  reported without blocking release.

### Context / history

- The first CI failure in this area was a separate portability bug: validator JSON
  embedded the absolute repository path, which differs between local clones and
  hosted runners. That was fixed by normalizing the repo root to `<REPO_ROOT>`.
- After path normalization, this fixture-file issue was the remaining mismatch.

### Final Status

Resolved. The fix was included before public release and is covered by CI.
