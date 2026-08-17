# PATH-002 - Execution path declaration looks stale

| | |
|---|---|
| Level | WARN |
| Runs when | `node cli/axiom.mjs validate` is invoked, any gate |
| Artifacts | `PROJECT.md`, `DELIVERY.md`, `.execution/**` |

## What this rule checks

Only runs when the project's [`PATH-001`](PATH-001.md)-resolved execution path
is `development_handoff`. For every `.execution/<work-item-id>/` directory:

- **skipped** if there is no `EXECUTION-CONTRACT.json` in it (nothing was ever
  exported for that id);
- **skipped** if an `EXECUTION-RESULT.json` already exists next to it (the
  execution ran to completion -- whether it verified is `EXEC-*`'s question,
  not this rule's; a completed execution is resolved history either way);
- **skipped** if the work item's `Status` in `DELIVERY.md` is `Done`;
- **WARN**, naming the work item id, otherwise.

## Why it exists

A project that declares Development Handoff but has an *active, unresolved*
execution package on disk is probably out of date -- the AI execution path is
what is actually happening. The rule exists to surface that mismatch, not to
decide it: only a human knows whether the declaration should be corrected, the
execution should be verified and closed out (`axiom verify`), or the package
should be archived.

The predicate is deliberately narrow. An earlier design fired on file
existence alone, which meant a project that legitimately ran an AI execution
to completion and then moved to a vendor handoff -- a normal, real scenario --
would warn forever. Checking for an unresolved contract and a non-`Done` work
item, instead of "a contract exists somewhere," is what makes archived and
completed execution evidence exempt.

## How to fix

Either update `Execution path:` in `PROJECT.md` to `governed_ai_execution` if
that is in fact the current strategy, or resolve the execution package
(`axiom verify`) and mark the work item `Done` if it is finished.

## See also

- [`PATH-001`](PATH-001.md) -- the declaration itself.
- [`docs/concepts/execution-paths.md`](../concepts/execution-paths.md)
