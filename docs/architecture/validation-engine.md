# Architecture: The Validation Engine

The validator is a PowerShell program driven entirely by JSON policy. There is no
hardcoded fallback: if the config is missing, it fails rather than guessing.

## Entry points (`scripts/`)

| Script | Role |
|---|---|
| `validate-project.ps1` | Orchestrator: loads config, resolves effective mode, runs each validator module, aggregates results, writes Text/JSON, sets the exit code. |
| `pmo-doctor.ps1` | Validates the framework *itself*: required files, skill runtime, version/schema consistency, rule-catalog completeness, permissions, links, table integrity. |
| `run-validation-tests.ps1` | Positive/negative fixture matrix + golden-master engine. |
| `run-all-checks.ps1` | Aggregates doctor, fixtures, config-mutation, example validations, and end-to-end tests. |
| `new-project.ps1` | Mode-aware project generator. |

## Validator modules (`scripts/lib/`)

The orchestrator dot-sources focused modules: config loading, markdown-table
parsing, reference resolution, mode resolution, artifact policy, approval
validation, source validation, work-item validation, RTM validation, and release
validation, plus a result writer. Each raises typed rule ids via `Add-Result`.

## Policy (`pmo-config/`)

| File | Contents |
|---|---|
| `policy.json` | Enums, approval roles, strict triggers, source-ref patterns, table schemas, git-authority permissions. |
| `validation-rules.json` | The rule catalog: every rule id with a severity and description. |
| `artifact-policy.json` | The Mode × Gate required-artifact matrix. |
| `reference-types.json` | Regexes per reference type; which types are externally unverifiable. |
| `context-map.json` | Per-mode context budgets (guidance). |
| `skill-manifest.json` | The active skill runtime. |

## Severity model

`info` never blocks; `warn` blocks only under `-FailOnWarning`; `fail` always
blocks; `fail_release` blocks a Release gate. The exit code is derived from the
highest blocking result.

## How the engine defends itself

- **Rule-catalog completeness** (`DOCTOR-007`) reconciles emitted rule ids
  against the catalog in both directions — no missing entries, no dead ones.
- **Version/schema consistency** (`DOCTOR-005`, `DOCTOR-006`) keeps `VERSION`,
  the changelog, and every config's `version`/`schema_version` aligned.
- **Config-mutation tests** prove the JSON policy is load-bearing: mutate a
  policy and a rule must change behavior.
- **Golden masters** make any behavioral change visible as a reviewed diff,
  normalized to a `<REPO_ROOT>` placeholder so they are portable across
  checkouts.
- **Generator-to-release E2E** exercises a real generated project end to end.

See [risk modes](../concepts/risk-modes.md) for effective-mode resolution and
[evidence-based execution](../concepts/evidence-based-execution.md) for reference
resolution.
