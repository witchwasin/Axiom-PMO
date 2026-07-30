param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

# Behaviour tests for M5 execution-contract verification
# (scripts/export-execution-contract.ps1, scripts/verify-execution-result.ps1,
# scripts/lib/execution-contract-*.ps1), exercised end to end through the real
# scripts as a subprocess -- never by dot-sourcing internals.
#
# Same fixture strategy as tests/helpers/scope-diff-tests.ps1, for the same
# reason: this feature's entire job is comparing an agent's claims against real
# git history, so each case builds a small disposable repository with real
# commits rather than mocking the git layer. A mock would prove the code agrees
# with the mock.
#
# The cases are written adversarially on purpose. A verifier that only handles
# well-behaved input verifies nothing -- the interesting cases are the ones
# where the result is wrong, self-serving, or actively lying, because that is
# the threat model this milestone exists for
# (docs/architecture/execution-contract-verification.md §3).

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

# --- fixture ----------------------------------------------------------------

function New-ExecFixture {
  $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-exec-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $dir "src/payments") -Force | Out-Null

  Set-Content -LiteralPath (Join-Path $dir "PROJECT.md") -Value "# P99-EXEC`n" -NoNewline
  Set-Content -LiteralPath (Join-Path $dir "SCOPE.json") -Value '{"schema_version":"1.0","project":"P99-EXEC","implementation_scope":{"include":["src/payments/**","tests/payments/**"],"exclude":["src/payments/generated/**"]}}' -NoNewline
  $delivery = @(
    "# DELIVERY - P99-EXEC",
    "",
    "## Work Items",
    "",
    "| ID | Mode | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Status |",
    "|---|---|---|---|---|---|---|---|---|",
    "| D-001 | Standard | Checkout flow | REQ-001, REQ-002 | DESIGN/FLOW.puml | Card payment succeeds | unit tests | Dev | To Do |"
  ) -join "`n"
  Set-Content -LiteralPath (Join-Path $dir "DELIVERY.md") -Value $delivery -NoNewline
  Set-Content -LiteralPath (Join-Path $dir "src/payments/app.ts") -Value "seed" -NoNewline

  & git -C $dir init -q --initial-branch=main 2>$null
  if ($LASTEXITCODE -ne 0) { & git -C $dir init -q 2>$null }
  & git -C $dir config user.email "test@axiom-pmo.local" | Out-Null
  & git -C $dir config user.name "Axiom Exec Tests" | Out-Null
  & git -C $dir add -A 2>$null | Out-Null
  & git -C $dir commit -q -m "base" 2>$null | Out-Null
  return $dir
}

function Remove-ExecFixture {
  param([string]$Dir)
  Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue
}

function Write-ExecFile {
  param([string]$Dir, [string]$RelativePath, [string]$Content)
  $full = Join-Path $Dir $RelativePath
  $parent = Split-Path -Parent $full
  if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  Set-Content -LiteralPath $full -Value $Content -NoNewline
}

function Invoke-Export {
  param([string]$Dir, [string]$Grant = "")
  $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $exportScript,
    "-ProjectPath", $Dir, "-WorkItemId", "D-001", "-Force")
  if ($Grant) { $psArgs += @("-Grant", $Grant) }
  $previous = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $output = & $pwshExe @psArgs 2>&1
  $code = $LASTEXITCODE
  $ErrorActionPreference = $previous
  return [pscustomobject]@{ Output = ($output | Out-String); ExitCode = $code }
}

function Invoke-Verify {
  param([string]$Dir, [string]$ResultPath = $null)
  if (-not $ResultPath) { $ResultPath = Join-Path $Dir ".execution/D-001/EXECUTION-RESULT.json" }
  $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $verifyScript,
    "-ProjectPath", $Dir, "-ResultPath", $ResultPath, "-Format", "Json")
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

