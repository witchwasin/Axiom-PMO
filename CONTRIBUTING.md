# Contributing to Axiom-PMO

Thank you for helping improve Axiom-PMO. This project is a **governance control
plane**: its value depends entirely on its checks being trustworthy. The single
most important contribution rule follows from that.

> **Do not weaken governance to make a test pass.**
> Do not turn a blocking failure into a warning, delete a rule, loosen a policy,
> or edit a user-owned source document just to get to green — unless the change
> is an intentional, documented policy decision with a clear risk rationale.
> Reviews will reject changes that reduce validation strictness without that
> justification.

## Project philosophy

- **Deterministic over persuasive.** Rules are enforced by scripts that exit
  non-zero, not by asking an agent nicely.
- **Evidence over assertion.** Requirements, decisions, tests, and release
  claims must carry a source reference and an evidence status.
- **Human authority is non-negotiable.** No automation may commit, push, tag,
  deploy, or approve a release on its own.
- **Smallest process that controls the real risk.** Lite/Standard/Strict exist
  so governance scales down as well as up.

## Development environment

- **PowerShell.** The validator is the reference implementation. Supported:
  - Windows PowerShell 5.1 (used by CI, `windows-latest`).
  - PowerShell 7 (`pwsh`).
  - Linux/macOS via `pwsh` is **experimental** — the wrappers run, but the suite
    is not yet verified there.
- No build step and no runtime dependencies beyond PowerShell. Optional:
  `make` for the convenience targets, PSScriptAnalyzer for lint.

## Run every check

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pmo-doctor.ps1
powershell -ExecutionPolicy Bypass -File scripts/run-validation-tests.ps1 -RepoPath . -VerifyGolden
powershell -ExecutionPolicy Bypass -File scripts/run-all-checks.ps1 -RepoPath .
powershell -ExecutionPolicy Bypass -File tests/golden/capture-examples.ps1 -Verify
```

Or, with `make`: `make check`. Everything must exit 0 before you open a PR.

## How to add a validation rule

1. **Emit it** from the relevant validator in `scripts/validate-project.ps1`,
   `scripts/lib/*.ps1`, or `scripts/pmo-doctor.ps1` via `Add-Result <LEVEL>
   "<message>" "<RULE-ID>"`. Levels: `PASS`, `INFO`, `WARN`, `FAIL` (and the
   release-only `fail_release` severity is expressed in the catalog).
2. **Register it** in `pmo-config/validation-rules.json` with a `severity` and a
   `description`. `DOCTOR-007` reconciles emitted rule ids against the catalog in
   **both** directions — a rule you emit but don't register, or register but
   never emit, fails the doctor. Keep them in sync.
3. **Decide severity deliberately.** `info` never blocks; `warn` blocks only
   under `-FailOnWarning`; `fail` always blocks; `fail_release` blocks a Release
   gate. Prefer the least severe level that still controls the risk — but do not
   downgrade an existing blocking rule without a documented reason.

## How to add fixtures

Fixtures live in `tests/fixtures/` (`valid-*` = positive, `invalid-*` =
negative), with doctor negatives in `tests/doctor-fixtures/`. Every new rule
needs **both** a positive fixture (the rule passes when it should) and a
**negative fixture** (the rule fires when it should).

1. Create the fixture project directory with the minimal files to exercise the
   rule.
2. Add a case row to `$cases` (or `$doctorCases`) in
   `scripts/run-validation-tests.ps1`: `Name`, `Path`, `Mode`, `Gate`,
   `ShouldPass`, `Rule`, `ExpectedLevel`, `Type`, plus optional `FailOnWarning`,
   `AllowedSecondaryRules`, `ForbiddenRules`.
3. A negative fixture that must not ship a real secret still needs its sensitive
   file — see the scoped `.gitignore` negation for the synthetic `Quotation.xlsx`
   placeholder as the pattern to follow.

## How to update golden outputs safely

Golden masters make behavior changes visible. Only regenerate them when the
behavioral change is **intentional and reviewed**.

- Fixture-matrix goldens: `run-validation-tests.ps1 -CaptureGolden` writes,
  `-VerifyGolden` checks. Paths are normalized to `<REPO_ROOT>` for portability.
- Example goldens: `tests/golden/capture-examples.ps1` captures,
  `-Verify` checks (also `<REPO_ROOT>`-normalized).
- In your PR, **explain the diff**: which rule changed, why, and confirm no rule
  was silently downgraded. A golden diff with no rationale is a red flag.

## How to add a mode or policy

Modes, gates, statuses, evidence statuses, strict triggers, approval roles,
table schemas, and git-authority live in `pmo-config/policy.json` and the
Mode×Gate artifact matrix in `pmo-config/artifact-policy.json`. Because these
files are load-bearing, add or extend a scenario in
`tests/helpers/config-mutation-tests.ps1` proving that mutating your new policy
actually changes validator behavior — a policy no test can move is decoration.

## Pull-request expectations

Use the PR template. In particular:

- Tests added, including a **negative** fixture for any new rule.
- Golden diffs reviewed and explained.
- No validation weakening (or an explicit, justified policy decision).
- Docs updated when behavior or configuration changed.
- No private data (paths, handles, secrets, customer material).
- Compatibility with the interoperability model considered where relevant.

Keep commits focused and messages descriptive. This project does not accept
pushes or merges performed by automation without a human in the loop.

## AI-assisted contributions

AI-assisted changes are welcome, but:

- **Disclose them.** Note in the PR that the change was AI-assisted and which
  parts.
- **A human must review them.** Do not submit unreviewed generated output.
- **Generated evidence is not automatically trusted.** Test results, approvals,
  and release claims produced by an agent are candidate evidence until verified —
  the same rule the framework applies to project work applies to its own code.

## Security

Please report vulnerabilities privately as described in
[`SECURITY.md`](SECURITY.md). Do not open a public issue for a security problem.

## License

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).
