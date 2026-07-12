param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pmo e2e strict " + [guid]::NewGuid().ToString("N"))
try {
  New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/new-project.ps1") -ProjectCode "STRICT-E2E" -Mode Strict -OutputRoot $workRoot | Out-Null
  $project = Join-Path $workRoot "STRICT-E2E"

  foreach ($name in @("PROJECT.md", "DELIVERY.md", "RELEASE.md", "RAID-log.md", "decision-log.md", "RTM.json")) {
    Copy-Item -LiteralPath (Join-Path $RepoPath "examples/STRICT-HIGH-RISK/$name") -Destination (Join-Path $project $name) -Force
  }
  Copy-Item -Path (Join-Path $RepoPath "examples/STRICT-HIGH-RISK/DESIGN/*") -Destination (Join-Path $project "DESIGN") -Recurse -Force
  Copy-Item -Path (Join-Path $RepoPath "examples/STRICT-HIGH-RISK/source/*") -Destination (Join-Path $project "source") -Recurse -Force

  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/validate-project.ps1") -ProjectPath $project -Mode Strict -Gate Release
  if ($LASTEXITCODE -ne 0) {
    $output | Write-Host
    throw "Strict E2E failed validation"
  }
  Write-Host "[PASS] Strict E2E"
} finally {
  if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force
  }
}
