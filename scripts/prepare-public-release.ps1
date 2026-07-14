#requires -Version 5.1
<#
.SYNOPSIS
  Non-destructive public-release readiness check for Axiom-PMO.

.DESCRIPTION
  Verifies version consistency, runs the public hygiene guard, and optionally
  runs the check suite. It NEVER commits, pushes, tags, merges, or deploys. At
  the end it PRINTS the git commands a human can review and run to publish the
  release.

.PARAMETER RepoPath
  Repository root. Defaults to the parent of this script's directory.

.PARAMETER RunSuite
  Also run the doctor, fixture matrix, and example golden verification.
#>
param(
  [string]$RepoPath = "",
  [switch]$RunSuite
)

$ErrorActionPreference = "Stop"
if (-not $RepoPath) { $RepoPath = Join-Path $PSScriptRoot ".." }
$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$expectedTag = "v1.0.0"

$problems = @()
$notes = @()

function Section($t) { Write-Host ""; Write-Host "== $t ==" }

Write-Host "Axiom-PMO public-release readiness (non-destructive): $repo"

# --- Version consistency -----------------------------------------------------
Section "Version consistency"
$versionText = (Get-Content -LiteralPath (Join-Path $repo "VERSION") -Raw).Trim()
$changelogText = Get-Content -LiteralPath (Join-Path $repo "CHANGELOG.md") -Raw
$changelogVersion = ""
if ($changelogText -match '(?m)^##\s+([^\s]+)\s+-') { $changelogVersion = $Matches[1] }
$configVersions = @()
foreach ($c in @("policy.json","skill-manifest.json","validation-rules.json","context-map.json","artifact-policy.json","reference-types.json")) {
  $cfg = Get-Content -LiteralPath (Join-Path $repo "pmo-config/$c") -Raw | ConvertFrom-Json
  $configVersions += $cfg.version
}
$allVersions = @($versionText, $changelogVersion) + $configVersions | Sort-Object -Unique
if ($allVersions.Count -eq 1) {
  Write-Host "OK: all version fields = $versionText"
} else {
  $problems += "Version drift: VERSION=$versionText CHANGELOG=$changelogVersion CONFIG=$($configVersions -join ',')"
  Write-Host "FAIL: version drift ($($allVersions -join ' / '))"
}

# --- Public hygiene ----------------------------------------------------------
Section "Public hygiene"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/check-public-hygiene.ps1") -RepoPath $repo
$hygieneCode = $LASTEXITCODE
if ($hygieneCode -ne 0) {
  $problems += "Public hygiene check failed (exit $hygieneCode)"
}

# --- Working tree status (informational) -------------------------------------
Section "Working tree"
$status = & git -C $repo -c core.excludesFile= status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
  Write-Host "Clean working tree."
} else {
  $notes += "Working tree has uncommitted changes (expected during the overhaul)."
  Write-Host "Note: uncommitted changes present:"
  $status -split "`n" | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" }
}

# --- Optional: run the suite -------------------------------------------------
if ($RunSuite) {
  Section "Check suite"
  $suite = @(
    @{ n = "doctor"; f = "scripts/pmo-doctor.ps1"; a = @() },
    @{ n = "fixtures"; f = "scripts/run-validation-tests.ps1"; a = @("-RepoPath", $repo, "-VerifyGolden") },
    @{ n = "example-goldens"; f = "tests/golden/capture-examples.ps1"; a = @("-Verify") }
  )
  foreach ($s in $suite) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo $s.f) @($s.a) | Out-Null
    $code = $LASTEXITCODE
    if ($code -ne 0) { $problems += "Check '$($s.n)' failed (exit $code)" }
    Write-Host ("{0}: exit {1}" -f $s.n, $code)
  }
}

# --- Verdict + printed release commands --------------------------------------
Section "Verdict"
if ($problems.Count -gt 0) {
  Write-Host "NOT READY. Resolve the following before releasing:"
  $problems | ForEach-Object { Write-Host "  - $_" }
} else {
  Write-Host "Readiness checks passed."
}
$notes | ForEach-Object { Write-Host "  note: $_" }

Section "Release commands (review and run manually -- this script runs none of them)"
@"
git status
git diff --check
git add .
git commit -m "release: publish Axiom-PMO 1.0.0"
git tag -a $expectedTag -m "Axiom-PMO 1.0.0"
git push origin <release-branch>
git push origin $expectedTag
"@ | Write-Host

if ($problems.Count -gt 0) { exit 1 } else { exit 0 }
