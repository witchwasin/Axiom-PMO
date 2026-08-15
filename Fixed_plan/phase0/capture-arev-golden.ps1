# Phase 0 helper — capture AREV-001..007 goldens.
#
# Replicates the disposable-git fixture machinery from tests/helpers/adversarial-review-tests.ps1
# verbatim (same functions, same fixture shape), runs one scenario per rule through the real
# entrypoint (scripts/verify-execution-result.ps1), and stores canonical JSON golden per rule.
param([string]$RepoPath = ".")

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "../../scripts/lib/golden-normalizer.ps1")
. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$exportScript = Join-Path $repo "scripts/export-execution-contract.ps1"
$verifyScript = Join-Path $repo "scripts/verify-execution-result.ps1"
$runExecutionScript = Join-Path $repo "scripts/run-execution-command.ps1"
$goldenDir = Join-Path $repo "tests/golden"
New-Item -ItemType Directory -Force -Path $goldenDir | Out-Null
$pwshExe = Get-PowerShellHost
if (-not $pwshExe) { Write-Host (Get-PowerShellHostMissingMessage); exit 127 }

function Invoke-FixtureGit {
  param([string]$Dir)
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  & git -C $Dir @Args 2>$null | Out-Null
  $ErrorActionPreference = $prev
}
function Get-FixtureGit {
  param([string]$Dir)
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $out = & git -C $Dir @Args 2>$null
  $ErrorActionPreference = $prev
  return $out
}
function New-ReviewFixture {
  param([string]$Mode = "Strict")
  $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-arev-golden-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $dir "src") -Force | Out-Null
  $projectMd = @(
    "# P99-AREV", "", "> Default mode: $Mode", "", "### In Scope", "",
    "| ID | Requirement | Source Ref | Evidence Status |", "|---|---|---|---|",
    "| REQ-001 | Checkout flow | MOM-001 | verified |"
  ) -join "`n"
  Set-Content -LiteralPath (Join-Path $dir "PROJECT.md") -Value $projectMd -NoNewline
  Set-Content -LiteralPath (Join-Path $dir "SCOPE.json") -Value '{"schema_version":"1.0","project":"P99-AREV","implementation_scope":{"include":["src/**"],"exclude":[]}}' -NoNewline
  $delivery = @(
    "# DELIVERY - P99-AREV", "", "## Work Items", "",
    "| ID | Mode | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Status |",
    "|---|---|---|---|---|---|---|---|---|",
    "| D-001 | $Mode | Checkout flow | REQ-001 | DESIGN/FLOW.puml | Works | unit tests | Dev | To Do |"
  ) -join "`n"
  Set-Content -LiteralPath (Join-Path $dir "DELIVERY.md") -Value $delivery -NoNewline
  Set-Content -LiteralPath (Join-Path $dir "src/app.ts") -Value "seed" -NoNewline
  Set-Content -LiteralPath (Join-Path $dir "decision-log.md") -Value "# Decision Log - P99-AREV`n`n| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |`n|---|---|---|---|---|---|---|---|`n" -NoNewline
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  & git -C $dir init -q --initial-branch=main 2>$null
  if ($LASTEXITCODE -ne 0) { & git -C $dir init -q 2>$null }
  $ErrorActionPreference = $prev
  Invoke-FixtureGit $dir config user.email "test@axiom-pmo.local"
  Invoke-FixtureGit $dir config user.name "Axiom Adversarial Review Golden"
  Invoke-FixtureGit $dir config core.autocrlf false
  Invoke-FixtureGit $dir config core.safecrlf false
  Invoke-FixtureGit $dir add -A
  Invoke-FixtureGit $dir commit -q -m "base"
  return $dir
}
function Remove-ReviewFixture { param([string]$Dir) Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue }
function Invoke-Export {
  param([string]$Dir)
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  & $pwshExe -NoProfile -ExecutionPolicy Bypass -File $exportScript -ProjectPath $Dir -WorkItemId "D-001" -Force 2>&1 | Out-Null
  $ErrorActionPreference = $prev
}
function Invoke-Verify {
  param([string]$Dir)
  $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $verifyScript, "-ProjectPath", $Dir, "-ResultPath", (Join-Path $Dir ".execution/D-001/EXECUTION-RESULT.json"), "-Format", "Json")
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $output = & $pwshExe @psArgs 2>$null
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prev
  $json = $null
  try { $json = (($output | Out-String) | ConvertFrom-Json) } catch { }
  return [pscustomobject]@{ Json = $json; ExitCode = $code; Raw = ($output | Out-String) }
}
function Get-ContractDigest { param([string]$Dir) return (Get-Content -LiteralPath (Join-Path $Dir ".execution/D-001/EXECUTION-CONTRACT.json.sha256") -Raw).Trim() }
function New-RealRunRecord {
  param([string]$Dir)
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  & $pwshExe -NoProfile -ExecutionPolicy Bypass -File $runExecutionScript -ProjectPath $Dir -WorkItemId "D-001" -Name "unit tests" -Command "echo ok" 2>&1 | Out-Null
  $ErrorActionPreference = $prev
  $runsDir = Join-Path $Dir ".execution/D-001/runs"
  $recordFile = @(Get-ChildItem -LiteralPath $runsDir -Filter "*.json" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '\.sha256$' })[0]
  return ".execution/D-001/runs/$($recordFile.Name)"
}
function New-BaseResult {
  param([string]$Dir, [hashtable]$Overrides = @{})
  $digest = Get-ContractDigest -Dir $Dir
  $contract = Get-Content -LiteralPath (Join-Path $Dir ".execution/D-001/EXECUTION-CONTRACT.json") -Raw | ConvertFrom-Json
  $head = (Get-FixtureGit $Dir rev-parse HEAD).Trim()
  $relRunRecordPath = New-RealRunRecord -Dir $Dir
  $recordDigest = (Get-FileHash -LiteralPath (Join-Path $Dir $relRunRecordPath) -Algorithm SHA256).Hash.ToLowerInvariant()
  $log = @(
    "# Decision Log - P99-AREV", "",
    "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
    "|---|---|---|---|---|---|---|---|",
    "| 2026-07-31 | DEC-100 | Accept unit tests for D-001 | accept / require CI | accept | axiom-authority: type=test-evidence-accepted; work_item=D-001; contract=$digest; test=unit tests; evidence=$recordDigest | none | test evidence accepted |"
  ) -join "`n"
  Set-Content -LiteralPath (Join-Path $Dir "decision-log.md") -Value $log -NoNewline
  $doc = [ordered]@{
    contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $digest
    base_sha = [string]$contract.base_sha; head_sha = $head; execution_status = "completed"
    changed_files = @()
    test_evidence = @([ordered]@{ type = "runner-exit-record"; name = "unit tests"; run_record_path = $relRunRecordPath })
    authority_claims = @([ordered]@{ type = "test-evidence-accepted"; actor = "human"; claim = "accepted"; decision_ref = "DEC-100"; test_name = "unit tests"; evidence_sha256 = $recordDigest; evidence_type = "runner-exit-record"; work_item_id = "D-001" })
  }
  foreach ($key in $Overrides.Keys) { $doc[$key] = $Overrides[$key] }
  $path = Join-Path $Dir ".execution/D-001/EXECUTION-RESULT.json"
  Set-Content -LiteralPath $path -Value ($doc | ConvertTo-Json -Depth 12) -NoNewline
  return [pscustomobject]@{ Digest = $digest; Head = $head; BaseSha = [string]$contract.base_sha }
}
function New-Review {
  param([string]$Dir, [pscustomobject]$Identity, [hashtable]$Overrides = @{}, $Findings = @())
  $doc = [ordered]@{
    schema_version = "1.0"; review_id = "AR-001"; contract_sha256 = $Identity.Digest
    base_sha = $Identity.BaseSha; head_sha = $Identity.Head; reviewed_at = "2026-08-05"
    reviewer_kind = "ai"; reviewer = "test-reviewer"
    provenance = [ordered]@{ tier = "artifact-observed"; check_run_id = $null }
    findings = $Findings
    recommendation = [ordered]@{ verdict = "request_changes"; notes = "test" }
  }
  foreach ($key in $Overrides.Keys) { $doc[$key] = $Overrides[$key] }
  Set-Content -LiteralPath (Join-Path $Dir ".execution/D-001/EXECUTION-REVIEW.json") -Value ($doc | ConvertTo-Json -Depth 12) -NoNewline
}
function Capture {
  param([string]$Dir, [string]$Name, [int]$Code, [string]$Raw)
  $raw = ($Raw.TrimEnd()) + "`nEXIT_CODE=$Code"
  $raw = $raw.Replace($Dir, '<REPO_ROOT>')
  Set-Content -LiteralPath (Join-Path $goldenDir "$Name.txt") -Value (Get-CanonicalGoldenText -Text $raw) -NoNewline -Encoding utf8
  Write-Host "Captured $Name.txt"
}

