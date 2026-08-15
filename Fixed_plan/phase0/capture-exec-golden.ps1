# Phase 0 helper — capture EXEC-001..008 goldens.
#
# Replicates the disposable-git fixture machinery from tests/helpers/execution-contract-tests.ps1
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
  param([string]$Dir, [Parameter(ValueFromRemainingArguments = $true)]$GitArgs)
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try { & git -C $Dir @GitArgs 2>&1 | Out-Null } finally { $ErrorActionPreference = $previous }
}
function Get-FixtureGit {
  param([string]$Dir, [Parameter(ValueFromRemainingArguments = $true)]$GitArgs)
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $out = & git -C $Dir @GitArgs 2>$null
    if ($out -is [array]) { $out = $out[0] }
    if ($null -eq $out) { return "" }
    return ([string]$out).Trim()
  } finally { $ErrorActionPreference = $previous }
}
function New-ExecFixture {
  $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-exec-golden-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $dir "src/payments") -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $dir "PROJECT.md") -Value "# P99-EXEC`n" -NoNewline
  Set-Content -LiteralPath (Join-Path $dir "SCOPE.json") -Value '{"schema_version":"1.0","project":"P99-EXEC","implementation_scope":{"include":["src/payments/**","tests/payments/**"],"exclude":["src/payments/generated/**"]}}' -NoNewline
  $delivery = @(
    "# DELIVERY - P99-EXEC", "", "## Work Items", "",
    "| ID | Mode | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Status |",
    "|---|---|---|---|---|---|---|---|---|",
    "| D-001 | Standard | Checkout flow | REQ-001, REQ-002 | DESIGN/FLOW.puml | Card payment succeeds | unit tests | Dev | To Do |"
  ) -join "`n"
  Set-Content -LiteralPath (Join-Path $dir "DELIVERY.md") -Value $delivery -NoNewline
  Set-Content -LiteralPath (Join-Path $dir "src/payments/app.ts") -Value "seed" -NoNewline
  $decisionLog = @(
    "# Decision Log - P99-EXEC", "",
    "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
    "|---|---|---|---|---|---|---|---|",
    "| 2026-07-30 | DEC-100 | Accept local test artifacts for D-001 | accept / require CI | accept | reviewed the artifacts by hand | none | test evidence accepted |"
  ) -join "`n"
  Set-Content -LiteralPath (Join-Path $dir "decision-log.md") -Value $decisionLog -NoNewline
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  & git -C $dir init -q --initial-branch=main 2>$null
  if ($LASTEXITCODE -ne 0) { & git -C $dir init -q 2>$null }
  $ErrorActionPreference = $prev
  Invoke-FixtureGit $dir config user.email "test@axiom-pmo.local"
  Invoke-FixtureGit $dir config user.name "Axiom Exec Golden"
  Invoke-FixtureGit $dir config core.autocrlf false
  Invoke-FixtureGit $dir config core.safecrlf false
  Invoke-FixtureGit $dir add -A
  Invoke-FixtureGit $dir commit -q -m "base"
  return $dir
}
function Remove-ExecFixture { param([string]$Dir) Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue }
function Write-ExecFile {
  param([string]$Dir, [string]$RelativePath, [string]$Content)
  $full = Join-Path $Dir $RelativePath
  $parent = Split-Path -Parent $full
  if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  Set-Content -LiteralPath $full -Value $Content -NoNewline
}
function Invoke-Export {
  param([string]$Dir, [string]$Grant = "")
  $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $exportScript, "-ProjectPath", $Dir, "-WorkItemId", "D-001", "-Force")
  if ($Grant) { $psArgs += @("-Grant", $Grant) }
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  & $pwshExe @psArgs 2>&1 | Out-Null
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
function Set-DecisionLogWithDigest {
  param([string]$Dir, [string]$Digest, [string]$DecisionId = "DEC-100", [string]$TestName = "unit tests", [string]$WorkItem = "D-001", [string]$ContractDigest = $null, [string]$ClaimType = "test-evidence-accepted")
  if (-not $ContractDigest) { $ContractDigest = Get-ContractDigest -Dir $Dir }
  $token = "axiom-authority: type=$ClaimType; work_item=$WorkItem; contract=$ContractDigest; test=$TestName; evidence=$Digest"
  $log = @(
    "# Decision Log - P99-EXEC", "",
    "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
    "|---|---|---|---|---|---|---|---|",
    "| 2026-07-31 | $DecisionId | Accept $TestName evidence for $WorkItem | accept / require CI | accept | reviewed the artifact by hand. $token | none | test evidence accepted |"
  ) -join "`n"
  Set-Content -LiteralPath (Join-Path $Dir "decision-log.md") -Value $log -NoNewline
}
function New-Result {
  param([string]$Dir, [hashtable]$Overrides = @{})
  $digest = Get-ContractDigest -Dir $Dir
  $contract = Get-Content -LiteralPath (Join-Path $Dir ".execution/D-001/EXECUTION-CONTRACT.json") -Raw | ConvertFrom-Json
  $head = Get-FixtureGit $Dir rev-parse HEAD
  $relRunRecordPath = New-RealRunRecord -Dir $Dir
  $recordDigest = (Get-FileHash -LiteralPath (Join-Path $Dir $relRunRecordPath) -Algorithm SHA256).Hash.ToLowerInvariant()
  Set-DecisionLogWithDigest -Dir $Dir -Digest $recordDigest
  $doc = [ordered]@{
    contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $digest
    base_sha = [string]$contract.base_sha; head_sha = ([string]$head).Trim(); execution_status = "completed"
    changed_files = @()
    test_evidence = @([ordered]@{ type = "runner-exit-record"; name = "unit tests"; run_record_path = $relRunRecordPath })
    authority_claims = @([ordered]@{ type = "test-evidence-accepted"; actor = "human"; claim = "accepted"; decision_ref = "DEC-100"; test_name = "unit tests"; evidence_sha256 = $recordDigest; evidence_type = "runner-exit-record"; work_item_id = "D-001" })
  }
  foreach ($key in $Overrides.Keys) { $doc[$key] = $Overrides[$key] }
  $path = Join-Path $Dir ".execution/D-001/EXECUTION-RESULT.json"
  Set-Content -LiteralPath $path -Value ($doc | ConvertTo-Json -Depth 12) -NoNewline
  return $path
}
function Capture {
  param([string]$Dir, [string]$Name, [int]$Code, [string]$Raw)
  $raw = ($Raw.TrimEnd()) + "`nEXIT_CODE=$Code"
  $raw = $raw.Replace($Dir, '<REPO_ROOT>')
  Set-Content -LiteralPath (Join-Path $goldenDir "$Name.txt") -Value (Get-CanonicalGoldenText -Text $raw) -NoNewline -Encoding utf8
  Write-Host "Captured $Name.txt"
}

