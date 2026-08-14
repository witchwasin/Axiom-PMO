param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

# Behaviour tests for the M4 second increment (L2 completion): the release-path
# Test Summary check reconciled against git ground truth (TEST-EVIDENCE-003).
# When -ReleaseDiffBase/-ReleaseDiffHead are supplied to validate-project.ps1,
# a passed Test Summary row whose FILE: evidence is tracked but was NOT changed
# within base..head is stale -- it cannot be the output of a test run of this
# release's work. Severity mirrors APPROVAL-003 (WARN-blocking at Standard,
# FAIL at Strict), there is no human-vouch escape hatch on this path, and only
# tracked files are in scope (untracked/gitignored evidence is neither passed
# nor failed by the check). Exercised through validate-project.ps1 exactly the
# way a real caller would -- subprocess, JSON output -- over small, disposable
# git repositories built per case, the same pattern as scope-diff-tests.ps1.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$validator = Join-Path $repo "scripts/validate-project.ps1"
$pass = 0
$fail = 0

function Assert-True {
  param([string]$Name, [bool]$Condition, [string]$Detail = "")
  if ($Condition) {
    $script:pass++
    Write-Host "[PASS] $Name"
  } else {
    $script:fail++
    Write-Host "[FAIL] $Name$(if ($Detail) { " -- $Detail" })"
  }
}

# --- disposable git fixture (same pattern as scope-diff-tests.ps1) -----------

function Invoke-ReleaseEvidenceGit {
  param([string]$Dir, [string[]]$Arguments)
  # Windows PowerShell 5.1 promotes any native stderr to an ErrorRecord. Git's
  # harmless CRLF conversion notice must not terminate a test running under
  # ErrorActionPreference=Stop.
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & git -C $Dir @Arguments 2>$null
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previous
  }
  return [pscustomobject]@{ Output = @($output); ExitCode = $exitCode }
}

function New-ReleaseEvidenceGitFixture {
  $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-release-evidence-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  $init = Invoke-ReleaseEvidenceGit -Dir $dir -Arguments @("init", "-q", "--initial-branch=main")
  if ($init.ExitCode -ne 0) { Invoke-ReleaseEvidenceGit -Dir $dir -Arguments @("init", "-q") | Out-Null }  # older git: no --initial-branch
  Invoke-ReleaseEvidenceGit -Dir $dir -Arguments @("config", "user.email", "test@axiom-pmo.local") | Out-Null
  Invoke-ReleaseEvidenceGit -Dir $dir -Arguments @("config", "user.name", "Axiom Release Evidence Tests") | Out-Null
  return $dir
}

function Write-FixtureFile {
  param([string]$Dir, [string]$RelativePath, [string]$Content = "content")
  $full = Join-Path $Dir $RelativePath
  $parent = Split-Path -Parent $full
  if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  Set-Content -LiteralPath $full -Value $Content -NoNewline
}

function New-FixtureCommit {
  param([string]$Dir, [string]$Message)
  Invoke-ReleaseEvidenceGit -Dir $Dir -Arguments @("add", "-A") | Out-Null
  Invoke-ReleaseEvidenceGit -Dir $Dir -Arguments @("commit", "-q", "-m", $Message) | Out-Null
  $head = Invoke-ReleaseEvidenceGit -Dir $Dir -Arguments @("rev-parse", "HEAD")
  return (($head.Output | Out-String).Trim())
}

function Remove-ReleaseEvidenceGitFixture {
  param([string]$Dir)
  Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue
}

