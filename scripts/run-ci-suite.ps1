#requires -Version 5.1
<#
.SYNOPSIS
  Runs one named CI suite for the risk-based `targeted` profile.

.DESCRIPTION
  The risk-based CI workflow (see docs/architecture/ci-risk-based.md) runs a
  whole host with scripts/run-all-checks.ps1 by default. When a human or agent
  dispatches a `targeted` run and names a suite, this script narrows the run to
  that one check instead, so a one-file fix does not pay for the full matrix.

  The whitelist here is deliberately closed: an unknown suite name is an error,
  never a silent no-op, because a targeted run that quietly runs nothing is
  worse than one that refuses to start.

.PARAMETER Suite
  One of: doctor, hygiene, golden, validation-fixtures, config-mutation,
  line-ending, plugin-drift, cli, github-action, all.

.PARAMETER RepoPath
  Repository root. Defaults to the parent of this script's directory.

.PARAMETER ResolveOnly
  Print the resolved command line without executing it (used by the regression
  test to prove the whitelist maps each token to a real script).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Suite,
  [string]$RepoPath = "",
  [switch]$ResolveOnly
)

$ErrorActionPreference = "Stop"

if (-not $RepoPath) { $RepoPath = Join-Path $PSScriptRoot ".." }
$repo = (Resolve-Path -LiteralPath $RepoPath).Path

. (Join-Path $PSScriptRoot "lib/pwsh-host.ps1")

# suite -> one of "ps" (PowerShell script) or "node" (Node module).
$suiteMap = @{
  "doctor"              = @{ kind = "ps";   target = "scripts/pmo-doctor.ps1";                args = @("-RepoPath", $repo) }
  "hygiene"             = @{ kind = "ps";   target = "scripts/check-public-hygiene.ps1";      args = @("-RepoPath", $repo) }
  "golden"              = @{ kind = "ps";   target = "tests/golden/capture-examples.ps1";     args = @("-RepoPath", $repo, "-Verify") }
  "validation-fixtures" = @{ kind = "ps";   target = "scripts/run-validation-tests.ps1";      args = @("-RepoPath", $repo, "-VerifyGolden") }
  "config-mutation"     = @{ kind = "ps";   target = "tests/helpers/config-mutation-tests.ps1"; args = @("-RepoPath", $repo) }
  "line-ending"         = @{ kind = "ps";   target = "tests/helpers/line-ending-tests.ps1";   args = @("-RepoPath", $repo) }
  "plugin-drift"        = @{ kind = "ps";   target = "scripts/build-plugin-package.ps1";      args = @("-Check") }
  "cli"                 = @{ kind = "node"; target = "tests/helpers/cli-tests.mjs";           args = @() }
  "github-action"       = @{ kind = "node"; target = "tests/helpers/github-action-tests.mjs"; args = @() }
  "all"                 = @{ kind = "ps";   target = "scripts/run-all-checks.ps1";            args = @("-RepoPath", $repo) }
}

if (-not $suiteMap.ContainsKey($Suite)) {
  Write-Host "[FAIL] CI-SUITE-001 Unknown suite '$Suite'. Expected one of: $(($suiteMap.Keys | Sort-Object) -join ', ')."
  exit 1
}

$entry = $suiteMap[$Suite]

if ($entry.kind -eq "node") {
  $node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $node) {
    Write-Host "[FAIL] CI-SUITE-002 Suite '$Suite' requires Node.js, which was not found on PATH."
    exit 1
  }
  if ($ResolveOnly) {
    Write-Output "node $($entry.target)"
    exit 0
  }
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & $node.Source (Join-Path $repo $entry.target) @($entry.args)
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorActionPreference
  exit $exitCode
}

# PowerShell suite: spawn the same host this script runs under, exactly the way
# run-all-checks.ps1 does, so a pwsh 7 parent never fans out to Windows
# PowerShell 5.1 and a 5.1 parent never fans out to pwsh.
$ps = Get-PowerShellHost
if (-not $ps) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}
if ($ResolveOnly) {
  Write-Output "$ps -NoProfile -ExecutionPolicy Bypass -File $(Join-Path $repo $entry.target) $($entry.args -join ' ')"
  exit 0
}
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo $entry.target) @($entry.args)
$exitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
exit $exitCode
