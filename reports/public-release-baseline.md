# Public Release Baseline

This report records the verified state of the framework's own validation suite
at the start of the Axiom-PMO public-release overhaul. It is the before/after
evidence that the overhaul preserved every enforced check.

- **Framework version at baseline:** 0.5.1 (`schema_version` 1.0)
- **Platform:** Windows PowerShell 5.1 (CI: `windows-latest`)
- **Scope of baseline:** the four framework self-checks below. No project data,
  secrets, absolute paths, or repository identifiers are recorded here.

## Baseline results (pre-overhaul)

| Check | Command | Exit | PASS | WARN | FAIL |
|---|---|---|---|---|---|
| Framework doctor | `scripts/pmo-doctor.ps1` | 0 | 52 | 0 | 0 |
| Fixture matrix + golden master | `scripts/run-validation-tests.ps1 -VerifyGolden` | 0 | 95 | 0 | 0 |
| Aggregate (doctor + fixtures + config-mutation + example validations + E2E) | `scripts/run-all-checks.ps1` | 0 | all | 0 | 0 |
| Example golden snapshot | `tests/golden/capture-examples.ps1 -Verify` | 1 | — | — | 2 |

Notes:

- **Fixture matrix:** positive = 20, negative = 70, doctor-negative = 5, total = 95.
  Golden master verification: all 90 cases match byte-for-byte.
- **Aggregate:** framework doctor, validation fixtures, config-mutation tests,
  the three example-project validations (Lite/Standard/Strict), and the three
  generator-to-release E2E flows all pass; final aggregate summary
  `PASS=30 WARN=0 FAIL=0` plus Lite/Standard/Strict E2E green.
- **Example golden snapshot (`capture-examples.ps1`):** fails at baseline with a
  pre-existing drift — the `run-all-checks-{standard,strict}-example.txt`
  snapshots predate the 0.5.1 rule additions (`TEST-EVIDENCE-002`,
  `TEST-SUMMARY-001`), so current validator output has *more* passing rows than
  the captured file. This snapshot is **not** exercised by CI or
  `run-all-checks.ps1` (which validate the examples directly), so the drift does
  not affect any enforced gate. The overhaul regenerates these three snapshots
  fresh and makes their captured path portable (`<REPO_ROOT>` placeholder), so
  the snapshot becomes verifiable on any checkout.

## Final results (post-overhaul)

Framework version `1.0.0`. All enforced checks remain green, and the example
golden snapshot moved from FAIL to PASS after regeneration and path
normalization.

| Check | Command | Exit | Result |
|---|---|---|---|
| Framework doctor | `scripts/pmo-doctor.ps1` | 0 | PASS=52 WARN=0 FAIL=0 |
| Fixture matrix + golden master | `scripts/run-validation-tests.ps1 -VerifyGolden` | 0 | PASS=95 FAIL=0; golden 90/90 byte-for-byte |
| Aggregate (+ E2E) | `scripts/run-all-checks.ps1` | 0 | all pass; Lite/Standard/Strict E2E green |
| Example golden snapshot | `tests/golden/capture-examples.ps1 -Verify` | 0 | all match (was FAIL at baseline) |
| Release readiness | `scripts/prepare-public-release.ps1` | 0 | version consistent; no old name; no private data |

No validator, rule, severity, or policy was weakened. The only runtime code
change was adding `<REPO_ROOT>` path normalization to the example-golden capture
script (a portability fix, mirroring the existing fixture-matrix behavior).