function New-Result {
  param([string]$Dir, [hashtable]$Overrides = @{})

  $digest = Get-ContractDigest -Dir $Dir
  $contract = Get-Content -LiteralPath (Join-Path $Dir ".execution/D-001/EXECUTION-CONTRACT.json") -Raw | ConvertFrom-Json
  $head = (& git -C $Dir rev-parse HEAD 2>$null)
  if ($head -is [array]) { $head = $head[0] }

  $doc = [ordered]@{
    contract_version = "1.0"
    work_item_id = "D-001"
    contract_sha256 = $digest
    base_sha = [string]$contract.base_sha
    head_sha = ([string]$head).Trim()
    execution_status = "completed"
    changed_files = @()
    test_evidence = @(
      [ordered]@{ type = "runner-exit-record"; name = "unit tests"; command = "npm test"; exit_code = 0; recorded_by = "axiom-runner" }
    )
  }
  foreach ($key in $Overrides.Keys) { $doc[$key] = $Overrides[$key] }

  $path = Join-Path $Dir ".execution/D-001/EXECUTION-RESULT.json"
  $json = ($doc | ConvertTo-Json -Depth 12)
  Set-Content -LiteralPath $path -Value $json -NoNewline
  return $path
}

function Get-Rules {
  param($Json, [string]$Level = "FAIL")
  if (-not $Json) { return @() }
  return @($Json.results | Where-Object { $_.level -eq $Level } | ForEach-Object { $_.rule_id })
}

Write-Host "Axiom-PMO Execution Contract Tests: $repo"
Write-Host ""

