# Architecture: The Validation Engine

The validator is a PowerShell program driven entirely by JSON policy. There is no
hardcoded fallback: if the config is missing, it fails rather than guessing.

## Entry points (`scripts/`)

| Script | Role |
|---|---|
| `validate-project.ps1` | Orchestrator: loads config, resolves effective mode, runs each validator module, aggregates results, writes Text/JSON, sets the exit code. |
| `pmo-doctor.ps1` | Validates the framework *itself*: required files, skill runtime, version/schema consistency, rule-catalog completeness, permissions, links, table integrity. |
| `run-validation-tests.ps1` | Positive/negative fixture matrix + golden-master engine. |
| `run-all-checks.ps1` | Aggregates doctor, fixtures **with golden verification**, example goldens, config-mutation, diagnostics-contract, line-endings, handoff-assessment, demo smoke, example validations, end-to-end tests, and the CLI tests. One pass: verifying goldens separately would re-run the whole fixture matrix. |
| `new-project.ps1` | Mode-aware project generator (`-IncludeHandoff` adds the handoff scaffolding). |
| `assess-handoff.ps1` | Runs the Handoff gate and reports readiness per stage, with a capped score. Reporting only — it is not a gate. |
| `handoff-digest.ps1` | Prints a project's Source Snapshot digest, which `HANDOFF-REVIEW.json` records for freshness. |
| `demo.ps1` | The three-minute proof: a broken handoff, then a fixed one. |

`cli/axiom.mjs` is a thin Node wrapper over the scripts above. It contains no
validation logic; it locates a PowerShell host, forwards arguments, and
preserves exit codes.

## Validator modules (`scripts/lib/`)

The orchestrator dot-sources focused modules: config loading, markdown-table
parsing, reference resolution, mode resolution, artifact policy, approval
validation, source validation, work-item validation, RTM validation, release
validation, and handoff validation, plus a result writer. Each raises typed rule
ids via `Add-Result`.

Two modules support the tooling rather than the checks themselves:

| Module | Role |
|---|---|
| `pwsh-host.ps1` | Resolves the PowerShell executable for child processes: `AXIOM_PWSH`, then the running host itself, then `pwsh` / `powershell` / `powershell.exe`. |
| `golden-normalizer.ps1` | Canonicalizes validator output for golden comparison so a capture under one PowerShell host verifies under another. |
| `ordinal-sort.ps1` | Ordinal string sorting for every sort whose output reaches a freshness digest or a diagnostic. `Sort-Object` is culture-sensitive, which makes both host-dependent. |

`handoff-validator.ps1` carries a hard scope boundary: it checks only what the
artifacts **declare**, and never infers domain meaning. It will not decide that a
photograph is personal data or that a scanner needs a secure context. Those
judgements belong to the semantic review — see
[handoff readiness](../concepts/handoff-readiness.md).

## Policy (`pmo-config/`)

| File | Contents |
|---|---|
| `policy.json` | Enums, approval roles, strict triggers, source-ref patterns, table schemas, git-authority permissions. |
| `validation-rules.json` | The rule catalog: every rule id with a severity, description, remediation `suggestion`, and optional `documentation` path. |
| `artifact-policy.json` | The Mode × Gate required-artifact matrix. |
| `handoff-policy.json` | Handoff artifacts, review lenses, blocking points, owner tokens, build-spec sections, score weights and caps. |
| `diagnostics-schema.json` | The structured diagnostic contract and its compatibility, exit-code, and sensitive-data policies. |
| `reference-types.json` | Regexes per reference type; which types are externally unverifiable. |
| `context-map.json` | Per-mode context budgets (guidance). |
| `skill-manifest.json` | The active skill runtime. |

## Severity model

`info` never blocks; `warn` blocks only under `-FailOnWarning`; `fail` always
blocks; `fail_release` blocks a Release gate. The exit code is derived from the
highest blocking result: `0` pass, `1` fail, `2` blocking warning under
`-FailOnWarning`.

Some handoff severities are resolved per mode from `handoff-policy.json` rather
than fixed in the catalog — a generic owner is a `WARN` at Lite and a `FAIL` at
Standard and Strict, for example.

## Diagnostic output

Every result carries `schema_version`, `level`, `rule_id`, `message`,
`blocking`, plus `artifact`, `item_id`, `field`, `suggestion`, and
`documentation_url`. `suggestion` and `documentation_url` are resolved from the
rule catalog by rule id, so remediation text lives in one place. The full
contract is [`docs/reference/diagnostics-contract.md`](../reference/diagnostics-contract.md).

## How the engine defends itself

- **Rule-catalog completeness** (`DOCTOR-007`) reconciles emitted rule ids
  against the catalog in both directions — no missing entries, no dead ones.
- **Version/schema consistency** (`DOCTOR-005`, `DOCTOR-006`) keeps `VERSION`,
  the changelog, and every config's `version`/`schema_version` aligned.
- **Config-mutation tests** prove the JSON policy is load-bearing: mutate a
  policy and a rule must change behavior.
- **Remediation completeness** (`DOCTOR-008`, `DOCTOR-009`) requires every
  fail/warn rule to carry a suggestion, and every referenced documentation page
  to exist — so a diagnostic can never advertise a dead link.
- **Golden masters** make any behavioral change visible as a reviewed diff,
  normalized to a `<REPO_ROOT>` placeholder and to a host-independent canonical
  form, so they are portable across checkouts *and* across PowerShell hosts.
- **Diagnostic contract tests** assert the shape of every row the validator
  emits, independently of which findings a fixture happens to produce.
- **Line-ending tests** assert that regexes, digests, and golden comparison
  behave identically on a CRLF checkout and an LF one. `.gitattributes` marks
  markdown as text, so those differ by platform, and a `(?m)$` anchor against
  raw file content silently matches nothing on Windows.
- **Generator-to-release E2E** exercises a real generated project end to end,
  including the Handoff gate, and asserts that an unfilled generated scaffold
  *fails* that gate.
- **Cross-host guard** (`DOCTOR-010`) fails the build when a script under
  `scripts/` invokes a native command without protecting against Windows
  PowerShell 5.1's stderr-as-terminating-error behaviour. It exists because
  that one difference caused three separate shipped defects, each invisible
  on the host they were written on. The wider set of cross-host pitfalls that
  have actually bitten this codebase — `ConvertTo-Json` spacing, `Get-Content
  -Raw` returning `$null`, `Invoke-Expression` running in-process,
  case-insensitive `-match` — is written up in
  [powershell-portability.md](powershell-portability.md).

See [risk modes](../concepts/risk-modes.md) for effective-mode resolution and
[evidence-based execution](../concepts/evidence-based-execution.md) for reference
resolution.
