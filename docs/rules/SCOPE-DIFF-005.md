# SCOPE-DIFF-005 - Excluded path changed

| | |
|---|---|
| Level | FAIL |
| Runs when | `-ScopeDiffBase` and `-ScopeDiffHead` are both supplied |
| Artifacts | every excluded-but-changed file individually |

## What this rule checks

A changed file matches an `implementation_scope.exclude` pattern in `SCOPE.json`.

## How this differs from SCOPE-DIFF-001

`SCOPE-DIFF-001` fires for a file that was never approved at all. `SCOPE-DIFF-005` fires for a file that sits *inside* a broader approved area but was explicitly carved back out — for example:

```json
{
  "implementation_scope": {
    "include": ["src/payments/**"],
    "exclude": ["src/payments/generated/**"]
  }
}
```

A change to `src/payments/generated/client.ts` matches `include` (it's under `src/payments/**`) but also matches `exclude`, so it fails as SCOPE-DIFF-005, not as a plain out-of-scope file. Exclude always wins over include and over a repo-wide exemption — see `docs/reference/scope-declaration.md`'s precedence section.

The distinct rule id matters for triage: an out-of-scope file (001) usually means the change wandered somewhere unrelated; an excluded file (005) usually means someone is trying to touch something the team already decided, in this same scope declaration, should not be touched as part of this work.

## How to fix

If the exclusion is still correct, this file should not be part of this change — remove it. If the exclusion is now wrong (the team's understanding changed), get the exclude entry itself reviewed and removed or narrowed through the same process that approved the scope, rather than working around the FAIL.

## Related

`SCOPE-DIFF-001` (outside approved scope entirely), `docs/reference/scope-declaration.md`.
