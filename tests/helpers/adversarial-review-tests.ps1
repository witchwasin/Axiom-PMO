param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

# Behaviour tests for Milestone 8.1 adversarial review evidence
# (scripts/lib/adversarial-review-validator.ps1), exercised end to end through
# scripts/export-execution-contract.ps1 and scripts/verify-execution-result.ps1
# as real subprocesses, using real disposable git repositories -- the same
# strategy and the same reason as tests/helpers/execution-contract-tests.ps1:
# this feature's job is comparing a review artifact's claims against a
# contract and against who is allowed to close what, so a mock would prove
# the code agrees with the mock. Cases are written adversarially: the
# interesting ones are where the review is self-served, unbound, or closed by
# an actor without authority to close it.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$exportScript = Join-Path $repo "scripts/export-execution-contract.ps1"
$verifyScript = Join-Path $repo "scripts/verify-execution-result.ps1"
$runExecutionScript = Join-Path $repo "scripts/run-execution-command.ps1"
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

function Invoke-FixtureGit {
  param([string]$Dir)
  $previous = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  & git -C $Dir @Args 2>$null | Out-Null
  $ErrorActionPreference = $previous
}

function Get-FixtureGit {
  param([string]$Dir)
  $previous = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $out = & git -C $Dir @Args 2>$null
  $ErrorActionPreference = $previous
  return $out
}

function New-ReviewFixture {
  param([string]$Mode = "Strict")

  $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-arev-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $dir "src") -Force | Out-Null

  Set-Content -LiteralPath (Join-Path $dir "PROJECT.md") -Value "# P99-AREV`n`n> Default mode: $Mode`n" -NoNewline
  Set-Content -LiteralPath (Join-Path $dir "SCOPE.json") -Value '{"schema_version":"1.0","project":"P99-AREV","implementation_scope":{"include":["src/**"],"exclude":[]}}' -NoNewline
  $delivery = @(
    "# DELIVERY - P99-AREV", "",
    "## Work Items", "",
    "| ID | Mode | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Status |",
    "|---|---|---|---|---|---|---|---|---|",
    "| D-001 | $Mode | Checkout flow | REQ-001 | DESIGN/FLOW.puml | Works | unit tests | Dev | To Do |"
  ) -join "`n"
  Set-Content -LiteralPath (Join-Path $dir "DELIVERY.md") -Value $delivery -NoNewline
  Set-Content -LiteralPath (Join-Path $dir "src/app.ts") -Value "seed" -NoNewline
  Set-Content -LiteralPath (Join-Path $dir "decision-log.md") -Value "# Decision Log - P99-AREV`n`n| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |`n|---|---|---|---|---|---|---|---|`n" -NoNewline

  $previousEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & git -C $dir init -q --initial-branch=main 2>$null
  if ($LASTEXITCODE -ne 0) { & git -C $dir init -q 2>$null }
  $ErrorActionPreference = $previousEap
  Invoke-FixtureGit $dir config user.email "test@axiom-pmo.local"
  Invoke-FixtureGit $dir config user.name "Axiom Adversarial Review Tests"
  Invoke-FixtureGit $dir config core.autocrlf false
  Invoke-FixtureGit $dir config core.safecrlf false
  Invoke-FixtureGit $dir add -A
  Invoke-FixtureGit $dir commit -q -m "base"
  return $dir
}

function Remove-ReviewFixture {
  param([string]$Dir)
  Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue
}

function Invoke-Export {
  param([string]$Dir)
  $previous = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  & $pwshExe -NoProfile -ExecutionPolicy Bypass -File $exportScript -ProjectPath $Dir -WorkItemId "D-001" -Force 2>&1 | Out-Null
  $ErrorActionPreference = $previous
}

