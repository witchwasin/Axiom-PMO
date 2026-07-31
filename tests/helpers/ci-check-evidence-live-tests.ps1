param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

# Live integration tests for the `ci-check` test-evidence adapter
# (Test-CiCheckEvidence in scripts/lib/execution-contract-evidence.ps1).
#
# Separate from tests/helpers/execution-contract-tests.ps1 on purpose. That
# suite is deliberately offline and hermetic -- disposable git fixtures, no
# network -- which is right for everything except this one adapter, whose
# entire value is that it asks a third party the verified actor cannot
# impersonate. Mocking the API here would test the mock; the offline suite can
# only cover the negative path (no remote, no gh, no auth -> unverified).
#
# Review called that a MAJOR test gap, correctly: the positive path -- a real
# check run found on a real commit, its *observed* conclusion deciding the
# verdict -- had never once executed. This file runs in CI, where a real API,
# a real repository, and real check runs exist.
#
# It SKIPS rather than fails when that context is absent (a developer running
# the suite locally without gh auth), and skips are reported loudly. A skipped
# assertion is not a passed one.

$ErrorActionPreference = "Stop"

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
. (Join-Path $repo "scripts/lib/scope-diff-matcher.ps1")
. (Join-Path $repo "scripts/lib/execution-contract-schema.ps1")
. (Join-Path $repo "scripts/lib/execution-contract-evidence.ps1")

$pass = 0
$fail = 0
$skip = 0

function Assert-True {
  param([string]$Name, [bool]$Condition, [string]$Detail = "")
  if ($Condition) { $script:pass++; Write-Host "[PASS] $Name" }
  else { $script:fail++; Write-Host "[FAIL] $Name$(if ($Detail) { " -- $Detail" })" }
}
function Add-Skip {
  param([string]$Name, [string]$Why)
  $script:skip++
  Write-Host "[SKIP] $Name -- $Why"
}

# Mirrors what the adapter itself builds an entry from, so these tests
# exercise the real function rather than a parallel implementation.
function New-CiEntry {
  param([string]$Name, [string]$CommitSha, [string]$Conclusion = $null)
  $raw = [ordered]@{ type = "ci-check"; name = $Name; commit_sha = $CommitSha }
  if ($Conclusion) { $raw["conclusion"] = $Conclusion }
  return [pscustomobject]@{
    Type = "ci-check"; Name = $Name; Known = $true; FieldsPresent = $true
    MissingFields = @(); Provenance = "externally-observed"
    Raw = ([pscustomobject]$raw)
  }
}

Write-Host "Axiom-PMO ci-check live evidence tests: $repo"
Write-Host ""

# --- context probe ----------------------------------------------------------

$ghAvailable = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
if (-not $ghAvailable) {
  Add-Skip "entire suite" "gh CLI not on PATH -- this file only means anything where a real GitHub API is reachable"
  Write-Host ""
  Write-Host "Summary: PASS=$pass FAIL=$fail SKIP=$skip"
  exit 0
}

$previousEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$remoteUrl = & git -C $repo remote get-url origin 2>$null
$remoteOk = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = $previousEap
if (-not $remoteOk -or [string]::IsNullOrWhiteSpace([string]$remoteUrl)) {
  Add-Skip "entire suite" "no git remote to query"
  Write-Host ""
  Write-Host "Summary: PASS=$pass FAIL=$fail SKIP=$skip"
  exit 0
}

# Find a commit that actually has a completed, successful check run. HEAD is
# a poor choice: this job may be running while its own siblings are still in
# progress, so their conclusions are null. Walking back a few commits finds
# one whose workflow finished, which is what a real consumer would cite
# anyway -- evidence is attached to work that already ran.
$foundSha = $null
$foundCheckName = $null
$foundFailingName = $null

for ($depth = 0; $depth -lt 8; $depth++) {
  $previousEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $sha = (& git -C $repo rev-parse "HEAD~$depth" 2>$null)
  $shaOk = ($LASTEXITCODE -eq 0)
  $ErrorActionPreference = $previousEap
  if (-not $shaOk) { break }
  if ($sha -is [array]) { $sha = $sha[0] }
  $sha = ([string]$sha).Trim()
  if ([string]::IsNullOrWhiteSpace($sha)) { break }

  $ownerRepo = Get-GitHubOwnerRepo -RemoteUrl ([string]$remoteUrl)
  if (-not $ownerRepo) { break }

  $previousEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $raw = & gh api "repos/$ownerRepo/commits/$sha/check-runs" 2>$null
  $apiOk = ($LASTEXITCODE -eq 0)
  $ErrorActionPreference = $previousEap
  if (-not $apiOk) { continue }

  try { $data = ($raw | Out-String) | ConvertFrom-Json } catch { continue }
  foreach ($run in @($data.check_runs)) {
    if ([string]$run.status -ne "completed") { continue }
    if ([string]$run.conclusion -eq "success" -and -not $foundCheckName) {
      $foundSha = $sha
      $foundCheckName = [string]$run.name
    }
    if ((@("failure", "cancelled", "timed_out") -contains [string]$run.conclusion) -and -not $foundFailingName) {
      $foundFailingName = [string]$run.name
    }
  }
  if ($foundCheckName) { break }
}

if (-not $foundCheckName) {
  Add-Skip "positive path" "no commit in the last 8 with a completed successful check run -- nothing real to verify against"
  Write-Host ""
  Write-Host "Summary: PASS=$pass FAIL=$fail SKIP=$skip"
  exit 0
}

Write-Host "Using real check run '$foundCheckName' on commit $foundSha"
Write-Host ""

# --- the positive path, finally exercised -----------------------------------

$entry = New-CiEntry -Name $foundCheckName -CommitSha $foundSha
$r = Test-CiCheckEvidence -Entry $entry -GitRepoRoot $repo
Assert-True "a real successful check run on a real commit verifies" $r.Verified $r.Reason

# --- and the ways it must not verify ----------------------------------------

$entry = New-CiEntry -Name "this-check-name-does-not-exist-anywhere" -CommitSha $foundSha
$r = Test-CiCheckEvidence -Entry $entry -GitRepoRoot $repo
Assert-True "a check name that does not exist on that commit does not verify" (-not $r.Verified)

# A syntactically valid SHA that is not a commit in this repository.
$entry = New-CiEntry -Name $foundCheckName -CommitSha ("0" * 40)
$r = Test-CiCheckEvidence -Entry $entry -GitRepoRoot $repo
Assert-True "the right check name on a nonexistent commit does not verify" (-not $r.Verified)

# The decisive one for this adapter: the result asserts success, and it is
# ignored. Only what the API reports counts. Without a real non-success check
# to point at, this can only be asserted against a nonexistent check -- still
# proves the claimed conclusion does not rescue an unverifiable entry.
$entry = New-CiEntry -Name "this-check-name-does-not-exist-anywhere" -CommitSha $foundSha -Conclusion "success"
$r = Test-CiCheckEvidence -Entry $entry -GitRepoRoot $repo
Assert-True "a claimed conclusion of success does not rescue a check the API cannot confirm" (-not $r.Verified)

if ($foundFailingName) {
  $entry = New-CiEntry -Name $foundFailingName -CommitSha $foundSha -Conclusion "success"
  $r = Test-CiCheckEvidence -Entry $entry -GitRepoRoot $repo
  Assert-True "a check the API reports as not-success is rejected despite the result claiming success" (-not $r.Verified)
} else {
  Add-Skip "observed-failure case" "no completed non-success check run found on that commit to point at"
}

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail SKIP=$skip"
if ($fail -gt 0) { exit 1 }
exit 0
