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

## Validation Rules

Rules are cataloged in `pmo-config/validation-rules.json`.

Each validator output includes:

- Level: `PASS`, `WARN`, `FAIL`, or `INFO`
- Rule ID
- Message

JSON output:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath examples/STANDARD-FEATURE -Mode Standard -Gate Release -FailOnWarning -Format Json
```

## Fixture Policy

Positive examples must pass.

Negative fixtures must fail with the expected rule ID and expected level (17 positive
+ 57 negative + 5 doctor-negative cases as of `VERSION` 0.5.0 — see
`scripts/run-validation-tests.ps1` for the current count and full list; do not
hardcode a number here again, it will drift).

## Golden Master

`scripts/run-validation-tests.ps1` supports `-CaptureGolden` / `-VerifyGolden`, which
capture or diff the raw stdout of every fixture case byte-for-byte against
`tests/golden/`. Run `-VerifyGolden` before and after any change to
`scripts/validate-project.ps1` or `scripts/lib/*.ps1` — any diff is a behavior change
and must be reviewed, not silently re-captured.

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
```

Each generates a real project with `scripts/new-project.ps1`, fills it in
deterministically (`tests/e2e/lib/fill-project.ps1` — not by copying an example
project over the generator's output), and validates it through every gate.