# A valid Standard-mode Release project, mirroring tests/fixtures/valid-standard
# so the positive cases genuinely pass every other rule. RELEASE.md's TEST-001
# row always cites FILE:evidence at $EvidencePath (project-relative). Pass
# -IncludeEvidenceFile to also create that file on disk.
function Write-StandardReleaseProject {
  param(
    [string]$Dir,
    [switch]$IncludeEvidenceFile,
    [string]$EvidencePath = "tests/evidence/report.xml",
    # The project's declared default mode. -Mode Lite cannot downgrade a
    # Standard-default project (MODE-001), so testing Lite behavior requires a
    # genuinely Lite-default project.
    [string]$DefaultMode = "Standard"
  )

  $projectMd = @'
# PROJECT - RELEVID

> Status: release-approved
> Default mode: DEFAULT_MODE_PLACEHOLDER
> Task source: file
> Owner: Fixture PM
> Last updated: 2026-07-10

## Task Management

```yaml
task_management:
  source_of_truth: delivery_file
  delivery_file: DELIVERY.md
  github_repository:
  rule: DELIVERY.md is master for this fixture
```

## Source Snapshot

| Source ID | Version / Date | Last Synced At |
|---|---|---|
| REQ-20260710 | v1 | 2026-07-10T10:00:00+07:00 |

## Scope

### In Scope

| ID | Requirement | Type | Source Ref | Evidence Status | Approval Status |
|---|---|---|---|---|---|
| REQ-001 | User can submit a valid request. | functional | REQ-20260710 row 1 | supported | approved |

## Approvals

| Gate | Approval Status | Approver | Role | Date | Evidence |
|---|---|---|---|---|---|
| Scope Approved | approved | Fixture PO | Product Owner | 2026-07-10 | DEC-001 |
| Design Ready | approved | Fixture PO | Product Owner | 2026-07-10 | DEC-002 |
| Release Approved | approved | Fixture PO | Product Owner | 2026-07-10 | DEC-003 |
'@
  $projectMd = $projectMd.Replace("DEFAULT_MODE_PLACEHOLDER", $DefaultMode)
  Write-FixtureFile $Dir "PROJECT.md" $projectMd

  $deliveryMd = @'
# DELIVERY - RELEVID

## Delivery Mode

- Mode: DEFAULT_MODE_PLACEHOLDER
- Task source of truth: `file`
- Mode owner: Fixture PM
- Current status set: `To Do`, `In Progress`, `Review / Test`, `Done`

## Work Items

| ID | Mode | Strict Trigger | Mode Reason | Mode Approved By | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Priority | Status | Review Stage | Evidence Ref | Labels |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| D-001 | DEFAULT_MODE_PLACEHOLDER | none | normal feature | Fixture PM | Request submission | REQ-001 | DESIGN/FLOW.puml | Valid request is accepted | Happy | Fixture Dev | high | Done | qa | DEC-003 | review:qa |
'@
  $deliveryMd = $deliveryMd.Replace("DEFAULT_MODE_PLACEHOLDER", $DefaultMode)
  Write-FixtureFile $Dir "DELIVERY.md" $deliveryMd

  $releaseMd = @'
# RELEASE - RELEVID

## Scope

- D-001

## Test Summary

| ID | Test Area | Result | Evidence | Notes |
|---|---|---|---|---|
| TEST-001 | Happy path | passed | FILE:EVIDENCE_PATH_PLACEHOLDER | |

## QA / Security Review

| Review Type | Status | Reviewer | Role | Date | Evidence |
|---|---|---|---|---|---|
| QA | approved | Fixture QA Lead | QA Lead | 2026-07-10 | DEC-003 |

## Structured Rollback Plan

| Trigger | Owner | Steps | Verification | Evidence Ref |
|---|---|---|---|---|
| Fixture release blocker | Fixture Lead | Revert the fixture change | Fixture no longer shows change | DEC-003 |
'@
  $releaseMd = $releaseMd.Replace("FILE:EVIDENCE_PATH_PLACEHOLDER", "FILE:$EvidencePath")
  Write-FixtureFile $Dir "RELEASE.md" $releaseMd

  Write-FixtureFile $Dir "decision-log.md" @'
# Decision Log

| ID | Decision | Date |
|---|---|---|
| DEC-001 | Scope approved | 2026-07-10 |
| DEC-002 | Design approved | 2026-07-10 |
| DEC-003 | Release approved | 2026-07-10 |
'@

  Write-FixtureFile $Dir "RAID-log.md" @'
# RAID Log

| ID | Type | Description | Status |
|---|---|---|---|
| R-001 | risk | Normal delivery risk | closed |
'@

  Write-FixtureFile $Dir "DESIGN/FLOW.puml" "@startuml`n@enduml"
  Write-FixtureFile $Dir "source/REQ-20260710.md" "Requirement source for REQ-001."

  if ($IncludeEvidenceFile) {
    Write-FixtureFile $Dir $EvidencePath '<testsuite name="happy" tests="1" failures="0"><testcase name="happy"/></testsuite>'
  }
}