# EXEC-001: malformed result
$d = New-ExecFixture
try {
  Invoke-Export -Dir $d -Grant "commit"
  Set-Content -LiteralPath (Join-Path $d ".execution/D-001/EXECUTION-RESULT.json") -Value "{ not json at all" -NoNewline
  $r = Invoke-Verify -Dir $d
  Capture $d "exec-001" $r.ExitCode $r.Raw
} finally { Remove-ExecFixture $d }

# EXEC-002: contract tampered after export
$d = New-ExecFixture
try {
  Invoke-Export -Dir $d -Grant "commit"
  New-Result -Dir $d | Out-Null
  $cp = Join-Path $d ".execution/D-001/EXECUTION-CONTRACT.json"
  $doc = Get-Content -LiteralPath $cp -Raw | ConvertFrom-Json
  $doc.git_authority.push = $true
  Set-Content -LiteralPath $cp -Value ($doc | ConvertTo-Json -Depth 12) -NoNewline
  $r = Invoke-Verify -Dir $d
  Capture $d "exec-002" $r.ExitCode $r.Raw
} finally { Remove-ExecFixture $d }

# EXEC-003: requirement the contract does not cover
$d = New-ExecFixture
try {
  Invoke-Export -Dir $d -Grant "commit"
  New-Result -Dir $d -Overrides @{ requirement_refs = @("REQ-001", "REQ-999") } | Out-Null
  $r = Invoke-Verify -Dir $d
  Capture $d "exec-003" $r.ExitCode $r.Raw
} finally { Remove-ExecFixture $d }

# EXEC-004: change outside approved scope
$d = New-ExecFixture
try {
  Invoke-Export -Dir $d -Grant "commit"
  Write-ExecFile $d "src/payments/app.ts" "implemented"
  Write-ExecFile $d "src/auth/tokens.ts" "wandered off"
  Invoke-FixtureGit $d add -A
  Invoke-FixtureGit $d commit -q -m "impl"
  New-Result -Dir $d -Overrides @{ changed_files = @("src/payments/app.ts", "src/auth/tokens.ts"); git_actions_performed = @("commit") } | Out-Null
  $r = Invoke-Verify -Dir $d
  Capture $d "exec-004" $r.ExitCode $r.Raw
} finally { Remove-ExecFixture $d }

# EXEC-005: required test backed only by agent assertion
$d = New-ExecFixture
try {
  Invoke-Export -Dir $d -Grant "commit"
  New-Result -Dir $d -Overrides @{ test_evidence = @([ordered]@{ type = "agent-assertion"; name = "unit tests"; result = "passed" }) } | Out-Null
  $r = Invoke-Verify -Dir $d
  Capture $d "exec-005" $r.ExitCode $r.Raw
} finally { Remove-ExecFixture $d }

# EXEC-006: result admits an action the contract withheld
$d = New-ExecFixture
try {
  Invoke-Export -Dir $d -Grant "commit"
  New-Result -Dir $d -Overrides @{ git_actions_performed = @("commit", "deploy") } | Out-Null
  $r = Invoke-Verify -Dir $d
  Capture $d "exec-006" $r.ExitCode $r.Raw
} finally { Remove-ExecFixture $d }

# EXEC-007: agent approving its own work
$d = New-ExecFixture
try {
  Invoke-Export -Dir $d -Grant "commit"
  New-Result -Dir $d -Overrides @{ authority_claims = @([ordered]@{ type = "release-approval"; actor = "agent"; claim = "approved" }) } | Out-Null
  $r = Invoke-Verify -Dir $d
  Capture $d "exec-007" $r.ExitCode $r.Raw
} finally { Remove-ExecFixture $d }

# EXEC-008: undeclared changed file
$d = New-ExecFixture
try {
  Invoke-Export -Dir $d -Grant "commit"
  Write-ExecFile $d "src/payments/app.ts" "implemented"
  Write-ExecFile $d "src/payments/quiet.ts" "changed but not declared"
  Invoke-FixtureGit $d add -A
  Invoke-FixtureGit $d commit -q -m "impl"
  New-Result -Dir $d -Overrides @{ changed_files = @("src/payments/app.ts"); git_actions_performed = @("commit") } | Out-Null
  $r = Invoke-Verify -Dir $d
  Capture $d "exec-008" $r.ExitCode $r.Raw
} finally { Remove-ExecFixture $d }

exit 0
