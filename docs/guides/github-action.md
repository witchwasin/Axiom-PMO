# GitHub Action

Axiom-PMO ships as a composite GitHub Action (`action.yml` at the repository
root) so a consumer repository can run the governance validator inside a pull
request without installing PowerShell locally. The Action wraps the same
`scripts/validate-project.ps1` reference validator that `cli/axiom.mjs`
wraps -- it adds no validation rules of its own. See
[diagnostics-contract.md](../reference/diagnostics-contract.md) for the JSON
shape both surfaces read.

## Quick start

```yaml
name: Axiom-PMO

on:
  pull_request:

jobs:
  governance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: witchwasin/Axiom-PMO@<pinned-sha-or-tag>
        with:
          project: projects/P01-ABC
          mode: Standard
          gate: Release
```

GitHub-hosted `ubuntu-latest`, `windows-latest`, and `macos-latest` runners
already ship PowerShell 7. The Action does not install a runtime; it finds
the one already on the runner, the same way `cli/axiom.mjs` finds one
locally.

## Report-only by default

`enforce` defaults to `false`. A run with real FAIL or blocking-WARN findings
still reports them in full -- Job Summary, PR annotations, and the
JSON/Markdown report artifact -- but the workflow step itself exits `0`. A
first install cannot break a pull request nobody has configured a rule set
for yet.

Set `enforce: "true"` once your team has read a few report-only runs and
wants the check to actually block:

```yaml
      - uses: witchwasin/Axiom-PMO@<pinned-sha-or-tag>
        with:
          project: projects/P01-ABC
          gate: Release
          enforce: "true"
```

This default does not soften an infrastructure failure. If no PowerShell
host is found on the runner (exit code `127`) or the Action receives a bad
input, the step fails regardless of `enforce` -- a silently-passing check
that never actually ran would be worse than one that fails loudly.

## Inputs

| Input | Required | Default | Meaning |
|---|---:|---|---|
| `project` | yes | -- | Project path to validate, relative to the job's working directory (or absolute). |
| `mode` | no | `Standard` | Requested PMO mode: `Lite`, `Standard`, or `Strict`. |
| `gate` | no | `Release` | Validation gate: `Draft`, `Scope`, `Design`, `Handoff`, or `Release`. |
| `fail-on-warning` | no | `true` | Whether a blocking `WARN` counts toward the governance verdict (validator exit `2` instead of `0`). This is independent of `enforce` -- it changes what the validator decides, not whether the Action step propagates that decision. |
| `working-directory` | no | `.` | Directory the Action resolves `project` and report paths from. |
| `upload-artifact` | no | `true` | Whether to upload `axiom-report.json` and `axiom-report.md` as a workflow artifact. |
| `artifact-name` | no | `axiom-pmo-report` | Name for the uploaded artifact. `actions/upload-artifact` v4 rejects a second artifact with the same name in one workflow run, so give each call a distinct name if this Action runs more than once in the same run (a matrix of projects, or a report-only pass and an enforced pass). |
| `annotation-mode` | no | `safe` | `safe` emits sanitized `FAIL`/`WARN` annotations on the pull request; `off` emits none. |
| `enforce` | no | `false` | Whether a governance verdict fails the workflow step. See "Report-only by default" above. |
| `enable-scope-diff` | no | `false` | Compare changed files against the project's approved `SCOPE.json`. Off by default -- this Action's behavior is unchanged unless a workflow opts in. See `docs/reference/scope-declaration.md`. |
| `scope-diff-base` | no | (empty) | Base commit SHA for SCOPE-DIFF. Overrides the `pull_request` event's base/head pair when **both** `scope-diff-base` and `scope-diff-head` are set; required on any other event. Setting only one of the two is treated as setting neither -- it falls back to the `pull_request` event (or, on any other event, to an actionable `SCOPE-DIFF-004`), never to a half-overridden pair. |
| `scope-diff-head` | no | (empty) | Head commit SHA for SCOPE-DIFF. See `scope-diff-base` -- the two are only ever honoured as an explicit pair. |

## Outputs

| Output | Meaning |
|---|---|
| `exit-code` | The underlying validator's exit code: `0` pass, `1` fail, `2` blocking warning, `127` no PowerShell host. |
| `outcome` | `success`, `failure`, `warning`, or `runtime-missing`. Reflects the real result even in report-only mode, so a later step can branch on it. |
| `json-report` | Path to `axiom-report.json`. |
| `markdown-report` | Path to `axiom-report.md`. |
| `scope-diff-verdict` | `pass`, `fail`, `scope_missing`, `invalid_scope`, or `git_error`. Empty when `enable-scope-diff` was not set. |

