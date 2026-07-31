# DOCTOR-011 - Bare `$IsWindows` host test

| | |
|---|---|
| Level | FAIL |
| Runs when | `scripts/pmo-doctor.ps1` is invoked |
| Artifacts | `scripts/**/*.ps1`, `tests/**/*.ps1` |

## What this rule checks

No PowerShell file under `scripts/` or `tests/` branches on `$IsWindows`
directly.

Two files are exempt by name, because both legitimately have to mention it:
`scripts/lib/pwsh-host.ps1`, which defines the safe wrapper, and
`scripts/pmo-doctor.ps1`, which implements this check.

## Why it exists

`$IsWindows` was introduced in PowerShell Core. **Windows PowerShell 5.1 does
not have it**, so it evaluates to `$null` there — and 5.1 only ever runs on
Windows.

Every natural way to write "not Windows" is therefore wrong on 5.1:

```powershell
if ($IsWindows -ne $true)      { }   # TRUE on 5.1. Runs on Windows.
if (-not $IsWindows)           { }   # TRUE on 5.1. Runs on Windows.
if ($null -eq $IsWindows)      { }   # TRUE on 5.1, written to mean "Unix".
```

The failure is silent in both directions. On PowerShell 7 — the host this
repository is developed on — every one of these behaves correctly, so nothing
looks wrong locally.

This shipped. The Milestone 6.3 and 6.5 test suites guarded their symlink and
`chmod` cases with `if ($IsWindows -ne $true)`. Both ran on Windows PowerShell
5.1 in CI, where `ln -s` and `chmod` do not exist, and the suite reported
failures that had nothing to do with the code under test. A `chmod` case that
silently no-ops is worse: it reports a pass for a scenario it never created.

The correct form already existed in `scripts/run-execution-command.ps1`. The
lesson simply had no name that anything else could call, which is the same
reason [`DOCTOR-010`](DOCTOR-010.md) exists.

## How to fix

```powershell
. (Join-Path $PSScriptRoot "lib/pwsh-host.ps1")

if (-not (Test-WindowsHost)) {
  # genuinely Unix-only
}
```

`Test-WindowsHost` checks `$PSVersionTable.PSEdition -eq "Desktop"` first,
which is true on 5.1 and false on PowerShell 7, then falls back to
`$IsWindows`. Correct on every supported host.

## Scope

Scanned across **both** `scripts/` and `tests/`, unlike `DOCTOR-010`, which is
limited to `scripts/`. The reason is what the defect costs in each place. An
unguarded native call in a test crashes loudly in CI. A wrong host branch in a
test does something worse — it runs the wrong platform's code path and can
report a pass for a scenario that was never exercised.

## Related

[`DOCTOR-010`](DOCTOR-010.md) (the same class of invisible-on-PowerShell-7
defect), [`docs/architecture/powershell-portability.md`](../architecture/powershell-portability.md).