function Invoke-Verify {
  param([string]$Dir, [switch]$Preflight)
  $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $verifyScript,
    "-ProjectPath", $Dir, "-ResultPath", (Join-Path $Dir ".execution/D-001/EXECUTION-RESULT.json"), "-Format", "Json")
  if ($Preflight) { $psArgs += "-Preflight" }
  $previous = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $output = & $pwshExe @psArgs 2>$null
  $code = $LASTEXITCODE
  $ErrorActionPreference = $previous
  $json = $null
  try { $json = (($output | Out-String) | ConvertFrom-Json) } catch { }
  return [pscustomobject]@{ Json = $json; ExitCode = $code }
}

function Get-ContractDigest {
  param([string]$Dir)
  return (Get-Content -LiteralPath (Join-Path $Dir ".execution/D-001/EXECUTION-CONTRACT.json.sha256") -Raw).Trim()
}

function New-RealRunRecord {
  param([string]$Dir)
  $previous = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  & $pwshExe -NoProfile -ExecutionPolicy Bypass -File $runExecutionScript -ProjectPath $Dir -WorkItemId "D-001" -Name "unit tests" -Command "echo ok" 2>&1 | Out-Null
  $ErrorActionPreference = $previous
  $runsDir = Join-Path $Dir ".execution/D-001/runs"
  $recordFile = @(Get-ChildItem -LiteralPath $runsDir -Filter "*.json" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '\.sha256$' })[0]
  return ".execution/D-001/runs/$($recordFile.Name)"
}

# Base EXECUTION-RESULT.json every case starts from: clean, satisfies EXEC-*
# on its own (real run record, human-vouched via a decision row outside the
# verified range), so a failure any of these cases assert is attributable to
# AREV-*, not to an unrelated EXEC-* problem.
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
    authority_claims = @([ordered]@{
      type = "test-evidence-accepted"; actor = "human"; claim = "accepted"
      decision_ref = "DEC-100"; test_name = "unit tests"; evidence_sha256 = $recordDigest
      evidence_type = "runner-exit-record"; work_item_id = "D-001"
    })
  }
  foreach ($key in $Overrides.Keys) { $doc[$key] = $Overrides[$key] }
  $path = Join-Path $Dir ".execution/D-001/EXECUTION-RESULT.json"
  Set-Content -LiteralPath $path -Value ($doc | ConvertTo-Json -Depth 12) -NoNewline
  return [pscustomobject]@{ Digest = $digest; Head = $head; BaseSha = [string]$contract.base_sha }
}

function New-Review {
  param([string]$Dir, [pscustomobject]$Identity, [hashtable]$Overrides = @{}, $Findings = @())

  $doc = [ordered]@{
    schema_version = "1.0"; review_id = "AR-001"
    contract_sha256 = $Identity.Digest; base_sha = $Identity.BaseSha; head_sha = $Identity.Head
    reviewed_at = "2026-08-05"; reviewer_kind = "ai"; reviewer = "test-reviewer"
    provenance = [ordered]@{ tier = "artifact-observed"; check_run_id = $null }
    findings = $Findings
    recommendation = [ordered]@{ verdict = "request_changes"; notes = "test" }
  }
  foreach ($key in $Overrides.Keys) { $doc[$key] = $Overrides[$key] }
  Set-Content -LiteralPath (Join-Path $Dir ".execution/D-001/EXECUTION-REVIEW.json") -Value ($doc | ConvertTo-Json -Depth 12) -NoNewline
}

function Get-Rules {
  param($Json, [string]$Level = "FAIL")
  if (-not $Json) { return @() }
  return @($Json.results | Where-Object { $_.level -eq $Level } | ForEach-Object { $_.rule_id })
}

Write-Host "Axiom-PMO Adversarial Review Evidence Tests: $repo"
Write-Host ""

