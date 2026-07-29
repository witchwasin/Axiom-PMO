# M4 GitHub Action Implementation Plan

Date: 2026-07-29
Status: planning ready; implementation not started
Parent milestone: Milestone 4 — GitHub Action

## Purpose

This plan turns the Milestone 4 roadmap outline into an executable build plan.
It is written for a future AI agent or developer to pick up without inventing
scope, evidence, or acceptance.

Milestone 4 should make Axiom-PMO visible inside GitHub pull requests while
preserving the current validator authority:

```text
existing PowerShell validator / CLI
-> GitHub Action wrapper
-> JSON and Markdown reports
-> safe Job Summary and PR annotations
```

The Action must not reimplement validation rules.

## Confirmed inputs

- M3.5 Runtime Portability is accepted by human decision on 2026-07-29.
- Ubuntu PowerShell 7 is promoted to a required workflow job.
- M1 walkthrough and recording evidence is deferred optional trust evidence and
  is not a blocker before M4.
- Issue #12 tracks Milestone 4.
- The repository currently has `cli/axiom.mjs` as a thin wrapper over the
  PowerShell validators.
- The repository does not yet have a root `package.json` or `action.yml`.
- Structured diagnostics are documented in
  `docs/reference/diagnostics-contract.md`.

## Non-goals

- Do not rewrite the validator in JavaScript.
- Do not add new governance rules as part of the Action wrapper.
- Do not start M5 Superpowers runtime bridge work.
- Do not require branch protection as part of M4 implementation.
- Do not publish a Marketplace release before M4 human acceptance.

## Proposed architecture

Use a lightweight repository-root GitHub Action:

```text
action.yml
scripts/github-action/
  run-action.ps1 or run-action.mjs
  render-report.mjs
  emit-annotations.mjs
tests/helpers/github-action-tests.mjs
tests/fixtures/github-action/
```

Preferred shape:

1. `action.yml` defines the Action interface and calls one internal wrapper.
2. The wrapper invokes the existing CLI:

   ```text
   node cli/axiom.mjs validate --project <project> --mode <mode> --gate <gate> --json [--fail-on-warning]
   ```

3. The wrapper captures the validator exit code without losing report output.
4. Report rendering reads the JSON contract and writes:
   - `axiom-report.json`
   - `axiom-report.md`
   - GitHub Job Summary content
   - safe workflow annotations for `FAIL` and `WARN`
5. The wrapper exits with the original validator/CLI exit code.

This keeps validation authority in `scripts/validate-project.ps1` and
`cli/axiom.mjs`, while the Action owns only CI presentation.

## Action interface

Inputs:

| Input | Required | Default | Meaning |
|---|---:|---|---|
| `project` | yes | — | Project path to validate, relative to the consumer repository workspace unless absolute. |
| `mode` | no | `Standard` | Requested PMO mode. |
| `gate` | no | `Release` | Validation gate. |
| `fail-on-warning` | no | `true` | Whether blocking warnings produce exit code `2`. |
| `working-directory` | no | `.` | Directory where the Action should run. |
| `upload-artifact` | no | `true` | Whether to upload `axiom-report.json` and `axiom-report.md`. |
| `annotation-mode` | no | `safe` | `safe` emits only sanitized diagnostics; `off` emits no annotations. |

Outputs:

| Output | Meaning |
|---|---|
| `exit-code` | Original validator/CLI exit code. |
| `outcome` | `success`, `failure`, `warning`, or `runtime-missing`. |
| `json-report` | Path to `axiom-report.json`. |
| `markdown-report` | Path to `axiom-report.md`. |

Exit-code mapping:

| Exit code | Outcome |
|---:|---|
| `0` | `success` |
| `1` | `failure` |
| `2` | `warning` |
| `127` | `runtime-missing` |
| other non-zero | `failure` |

## Report contract

`axiom-report.json` must preserve the validator JSON as-is, with only a small
wrapper metadata object if needed. Do not rename diagnostic fields from
`docs/reference/diagnostics-contract.md`.

`axiom-report.md` should contain:

- project, requested mode, effective mode, and gate;
- summary counts;
- final outcome and exit code;
- actionable rows for `FAIL` and `WARN`;
- Handoff stage verdicts when the Handoff envelope is available.

The Markdown report must not copy source content or approval evidence.

## Annotation safety rules

Only `FAIL` and `WARN` diagnostics create annotations.

Mapping:

| Diagnostic level | Annotation |
|---|---|
| `FAIL` | `::error` |
| `WARN` | `::warning` |
| `PASS` | none |
| `INFO` | none |

Allowed annotation content:

