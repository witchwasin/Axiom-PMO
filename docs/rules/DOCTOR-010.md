# DOCTOR-010 - Unguarded native command under ErrorActionPreference = Stop

| | |
|---|---|
| Level | FAIL |
| Runs when | `scripts/pmo-doctor.ps1` is invoked |
| Artifacts | any `scripts/**/*.ps1` that sets `ErrorActionPreference = "Stop"` |

## What this rule checks

For every script under `scripts/` that sets `$ErrorActionPreference = "Stop"`,
each native command invocation (`& git`, `& gh`, `& $shellExe`, `& $pwshExe`)
must either drop to `"Continue"` around the call or match a known-safe
pattern.

## Why it exists

In **Windows PowerShell 5.1**, when `$ErrorActionPreference` is `"Stop"`, any
output a native command writes to stderr becomes a **terminating error** —
including purely informational messages, and **despite `2>$null`**.
PowerShell 7 does not behave this way.

The consequence is not a wrong answer; it is the script dying mid-run. And
because it only happens on one of four required hosts — the one a macOS or
Linux maintainer cannot run locally — it passes every local check and fails
in CI, or worse, on a user's machine.

**This rule exists because the same defect shipped three times:**

| Where | The stderr that killed it |
|---|---|
| `tests/helpers/execution-contract-tests.ps1` | `git add` printing "LF will be replaced by CRLF" |
| `Test-CiCheckEvidence` | `git remote get-url origin` on a repo with no remote — verification crashed instead of returning "unverified" |
| `scripts/run-execution-command.ps1` | *any* passing test command that writes to stderr (`npm`, `pytest`, `jest` all do) — the runner died before sealing its evidence record |

The third was never caught by a test, because every fixture command in the
suite was `echo ok` or `exit 1`. It was found by auditing for the pattern.
Encoding the rule here is the point: the framework's own thesis is that a
lesson which lives only in a commit message will be relearned the hard way.

## How to fix

```powershell
$previousEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $output = & git -C $repo remote get-url origin 2>$null
  $exitCode = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $previousEap
}
```

`scripts/lib/execution-contract-evidence.ps1` exposes this as
`Invoke-NativeCapture`; reuse it where it is in scope rather than open-coding
another save/restore.

### Patterns that need no guard

- `--quiet` on a git command — git suppresses its own stderr by design.
- `2>$stderrFile` — redirecting to a real file is a different mechanism and
  does not raise. Use this when you actually want the stderr text for a log
  (see `scope-diff-git-adapter.ps1`).

## Known limitations

**Lexical, not a parse.** The check looks at the ~15 lines before each
invocation for a `"Continue"` assignment or a recognised wrapper. A false
positive is resolved by adding the guard (or a genuinely safe pattern); a
false negative is a crash on a host the author cannot run, so the check errs
toward flagging.

**Scoped to `scripts/`, not `tests/`.** Roughly 50 equivalent sites exist
under `tests/`. They are real instances of the same class and are recorded as
known debt in
[`docs/architecture/powershell-portability.md`](../architecture/powershell-portability.md),
not silently excluded. The scoping is about consequence: an unguarded call in
a test harness crashes loudly in CI, which is self-revealing; the same call in
product code crashes on a user's machine and looks like the tool is broken.
New test code should still follow the rule.

## Related

[`docs/architecture/powershell-portability.md`](../architecture/powershell-portability.md)
— the full set of cross-host pitfalls that have caused real defects here,
including `ConvertTo-Json` spacing differences, `Get-Content -Raw` returning
`$null`, `Invoke-Expression` running in-process, and case-insensitive
`-match`.