# AREV-001: Strict mode, missing review fails closed
$d = New-ReviewFixture -Mode "Strict"
try {
  Invoke-Export -Dir $d
  New-BaseResult -Dir $d | Out-Null
  $r = Invoke-Verify -Dir $d
  Capture $d "arev-001" $r.ExitCode $r.Raw
} finally { Remove-ReviewFixture $d }

# AREV-002: review answers a different contract
$d = New-ReviewFixture -Mode "Strict"
try {
  Invoke-Export -Dir $d
  $id = New-BaseResult -Dir $d
  New-Review -Dir $d -Identity $id -Overrides @{ contract_sha256 = ("0" * 64) }
  $r = Invoke-Verify -Dir $d
  Capture $d "arev-002" $r.ExitCode $r.Raw
} finally { Remove-ReviewFixture $d }

# AREV-003: artifact-observed alone never satisfies (Strict, no human vouch)
$d = New-ReviewFixture -Mode "Strict"
try {
  Invoke-Export -Dir $d
  $id = New-BaseResult -Dir $d
  New-Review -Dir $d -Identity $id
  $r = Invoke-Verify -Dir $d
  Capture $d "arev-003" $r.ExitCode $r.Raw
} finally { Remove-ReviewFixture $d }

# AREV-004: finding missing required fields
$d = New-ReviewFixture -Mode "Standard"
try {
  Invoke-Export -Dir $d
  $id = New-BaseResult -Dir $d
  New-Review -Dir $d -Identity $id -Findings @([ordered]@{ finding_id = "AF-001"; category = "not-a-real-category"; severity = "major"; status = "open"; description = ""; suggestion = ""; requirement_ref = "REQ-001"; implementation_claim = "x"; test_claim = "x"; owner = "Alice Chen" })
  $r = Invoke-Verify -Dir $d
  Capture $d "arev-004" $r.ExitCode $r.Raw
} finally { Remove-ReviewFixture $d }

