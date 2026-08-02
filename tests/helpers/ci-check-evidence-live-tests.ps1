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
  param([string]$Name, [string]$CommitSha, [string]$Conclusion = $null, [string]$CheckRunId = $null)
  $raw = [ordered]@{ type = "ci-check"; name = $Name; commit_sha = $CommitSha }
  if ($Conclusion) { $raw["conclusion"] = $Conclusion }
  if ($CheckRunId) { $raw["check_run_id"] = $CheckRunId }
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

# Find a commit that has a completed, successful check run -- starting at
# HEAD~1, deliberately skipping HEAD.
#
# HEAD is where this job itself is running, and its check runs are in flight
# by definition. Worse, a SHA can carry two workflow runs at once (an
# automatic push trigger plus a manual dispatch), so the *same check name*
# appears twice: one completed, one running. The first version of this file
# started at HEAD and did exactly that -- discovery selected a completed
# successful run, and the adapter then matched the in-flight twin with a
# null conclusion. That surfaced a real ordering bug in the adapter (now
# fixed: same-named runs must all agree), but the test itself was also wrong
# to look at a commit whose checks were still moving.
#
# Starting one commit back is also more honest about the real usage: evidence
# is cited for work that already ran, not for the run producing it.
$foundSha = $null
$foundCheckName = $null
$foundCheckRunId = $null
$foundFailingName = $null

for ($depth = 1; $depth -lt 9; $depth++) {
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
      $foundCheckRunId = [string]$run.id
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

# --- case sensitivity: "Build" must not satisfy evidence naming "build" ----
# Review found both name-comparison sites used PowerShell's -eq/-ne, which are
# case-insensitive for strings. Proved directly rather than argued:
# $flippedName is the SAME real, currently-passing check, cited by a
# different-case spelling of its own real name. If case were ignored, either
# path below would verify; neither must.
$flippedName = $foundCheckName.ToUpperInvariant()
$flippedNameUsable = ($flippedName -cne $foundCheckName)

if ($flippedNameUsable) {
  $entry = New-CiEntry -Name $flippedName -CommitSha $foundSha
  $r = Test-CiCheckEvidence -Entry $entry -GitRepoRoot $repo
  Assert-True "name-search path: a different-case name does not verify a real, currently-passing run" `
    (-not $r.Verified) $r.Reason
} else {
  Add-Skip "name-search path case-sensitivity" "the real check name has no letter case to flip ('$foundCheckName')"
}

# --- check_run_id: the direct-lookup path and its binding checks -----------

if ($foundCheckRunId) {
  $entry = New-CiEntry -Name $foundCheckName -CommitSha $foundSha -CheckRunId $foundCheckRunId
  $r = Test-CiCheckEvidence -Entry $entry -GitRepoRoot $repo
  Assert-True "citing check_run_id directly verifies the same real run" $r.Verified $r.Reason

  # The binding checks -- an id alone is not enough, or an actor could cite a
  # real, green check_run_id that happened to belong to someone else's commit
  # or a different check entirely.
  $entry = New-CiEntry -Name $foundCheckName -CommitSha ("0" * 40) -CheckRunId $foundCheckRunId
  $r = Test-CiCheckEvidence -Entry $entry -GitRepoRoot $repo
  Assert-True "check_run_id bound to the wrong commit_sha does not verify" (-not $r.Verified) $r.Reason

  $entry = New-CiEntry -Name "this-check-name-does-not-exist-anywhere" -CommitSha $foundSha -CheckRunId $foundCheckRunId
  $r = Test-CiCheckEvidence -Entry $entry -GitRepoRoot $repo
  Assert-True "check_run_id bound to the wrong name does not verify" (-not $r.Verified) $r.Reason

  # A syntactically plausible but real-world-impossible id. GitHub check run
  # ids are large; a small one should 404 rather than collide with anything.
  $entry = New-CiEntry -Name $foundCheckName -CommitSha $foundSha -CheckRunId "1"
  $r = Test-CiCheckEvidence -Entry $entry -GitRepoRoot $repo
  Assert-True "a nonexistent check_run_id does not verify" (-not $r.Verified) $r.Reason

  $entry = New-CiEntry -Name $foundCheckName -CommitSha $foundSha -CheckRunId "not-a-number"
  $r = Test-CiCheckEvidence -Entry $entry -GitRepoRoot $repo
  Assert-True "a non-numeric check_run_id does not verify" (-not $r.Verified) $r.Reason

  if ($flippedNameUsable) {
    $entry = New-CiEntry -Name $flippedName -CommitSha $foundSha -CheckRunId $foundCheckRunId
    $r = Test-CiCheckEvidence -Entry $entry -GitRepoRoot $repo
    Assert-True "check_run_id path: a different-case name does not verify a real, currently-passing run" `
      (-not $r.Verified) $r.Reason
  } else {
    Add-Skip "check_run_id path case-sensitivity" "the real check name has no letter case to flip ('$foundCheckName')"
  }
} else {
  Add-Skip "check_run_id positive path" "the discovered successful run carried no id, which should not happen against a real API response"
}

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

