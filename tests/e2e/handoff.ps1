param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

# End-to-end: generate a project with handoff scaffolding, fill the real
# templates deterministically, and walk every gate in order.
#
#   new project -> Draft -> Scope -> Design -> Handoff -> Release
#
# The Handoff gate sits between Design and Release without disturbing either,
# which is the compatibility claim this test exists to prove. The generated
# scaffold is also asserted to FAIL the Handoff gate before it is filled: a
# generator that emitted a passing handoff would be manufacturing evidence.

. (Join-Path $PSScriptRoot "lib/fill-project.ps1")
. (Join-Path $PSScriptRoot "../../scripts/lib/markdown-table-parser.ps1")
. (Join-Path $PSScriptRoot "../../scripts/lib/handoff-validator.ps1")

$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pmo e2e handoff " + [guid]::NewGuid().ToString("N"))
try {
  New-Item -ItemType Directory -Force -Path $workRoot | Out-Null

  & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/new-project.ps1") `
    -ProjectCode "HANDOFF-E2E" -Mode Standard -OutputRoot $workRoot `
    -IncludeHandoff -Target demo -HorizonDays 21 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Handoff E2E: new-project.ps1 failed with exit $LASTEXITCODE" }

  $project = Join-Path $workRoot "HANDOFF-E2E"

  foreach ($artifact in @("HANDOFF.md", "DESIGN/BUILD-SPEC.md", "HANDOFF-REVIEW.json")) {
    if (-not (Test-Path -LiteralPath (Join-Path $project $artifact))) {
      throw "Handoff E2E: -IncludeHandoff did not create $artifact"
    }
  }

  # An unfilled scaffold must not pass. This is the guard against a generator
  # that quietly produces something that looks reviewed.
  & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/validate-project.ps1") `
    -ProjectPath $project -Mode Standard -Gate Handoff | Out-Null
  if ($LASTEXITCODE -eq 0) {
    throw "Handoff E2E: a freshly generated, unfilled scaffold passed the Handoff gate"
  }

  Set-E2EProjectContent -ProjectPath $project -Mode Standard -ProjectCode "HANDOFF-E2E"
  Set-E2EHandoffContent -ProjectPath $project -Mode Standard -ProjectCode "HANDOFF-E2E"

  foreach ($gate in @("Draft", "Scope", "Design", "Handoff", "Release")) {
    $output = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/validate-project.ps1") `
      -ProjectPath $project -Mode Standard -Gate $gate -FailOnWarning
    if ($LASTEXITCODE -ne 0) {
      $output | Write-Host
      throw "Handoff E2E failed validation at Gate=$gate"
    }
  }

  # The assessment must run on the same project and report stage verdicts.
  $assessment = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/assess-handoff.ps1") `
    -ProjectPath $project -Mode Standard -Format Json
  if ($LASTEXITCODE -ne 0) {
    $assessment | Write-Host
    throw "Handoff E2E: assess-handoff.ps1 failed"
  }
  $parsed = ($assessment | Out-String) | ConvertFrom-Json
  if (-not $parsed.verdicts.'Contract Valid') {
    throw "Handoff E2E: assessment did not report a valid contract"
  }
  if (-not $parsed.verdicts.'Ready to Start Development') {
    throw "Handoff E2E: assessment did not report the project as ready to start development"
  }

  # Editing a reviewed artifact must invalidate the review even though the
  # sources are untouched. This is the path a single-digest design misses.
  $specFile = Join-Path $project "DESIGN/BUILD-SPEC.md"
  Add-Content -LiteralPath $specFile -Value "`nAdded after the review was recorded."
  $inputStaleOutput = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/validate-project.ps1") `
    -ProjectPath $project -Mode Standard -Gate Handoff -Format Json
  $inputStaleJson = ($inputStaleOutput | Out-String) | ConvertFrom-Json
  $inputStaleHits = @($inputStaleJson.results | Where-Object {
    $_.rule_id -eq "HANDOFF-010" -and $_.field -eq "review_inputs.digest"
  })
  if ($inputStaleHits.Count -eq 0) {
    throw "Handoff E2E: editing a reviewed artifact did not mark the review stale"
  }

  # Staleness is the property most likely to silently stop working: the digest
  # has to actually change when the sources do.
  $projectFile = Join-Path $project "PROJECT.md"
  $before = Get-SourceSnapshotDigest -ProjectText (Get-Content -LiteralPath $projectFile -Raw)
  $mutated = (Get-Content -LiteralPath $projectFile -Raw) -replace 'MOM-20260710', 'MOM-20260901'
  Set-Content -LiteralPath $projectFile -Value $mutated -Encoding utf8 -NoNewline
  $after = Get-SourceSnapshotDigest -ProjectText (Get-Content -LiteralPath $projectFile -Raw)
  if ($before -eq $after) {
    throw "Handoff E2E: the source snapshot digest did not change when the sources changed"
  }

  $staleOutput = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/validate-project.ps1") `
    -ProjectPath $project -Mode Standard -Gate Handoff -Format Json
  $staleJson = ($staleOutput | Out-String) | ConvertFrom-Json
  $staleHits = @($staleJson.results | Where-Object { $_.rule_id -eq "HANDOFF-010" -and $_.message -match "stale" })
  if ($staleHits.Count -eq 0) {
    throw "Handoff E2E: a review recorded against changed sources was not reported as stale"
  }

  Write-Host "[PASS] Handoff E2E"
} finally {
  if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force
  }
}
