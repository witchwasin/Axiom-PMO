# SCOPE-DIFF-003 - Invalid scope declaration

| | |
|---|---|
| Level | FAIL |
| Runs when | `-ScopeDiffBase` and `-ScopeDiffHead` are both supplied, and `SCOPE.json` exists |
| Artifacts | `SCOPE.json` |

## What this rule checks

`SCOPE.json` exists but fails schema validation. Any of the following trips this rule:

- The file is not valid JSON.
- `implementation_scope` is missing.
- `implementation_scope.include` is missing, or is an empty list (an empty include list would make every changed file a violation by construction — almost certainly a mistake, not an intentional "approve nothing").
- `implementation_scope.exclude` is present but is not a list.
- Any include or exclude entry is not a string.
- Any pattern fails syntax validation: starts with `/` (patterns are already repo-root-relative), contains a backslash (paths are always forward-slash, even on Windows), or contains a `..` segment.

This is a fail-closed check, deliberately: an unreadable or malformed scope declaration is treated the same as "the scope check could not run," never silently skipped or treated as a pass.

## How to fix

Compare `SCOPE.json` against `templates/SCOPE.json` and the pattern rules in `docs/reference/scope-declaration.md`. The diagnostic's `message` names the specific problem found.

## Related

`SCOPE-DIFF-002` (declaration missing entirely), `docs/reference/scope-declaration.md`.