function Invoke-ReleaseValidate {
  param(
    [string]$ProjectPath,
    [string]$Mode = "Standard",
    [string]$Base = $null,
    [string]$Head = $null
  )
  $psArgs = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $validator,
    "-ProjectPath", $ProjectPath, "-Mode", $Mode, "-Gate", "Release", "-Format", "Json"
  )
  if ($Base) { $psArgs += @("-ReleaseDiffBase", $Base) }
  if ($Head) { $psArgs += @("-ReleaseDiffHead", $Head) }
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & $pwshExe @psArgs 2>$null
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $previous
  $json = $null
  try { $json = (($output | Out-String) | ConvertFrom-Json) } catch { }
  return [pscustomobject]@{ Json = $json; ExitCode = $exitCode }
}

function Get-TestEvidenceRows {
  param($Json, [string]$Level)
  return @($Json.results | Where-Object { $_.rule_id -eq "TEST-EVIDENCE-003" -and $_.level -eq $Level })
}

Write-Host "Axiom-PMO Release Evidence (git ground truth) Tests: $repo"
Write-Host ""

# ---- Case: opt-in -- no refs supplied, no TEST-EVIDENCE-003 rows, exit 0 ----
{
  $dir = New-ReleaseEvidenceGitFixture
  try {
    Write-StandardReleaseProject -Dir $dir -IncludeEvidenceFile
    New-FixtureCommit $dir "base" | Out-Null

    $r = Invoke-ReleaseValidate -ProjectPath $dir
    Assert-True "opt-in: no TEST-EVIDENCE-003 rows when refs are omitted" `
      (@($r.Json.results | Where-Object { $_.rule_id -eq "TEST-EVIDENCE-003" }).Count -eq 0)
    Assert-True "opt-in: project still passes at Standard Release" ($r.ExitCode -eq 0) "exit $($r.ExitCode)"
  } finally { Remove-ReleaseEvidenceGitFixture $dir }
}.Invoke()

# ---- Case: fresh evidence inside the verified range -> PASS, exit 0 ---------
{
  $dir = New-ReleaseEvidenceGitFixture
  try {
    Write-StandardReleaseProject -Dir $dir
    $base = New-FixtureCommit $dir "base"
    # The release's work: the evidence file is produced and committed within
    # the range, alongside the code change it proves.
    Write-FixtureFile $dir "tests/evidence/report.xml" '<testsuite name="happy" tests="1" failures="0"><testcase name="happy"/></testsuite>'
    Write-FixtureFile $dir "src/feature.ts" "export const ok = true;"
    $head = New-FixtureCommit $dir "change"

    $r = Invoke-ReleaseValidate -ProjectPath $dir -Base $base -Head $head
    Assert-True "fresh-in-range: TEST-EVIDENCE-003 PASS row present" `
      ((Get-TestEvidenceRows -Json $r.Json -Level "PASS").Count -eq 1)
    Assert-True "fresh-in-range: no TEST-EVIDENCE-003 WARN/FAIL row" `
      ((Get-TestEvidenceRows -Json $r.Json -Level "WARN").Count -eq 0 -and (Get-TestEvidenceRows -Json $r.Json -Level "FAIL").Count -eq 0)
    Assert-True "fresh-in-range: overall exit 0" ($r.ExitCode -eq 0) "exit $($r.ExitCode)"
  } finally { Remove-ReleaseEvidenceGitFixture $dir }
}.Invoke()

# ---- Case: stale evidence (tracked, unchanged in range) -> WARN-block Standard --
{
  $dir = New-ReleaseEvidenceGitFixture
  try {
    Write-StandardReleaseProject -Dir $dir -IncludeEvidenceFile
    $base = New-FixtureCommit $dir "base"
    # The release's work changes code, but the evidence report is an old file.
    Write-FixtureFile $dir "src/feature.ts" "export const ok = true;"
    $head = New-FixtureCommit $dir "change"

    $r = Invoke-ReleaseValidate -ProjectPath $dir -Base $base -Head $head
    $warns = Get-TestEvidenceRows -Json $r.Json -Level "WARN"
    Assert-True "stale-standard: TEST-EVIDENCE-003 WARN row present" ($warns.Count -eq 1)
    Assert-True "stale-standard: WARN is blocking (mirrors APPROVAL-003)" ($warns[0].blocking -eq $true)
    Assert-True "stale-standard: message names the evidence path" `
      ($warns[0].message -match "tests/evidence/report\.xml")
    Assert-True "stale-standard: message names the git-ground-truth defect" `
      ($warns[0].message -match "not changed within the release's verified commit range")
    Assert-True "stale-standard: WARN-block alone does not fail the run (exit 0)" ($r.ExitCode -eq 0) "exit $($r.ExitCode)"
  } finally { Remove-ReleaseEvidenceGitFixture $dir }
}.Invoke()

# ---- Case: same stale evidence at Strict -> FAIL, exit 1 ---------------------
{
  $dir = New-ReleaseEvidenceGitFixture
  try {
    Write-StandardReleaseProject -Dir $dir -IncludeEvidenceFile
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "src/feature.ts" "export const ok = true;"
    $head = New-FixtureCommit $dir "change"

    $r = Invoke-ReleaseValidate -ProjectPath $dir -Mode "Strict" -Base $base -Head $head
    $fails = Get-TestEvidenceRows -Json $r.Json -Level "FAIL"
    Assert-True "stale-strict: TEST-EVIDENCE-003 FAIL row present" ($fails.Count -eq 1)
    Assert-True "stale-strict: message names the git-ground-truth defect" `
      ($fails[0].message -match "not changed within the release's verified commit range")
    Assert-True "stale-strict: overall exit 1" ($r.ExitCode -eq 1) "exit $($r.ExitCode)"
  } finally { Remove-ReleaseEvidenceGitFixture $dir }
}.Invoke()

