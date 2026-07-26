# Testing

## Main Commands

Run all checks:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-all-checks.ps1
```

Run framework doctor only:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pmo-doctor.ps1
```

Run project validator:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath examples/STANDARD-FEATURE -Mode Standard -Gate Release -FailOnWarning
```

Run fixture tests:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-validation-tests.ps1
```

Run the Handoff gate and readiness assessment on the worked example:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath examples/HANDOFF-DEMO -Mode Standard -Gate Handoff -FailOnWarning
powershell -ExecutionPolicy Bypass -File scripts/assess-handoff.ps1 -ProjectPath examples/HANDOFF-DEMO -Mode Standard
```

## Running on PowerShell 7 / non-Windows

Windows PowerShell 5.1 is the reference platform. PowerShell 7 (`pwsh`) on
Linux/macOS is experimental but supported by the test tooling: every runner
resolves its host through `scripts/lib/pwsh-host.ps1`, which honours
`AXIOM_PWSH` and then probes `pwsh`, `powershell`, `powershell.exe` in that
order.

```bash
AXIOM_PWSH=/path/to/pwsh pwsh -File scripts/run-all-checks.ps1 -RepoPath .
```

A test that cannot run must say so. `scripts/run-all-checks.ps1` reports a
missing Node.js as an explicit SKIPPED line rather than passing silently, and
the CLI exits `127` with remediation when no PowerShell host is found.

## Validation Rules

Rules are cataloged in `pmo-config/validation-rules.json`.

Each validator output includes:

- `schema_version`, `level`, `rule_id`, `message`, `blocking`
- `artifact`, `item_id`, `field` — where the finding is
- `suggestion`, `documentation_url` — what to do about it

The full contract, its compatibility policy, and the sensitive-data rules are in
[`docs/reference/diagnostics-contract.md`](docs/reference/diagnostics-contract.md).
`tests/helpers/diagnostics-contract-tests.ps1` asserts the shape of every row the
validator emits, independently of which findings any particular fixture produces.

JSON output:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath examples/STANDARD-FEATURE -Mode Standard -Gate Release -FailOnWarning -Format Json
```

## Fixture Policy

Positive examples must pass.

Negative fixtures must fail with the expected rule ID and expected level. The
runner prints the current positive/negative/doctor-negative matrix on every run;
read it from there rather than from this page, which will drift.

A negative fixture must isolate its rule. When a mutation trips a second,
unrelated rule, either narrow the mutation or list the extra rule in
`AllowedSecondaryRules` — never leave it implicit.

## Golden Master

`scripts/run-validation-tests.ps1` supports `-CaptureGolden` / `-VerifyGolden`, which
capture or diff every fixture case's stdout against `tests/golden/`. Run
`-VerifyGolden` before and after any change to `scripts/validate-project.ps1` or
`scripts/lib/*.ps1` — any diff is a behavior change and must be reviewed, not
silently re-captured.

`run-all-checks.ps1` already passes `-VerifyGolden`, and separately verifies the
example goldens. Both happen inside the single fixture pass on purpose: running
the matrix is the most expensive thing this suite does, and verifying goldens
re-executes every case, so doing it as a second step doubles the cost for no
extra coverage.

Comparison is canonical, not byte-exact: `scripts/lib/golden-normalizer.ps1`
folds away the UTF-8 BOM, line endings, JSON indentation, numeric character
escapes, and path separators, because none of those are part of the diagnostic
contract and all of them differ between PowerShell hosts. Rule ids, levels,
blocking flags, message text, summary counters, and exit codes are still
compared exactly. Golden files are stored in that canonical form, so a capture
under Windows PowerShell 5.1 and one under pwsh 7 produce identical bytes.

## Config Mutation Tests

```powershell
powershell -ExecutionPolicy Bypass -File tests/helpers/config-mutation-tests.ps1
```

Proves `pmo-config/*.json` is the real source of truth (not a hardcoded fallback) by
mutating each config file and asserting the validator/doctor fails on the *specific*
expected rule ID, not just a non-zero exit code.

## End-to-End Tests

```powershell
powershell -ExecutionPolicy Bypass -File tests/e2e/lite.ps1
powershell -ExecutionPolicy Bypass -File tests/e2e/standard.ps1
powershell -ExecutionPolicy Bypass -File tests/e2e/strict.ps1
powershell -ExecutionPolicy Bypass -File tests/e2e/handoff.ps1
```

Each generates a real project with `scripts/new-project.ps1`, fills it in
deterministically (`tests/e2e/lib/fill-project.ps1` — not by copying an example
project over the generator's output), and validates it through every gate.

`handoff.ps1` additionally asserts two things the others cannot: that a freshly
generated, unfilled handoff scaffold **fails** the Handoff gate (a generator that
emitted a passing handoff would be manufacturing evidence), and that changing the
sources changes the Source Snapshot digest so the recorded review is reported as
stale.

## Other Suites

```powershell
powershell -ExecutionPolicy Bypass -File tests/helpers/diagnostics-contract-tests.ps1
powershell -ExecutionPolicy Bypass -File tests/helpers/line-ending-tests.ps1
powershell -ExecutionPolicy Bypass -File tests/helpers/handoff-assessment-tests.ps1
powershell -ExecutionPolicy Bypass -File tests/helpers/demo-smoke-tests.ps1
```

```bash
node tests/helpers/cli-tests.mjs
```

| Suite | Proves |
|---|---|
| diagnostics-contract | Every emitted diagnostic matches `pmo-config/diagnostics-schema.json`, carries remediation on WARN/FAIL, and does not echo artifact content |
| line-endings | Regexes, digests, and golden comparison behave identically on a CRLF (Windows) and an LF checkout |
| cli | Exit codes propagate unchanged, `handoff --json` is one parseable document, and no validation logic has leaked into JavaScript |
| handoff-assessment | Stage verdicts stay separate, and every score cap actually binds |
| demo-smoke | The demo's narration matches its real output, and it finishes well inside three minutes |

All of these run as part of `scripts/run-all-checks.ps1`.
