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

Negative fixtures must fail with the expected rule ID and expected level. The runner currently asserts:

- 7 positive cases.
- 25 negative fixture cases.
- Expected `FAIL` or warning-as-failure behavior for each negative case.