# ---- Case: tracked evidence modified in the working tree (uncommitted) ------
{
  $dir = New-ReleaseEvidenceGitFixture
  try {
    Write-StandardReleaseProject -Dir $dir -IncludeEvidenceFile
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "src/feature.ts" "export const ok = true;"
    $head = New-FixtureCommit $dir "change"
    # The report is touched after the fact, never committed.
    Write-FixtureFile $dir "tests/evidence/report.xml" '<testsuite name="forged" tests="99" failures="0"/>'

    $r = Invoke-ReleaseValidate -ProjectPath $dir -Base $base -Head $head
    $warns = Get-TestEvidenceRows -Json $r.Json -Level "WARN"
    Assert-True "uncommitted: TEST-EVIDENCE-003 WARN row present" ($warns.Count -eq 1)
    Assert-True "uncommitted: message names the uncommitted state" `
      ($warns[0].message -match "uncommitted changes")
  } finally { Remove-ReleaseEvidenceGitFixture $dir }
}.Invoke()

# ---- Case: evidence staged but never committed (retro-added after head) -----
{
  $dir = New-ReleaseEvidenceGitFixture
  try {
    Write-StandardReleaseProject -Dir $dir
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "src/feature.ts" "export const ok = true;"
    $head = New-FixtureCommit $dir "change"
    # Added to the index after the head commit: tracked (visible to
    # ls-files) but not part of base..head.
    Write-FixtureFile $dir "tests/evidence/report.xml" '<testsuite name="happy" tests="1" failures="0"/>'
    Invoke-ReleaseEvidenceGit -Dir $dir -Arguments @("add", "tests/evidence/report.xml") | Out-Null

    $r = Invoke-ReleaseValidate -ProjectPath $dir -Base $base -Head $head
    $warns = Get-TestEvidenceRows -Json $r.Json -Level "WARN"
    Assert-True "retro-added: TEST-EVIDENCE-003 WARN row present" ($warns.Count -eq 1)
    Assert-True "retro-added: message names the uncommitted state" `
      ($warns[0].message -match "uncommitted changes")
  } finally { Remove-ReleaseEvidenceGitFixture $dir }
}.Invoke()