# ---- Case: Lite mode -- disabled, no diagnostic at all ----------------------
{
  $dir = New-ReviewFixture -Mode "Lite"
  try {
    Invoke-Export -Dir $dir
    New-BaseResult -Dir $dir | Out-Null
    $r = Invoke-Verify -Dir $dir
    Assert-True "Lite mode: no EXECUTION-REVIEW.json, no AREV-001 diagnostic at all" `
      (-not (@($r.Json.results | Where-Object { $_.rule_id -eq "AREV-001" }).Count))
    Assert-True "Lite mode: verdict still pass" ($r.Json.execution_verification.verdict -eq "pass")
  } finally { Remove-ReviewFixture $dir }
}.Invoke()

# ---- Case: Standard mode -- missing review is advisory, not blocking -------
{
  $dir = New-ReviewFixture -Mode "Standard"
  try {
    Invoke-Export -Dir $dir
    New-BaseResult -Dir $dir | Out-Null
    $r = Invoke-Verify -Dir $dir
    Assert-True "Standard mode: missing review is WARN, not FAIL" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "AREV-001" })[0]).level -eq "WARN")
    Assert-True "Standard mode: missing review does not block the verdict" ($r.Json.execution_verification.verdict -eq "pass")
  } finally { Remove-ReviewFixture $dir }
}.Invoke()

# ---- Case: Strict mode -- missing review fails closed -----------------------
{
  $dir = New-ReviewFixture -Mode "Strict"
  try {
    Invoke-Export -Dir $dir
    New-BaseResult -Dir $dir | Out-Null
    $r = Invoke-Verify -Dir $dir
    Assert-True "Strict mode: missing review is FAIL" ((Get-Rules $r.Json) -contains "AREV-001")
    Assert-True "Strict mode: missing review blocks the verdict" ($r.Json.execution_verification.verdict -ne "pass")
  } finally { Remove-ReviewFixture $dir }
}.Invoke()

# ---- Case: Strict mode -- --preflight skips AREV entirely -------------------
{
  $dir = New-ReviewFixture -Mode "Strict"
  try {
    Invoke-Export -Dir $dir
    New-BaseResult -Dir $dir | Out-Null
    $r = Invoke-Verify -Dir $dir -Preflight
    Assert-True "--preflight: no AREV-* diagnostic at all, even in Strict with no review" `
      (-not (@($r.Json.results | Where-Object { $_.rule_id -like "AREV-*" }).Count))
    Assert-True "--preflight: verdict still pass (mechanical checks alone are clean)" ($r.Json.execution_verification.verdict -eq "pass")
  } finally { Remove-ReviewFixture $dir }
}.Invoke()

# ---- Case: Strict mode -- artifact-observed alone never satisfies ----------
{
  $dir = New-ReviewFixture -Mode "Strict"
  try {
    Invoke-Export -Dir $dir
    $id = New-BaseResult -Dir $dir
    New-Review -Dir $dir -Identity $id
    $r = Invoke-Verify -Dir $dir
    Assert-True "artifact-observed alone: AREV-003 raised" ((Get-Rules $r.Json) -contains "AREV-003")
    Assert-True "artifact-observed alone: blocks the verdict" ($r.Json.execution_verification.verdict -ne "pass")
  } finally { Remove-ReviewFixture $dir }
}.Invoke()

# ---- Case: artifact-observed, promoted by a bound human claim, satisfies ---
{
  $dir = New-ReviewFixture -Mode "Strict"
  try {
    Invoke-Export -Dir $dir
    $id = New-BaseResult -Dir $dir
    New-Review -Dir $dir -Identity $id
    $resultPath = Join-Path $dir ".execution/D-001/EXECUTION-RESULT.json"
    $resultDoc = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    $claims = @($resultDoc.authority_claims) + @([pscustomobject]@{ type = "review-evidence-accepted"; actor = "human"; claim = "accepted"; decision_ref = "DEC-101"; work_item_id = "D-001" })
    $resultDoc | Add-Member -NotePropertyName authority_claims -NotePropertyValue $claims -Force
    Set-Content -LiteralPath $resultPath -Value ($resultDoc | ConvertTo-Json -Depth 12) -NoNewline

    $logPath = Join-Path $dir "decision-log.md"
    $log = (Get-Content -LiteralPath $logPath -Raw).TrimEnd("`n") + "`n| 2026-07-31 | DEC-101 | Accept the review for D-001 | accept | accept | axiom-authority: type=review-evidence-accepted; work_item=D-001; contract=$($id.Digest) | none | review accepted |"
    Set-Content -LiteralPath $logPath -Value $log -NoNewline

    $r = Invoke-Verify -Dir $dir
    Assert-True "artifact-observed promoted: AREV-003 not raised" ((Get-Rules $r.Json) -notcontains "AREV-003")
    Assert-True "artifact-observed promoted: verdict pass" ($r.Json.execution_verification.verdict -eq "pass")
  } finally { Remove-ReviewFixture $dir }
}.Invoke()