# --- ambiguity: the same name, more than one completed run -----------------
#
# A SHA can carry several runs under one check name -- a re-run, or two
# workflows triggered on the same commit. Before this was handled, the
# adapter took whichever the API listed first, so a name that failed once and
# passed once could verify or not depending on ordering. That is precisely
# the shape an actor would exploit: re-run a job until one attempt goes
# green, then cite the name.
$ambiguousName = $null
$ambiguousSuccessId = $null
$allSuccessDuplicateName = $null
$previousEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$rawAll = & gh api "repos/$(Get-GitHubOwnerRepo -RemoteUrl ([string]$remoteUrl))/commits/$foundSha/check-runs" 2>$null
$allOk = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = $previousEap
if ($allOk) {
  try {
    $allData = ($rawAll | Out-String) | ConvertFrom-Json
    $byName = @{}
    $successIdByName = @{}
    foreach ($run in @($allData.check_runs)) {
      if ([string]$run.status -ne "completed") { continue }
      $n = [string]$run.name
      if (-not $byName.ContainsKey($n)) { $byName[$n] = @() }
      $byName[$n] += [string]$run.conclusion
      if ([string]$run.conclusion -eq "success" -and -not $successIdByName.ContainsKey($n)) {
        $successIdByName[$n] = [string]$run.id
      }
    }
    foreach ($k in $byName.Keys) {
      $vals = @($byName[$k])
      if ($vals.Count -lt 2) { continue }
      $distinct = @($vals | Select-Object -Unique)
      if (($distinct.Count -gt 1) -and (-not $ambiguousName)) {
        $ambiguousName = $k
        if ($successIdByName.ContainsKey($k)) { $ambiguousSuccessId = $successIdByName[$k] }
      }
      if (($distinct.Count -eq 1) -and ($distinct[0] -eq "success") -and (-not $allSuccessDuplicateName)) { $allSuccessDuplicateName = $k }
    }
  } catch { }
}

if ($ambiguousName) {
  $entry = New-CiEntry -Name $ambiguousName -CommitSha $foundSha -Conclusion "success"
  $r = Test-CiCheckEvidence -Entry $entry -GitRepoRoot $repo
  Assert-True "a name with both a passing and a failing completed run does not verify" (-not $r.Verified) $r.Reason

  # This is the defect check_run_id exists to close, reproduced against a real
  # commit rather than argued about: the same name that just failed to verify
  # above -- because SOME completed run under it is not success -- verifies
  # when the evidence names the specific successful run's id instead. A check
  # that failed once and was re-run to green is no longer permanently unable
  # to be cited; it was only ever the by-name search that could not tell the
  # two runs apart.
  if ($ambiguousSuccessId) {
    $entry = New-CiEntry -Name $ambiguousName -CommitSha $foundSha -CheckRunId $ambiguousSuccessId
    $r = Test-CiCheckEvidence -Entry $entry -GitRepoRoot $repo
    Assert-True "the decisive case: citing the successful run's id verifies despite a failing sibling under the same name" `
      $r.Verified $r.Reason
  } else {
    Add-Skip "check_run_id closes the permanent-false-negative case" "the ambiguous name's successful run carried no id"
  }
} else {
  Add-Skip "mixed-conclusion duplicate case" "no check name on that commit has completed runs disagreeing"
  Add-Skip "check_run_id closes the permanent-false-negative case" "no mixed-conclusion duplicate name found to reproduce it against"
}

if ($allSuccessDuplicateName) {
  $entry = New-CiEntry -Name $allSuccessDuplicateName -CommitSha $foundSha
  $r = Test-CiCheckEvidence -Entry $entry -GitRepoRoot $repo
  Assert-True "duplicate runs that all report success still verify" $r.Verified $r.Reason
} else {
  Add-Skip "all-success duplicate case" "no check name on that commit has multiple completed successful runs"
}

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail SKIP=$skip"
if ($fail -gt 0) { exit 1 }
exit 0