## Report contract

`axiom-report.json` preserves the validator's own JSON fields unchanged --
`schema_version`, `project`, `requested_mode`, `effective_mode`, `gate`,
`summary`, `results` -- and adds one namespaced `action` object next to them
(`outcome`, `exit_code`, `enforce`, `fail_on_warning`, `annotation_mode`,
`generated_at`). Existing tooling written against the diagnostics contract
keeps working unchanged; nothing is renamed.

`project` in the report is always the value you configured (for example
`projects/P01-ABC`), never the CI runner's resolved absolute filesystem
path -- a Job Summary or PR annotation is not the place to expose runner
directory layout.

`axiom-report.md` and the Job Summary render the same content; the Job
Summary caps each of the FAIL/WARN sections at 10 rows (GitHub also caps
annotations at 10 per level per step) and points to the full uncapped
Markdown/JSON artifact for the rest.

When `enable-scope-diff: true`, the JSON report also carries a `scope_diff`
object (approved paths, changed files by bucket, base/head SHA, verdict) --
omitted entirely, not present-as-null, when SCOPE-DIFF was not requested.
See [docs/reference/scope-declaration.md](../reference/scope-declaration.md).

## Annotations

Only `FAIL` and `WARN` diagnostics become PR annotations. `PASS` and `INFO`
never do -- a clean run would otherwise bury the pull request in notices.
Annotation content is drawn from an explicit allowlist of fields the
diagnostics contract already publishes (`rule_id`, `message`, `artifact`,
`item_id`, `field`, `suggestion`, `documentation_url`). Requirement prose,
source file contents, and approval evidence are never read by the
annotation code and cannot appear in an annotation.

A file-targeted annotation only fires when the diagnostic's `artifact` path
resolves inside the job's working directory; a path that would resolve
outside it (for example via `../`) degrades to a locationless annotation
instead of pointing at an unrelated file.

## SCOPE-DIFF: is this change inside its approved scope?

Off by default. Set `enable-scope-diff: true` to also compare the PR's
changed files against the project's `SCOPE.json`:

```yaml
- uses: witchwasin/Axiom-PMO@<pinned-sha-or-tag>
  with:
    project: projects/P02-MYPROJECT
    gate: Release
    enable-scope-diff: "true"
```

That's the whole example -- on a `pull_request` event, base and head are
read automatically from the GitHub event context, no SHAs to supply by
hand. SCOPE-DIFF needs full git history to resolve the base commit, so
also give the checkout step `fetch-depth: 0` (the default `fetch-depth: 1`
only fetches the current commit):

```yaml
- uses: actions/checkout@v7
  with:
    fetch-depth: 0
- uses: witchwasin/Axiom-PMO@<pinned-sha-or-tag>
  with:
    project: projects/P02-MYPROJECT
    gate: Release
    enable-scope-diff: "true"
```

**SCOPE-DIFF checks *where* a change happened, not *what* it changed.** A
passing SCOPE-DIFF result means every changed file was in the approved
list -- it says nothing about whether the code inside those files is
correct. Full syntax, precedence rules, the repo-wide exemption mechanism,
and git range semantics: [docs/reference/scope-declaration.md](../reference/scope-declaration.md).

## Troubleshooting

- **`exit-code: 127`, `outcome: runtime-missing`** -- no PowerShell host was
  found on the runner. GitHub-hosted runners ship one; a self-hosted runner
  needs `pwsh` on `PATH` (see
  [powershell-runtime.md](powershell-runtime.md)).
- **Step succeeded but findings exist in the report** -- this is report-only
  mode (`enforce` defaults to `false`), not a bug. Check the Job Summary,
  the uploaded artifact, or the `outcome`/`exit-code` outputs.
- **No annotations on the PR** -- confirm `annotation-mode` is not set to
  `off`, and check the Job Summary/artifact for the full result regardless.
- **`scope-diff-verdict: git_error` (`SCOPE-DIFF-004`)** -- almost always a
  shallow checkout. Add `fetch-depth: 0` to the `actions/checkout` step, as
  shown above.
- **`scope-diff-verdict: scope_missing` (`SCOPE-DIFF-002`)** -- the project
  has no `SCOPE.json`. `enable-scope-diff: true` is a real request that
  must get a real answer; a missing declaration is never silently treated
  as "everything is approved." Add `SCOPE.json` (`templates/SCOPE.json`) or
  turn `enable-scope-diff` back off for this project.
