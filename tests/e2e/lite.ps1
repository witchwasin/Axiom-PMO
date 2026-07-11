param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

$thaiLite = -join ([char[]](0x0E44, 0x0E25, 0x0E17, 0x0E4C))
$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pmo e2e $thaiLite " + [guid]::NewGuid().ToString("N"))
try {
  New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/new-project.ps1") -ProjectCode "LITE-E2E" -Mode Lite -OutputRoot $workRoot | Out-Null
  $project = Join-Path $workRoot "LITE-E2E"

  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/LITE-BUGFIX/PROJECT.md") -Destination (Join-Path $project "PROJECT.md") -Force
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/LITE-BUGFIX/DELIVERY.md") -Destination (Join-Path $project "DELIVERY.md") -Force

  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/validate-project.ps1") -ProjectPath $project -Mode Lite -Gate Release | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Lite E2E failed validation" }

  if (Test-Path -LiteralPath (Join-Path $project "RELEASE.md")) { throw "Lite E2E generated RELEASE.md unexpectedly" }
  if (Test-Path -LiteralPath (Join-Path $project "RTM.yaml")) { throw "Lite E2E generated RTM.yaml unexpectedly" }
  Write-Host "[PASS] Lite E2E"
} finally {
  if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force
  }
}