- `rule_id`
- diagnostic `message`
- `artifact`
- `item_id`
- `field`
- `suggestion`
- `documentation_url`

The annotation implementation must:

- escape `%`, carriage return, line feed, `:`, and other workflow-command
  control characters required by GitHub workflow commands;
- avoid file-targeted annotations when `artifact` is null;
- avoid file-targeted annotations when `artifact` resolves outside the
  repository workspace;
- not include requirement prose, source file content, approval evidence,
  customer data, credentials, or confidential material.

## Implementation slices

### M4-1 — Reusable Action and interface

Files likely touched:

- `action.yml`
- `scripts/github-action/run-action.*`
- `README.md`
- `docs/guides/github-action.md`

Acceptance:

- a consumer can run the Action with no more than ten workflow lines;
- inputs and outputs are documented;
- the Action invokes `cli/axiom.mjs` or the PowerShell validator only;
- no validation rule logic is duplicated in Action code.

### M4-2 — Job Summary and artifacts

Files likely touched:

- `scripts/github-action/render-report.mjs`
- `.github/workflows/pmo-checks.yml`
- `tests/helpers/github-action-tests.mjs`

Acceptance:

- `axiom-report.json` is created on pass and fail;
- `axiom-report.md` is created on pass and fail;
- `$GITHUB_STEP_SUMMARY` receives a concise summary when available;
- the original validator exit code is retained after reports are written.

### M4-3 — Safe PR annotations

Files likely touched:

- `scripts/github-action/emit-annotations.mjs`
- `tests/helpers/github-action-tests.mjs`
- `docs/guides/github-action.md`

Acceptance:

- `FAIL` rows become error annotations;
- `WARN` rows become warning annotations;
- `PASS` and `INFO` rows do not create annotations;
- unsafe or missing locations fall back to locationless annotations;
- workflow command control characters are escaped;
- source-sensitive content is not copied into annotations.

### M4-4 — Consumer and failure-path tests

Files likely touched:

- `.github/workflows/pmo-checks.yml`
- `tests/fixtures/github-action/`
- `tests/helpers/github-action-tests.mjs`
- `scripts/run-all-checks.ps1`

Required test cases:

- passing Release gate;
- failing Release gate;
- blocking warning with `fail-on-warning`;
- Handoff envelope with mixed stage verdicts;
- missing PowerShell returns `127`;
- malformed JSON still produces a useful failure report;
- report files exist even when validation fails;
- null diagnostic location;
- artifact path outside repository;
- workflow-command escaping;
- source-sensitive content exclusion;
- Windows and Ubuntu runner coverage.

### M4-5 — Documentation and acceptance

Files likely touched:

- `README.md`
- `ROADMAP.md`
- `docs/guides/github-action.md`
- `docs/releases/<next-version>.md` when release timing is chosen
- Issue #12 and child GitHub issues

Acceptance:

- installation and usage example exists;
- input/output reference exists;
- required permissions are documented;
- privacy/log-safety statement exists;
- troubleshooting and exit-code guide exists;
- consumer test evidence is recorded;
- required CI is green;
- no P0 defect is open;
- a human records M4 acceptance.

## Suggested consumer workflow

The final Action should support a consumer workflow no larger than this shape:

```yaml
name: Axiom-PMO

on:
  pull_request:
  push:
    branches: [main]

jobs:
  governance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<pinned-sha>
      - uses: witchwasin/Axiom-PMO@<version-or-sha>
        with:
          project: examples/STANDARD-FEATURE
          mode: Standard
          gate: Release
```

Pinning policy:

- internal self-tests may use the local checkout path;
- documentation for external consumers should prefer a released tag or reviewed
  commit SHA;
- third-party Actions used by repository workflows should remain pinned to
  reviewed SHAs where practical.

## GitHub issue plan

Do not open issues without explicit user confirmation.

When approved, use Issue #12 as the parent and add a checklist linking:

- `[M4-1] Package Axiom-PMO as a reusable GitHub Action`
- `[M4-2] Render diagnostics as Job Summary and report artifacts`
- `[M4-3] Emit safe PR annotations from structured diagnostics`
- `[M4-4] Add GitHub Action consumer, failure-path, and privacy tests`
- `[M4-5] Document and accept Milestone 4`

Do not assign an owner unless a human names one.

## Definition of done

Milestone 4 is complete only when:

- all M4 child issues are closed;
- required CI is green on Windows and Ubuntu;
- the Action can be consumed in a small workflow;
- reports and annotations are produced safely on pass and fail;
- documentation is verified;
- no P0 defect is open;
- a human accepts M4.

Until then, M5 remains blocked.
