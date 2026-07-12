param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/fill-project.ps1")

# Path with spaces, deliberately: real Windows project paths are rarely
# space-free ("D:\Projects\My Client\...").
$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pmo e2e standard fixture " + [guid]::NewGuid().ToString("N"))
try {
  New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/new-project.ps1") -ProjectCode "STANDARD-E2E" -Mode Standard -OutputRoot $workRoot | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Standard E2E: new-project.ps1 failed with exit $LASTEXITCODE" }
  $project = Join-Path $workRoot "STANDARD-E2E"

  # Real generated templates, filled in deterministically -- no copying an
  # example project over the generator's own output. This is what actually
  # exercises the template -> generator -> validator schema contract.
  Set-E2EProjectContent -ProjectPath $project -Mode Standard -ProjectCode "STANDARD-E2E"

  foreach ($gate in @("Draft", "Scope", "Design")) {
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/validate-project.ps1") -ProjectPath $project -Mode Standard -Gate $gate -FailOnWarning
    if ($LASTEXITCODE -ne 0) {
      $output | Write-Host
      throw "Standard E2E failed validation at Gate=$gate"
    }
  }

  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/validate-project.ps1") -ProjectPath $project -Mode Standard -Gate Release -FailOnWarning
  if ($LASTEXITCODE -ne 0) {
    $output | Write-Host
    throw "Standard E2E failed validation at Gate=Release"
  }
  Write-Host "[PASS] Standard E2E"
} finally {
  if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force
  }
}
