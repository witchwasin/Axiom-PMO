param(
  [string]$RepoPath = "."
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path -LiteralPath $RepoPath
$repo = $root.Path

Write-Host "Running PMO framework checks for $repo"
Write-Host ""

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/pmo-doctor.ps1") -RepoPath $repo
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/run-validation-tests.ps1") -RepoPath $repo
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/validate-project.ps1") -ProjectPath (Join-Path $repo "examples/LITE-BUGFIX") -Mode Lite -Gate Scope -FailOnWarning
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/validate-project.ps1") -ProjectPath (Join-Path $repo "examples/STANDARD-FEATURE") -Mode Standard -Gate Release -FailOnWarning
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/validate-project.ps1") -ProjectPath (Join-Path $repo "examples/STRICT-HIGH-RISK") -Mode Strict -Gate Release -FailOnWarning

Write-Host ""
Write-Host "All PMO framework checks completed."