# ---- Case: export produces a contract, a digest, and derives scope ----------
{
  $dir = New-ExecFixture
  try {
    $r = Invoke-Export -Dir $dir
    Assert-True "export: exits 0" ($r.ExitCode -eq 0) $r.Output

    $contractPath = Join-Path $dir ".execution/D-001/EXECUTION-CONTRACT.json"
    Assert-True "export: contract file written" (Test-Path -LiteralPath $contractPath)
    Assert-True "export: digest sidecar written" (Test-Path -LiteralPath "$contractPath.sha256")

    $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    Assert-True "export: allowed_paths derived from SCOPE.json include" `
      ((@($contract.allowed_paths) -contains "src/payments/**") -and (@($contract.allowed_paths) -contains "tests/payments/**"))
    Assert-True "export: prohibited_paths derived from SCOPE.json exclude" `
      (@($contract.prohibited_paths) -contains "src/payments/generated/**")
    Assert-True "export: base_sha is a resolved commit, not a branch name" `
      ([string]$contract.base_sha -match '^[0-9a-f]{40}$')
    Assert-True "export: git authority denies commit/push/merge/deploy by default" `
      ((-not $contract.git_authority.commit) -and (-not $contract.git_authority.push) -and `
       (-not $contract.git_authority.merge) -and (-not $contract.git_authority.deploy))
    Assert-True "export: requirement refs carried from the work item" `
      ((@($contract.requirement_refs) -contains "REQ-001") -and (@($contract.requirement_refs) -contains "REQ-002"))

    $sidecar = Get-ContractDigest -Dir $dir
    Assert-True "export: sidecar digest matches the contract file's real hash" `
      ($sidecar -eq (Get-FileHash -LiteralPath $contractPath -Algorithm SHA256).Hash.ToLowerInvariant())
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: export refuses without an approved SCOPE.json -------------------
{
  $dir = New-ExecFixture
  try {
    Remove-Item -LiteralPath (Join-Path $dir "SCOPE.json") -Force
    $r = Invoke-Export -Dir $dir
    Assert-True "export: fails closed when the project has no approved scope" ($r.ExitCode -ne 0)
    Assert-True "export: says why (allowed_paths come from approved scope)" ($r.Output -match "SCOPE.json")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: -Grant is the only way to widen authority -----------------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit,push" | Out-Null
    $contract = Get-Content -LiteralPath (Join-Path $dir ".execution/D-001/EXECUTION-CONTRACT.json") -Raw | ConvertFrom-Json
    Assert-True "grant: named actions granted" ($contract.git_authority.commit -and $contract.git_authority.push)
    Assert-True "grant: unnamed actions stay denied" ((-not $contract.git_authority.merge) -and (-not $contract.git_authority.deploy))

    $r = Invoke-Export -Dir $dir -Grant "sudo"
    Assert-True "grant: an unknown action is rejected, not silently ignored" ($r.ExitCode -ne 0)
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: clean run verifies (the no-false-positive proof) ----------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    Write-ExecFile $dir "src/payments/app.ts" "implemented"
    Write-ExecFile $dir "tests/payments/app.test.ts" "tested"
    & git -C $dir add -A 2>$null | Out-Null
    & git -C $dir commit -q -m "impl" 2>$null | Out-Null
    New-Result -Dir $dir -Overrides @{
      changed_files = @("src/payments/app.ts", "tests/payments/app.test.ts")
      git_actions_performed = @("commit")
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "clean: verdict pass" ($r.Json.execution_verification.verdict -eq "pass") `
      ("verdict=" + $r.Json.execution_verification.verdict + " fails=" + ((Get-Rules $r.Json) -join ","))
    Assert-True "clean: exit code 0" ($r.ExitCode -eq 0)
    Assert-True "clean: no FAIL rows at all" (@(Get-Rules $r.Json).Count -eq 0)
    Assert-True "clean: the contract's own bookkeeping files are not counted as implementation" `
      (-not (@($r.Json.execution_verification.changed_files_observed) -match '^\.execution/'))
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: change outside approved scope -> EXEC-004 -----------------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    Write-ExecFile $dir "src/payments/app.ts" "implemented"
    Write-ExecFile $dir "src/auth/tokens.ts" "wandered off"
    & git -C $dir add -A 2>$null | Out-Null
    & git -C $dir commit -q -m "impl" 2>$null | Out-Null
    New-Result -Dir $dir -Overrides @{
      changed_files = @("src/payments/app.ts", "src/auth/tokens.ts")
      git_actions_performed = @("commit")
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "out-of-scope: EXEC-004 raised" ((Get-Rules $r.Json) -contains "EXEC-004")
    Assert-True "out-of-scope: the offending path is named" `
      (@($r.Json.execution_verification.changed_files_out_of_scope) -contains "src/auth/tokens.ts")
    Assert-True "out-of-scope: exit code is non-zero" ($r.ExitCode -ne 0)
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: change matching prohibited_paths -> EXEC-004 --------------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    Write-ExecFile $dir "src/payments/generated/client.ts" "touched a carve-out"
    & git -C $dir add -A 2>$null | Out-Null
    & git -C $dir commit -q -m "impl" 2>$null | Out-Null
    New-Result -Dir $dir -Overrides @{
      changed_files = @("src/payments/generated/client.ts")
      git_actions_performed = @("commit")
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "prohibited: EXEC-004 raised even though the path is inside the include tree" `
      ((Get-Rules $r.Json) -contains "EXEC-004")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: scope matching is case-sensitive --------------------------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    # Injected through the index rather than the working tree: on a
    # case-insensitive filesystem writing SRC/PAYMENTS/ would silently land in
    # the existing src/payments/ and hide the very bug this asserts against.
    # Same technique and the same reason as the SCOPE-DIFF case-sensitivity test.
    & git -C $dir add -A 2>$null | Out-Null
    $blob = ("case" | & git -C $dir hash-object -w --stdin)
    if ($blob -is [array]) { $blob = $blob[0] }
    & git -C $dir update-index --add --cacheinfo "100644,$(([string]$blob).Trim()),SRC/PAYMENTS/sneaky.ts" 2>$null | Out-Null
    & git -C $dir commit -q -m "impl" 2>$null | Out-Null
    New-Result -Dir $dir -Overrides @{
      changed_files = @("SRC/PAYMENTS/sneaky.ts")
      git_actions_performed = @("commit")
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "case-sensitivity: a wrong-case path does not satisfy allowed_paths" `
      ((Get-Rules $r.Json) -contains "EXEC-004")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: contract edited after export -> EXEC-002 ------------------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir | Out-Null

    # The attack this exists to stop: widen the granted authority in the
    # already-approved contract, leaving the sidecar (written at approval
    # time) behind as the only witness.
    $contractPath = Join-Path $dir ".execution/D-001/EXECUTION-CONTRACT.json"
    $text = Get-Content -LiteralPath $contractPath -Raw
    Set-Content -LiteralPath $contractPath -Value ($text -replace '"push": false', '"push": true') -NoNewline

    $r = Invoke-Verify -Dir $dir
    Assert-True "tampered contract: EXEC-002 raised" ((Get-Rules $r.Json) -contains "EXEC-002")
    Assert-True "tampered contract: verdict names tampering" `
      ($r.Json.execution_verification.verdict -eq "contract_tampered") `
      ("verdict=" + $r.Json.execution_verification.verdict)
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: result answers a different contract version -> EXEC-002 ---------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{
      contract_sha256 = ("0" * 64)
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "digest mismatch: EXEC-002 raised" ((Get-Rules $r.Json) -contains "EXEC-002")
    Assert-True "digest mismatch: verdict is contract_mismatch" `
      ($r.Json.execution_verification.verdict -eq "contract_mismatch")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: requirement the contract does not cover -> EXEC-003 -------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{ requirement_refs = @("REQ-001", "REQ-999") } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "requirement drift: EXEC-003 raised for the uncovered requirement" `
      ((Get-Rules $r.Json) -contains "EXEC-003")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: fewer requirements than approved is legitimate ------------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{
      requirement_refs = @("REQ-001")
      execution_status = "partial"
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "partial work: satisfying fewer requirements is not a violation" `
      (-not ((Get-Rules $r.Json) -contains "EXEC-003"))
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: committed without commit authority -> EXEC-006 ------------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir | Out-Null   # no -Grant: commit stays denied
    Write-ExecFile $dir "src/payments/app.ts" "implemented"
    & git -C $dir add -A 2>$null | Out-Null
    & git -C $dir commit -q -m "impl" 2>$null | Out-Null
    New-Result -Dir $dir -Overrides @{ changed_files = @("src/payments/app.ts") } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "ungranted commit: EXEC-006 raised from observed history, not from the result's own admission" `
      ((Get-Rules $r.Json) -contains "EXEC-006")
    Assert-True "ungranted commit: recorded in the structured verdict" `
      (@($r.Json.execution_verification.authority_violations) -contains "commit")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: result admits an action the contract withheld -> EXEC-006 -------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{ git_actions_performed = @("commit", "deploy") } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "self-reported ungranted action: EXEC-006 raised" ((Get-Rules $r.Json) -contains "EXEC-006")
    Assert-True "self-reported ungranted action: deploy named in the verdict" `
      (@($r.Json.execution_verification.authority_violations) -contains "deploy")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: agent approving its own work -> EXEC-007 ------------------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{
      authority_claims = @(
        [ordered]@{ type = "release-approval"; actor = "agent"; claim = "approved" }
      )
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "self-approval: EXEC-007 raised" ((Get-Rules $r.Json) -contains "EXEC-007")
    Assert-True "self-approval: exit code is non-zero" ($r.ExitCode -ne 0)
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: human approval claim with no decision record -> EXEC-007 --------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{
      authority_claims = @(
        [ordered]@{ type = "release-approval"; actor = "human"; claim = "approved" }
      )
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "unanchored human claim: EXEC-007 raised (actor 'human' is not self-proving)" `
      ((Get-Rules $r.Json) -contains "EXEC-007")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: agent may report implementation-complete ------------------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{
      authority_claims = @(
        [ordered]@{ type = "implementation-complete"; actor = "agent"; claim = "done" }
      )
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "permitted claim: implementation-complete from an agent is allowed" `
      (-not ((Get-Rules $r.Json) -contains "EXEC-007"))
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: unknown actor type -> EXEC-007 ----------------------------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{
      authority_claims = @(
        [ordered]@{ type = "release-approval"; actor = "ci-robot"; claim = "approved" }
      )
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "unknown actor: EXEC-007 raised rather than defaulting to permitted" `
      ((Get-Rules $r.Json) -contains "EXEC-007")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: required test backed only by an agent assertion -> EXEC-005 -----
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{
      test_evidence = @(
        [ordered]@{ type = "agent-assertion"; name = "unit tests"; result = "passed" }
      )
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "agent-asserted test: EXEC-005 raised" ((Get-Rules $r.Json) -contains "EXEC-005")
    Assert-True "agent-asserted test: named in the structured verdict" `
      (@($r.Json.execution_verification.unverified_required_tests) -contains "unit tests")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: verifiable adapter missing its evidence fields -> EXEC-005 ------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{
      test_evidence = @(
        # Names a verifiable adapter but carries none of what makes it
        # verifiable -- claiming the label must not be enough.
        [ordered]@{ type = "ci-check"; name = "unit tests" }
      )
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "hollow evidence: EXEC-005 raised for an adapter with no evidence fields" `
      ((Get-Rules $r.Json) -contains "EXEC-005")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: required test with no evidence entry at all -> EXEC-005 ---------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{ test_evidence = @() } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "missing evidence: EXEC-005 raised" ((Get-Rules $r.Json) -contains "EXEC-005")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: undeclared changed file -> EXEC-008 -----------------------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    Write-ExecFile $dir "src/payments/app.ts" "implemented"
    Write-ExecFile $dir "src/payments/quiet.ts" "changed but not declared"
    & git -C $dir add -A 2>$null | Out-Null
    & git -C $dir commit -q -m "impl" 2>$null | Out-Null
    New-Result -Dir $dir -Overrides @{
      changed_files = @("src/payments/app.ts")   # quiet.ts omitted
      git_actions_performed = @("commit")
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "undeclared change: EXEC-008 raised" ((Get-Rules $r.Json) -contains "EXEC-008")
    Assert-True "undeclared change: in-scope path alone does not excuse the omission" `
      (-not ((Get-Rules $r.Json) -contains "EXEC-004"))
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: head does not descend from the approved base -> EXEC-008 --------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $contract = Get-Content -LiteralPath (Join-Path $dir ".execution/D-001/EXECUTION-CONTRACT.json") -Raw | ConvertFrom-Json

    # An orphan branch: real commits, real SHAs, no ancestry to the approved base.
    & git -C $dir checkout -q --orphan elsewhere 2>$null | Out-Null
    Write-ExecFile $dir "src/payments/app.ts" "built somewhere else entirely"
    & git -C $dir add -A 2>$null | Out-Null
    & git -C $dir commit -q -m "orphan" 2>$null | Out-Null
    $orphanHead = (& git -C $dir rev-parse HEAD 2>$null)
    if ($orphanHead -is [array]) { $orphanHead = $orphanHead[0] }

    $resultPath = Join-Path $dir ".execution/D-001/EXECUTION-RESULT.json"
    $doc = [ordered]@{
      contract_version = "1.0"
      work_item_id = "D-001"
      contract_sha256 = (Get-ContractDigest -Dir $dir)
      base_sha = [string]$contract.base_sha
      head_sha = ([string]$orphanHead).Trim()
      execution_status = "completed"
      changed_files = @("src/payments/app.ts")
      git_actions_performed = @("commit")
      test_evidence = @([ordered]@{ type = "runner-exit-record"; name = "unit tests"; command = "npm test"; exit_code = 0; recorded_by = "axiom-runner" })
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $resultPath) -Force | Out-Null
    Set-Content -LiteralPath $resultPath -Value ($doc | ConvertTo-Json -Depth 12) -NoNewline

    $r = Invoke-Verify -Dir $dir
    Assert-True "no ancestry: EXEC-008 raised" ((Get-Rules $r.Json) -contains "EXEC-008")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: unresolvable head commit -> EXEC-008 infrastructure failure -----
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{ head_sha = ("0" * 40) } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "unresolvable head: EXEC-008 raised" ((Get-Rules $r.Json) -contains "EXEC-008")
    Assert-True "unresolvable head: reported as git_error, not as a clean pass" `
      ($r.Json.execution_verification.verdict -eq "git_error")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: missing contract -> EXEC-002, never a silent pass ---------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir | Out-Null
    Remove-Item -LiteralPath (Join-Path $dir ".execution/D-001/EXECUTION-CONTRACT.json") -Force
    Remove-Item -LiteralPath (Join-Path $dir ".execution/D-001/EXECUTION-CONTRACT.json.sha256") -Force

    $r = Invoke-Verify -Dir $dir
    Assert-True "missing contract: EXEC-002 raised" ((Get-Rules $r.Json) -contains "EXEC-002")
    Assert-True "missing contract: exit code 1, not a pass" ($r.ExitCode -eq 1)
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: malformed result -> EXEC-001 ------------------------------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $resultPath = Join-Path $dir ".execution/D-001/EXECUTION-RESULT.json"
    Set-Content -LiteralPath $resultPath -Value "{ not json at all" -NoNewline

    $r = Invoke-Verify -Dir $dir
    Assert-True "malformed result: EXEC-001 raised" ((Get-Rules $r.Json) -contains "EXEC-001")
    Assert-True "malformed result: verdict is result_invalid" `
      ($r.Json.execution_verification.verdict -eq "result_invalid")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: result missing a required field -> EXEC-001 ---------------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $resultPath = Join-Path $dir ".execution/D-001/EXECUTION-RESULT.json"
    Set-Content -LiteralPath $resultPath -Value '{"contract_version":"1.0","work_item_id":"D-001"}' -NoNewline

    $r = Invoke-Verify -Dir $dir
    Assert-True "incomplete result: EXEC-001 raised" ((Get-Rules $r.Json) -contains "EXEC-001")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: diagnostics follow the shared contract --------------------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{
      authority_claims = @([ordered]@{ type = "release-approval"; actor = "agent"; claim = "approved" })
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    $row = @($r.Json.results | Where-Object { $_.rule_id -eq "EXEC-007" })[0]
    Assert-True "diagnostics: envelope carries the shared schema version" ($r.Json.schema_version -eq "1.1")
    Assert-True "diagnostics: every declared row field is present" `
      (($row.PSObject.Properties.Name -contains "artifact") -and ($row.PSObject.Properties.Name -contains "item_id") -and `
       ($row.PSObject.Properties.Name -contains "field") -and ($row.PSObject.Properties.Name -contains "suggestion") -and `
       ($row.PSObject.Properties.Name -contains "documentation_url"))
    Assert-True "diagnostics: FAIL rows carry a suggestion" (-not [string]::IsNullOrWhiteSpace([string]$row.suggestion))
    Assert-True "diagnostics: FAIL rows carry a documentation url" (-not [string]::IsNullOrWhiteSpace([string]$row.documentation_url))
    Assert-True "diagnostics: summary counters agree with the results array" `
      ($r.Json.summary.fail -eq @($r.Json.results | Where-Object { $_.level -eq "FAIL" }).Count)
  } finally { Remove-ExecFixture $dir }
}.Invoke()

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"
if ($fail -gt 0) { exit 1 }
exit 0