# AREV-005: executor tries to close its own finding
$d = New-ReviewFixture -Mode "Standard"
try {
  Invoke-Export -Dir $d
  $id = New-BaseResult -Dir $d -Overrides @{ review_finding_dispositions = @([ordered]@{ finding_id = "AF-001"; status = "accepted_risk" }) }
  New-Review -Dir $d -Identity $id -Findings @([ordered]@{ finding_id = "AF-001"; category = "other"; severity = "minor"; status = "open"; description = "d"; suggestion = "s"; requirement_ref = "REQ-001"; implementation_claim = "x"; test_claim = "x"; owner = "Alice Chen" })
  $r = Invoke-Verify -Dir $d
  Capture $d "arev-005" $r.ExitCode $r.Raw
} finally { Remove-ReviewFixture $d }

# AREV-006: accepted_risk with an unresolvable decision_ref
$d = New-ReviewFixture -Mode "Standard"
try {
  Invoke-Export -Dir $d
  $id = New-BaseResult -Dir $d
  New-Review -Dir $d -Identity $id -Findings @([ordered]@{ finding_id = "AF-001"; category = "other"; severity = "minor"; status = "accepted_risk"; description = "d"; suggestion = "s"; decision_ref = "DEC-999"; requirement_ref = "REQ-001"; implementation_claim = "x"; test_claim = "x"; owner = "Alice Chen" })
  $r = Invoke-Verify -Dir $d
  Capture $d "arev-006" $r.ExitCode $r.Raw
} finally { Remove-ReviewFixture $d }

# AREV-007: finding missing requirement_ref
$d = New-ReviewFixture -Mode "Standard"
try {
  Invoke-Export -Dir $d
  $id = New-BaseResult -Dir $d
  New-Review -Dir $d -Identity $id -Findings @([ordered]@{ finding_id = "AF-001"; category = "acceptance-criteria-gap"; severity = "major"; status = "open"; description = "d"; suggestion = "s"; implementation_claim = "x"; test_claim = "x"; owner = "Alice Chen" })
  $r = Invoke-Verify -Dir $d
  Capture $d "arev-007" $r.ExitCode $r.Raw
} finally { Remove-ReviewFixture $d }

exit 0
