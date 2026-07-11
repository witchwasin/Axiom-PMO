param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pmo e2e standard " + [guid]::NewGuid().ToString("N"))
try {
  New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/new-project.ps1") -ProjectCode "STANDARD-E2E" -Mode Standard -OutputRoot $workRoot | Out-Null
  $project = Join-Path $workRoot "STANDARD-E2E"

  foreach ($name in @("PROJECT.md", "DELIVERY.md", "RELEASE.md", "RAID-log.md", "decision-log.md")) {
    Copy-Item -LiteralPath (Join-Path $RepoPath "examples/STANDARD-FEATURE/$name") -Destination (Join-Path $project $name) -Force
  }
  Copy-Item -Path (Join-Path $RepoPath "examples/STANDARD-FEATURE/DESIGN/*") -Destination (Join-Path $project "DESIGN") -Recurse -Force
  Copy-Item -Path (Join-Path $RepoPath "examples/STANDARD-FEATURE/source/*") -Destination (Join-Path $project "source") -Recurse -Force

  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/validate-project.ps1") -ProjectPath $project -Mode Standard -Gate Release
  if ($LASTEXITCODE -ne 0) {
    $output | Write-Host
    throw "Standard E2E failed validation"
  }
  Write-Host "[PASS] Standard E2E"
} finally {
  if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force
  }
}