# ---- Case: review answers a different contract ------------------------------
{
  $dir = New-ReviewFixture -Mode "Strict"
  try {
    Invoke-Export -Dir $dir
    $id = New-BaseResult -Dir $dir
    New-Review -Dir $dir -Identity $id -Overrides @{ contract_sha256 = "0" * 64 }
    $r = Invoke-Verify -Dir $dir
    Assert-True "wrong contract digest: AREV-002 raised" ((Get-Rules $r.Json) -contains "AREV-002")
  } finally { Remove-ReviewFixture $dir }
}.Invoke()

# ---- Case: finding missing required fields ----------------------------------
{
  $dir = New-ReviewFixture -Mode "Standard"
  try {
    Invoke-Export -Dir $dir
    $id = New-BaseResult -Dir $dir
    New-Review -Dir $dir -Identity $id -Findings @([ordered]@{ finding_id = "AF-001"; category = "not-a-real-category"; severity = "major"; status = "open"; description = ""; suggestion = "" })
    $r = Invoke-Verify -Dir $dir
    Assert-True "malformed finding: AREV-004 raised" ((Get-Rules $r.Json) -contains "AREV-004")
  } finally { Remove-ReviewFixture $dir }
}.Invoke()

# ---- Case: executor tries to close its own finding --------------------------
{
  $dir = New-ReviewFixture -Mode "Standard"
  try {
    Invoke-Export -Dir $dir
    $id = New-BaseResult -Dir $dir -Overrides @{ review_finding_dispositions = @([ordered]@{ finding_id = "AF-001"; status = "accepted_risk" }) }
    New-Review -Dir $dir -Identity $id -Findings @([ordered]@{ finding_id = "AF-001"; category = "other"; severity = "minor"; status = "open"; description = "d"; suggestion = "s" })
    $r = Invoke-Verify -Dir $dir
    Assert-True "executor self-closure attempt: AREV-005 raised" ((Get-Rules $r.Json) -contains "AREV-005")
    Assert-True "executor self-closure attempt: names EXECUTION-RESULT.json as the artifact" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "AREV-005" -and $_.artifact -eq "EXECUTION-RESULT.json" }).Count) -gt 0)
  } finally { Remove-ReviewFixture $dir }
}.Invoke()

# ---- Case: AI reviewer closes a human-only-category finding ----------------
{
  $dir = New-ReviewFixture -Mode "Standard"
  try {
    Invoke-Export -Dir $dir
    $id = New-BaseResult -Dir $dir
    New-Review -Dir $dir -Identity $id -Findings @([ordered]@{ finding_id = "AF-001"; category = "security"; severity = "critical"; status = "resolved"; description = "d"; suggestion = "s" })
    $r = Invoke-Verify -Dir $dir
    Assert-True "AI closes human-only category: AREV-005 raised" ((Get-Rules $r.Json) -contains "AREV-005")
  } finally { Remove-ReviewFixture $dir }
}.Invoke()

