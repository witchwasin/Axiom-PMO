param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/fill-project.ps1")

# Thai directory name + a space, deliberately: the generator/validator must
# work on real-world Windows paths, not just ASCII no-space temp dirs.
$thaiLite = -join ([char[]](0x0E44, 0x0E25, 0x0E17, 0x0E4C))
$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pmo e2e $thaiLite " + [guid]::NewGuid().ToString("N"))
try {
  New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/new-project.ps1") -ProjectCode "LITE-E2E" -Mode Lite -OutputRoot $workRoot | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Lite E2E: new-project.ps1 failed with exit $LASTEXITCODE" }
  $project = Join-Path $workRoot "LITE-E2E"

  Set-E2EProjectContent -ProjectPath $project -Mode Lite -ProjectCode "LITE-E2E"

  foreach ($gate in @("Draft", "Scope", "Release")) {
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/validate-project.ps1") -ProjectPath $project -Mode Lite -Gate $gate
    if ($LASTEXITCODE -ne 0) {
      $output | Write-Host
      throw "Lite E2E failed validation at Gate=$gate"
    }
  }

  if (Test-Path -LiteralPath (Join-Path $project "RELEASE.md")) { throw "Lite E2E generated RELEASE.md unexpectedly" }
  if (Test-Path -LiteralPath (Join-Path $project "RTM.yaml")) { throw "Lite E2E generated RTM.yaml unexpectedly" }
  Write-Host "[PASS] Lite E2E"
} finally {
  if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force
  }
}
