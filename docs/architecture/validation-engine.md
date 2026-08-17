# Architecture: The Validation Engine

The validator is a TypeScript program (compiled to `dist/`, run entirely
in-process by `cli/axiom.mjs`), driven entirely by JSON policy. There is no
hardcoded fallback: if the config is missing, it fails rather than guessing.

## Entry points (`src/` + `cli/`)

| Entry point | Role |
|---|---|
| `src/probe/validate-chain.ts` | Orchestrator: loads config, resolves effective mode, runs each validator module, aggregates results, writes Text/JSON, sets the exit code. Backs `axiom validate` (and the demo's gate step). |
| `src/doctor/pmo-doctor.ts` | Validates the framework *itself*: required files, skill runtime, version/schema consistency, rule-catalog completeness, permissions, links, table integrity. (`axiom doctor`) |
| `src/tools/validation-fixtures.ts` | Positive/negative fixture matrix + golden-master engine. |
| `src/tools/run-all-checks.ts` | Aggregates doctor, fixtures **with golden verification**, example goldens, config-mutation, diagnostics-contract, line-endings, handoff-assessment, demo smoke, example validations, end-to-end tests, and the CLI tests. One pass: verifying goldens separately would re-run the whole fixture matrix. (`axiom check`) |
| `src/tools/new-project.ts` | Mode-aware project generator (`axiom init`; `--handoff` adds the handoff scaffolding). |
| `src/tools/assess-handoff.ts` | Runs the Handoff gate and reports readiness per stage, with a capped score. Reporting only — it is not a gate. (`axiom handoff`) |
| `src/tools/digest-tools.ts` | Prints a project's Source Snapshot / design-provider / visual-proof digests, which `HANDOFF-REVIEW.json` and `EXECUTION-REVIEW.json` record for freshness. |
| `src/tools/demo.ts` | The three-minute proof: a broken handoff, then a fixed one. (`axiom demo`) |

`cli/axiom.mjs` is a thin dispatch layer over the engine above. It contains no
validation logic; it maps verbs to the in-process TypeScript entry points,
forwards arguments, and preserves exit codes.

## Validator modules (`src/rules/`, `src/exec/`, `src/core/`)

The orchestrator calls focused modules: config loading (`src/config/`),
markdown-table parsing (`src/markdown/table-parser.ts`), reference resolution
(`src/core/reference-resolver.ts`), mode resolution
(`src/core/mode-resolver.ts`), artifact policy (`src/core/artifact-policy.ts`),
approval/source/work-item/RTM/release/handoff validation (`src/rules/`),
execution-contract validation (`src/exec/`), plus a result writer
(`src/core/result-writer.ts`). Each raises typed rule ids via `addResult`.

Three modules support the tooling rather than the checks themselves:

| Module | Role |
|---|---|
| `src/output/canonical-normalizer.ts` | Canonicalizes validator output for golden comparison so a capture on one OS verifies on any other. |
| `src/core/ordinal-sort.ts` | Ordinal string sorting for every sort whose output reaches a freshness digest or a diagnostic. |
| `src/markdown/files.ts` | Markdown discovery and local-link checks for the doctor. |

`handoff-validator` (`src/rules/handoff-validator.ts`) carries a hard scope
boundary: it checks only what the artifacts **declare**, and never infers domain
meaning. It will not decide that a photograph is personal data or that a scanner
needs a secure context. Those judgements belong to the semantic review — see
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
  normalized to a `<REPO_ROOT>` placeholder and to a platform-independent
  canonical form, so they are portable across checkouts *and* across OSes.
- **Diagnostic contract tests** assert the shape of every row the validator
  emits, independently of which findings a fixture happens to produce.
- **Line-ending tests** assert that regexes, digests, and golden comparison
  behave identically on a CRLF checkout and an LF one. `.gitattributes` marks
  markdown as text, so those differ by platform, and a `(?m)$` anchor against
  raw file content silently matches nothing on Windows.
- **Generator-to-release E2E** exercises a real generated project end to end,
  including the Handoff gate, and asserts that an unfilled generated scaffold
  *fails* that gate.
- **Cross-host guard** (the retired `DOCTOR-010`) used to fail the build when
  a PowerShell script under `scripts/` invoked a native command without
  protecting against Windows PowerShell 5.1's stderr-as-terminating-error
  behaviour — that one difference caused three separate shipped defects before
  the PowerShell reference was deleted. The wider set of cross-host pitfalls
  that actually bit this codebase is written up in
  [powershell-portability.md](powershell-portability.md) as a historical
  record.

See [risk modes](../concepts/risk-modes.md) for effective-mode resolution and
[evidence-based execution](../concepts/evidence-based-execution.md) for reference
resolution.
