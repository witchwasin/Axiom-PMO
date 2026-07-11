param(
  [string]$RepoPath = ".",
  [string]$TestChildScript = ""
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path -LiteralPath $RepoPath
$repo = $root.Path

Write-Host "Running PMO framework checks for $repo"
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
    exit $exitCode
  }
}

if ($TestChildScript) {
  $testChild = Resolve-Path -LiteralPath $TestChildScript
  Invoke-Check "fault-injection" { powershell -NoProfile -ExecutionPolicy Bypass -File $testChild.Path }
}

Invoke-Check "pmo-doctor" { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/pmo-doctor.ps1") -RepoPath $repo }
Invoke-Check "validation-fixtures" { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/run-validation-tests.ps1") -RepoPath $repo }
Invoke-Check "config-mutation" { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/config-mutation-tests.ps1") -RepoPath $repo }
Invoke-Check "lite-example" { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/validate-project.ps1") -ProjectPath (Join-Path $repo "examples/LITE-BUGFIX") -Mode Lite -Gate Scope -FailOnWarning }
Invoke-Check "standard-example" { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/validate-project.ps1") -ProjectPath (Join-Path $repo "examples/STANDARD-FEATURE") -Mode Standard -Gate Release -FailOnWarning }
Invoke-Check "strict-example" { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/validate-project.ps1") -ProjectPath (Join-Path $repo "examples/STRICT-HIGH-RISK") -Mode Strict -Gate Release -FailOnWarning }
Invoke-Check "e2e-lite" { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/e2e/lite.ps1") -RepoPath $repo }
Invoke-Check "e2e-standard" { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/e2e/standard.ps1") -RepoPath $repo }
Invoke-Check "e2e-strict" { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/e2e/strict.ps1") -RepoPath $repo }

Write-Host ""
Write-Host "All PMO framework checks completed."
