# PATH-001 - Execution path declaration

| | |
|---|---|
| Level | INFO (missing) / WARN (unrecognized) / PASS (valid) |
| Runs when | `node cli/axiom.mjs validate` is invoked, any gate |
| Artifacts | `PROJECT.md` |

## What this rule checks

`PROJECT.md`'s `Execution path:` line, read the same way `Default mode:` is:
a plain-text field just below the title.

- **Missing** -- INFO. `execution_path` defaults to `development_handoff`, the
  core product's own default, so every project that predates this field keeps
  validating exactly as it did before.
- **Present but not `development_handoff` or `governed_ai_execution`** -- WARN.
- **Present and valid** -- PASS.

## Why it exists

Axiom-PMO supports two ways a piece of work gets built: a **Development
Handoff** to a human developer or vendor, or a **Governed AI Execution** using
`axiom export` / `axiom run` / `axiom verify`. Both paths already existed as
working engines before this rule; nothing named them, and nothing recorded
which one a given project was actually on. See
[`docs/concepts/execution-paths.md`](../concepts/execution-paths.md).

The declaration is a statement of **current delivery strategy, not project
identity** -- a project may switch paths with an ordinary edit to `PROJECT.md`.
A declared path may only ever *add* required artifacts relative to the
Mode x Gate matrix in `pmo-config/artifact-policy.json`, never remove any; this
rule does not itself add any required artifact.

## How to fix

Set `Execution path:` in `PROJECT.md` to `development_handoff` or
`governed_ai_execution`. `axiom init`'s interactive prompt asks this directly
so a new project starts with a valid declaration.

## See also

- [`PATH-002`](PATH-002.md) -- whether that declaration still matches an active
  execution package on disk.
- [`docs/concepts/execution-paths.md`](../concepts/execution-paths.md)