# ---- Case: untracked evidence is out of scope entirely (Round 3 decision 3) -
{
  $dir = New-ReleaseEvidenceGitFixture
  try {
    Write-StandardReleaseProject -Dir $dir
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "src/feature.ts" "export const ok = true;"
    $head = New-FixtureCommit $dir "change"
    # A brand-new file that git never saw: a legitimately gitignored CI report
    # directory behaves exactly this way. Must be neither passed nor failed by
    # the git check -- same as before this check existed.
    Write-FixtureFile $dir "tests/evidence/report.xml" '<testsuite name="happy" tests="1" failures="0"/>'

    $r = Invoke-ReleaseValidate -ProjectPath $dir -Base $base -Head $head
    Assert-True "untracked: no TEST-EVIDENCE-003 WARN/FAIL row (out of scope)" `
      ((Get-TestEvidenceRows -Json $r.Json -Level "WARN").Count -eq 0 -and (Get-TestEvidenceRows -Json $r.Json -Level "FAIL").Count -eq 0)
    Assert-True "untracked: overall exit 0 (evidence still resolves on disk)" ($r.ExitCode -eq 0) "exit $($r.ExitCode)"
  } finally { Remove-ReleaseEvidenceGitFixture $dir }
}.Invoke()

# ---- Case: project inside a subdirectory of the repo (Action shape) --------
# The GitHub Action runs the framework from the consumer checkout, where the
# project is a subdirectory of the repository. Evidence paths are project-
# relative; git diff names repo-root-relative paths; the bridge must hold.
{
  $dir = New-ReleaseEvidenceGitFixture
  try {
    Write-StandardReleaseProject -Dir (Join-Path $dir "project") -IncludeEvidenceFile
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "project/src/feature.ts" "export const ok = true;"
    $head = New-FixtureCommit $dir "change"

    $r = Invoke-ReleaseValidate -ProjectPath (Join-Path $dir "project") -Base $base -Head $head
    $warns = Get-TestEvidenceRows -Json $r.Json -Level "WARN"
    Assert-True "subdir: stale evidence caught across the repo-root boundary" ($warns.Count -eq 1)
    Assert-True "subdir: message names the repo-root-relative evidence path" `
      ($warns[0].message -match "project/tests/evidence/report\.xml")
  } finally { Remove-ReleaseEvidenceGitFixture $dir }
}.Invoke()

# ---- Case: Lite is exempt, same as APPROVAL-003 (no row at all) ------------
{
  $dir = New-ReleaseEvidenceGitFixture
  try {
    # A genuinely Lite-default project: -Mode Lite cannot downgrade a
    # Standard-default one (MODE-001), so the exemption is only reachable
    # when the project itself is Lite.
    Write-StandardReleaseProject -Dir $dir -IncludeEvidenceFile -DefaultMode "Lite"
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "src/feature.ts" "export const ok = true;"
    $head = New-FixtureCommit $dir "change"

    $r = Invoke-ReleaseValidate -ProjectPath $dir -Mode "Lite" -Base $base -Head $head
    Assert-True "lite: no TEST-EVIDENCE-003 row of any level" `
      (@($r.Json.results | Where-Object { $_.rule_id -eq "TEST-EVIDENCE-003" }).Count -eq 0)
    Assert-True "lite: project still passes at Lite Release" ($r.ExitCode -eq 0) "exit $($r.ExitCode)"
  } finally { Remove-ReleaseEvidenceGitFixture $dir }
}.Invoke()

# ---- Case: unresolvable base commit -> always FAIL (infra, mirrors SCOPE-DIFF-004) --
{
  $dir = New-ReleaseEvidenceGitFixture
  try {
    Write-StandardReleaseProject -Dir $dir -IncludeEvidenceFile
    $base = New-FixtureCommit $dir "base"

    $r = Invoke-ReleaseValidate -ProjectPath $dir -Base "0000000000000000000000000000000000000000" -Head $base
    $fails = Get-TestEvidenceRows -Json $r.Json -Level "FAIL"
    Assert-True "bad base: TEST-EVIDENCE-003 FAIL row present" ($fails.Count -eq 1)
    Assert-True "bad base: message mentions fetch-depth guidance" `
      ($fails[0].message -match "fetch-depth")
    Assert-True "bad base: overall exit 1" ($r.ExitCode -eq 1) "exit $($r.ExitCode)"
  } finally { Remove-ReleaseEvidenceGitFixture $dir }
}.Invoke()

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"
if ($fail -gt 0) { exit 1 }
exit 0
