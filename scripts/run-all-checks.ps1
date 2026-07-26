param(
  [string]$RepoPath = ".",
  [string]$TestChildScript = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/pwsh-host.ps1")

$root = Resolve-Path -LiteralPath $RepoPath
$repo = $root.Path

$ps = Get-PowerShellHost
if (-not $ps) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

Write-Host "Running Axiom-PMO framework checks for $repo"
Write-Host ""

function Invoke-Check {
  param(
    [string]$Name,
    [scriptblock]$Command
  )

  & $Command
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    Write-Host ""
    Write-Host "Check failed: $Name exit $exitCode"
    # This aggregator runs a dozen checks inside a single CI step, so a bare
    # "Process completed with exit code 1" annotation says nothing about which
    # one broke -- and downloading the job log needs repository admin rights
    # that a contributor reading a failed PR does not have. A workflow-command
    # annotation puts the failing check's name on the run summary, where anyone
    # can see it.
    if ($env:GITHUB_ACTIONS -eq "true") {
      Write-Host "::error title=Axiom-PMO check failed::$Name exited $exitCode"
    }
    exit $exitCode
  }
}

if ($TestChildScript) {
  $testChild = Resolve-Path -LiteralPath $TestChildScript
  Invoke-Check "fault-injection" { & $ps -NoProfile -ExecutionPolicy Bypass -File $testChild.Path }
}

Invoke-Check "pmo-doctor" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/pmo-doctor.ps1") -RepoPath $repo }
Invoke-Check "validation-fixtures" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/run-validation-tests.ps1") -RepoPath $repo }
Invoke-Check "config-mutation" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/config-mutation-tests.ps1") -RepoPath $repo }
Invoke-Check "diagnostics-contract" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/diagnostics-contract-tests.ps1") -RepoPath $repo }
Invoke-Check "handoff-assessment" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/handoff-assessment-tests.ps1") -RepoPath $repo }
Invoke-Check "demo-smoke" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/demo-smoke-tests.ps1") -RepoPath $repo }
Invoke-Check "lite-example" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/validate-project.ps1") -ProjectPath (Join-Path $repo "examples/LITE-BUGFIX") -Mode Lite -Gate Scope -FailOnWarning }
Invoke-Check "standard-example" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/validate-project.ps1") -ProjectPath (Join-Path $repo "examples/STANDARD-FEATURE") -Mode Standard -Gate Release -FailOnWarning }
Invoke-Check "strict-example" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/validate-project.ps1") -ProjectPath (Join-Path $repo "examples/STRICT-HIGH-RISK") -Mode Strict -Gate Release -FailOnWarning }
Invoke-Check "e2e-lite" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/e2e/lite.ps1") -RepoPath $repo }
Invoke-Check "e2e-standard" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/e2e/standard.ps1") -RepoPath $repo }
Invoke-Check "e2e-strict" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/e2e/strict.ps1") -RepoPath $repo }
Invoke-Check "e2e-handoff" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/e2e/handoff.ps1") -RepoPath $repo }

# The CLI is the only part of the framework that is not PowerShell, so it is the
# only check that can be skipped for a missing runtime. Skipping is reported,
# never silent: a check that quietly does not run is worse than one that fails.
$node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($node) {
  Invoke-Check "cli" { & $node.Source (Join-Path $repo "tests/helpers/cli-tests.mjs") }
} else {
  Write-Host ""
  Write-Host "SKIPPED: cli tests -- Node.js was not found on PATH."
  Write-Host "         The CLI is an optional wrapper; the PowerShell scripts above are the reference implementation."
}

Write-Host ""
Write-Host "All Axiom-PMO framework checks completed."
