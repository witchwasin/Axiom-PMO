# Phase 0 helper — capture TEST-EVIDENCE-003 golden (stale release test evidence).
#
# Replicates the disposable-git fixture from tests/helpers/release-evidence-tests.ps1:
# a Standard Release project whose FILE: test evidence is committed in the base commit,
# then a change is committed WITHOUT touching the evidence file. The evidence is tracked
# but unchanged within base..head, so -ReleaseDiffBase/-ReleaseDiffHead flags it stale.
param([string]$RepoPath = ".")

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "../../scripts/lib/golden-normalizer.ps1")
. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$validator = Join-Path $repo "scripts/validate-project.ps1"
$goldenDir = Join-Path $repo "tests/golden"
New-Item -ItemType Directory -Force -Path $goldenDir | Out-Null
$pwshExe = Get-PowerShellHost
if (-not $pwshExe) { Write-Host (Get-PowerShellHostMissingMessage); exit 127 }

function Git-Cmd {
  param([string]$Dir, [string[]]$Arguments)
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try { $out = & git -C $Dir @Arguments 2>$null; $code = $LASTEXITCODE } finally { $ErrorActionPreference = $prev }
  return [pscustomobject]@{ Output = @($out); ExitCode = $code }
}
function Write-F {
  param([string]$Dir, [string]$Rel, [string]$Content = "content")
  $full = Join-Path $Dir $Rel
  $parent = Split-Path -Parent $full
  if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  Set-Content -LiteralPath $full -Value $Content -NoNewline
}
function Commit {
  param([string]$Dir, [string]$Msg)
  Git-Cmd -Dir $Dir -Arguments @("add", "-A") | Out-Null
  Git-Cmd -Dir $Dir -Arguments @("commit", "-q", "-m", $Msg) | Out-Null
  return ((Git-Cmd -Dir $Dir -Arguments @("rev-parse", "HEAD")).Output | Out-String).Trim()
}
function Write-StandardReleaseProject {
  param([string]$Dir, [string]$EvidencePath = "tests/evidence/report.xml")
  $projectMd = @'
# PROJECT - RELEVID

> Status: release-approved
> Default mode: Standard
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
  Write-F $Dir "PROJECT.md" $projectMd
  Write-F $Dir "DELIVERY.md" @'
# DELIVERY - RELEVID

## Delivery Mode

- Mode: Standard
- Task source of truth: `file`
- Mode owner: Fixture PM
- Current status set: `To Do`, `In Progress`, `Review / Test`, `Done`

## Work Items

| ID | Mode | Strict Trigger | Mode Reason | Mode Approved By | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Priority | Status | Review Stage | Evidence Ref | Labels |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| D-001 | Standard | none | normal feature | Fixture PM | Request submission | REQ-001 | DESIGN/FLOW.puml | Valid request is accepted | Happy | Fixture Dev | high | Done | qa | DEC-003 | review:qa |
'@
  Write-F $Dir "RELEASE.md" @"
# RELEASE - RELEVID

## Scope

- D-001

## Test Summary

| ID | Test Area | Result | Evidence | Notes |
|---|---|---|---|---|
| TEST-001 | Happy path | passed | FILE:$EvidencePath | |

## QA / Security Review

| Review Type | Status | Reviewer | Role | Date | Evidence |
|---|---|---|---|---|---|
| QA | approved | Fixture QA Lead | QA Lead | 2026-07-10 | DEC-003 |

## Structured Rollback Plan

| Trigger | Owner | Steps | Verification | Evidence Ref |
|---|---|---|---|---|
| Fixture release blocker | Fixture Lead | Revert the fixture change | Fixture no longer shows change | DEC-003 |
"@
  Write-F $Dir "decision-log.md" @'
# Decision Log

| ID | Decision | Date |
|---|---|---|
| DEC-001 | Scope approved | 2026-07-10 |
| DEC-002 | Design approved | 2026-07-10 |
| DEC-003 | Release approved | 2026-07-10 |
'@
  Write-F $Dir "RAID-log.md" @'
# RAID Log

| ID | Type | Description | Status |
|---|---|---|---|
| R-001 | risk | Normal delivery risk | closed |
'@
  Write-F $Dir "DESIGN/FLOW.puml" "@startuml`n@enduml"
  Write-F $Dir "source/REQ-20260710.md" "Requirement source for REQ-001."
  Write-F $Dir $EvidencePath '<testsuite name="happy" tests="1" failures="0"><testcase name="happy"/></testsuite>'
}

$dir = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-release-evidence-golden-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$init = Git-Cmd -Dir $dir -Arguments @("init", "-q", "--initial-branch=main")
if ($init.ExitCode -ne 0) { Git-Cmd -Dir $dir -Arguments @("init", "-q") | Out-Null }
Git-Cmd -Dir $dir -Arguments @("config", "user.email", "test@axiom-pmo.local") | Out-Null
Git-Cmd -Dir $dir -Arguments @("config", "user.name", "Axiom Release Evidence Golden") | Out-Null

try {
  Write-StandardReleaseProject -Dir $dir
  $base = Commit $dir "base"
  # A release change that does NOT touch the evidence file: the evidence is
  # tracked but unchanged within base..head, so it is stale.
  Write-F $dir "src/feature.ts" "export const ok = true;"
  $head = Commit $dir "change"

  $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $validator,
    "-ProjectPath", $dir, "-Mode", "Standard", "-Gate", "Release", "-Format", "Json",
    "-ReleaseDiffBase", $base, "-ReleaseDiffHead", $head)
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $output = & $pwshExe @psArgs 2>$null
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prev

  $raw = (($output | Out-String).TrimEnd()) + "`nEXIT_CODE=$code"
  $raw = $raw.Replace($dir, '<REPO_ROOT>')
  Set-Content -LiteralPath (Join-Path $goldenDir "test-evidence-003.txt") -Value (Get-CanonicalGoldenText -Text $raw) -NoNewline -Encoding utf8
  Write-Host "Captured test-evidence-003.txt"
} finally {
  Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
}
exit 0