# ---- Case: disputed is not a closure, stays out of AREV-005 ----------------
{
  $dir = New-ReviewFixture -Mode "Standard"
  try {
    Invoke-Export -Dir $dir
    $id = New-BaseResult -Dir $dir
    New-Review -Dir $dir -Identity $id -Findings @([ordered]@{ finding_id = "AF-001"; category = "other"; severity = "minor"; status = "disputed"; description = "d"; suggestion = "s" })
    $r = Invoke-Verify -Dir $dir
    Assert-True "disputed status alone: no AREV-005" ((Get-Rules $r.Json) -notcontains "AREV-005")
  } finally { Remove-ReviewFixture $dir }
}.Invoke()

# ---- Case: accepted_risk with an unresolvable decision_ref -----------------
{
  $dir = New-ReviewFixture -Mode "Standard"
  try {
    Invoke-Export -Dir $dir
    $id = New-BaseResult -Dir $dir
    New-Review -Dir $dir -Identity $id -Findings @([ordered]@{ finding_id = "AF-001"; category = "other"; severity = "minor"; status = "accepted_risk"; description = "d"; suggestion = "s"; decision_ref = "DEC-999" })
    $r = Invoke-Verify -Dir $dir
    Assert-True "unresolvable decision_ref: AREV-006 raised" ((Get-Rules $r.Json) -contains "AREV-006")
  } finally { Remove-ReviewFixture $dir }
}.Invoke()

# ---- Case: accepted_risk citing a decision added within the verified range -
{
  $dir = New-ReviewFixture -Mode "Standard"
  try {
    Invoke-Export -Dir $dir
    $digest = Get-ContractDigest -Dir $dir
    $contract = Get-Content -LiteralPath (Join-Path $dir ".execution/D-001/EXECUTION-CONTRACT.json") -Raw | ConvertFrom-Json
    $relRunRecordPath = New-RealRunRecord -Dir $dir

    # The forged-decision attack, adapted from execution-contract-tests.ps1's
    # own EXEC-007 case: within the SAME commit range under verification, add
    # a decision row that resolves and cite it.
    $forgedLog = @(
      "# Decision Log - P99-AREV", "",
      "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
      "|---|---|---|---|---|---|---|---|",
      "| 2026-07-30 | DEC-200 | forged | A | A | agent wrote this | none | none |"
    ) -join "`n"
    Set-Content -LiteralPath (Join-Path $dir "decision-log.md") -Value $forgedLog -NoNewline
    & git -C $dir add -A 2>$null | Out-Null
    & git -C $dir commit -q -m "self-forged decision" 2>$null | Out-Null
    $head = (Get-FixtureGit $dir rev-parse HEAD).Trim()

    $doc = [ordered]@{
      contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $digest
      base_sha = [string]$contract.base_sha; head_sha = $head; execution_status = "completed"
      changed_files = @("decision-log.md")
      test_evidence = @([ordered]@{ type = "runner-exit-record"; name = "unit tests"; run_record_path = $relRunRecordPath })
    }
    Set-Content -LiteralPath (Join-Path $dir ".execution/D-001/EXECUTION-RESULT.json") -Value ($doc | ConvertTo-Json -Depth 12) -NoNewline
    $identity = [pscustomobject]@{ Digest = $digest; Head = $head; BaseSha = [string]$contract.base_sha }
    New-Review -Dir $dir -Identity $identity -Findings @([ordered]@{ finding_id = "AF-001"; category = "other"; severity = "minor"; status = "accepted_risk"; description = "d"; suggestion = "s"; decision_ref = "DEC-200" })

    $r = Invoke-Verify -Dir $dir
    Assert-True "decision added within verified range: AREV-006 raised even though DEC-200 resolves" ((Get-Rules $r.Json) -contains "AREV-006")
    Assert-True "decision added within verified range: reason names decision-log.md" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "AREV-006" -and $_.artifact -eq "decision-log.md" }).Count) -gt 0)
  } finally { Remove-ReviewFixture $dir }
}.Invoke()

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"
if ($fail -gt 0) { exit 1 }
exit 0
