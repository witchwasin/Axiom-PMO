param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/fill-project.ps1")

$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pmo e2e strict " + [guid]::NewGuid().ToString("N"))
try {
  New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/new-project.ps1") -ProjectCode "STRICT-E2E" -Mode Strict -OutputRoot $workRoot | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Strict E2E: new-project.ps1 failed with exit $LASTEXITCODE" }
  $project = Join-Path $workRoot "STRICT-E2E"

  # Real generated templates (including the generator's own RTM.json), filled
  # in deterministically -- no copying an example project's RTM.json over the
  # generator's output. This is the exact blind spot that hid the RTM.yaml vs
  # RTM.json schema mismatch in Round 1.
  Set-E2EProjectContent -ProjectPath $project -Mode Strict -ProjectCode "STRICT-E2E"

  foreach ($gate in @("Draft", "Scope", "Design")) {
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/validate-project.ps1") -ProjectPath $project -Mode Strict -Gate $gate -FailOnWarning
    if ($LASTEXITCODE -ne 0) {
      $output | Write-Host
      throw "Strict E2E failed validation at Gate=$gate"
    }
  }

  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/validate-project.ps1") -ProjectPath $project -Mode Strict -Gate Release -FailOnWarning
  if ($LASTEXITCODE -ne 0) {
    $output | Write-Host
    throw "Strict E2E failed validation at Gate=Release"
  }
  Write-Host "[PASS] Strict E2E"
} finally {
  if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force
  }
}
