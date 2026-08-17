# SCOPE-DIFF-002 - Approved implementation scope missing

| | |
|---|---|
| Level | FAIL |
| Runs when | `-ScopeDiffBase` and `-ScopeDiffHead` are both supplied to `node cli/axiom.mjs validate` |
| Artifacts | `SCOPE.json` |

## What this rule checks

SCOPE-DIFF was explicitly requested for this project (a base and head commit were supplied) but no `SCOPE.json` exists at the project root.

## Why it exists

A missing scope declaration is never treated as "no restriction, everything is approved." That would make the check silently do nothing exactly when it was asked to do something — the one behavior worse than a check that is too strict. If scope enforcement is turned on for a project, that project must say what its scope is.

## How to fix

Create `SCOPE.json` from `templates/SCOPE.json`:

```json
{
  "schema_version": "1.0",
  "project": "<PROJECT-CODE>",
  "implementation_scope": {
    "include": ["src/<area>/**"],
    "exclude": []
  }
}
```

See `docs/reference/scope-declaration.md` for the full pattern syntax.

## Related

`SCOPE-DIFF-001` (out-of-scope change, once a declaration exists), `SCOPE-DIFF-003` (declaration present but invalid).
