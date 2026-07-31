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

# Every fixture git call goes through these two helpers. Both exist because of
# one Windows PowerShell 5.1 behaviour that cost a red CI run:
#
# With $ErrorActionPreference = "Stop", PowerShell 5.1 turns *any* native
# command's stderr output into a terminating error -- including git's purely
# informational "LF will be replaced by CRLF" notice. This file's fixtures
# write multi-line DELIVERY.md and PROJECT.md content, so `git add` emits that
# notice on a Windows runner with core.autocrlf on, and the whole test file
# died on it while passing everywhere else. (tests/helpers/scope-diff-tests.ps1
# never hit this only because its fixture files contain no newlines at all --
# an accident, not a design, and not one to rely on again here.)
#
# Two independent defences, deliberately both:
#   1. New-ExecFixture disables autocrlf/safecrlf, so the notice is never
#      emitted in the first place and fixture bytes stay identical on every
#      platform -- which also matters because SCOPE-DIFF and this verifier
#      compare paths and digests byte-for-byte.
#   2. These helpers drop to "Continue" around the call, so any *other*
#      informational git stderr (advice hints, detached-HEAD notices) cannot
#      resurrect the same failure mode in a future case.
function Invoke-FixtureGit {
  param([string]$Dir, [Parameter(ValueFromRemainingArguments = $true)]$GitArgs)
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try { & git -C $Dir @GitArgs 2>&1 | Out-Null } finally { $ErrorActionPreference = $previous }
}

# Same, for the calls whose stdout is the point (rev-parse, hash-object).
# stderr is discarded rather than merged so it cannot contaminate the value.
function Get-FixtureGit {
  param([string]$Dir, [Parameter(ValueFromRemainingArguments = $true)]$GitArgs)
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $out = & git -C $Dir @GitArgs 2>$null
    if ($out -is [array]) { $out = $out[0] }
    # Explicit $null check, not a [string] cast: a git command that outputs
    # nothing (e.g. `remote -v` on a repo with no remotes) yields $null, and
    # casting that null does not reliably produce a real .NET string on
    # Windows PowerShell 5.1 -- the diagnostic added for the ci-check case
    # crashed on exactly this before it could print anything useful.
    if ($null -eq $out) { return "" }
    return ([string]$out).Trim()
  } finally { $ErrorActionPreference = $previous }
}

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

  # Committed in the base commit, deliberately: artifact-observed evidence
  # (a runner record or a JUnit file) no longer satisfies a required test on
  # its own, because the actor being verified can write both the artifact and
  # its digest. A human accepting it on the record is one of the two ways
  # through, so the fixture carries a decision-log.md the vouch can cite --
  # and it lives in the *base* commit so it is never inside the range under
  # verification, which would disqualify it as self-forged.
  $decisionLog = @(
    "# Decision Log - P99-EXEC",
    "",
    "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
    "|---|---|---|---|---|---|---|---|",
    "| 2026-07-30 | DEC-100 | Accept local test artifacts for D-001 | accept / require CI | accept | reviewed the artifacts by hand | none | test evidence accepted |"
  ) -join "`n"
  Set-Content -LiteralPath (Join-Path $dir "decision-log.md") -Value $decisionLog -NoNewline

  # Not Invoke-FixtureGit: this one needs $LASTEXITCODE to pick the fallback
  # for git versions predating --initial-branch. Same "Continue" guard though,
  # since that unknown-option error is exactly the stderr that would otherwise
  # terminate the run before the fallback could execute.
  $previousEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & git -C $dir init -q --initial-branch=main 2>$null
  if ($LASTEXITCODE -ne 0) { & git -C $dir init -q 2>$null }
  $ErrorActionPreference = $previousEap

  Invoke-FixtureGit $dir config user.email "test@axiom-pmo.local"
  Invoke-FixtureGit $dir config user.name "Axiom Exec Tests"
  # Keep fixture bytes identical on every platform: this verifier compares
  # paths and file digests exactly, so a Windows checkout silently rewriting
  # LF to CRLF would change what is being asserted, not just how git reports it.
  Invoke-FixtureGit $dir config core.autocrlf false
  Invoke-FixtureGit $dir config core.safecrlf false
  Invoke-FixtureGit $dir add -A
  Invoke-FixtureGit $dir commit -q -m "base"
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

$runExecutionScript = Join-Path $repo "scripts/run-execution-command.ps1"

# Produces a REAL sealed runner-exit-record by actually invoking
# scripts/run-execution-command.ps1 -- not a hand-typed claim shape. This is
# deliberate: the FATAL finding this file's tests exist to guard against was
# exactly a hand-typed evidence entry with plausible fields passing as
# verified. Using the real runner for every case's default evidence, rather
# than a fixture shortcut, means the "clean" case actually exercises
# Test-RunnerExitEvidence's real path -- containment, digest recomputation,
# work-item/contract binding, exit code -- instead of assuming it works.
function New-RealRunRecord {
  param([string]$Dir)
  $previous = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $output = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File $runExecutionScript `
    -ProjectPath $Dir -WorkItemId "D-001" -Name "unit tests" -Command "echo ok" 2>&1
  $ErrorActionPreference = $previous
  $runsDir = Join-Path $Dir ".execution/D-001/runs"
  $recordFile = @(Get-ChildItem -LiteralPath $runsDir -Filter "*.json" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '\.sha256$' })[0]
  if (-not $recordFile) { throw "New-RealRunRecord: no run record produced. Runner output: $($output | Out-String)" }
  return ".execution/D-001/runs/$($recordFile.Name)"
}

# Writes decision-log.md with a DEC-100 row that names $Digest. Uncommitted on
# purpose -- see New-Result for why the row must sit outside the verified
# commit range.
function Set-DecisionLogWithDigest {
  param([string]$Dir, [string]$Digest, [string]$DecisionId = "DEC-100", [string]$TestName = "unit tests")
  $log = @(
    "# Decision Log - P99-EXEC",
    "",
    "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
    "|---|---|---|---|---|---|---|---|",
    "| 2026-07-31 | $DecisionId | Accept $TestName evidence for D-001 | accept / require CI | accept | reviewed the artifact by hand; sha256 $Digest | none | test evidence accepted |"
  ) -join "`n"
  Set-Content -LiteralPath (Join-Path $Dir "decision-log.md") -Value $log -NoNewline
}

function New-Result {
  param([string]$Dir, [hashtable]$Overrides = @{})

  $digest = Get-ContractDigest -Dir $Dir
  $contract = Get-Content -LiteralPath (Join-Path $Dir ".execution/D-001/EXECUTION-CONTRACT.json") -Raw | ConvertFrom-Json
  $head = Get-FixtureGit $Dir rev-parse HEAD
  $relRunRecordPath = New-RealRunRecord -Dir $Dir

  # The run record's own digest -- what a vouch must name to be about *this*
  # artifact rather than about test evidence in the abstract.
  $recordDigest = (Get-FileHash -LiteralPath (Join-Path $Dir $relRunRecordPath) -Algorithm SHA256).Hash.ToLowerInvariant()

  # Write the human decision naming that digest, into the working tree and
  # deliberately NOT committed. That is the real-world order: the agent
  # produces artifacts and commits (head), a human then reviews them and
  # records the decision afterward, so the row is never inside the base..head
  # range being verified. Committing it here would make decision-log.md part
  # of the execution's own diff and correctly disqualify it as self-forged.
  Set-DecisionLogWithDigest -Dir $Dir -Digest $recordDigest

  $doc = [ordered]@{
    contract_version = "1.0"
    work_item_id = "D-001"
    contract_sha256 = $digest
    base_sha = [string]$contract.base_sha
    head_sha = ([string]$head).Trim()
    execution_status = "completed"
    changed_files = @()
    test_evidence = @(
      [ordered]@{ type = "runner-exit-record"; name = "unit tests"; run_record_path = $relRunRecordPath }
    )
    # A runner record is artifact-observed: real, digest-checked, and still
    # written somewhere the verified actor controls. The default result
    # therefore carries a fully bound human vouch -- naming the test and the
    # exact artifact digest, citing a decision row that names that same digest
    # -- so these cases represent a legitimately satisfiable execution. The
    # cases asserting the tier and binding rules override this away.
    authority_claims = @(
      [ordered]@{
        type = "test-evidence-accepted"; actor = "human"; claim = "accepted"
        decision_ref = "DEC-100"; test_name = "unit tests"; evidence_sha256 = $recordDigest
        evidence_type = "runner-exit-record"; work_item_id = "D-001"
      }
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
    Invoke-FixtureGit $dir add -A
    Invoke-FixtureGit $dir commit -q -m "impl"
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
    Invoke-FixtureGit $dir add -A
    Invoke-FixtureGit $dir commit -q -m "impl"
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
    Invoke-FixtureGit $dir add -A
    Invoke-FixtureGit $dir commit -q -m "impl"
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
    Invoke-FixtureGit $dir add -A
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $blob = ("case" | & git -C $dir hash-object -w --stdin 2>$null)
    $ErrorActionPreference = $previousEap
    if ($blob -is [array]) { $blob = $blob[0] }
    $blob = ([string]$blob).Trim()
    Invoke-FixtureGit $dir update-index --add --cacheinfo "100644,$blob,SRC/PAYMENTS/sneaky.ts"
    Invoke-FixtureGit $dir commit -q -m "impl"
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
    #
    # Edited through the parsed object, not by string-replacing JSON text.
    # Windows PowerShell 5.1's ConvertTo-Json writes `"key":  value` with two
    # spaces after the colon where PowerShell 7 writes one, so a literal
    # '"push": false' match silently found nothing on the 5.1 leg, left the
    # file untouched, and the digest correctly still matched -- the test
    # failed while the product was behaving exactly as designed. Asserting on
    # a JSON document's incidental whitespace is testing the serializer, not
    # the contract.
    $contractPath = Join-Path $dir ".execution/D-001/EXECUTION-CONTRACT.json"
    $doc = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    $doc.git_authority.push = $true
    Set-Content -LiteralPath $contractPath -Value ($doc | ConvertTo-Json -Depth 12) -NoNewline

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
    Invoke-FixtureGit $dir add -A
    Invoke-FixtureGit $dir commit -q -m "impl"
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
    Invoke-FixtureGit $dir add -A
    Invoke-FixtureGit $dir commit -q -m "impl"
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
    Invoke-FixtureGit $dir checkout -q --orphan elsewhere
    Write-ExecFile $dir "src/payments/app.ts" "built somewhere else entirely"
    Invoke-FixtureGit $dir add -A
    Invoke-FixtureGit $dir commit -q -m "orphan"
    $orphanHead = Get-FixtureGit $dir rev-parse HEAD

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

# =============================================================================
# Sol's 2026-07-30 code review found the tests above proved the shape of
# verification worked without proving the checks were real: every case's
# default evidence had all the right fields, and none of them tried
# fabricating an artifact that merely *looked* like evidence. These cases are
# the direct response -- 1 FATAL and 2 MAJOR findings, each reproduced first,
# then confirmed fixed.
# =============================================================================

function Get-BaseResultFields {
  param([string]$Dir)
  return [pscustomobject]@{
    Digest = (Get-ContractDigest -Dir $Dir)
    Contract = (Get-Content -LiteralPath (Join-Path $Dir ".execution/D-001/EXECUTION-CONTRACT.json") -Raw | ConvertFrom-Json)
    Head = (Get-FixtureGit $Dir rev-parse HEAD).Trim()
  }
}

function Write-ResultDoc {
  param([string]$Dir, [System.Collections.Specialized.OrderedDictionary]$Doc)
  $path = Join-Path $Dir ".execution/D-001/EXECUTION-RESULT.json"
  Set-Content -LiteralPath $path -Value ($Doc | ConvertTo-Json -Depth 12) -NoNewline
  return $path
}

# ---- FATAL fix: junit-artifact must be real, not just present-fielded ------

# ---- Case: junit-artifact with a fabricated sha256 -> EXEC-005 ------------
{
  $dir = New-ExecFixture
  try {
    Write-ExecFile $dir "reports/junit.xml" '<testsuite name="s" tests="1" failures="0" errors="0"><testcase name="a"/></testsuite>'
    & git -C $dir add -A 2>$null | Out-Null; & git -C $dir commit -q -m junit 2>$null | Out-Null
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $f = Get-BaseResultFields -Dir $dir
    $doc = [ordered]@{
      contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $f.Digest
      base_sha = [string]$f.Contract.base_sha; head_sha = $f.Head; execution_status = "completed"
      changed_files = @()
      test_evidence = @([ordered]@{ type = "junit-artifact"; name = "unit tests"; path = "reports/junit.xml"; sha256 = ("0" * 64) })
    }
    Write-ResultDoc -Dir $dir -Doc $doc | Out-Null
    $r = Invoke-Verify -Dir $dir
    Assert-True "junit fabricated hash: EXEC-005 raised" ((Get-Rules $r.Json) -contains "EXEC-005")
    Assert-True "junit fabricated hash: reason names the real vs. claimed mismatch" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "EXEC-005" })[0]).message -match "does not match the claimed")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: junit-artifact naming a file that does not exist -> EXEC-005 ---
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $f = Get-BaseResultFields -Dir $dir
    $doc = [ordered]@{
      contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $f.Digest
      base_sha = [string]$f.Contract.base_sha; head_sha = $f.Head; execution_status = "completed"
      changed_files = @()
      test_evidence = @([ordered]@{ type = "junit-artifact"; name = "unit tests"; path = "reports/does-not-exist.xml"; sha256 = ("a" * 64) })
    }
    Write-ResultDoc -Dir $dir -Doc $doc | Out-Null
    $r = Invoke-Verify -Dir $dir
    Assert-True "junit missing file: EXEC-005 raised" ((Get-Rules $r.Json) -contains "EXEC-005")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: junit-artifact path traversal -> EXEC-005, never opened outside project
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $f = Get-BaseResultFields -Dir $dir
    $doc = [ordered]@{
      contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $f.Digest
      base_sha = [string]$f.Contract.base_sha; head_sha = $f.Head; execution_status = "completed"
      changed_files = @()
      test_evidence = @([ordered]@{ type = "junit-artifact"; name = "unit tests"; path = "../../../../etc/passwd"; sha256 = ("a" * 64) })
    }
    Write-ResultDoc -Dir $dir -Doc $doc | Out-Null
    $r = Invoke-Verify -Dir $dir
    Assert-True "junit path traversal: EXEC-005 raised" ((Get-Rules $r.Json) -contains "EXEC-005")
    Assert-True "junit path traversal: reported as a containment breach, not silently resolved" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "EXEC-005" })[0]).message -match "containment breach")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: junit-artifact with real hash but failures>0 -> EXEC-005 -------
{
  $dir = New-ExecFixture
  try {
    Write-ExecFile $dir "reports/junit.xml" '<testsuite name="s" tests="2" failures="1" errors="0"><testcase name="a"/><testcase name="b"><failure/></testcase></testsuite>'
    & git -C $dir add -A 2>$null | Out-Null; & git -C $dir commit -q -m junit 2>$null | Out-Null
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $f = Get-BaseResultFields -Dir $dir
    $realHash = (Get-FileHash -LiteralPath (Join-Path $dir "reports/junit.xml") -Algorithm SHA256).Hash.ToLowerInvariant()
    $doc = [ordered]@{
      contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $f.Digest
      base_sha = [string]$f.Contract.base_sha; head_sha = $f.Head; execution_status = "completed"
      changed_files = @()
      test_evidence = @([ordered]@{ type = "junit-artifact"; name = "unit tests"; path = "reports/junit.xml"; sha256 = $realHash })
    }
    Write-ResultDoc -Dir $dir -Doc $doc | Out-Null
    $r = Invoke-Verify -Dir $dir
    Assert-True "junit real failures: EXEC-005 raised even with a correct hash" ((Get-Rules $r.Json) -contains "EXEC-005")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: junit-artifact real path, real hash, zero failures -> passes ---
{
  $dir = New-ExecFixture
  try {
    Write-ExecFile $dir "reports/junit.xml" '<testsuite name="s" tests="3" failures="0" errors="0"><testcase name="a"/><testcase name="b"/><testcase name="c"/></testsuite>'
    & git -C $dir add -A 2>$null | Out-Null; & git -C $dir commit -q -m junit 2>$null | Out-Null
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $f = Get-BaseResultFields -Dir $dir
    $realHash = (Get-FileHash -LiteralPath (Join-Path $dir "reports/junit.xml") -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-DecisionLogWithDigest -Dir $dir -Digest $realHash
    $doc = [ordered]@{
      contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $f.Digest
      base_sha = [string]$f.Contract.base_sha; head_sha = $f.Head; execution_status = "completed"
      changed_files = @()
      test_evidence = @([ordered]@{ type = "junit-artifact"; name = "unit tests"; path = "reports/junit.xml"; sha256 = $realHash })
      # JUnit evidence is artifact-observed: the file and its digest are both
      # writable by the verified actor, so a human vouch is what promotes it.
      authority_claims = @([ordered]@{
        type = "test-evidence-accepted"; actor = "human"; claim = "accepted"
        decision_ref = "DEC-100"; test_name = "unit tests"; evidence_sha256 = $realHash
      })
    }
    Write-ResultDoc -Dir $dir -Doc $doc | Out-Null
    $r = Invoke-Verify -Dir $dir
    Assert-True "junit real pass, human-vouched: verdict pass" ($r.Json.execution_verification.verdict -eq "pass") `
      ("fails=" + ((Get-Rules $r.Json) -join ","))
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- FATAL fix: runner-exit-record must be a real sealed record -----------

# ---- Case: hand-typed runner-exit-record with no sidecar -> EXEC-005 ------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $f = Get-BaseResultFields -Dir $dir
    $fakeRecordDir = Join-Path $dir ".execution/D-001/runs"
    New-Item -ItemType Directory -Path $fakeRecordDir -Force | Out-Null
    $fakeRecord = [ordered]@{
      run_id = "fake"; work_item_id = "D-001"; contract_sha256 = $f.Digest
      command = "npm test"; cwd = "."; exit_code = 0
      started_at = "x"; ended_at = "x"; stdout_sha256 = "x"; sealed_by = "axiom-runner"
    }
    Set-Content -LiteralPath (Join-Path $fakeRecordDir "fake.json") -Value ($fakeRecord | ConvertTo-Json) -NoNewline
    # Deliberately no fake.json.sha256 sidecar -- this is exactly the "agent
    # hand-types a plausible JSON object" attack the FATAL finding described.
    $doc = [ordered]@{
      contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $f.Digest
      base_sha = [string]$f.Contract.base_sha; head_sha = $f.Head; execution_status = "completed"
      changed_files = @()
      test_evidence = @([ordered]@{ type = "runner-exit-record"; name = "unit tests"; run_record_path = ".execution/D-001/runs/fake.json" })
    }
    Write-ResultDoc -Dir $dir -Doc $doc | Out-Null
    $r = Invoke-Verify -Dir $dir
    Assert-True "hand-typed run record: EXEC-005 raised (no sidecar = unsealed)" ((Get-Rules $r.Json) -contains "EXEC-005")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: FULLY forged run record + a genuinely matching sidecar ----------
#
# The decisive case. The one above only proves a record with *no* sidecar is
# rejected -- which is a trivial bar, because computing a SHA-256 is exactly
# as easy as writing the JSON. This one writes every field correctly (real
# contract digest, right work item, exit_code 0, sealed_by "axiom-runner"),
# then computes the record's real hash and writes a matching sidecar, and
# never invokes scripts/run-execution-command.ps1 at all.
#
# It must fail. A digest proves the file has not changed since the digest was
# taken; it proves nothing about who took it. Every input here is inside
# .execution/**, which the verified actor can write and which is deliberately
# exempt from scope analysis -- so "sealed" was never a seal, and
# `sealed_by: axiom-runner` is a self-assertion wearing a uniform. Confirmed
# passing (i.e. bypassed) before the provenance-tier fix; kept as the
# regression guard for it.
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $f = Get-BaseResultFields -Dir $dir

    $runsDir = Join-Path $dir ".execution/D-001/runs"
    New-Item -ItemType Directory -Path $runsDir -Force | Out-Null
    $forgedPath = Join-Path $runsDir "forged.json"
    $forged = [ordered]@{
      run_id = "forged-by-hand"
      work_item_id = "D-001"
      contract_sha256 = $f.Digest
      command = "npm test"
      cwd = "."
      exit_code = 0
      started_at = "2026-01-01T00:00:00.0000000+00:00"
      ended_at = "2026-01-01T00:00:01.0000000+00:00"
      stdout_sha256 = ("0" * 64)
      sealed_by = "axiom-runner"
    }
    Set-Content -LiteralPath $forgedPath -Value ($forged | ConvertTo-Json -Depth 8) -NoNewline
    # The "seal" an attacker can trivially produce for themselves.
    $forgedDigest = (Get-FileHash -LiteralPath $forgedPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath "$forgedPath.sha256" -Value ($forgedDigest + "`n") -NoNewline

    $doc = [ordered]@{
      contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $f.Digest
      base_sha = [string]$f.Contract.base_sha; head_sha = $f.Head; execution_status = "completed"
      changed_files = @()
      test_evidence = @([ordered]@{ type = "runner-exit-record"; name = "unit tests"; run_record_path = ".execution/D-001/runs/forged.json" })
    }
    Write-ResultDoc -Dir $dir -Doc $doc | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "forged record + valid sidecar, runner never invoked: EXEC-005 raised" `
      ((Get-Rules $r.Json) -contains "EXEC-005") `
      ("verdict=" + $r.Json.execution_verification.verdict)
    Assert-True "forged record + valid sidecar: verdict is not pass" `
      ($r.Json.execution_verification.verdict -ne "pass")
    Assert-True "forged record: the reason names provenance, not integrity" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "EXEC-005" }) | Select-Object -First 1).message -match "who produced|provenance|independently")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: a GENUINE runner record, no human vouch -> still EXEC-005 ------
#
# The tier rule is about provenance, not authenticity, so it has to bite even
# when the record is entirely legitimate. This one really does invoke
# scripts/run-execution-command.ps1 -- the command really ran, the exit code
# really was 0, the digest really matches -- and it is still rejected on its
# own, because Axiom-PMO cannot tell this record apart from the forged one
# above. Both are bytes under .execution/** that the verified actor could
# have written. If this case ever passes without a vouch, the distinction the
# provenance model rests on has quietly collapsed back to "well-formed
# equals trustworthy".
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{ authority_claims = @() } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "genuine runner record without a vouch: EXEC-005 raised" `
      ((Get-Rules $r.Json) -contains "EXEC-005") `
      ("verdict=" + $r.Json.execution_verification.verdict)
    Assert-True "genuine runner record without a vouch: reason names artifact-observed" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "EXEC-005" }) | Select-Object -First 1).message -match "artifact-observed")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: a vouch citing a decision that does not resolve -> EXEC-005 ----
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{
      authority_claims = @([ordered]@{ type = "test-evidence-accepted"; actor = "human"; claim = "accepted"; decision_ref = "DEC-404" })
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "vouch citing an unresolvable decision: does not promote the evidence" `
      ((Get-Rules $r.Json) -contains "EXEC-005")
    Assert-True "vouch citing an unresolvable decision: also raises EXEC-007" `
      ((Get-Rules $r.Json) -contains "EXEC-007")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: an AGENT cannot vouch for its own evidence -> EXEC-005 + 007 ---
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{
      # The obvious next forgery: if a human vouch promotes artifact evidence,
      # claim to be the human. Rejected on actor authority, exactly as
      # release-approval is.
      authority_claims = @([ordered]@{ type = "test-evidence-accepted"; actor = "agent"; claim = "accepted"; decision_ref = "DEC-100" })
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "agent self-vouch: EXEC-007 raised (agent cannot grant test-evidence-accepted)" `
      ((Get-Rules $r.Json) -contains "EXEC-007")
    Assert-True "agent self-vouch: evidence stays unpromoted, EXEC-005 raised" `
      ((Get-Rules $r.Json) -contains "EXEC-005")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: a vouch citing a REAL but UNRELATED decision -> EXEC-005 -------
#
# Review round 3's finding, reproduced. The first version of the vouch check
# was a single global boolean: any resolvable test-evidence-accepted claim
# promoted every artifact-observed entry in the execution. Demonstrated with a
# fabricated JUnit report claiming 99 passing tests, vouched by a real
# decision record about which logging library to use. The claim named no test,
# no artifact and no digest, so there was nothing for it to be wrong about.
{
  $dir = New-ExecFixture
  try {
    Write-ExecFile $dir "reports/junit.xml" '<testsuite name="fabricated" tests="99" failures="0" errors="0"><testcase name="a"/></testsuite>'
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $f = Get-BaseResultFields -Dir $dir
    $fakeHash = (Get-FileHash -LiteralPath (Join-Path $dir "reports/junit.xml") -Algorithm SHA256).Hash.ToLowerInvariant()

    # A decision that resolves, is unique, predates the range -- and has
    # nothing whatever to do with test evidence.
    $unrelated = @(
      "# Decision Log - P99-EXEC",
      "",
      "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
      "|---|---|---|---|---|---|---|---|",
      "| 2026-01-01 | DEC-100 | Pick a logging library | winston / pino | pino | faster | none | none |"
    ) -join "`n"
    Set-Content -LiteralPath (Join-Path $dir "decision-log.md") -Value $unrelated -NoNewline

    $doc = [ordered]@{
      contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $f.Digest
      base_sha = [string]$f.Contract.base_sha; head_sha = $f.Head; execution_status = "completed"
      changed_files = @()
      test_evidence = @([ordered]@{ type = "junit-artifact"; name = "unit tests"; path = "reports/junit.xml"; sha256 = $fakeHash })
      authority_claims = @([ordered]@{ type = "test-evidence-accepted"; actor = "human"; claim = "accepted"; decision_ref = "DEC-100" })
    }
    Write-ResultDoc -Dir $dir -Doc $doc | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "vouch citing a real but unrelated decision: EXEC-005 raised" `
      ((Get-Rules $r.Json) -contains "EXEC-005") ("verdict=" + $r.Json.execution_verification.verdict)
    Assert-True "unbound vouch: verdict is not pass" ($r.Json.execution_verification.verdict -ne "pass")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: fully SELF-CONSISTENT bindings, unrelated decision -> EXEC-005 --
#
# The case a claim-only binding rule would miss, and the reason the decision
# row itself has to name the digest. Every binding review asked for is present
# and correct -- test_name matches the required test, evidence_sha256 matches
# the artifact's real digest, work_item and contract match -- because the
# actor being verified writes all of them. Forge the artifact, hash it, copy
# the hash into your own claim, cite the same unrelated decision, and every
# field "matches". Self-consistent forgery is still forgery; only the decision
# row, which the actor cannot write inside the verified range, breaks the loop.
{
  $dir = New-ExecFixture
  try {
    Write-ExecFile $dir "reports/junit.xml" '<testsuite name="fabricated" tests="99" failures="0" errors="0"><testcase name="a"/></testsuite>'
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $f = Get-BaseResultFields -Dir $dir
    $fakeHash = (Get-FileHash -LiteralPath (Join-Path $dir "reports/junit.xml") -Algorithm SHA256).Hash.ToLowerInvariant()

    $unrelated = @(
      "# Decision Log - P99-EXEC",
      "",
      "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
      "|---|---|---|---|---|---|---|---|",
      "| 2026-01-01 | DEC-100 | Pick a logging library | winston / pino | pino | faster | none | none |"
    ) -join "`n"
    Set-Content -LiteralPath (Join-Path $dir "decision-log.md") -Value $unrelated -NoNewline

    $doc = [ordered]@{
      contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $f.Digest
      base_sha = [string]$f.Contract.base_sha; head_sha = $f.Head; execution_status = "completed"
      changed_files = @()
      test_evidence = @([ordered]@{ type = "junit-artifact"; name = "unit tests"; path = "reports/junit.xml"; sha256 = $fakeHash })
      authority_claims = @([ordered]@{
        type = "test-evidence-accepted"; actor = "human"; claim = "accepted"; decision_ref = "DEC-100"
        test_name = "unit tests"; evidence_sha256 = $fakeHash
        evidence_type = "junit-artifact"; work_item_id = "D-001"; contract_sha256 = $f.Digest
      })
    }
    Write-ResultDoc -Dir $dir -Doc $doc | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "self-consistent bindings, decision row silent on the digest: EXEC-005 raised" `
      ((Get-Rules $r.Json) -contains "EXEC-005") ("verdict=" + $r.Json.execution_verification.verdict)
    Assert-True "self-consistent bindings: reason names the decision record" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "EXEC-005" }) | Select-Object -First 1).message -match "does not name the digest")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: a vouch for test A does not cover test B -> EXEC-005 -----------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir | Out-Null
    # Rewrite the (correct, bound) vouch to name a different test.
    $resultPath = Join-Path $dir ".execution/D-001/EXECUTION-RESULT.json"
    $rd = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    $rd.authority_claims[0].test_name = "some other test"
    Set-Content -LiteralPath $resultPath -Value ($rd | ConvertTo-Json -Depth 12) -NoNewline

    $r = Invoke-Verify -Dir $dir
    Assert-True "vouch bound to a different test does not promote this one" `
      ((Get-Rules $r.Json) -contains "EXEC-005")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: right test, wrong artifact digest -> EXEC-005 ------------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir | Out-Null
    $resultPath = Join-Path $dir ".execution/D-001/EXECUTION-RESULT.json"
    $rd = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    $rd.authority_claims[0].evidence_sha256 = ("b" * 64)
    Set-Content -LiteralPath $resultPath -Value ($rd | ConvertTo-Json -Depth 12) -NoNewline

    $r = Invoke-Verify -Dir $dir
    Assert-True "vouch naming a different artifact digest does not promote this one" `
      ((Get-Rules $r.Json) -contains "EXEC-005")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: a vouch with no bindings at all -> EXEC-005, fail closed -------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir | Out-Null
    $resultPath = Join-Path $dir ".execution/D-001/EXECUTION-RESULT.json"
    $rd = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    # The shape the old global-boolean version accepted.
    $rd.authority_claims = @([pscustomobject]@{ type = "test-evidence-accepted"; actor = "human"; claim = "accepted"; decision_ref = "DEC-100" })
    Set-Content -LiteralPath $resultPath -Value ($rd | ConvertTo-Json -Depth 12) -NoNewline

    $r = Invoke-Verify -Dir $dir
    Assert-True "legacy unbound vouch fails closed" ((Get-Rules $r.Json) -contains "EXEC-005")
    Assert-True "legacy unbound vouch: reason says it names no test" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "EXEC-005" }) | Select-Object -First 1).message -match "names no test_name")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: vouch bound to a different work item -> EXEC-005 ---------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir | Out-Null
    $resultPath = Join-Path $dir ".execution/D-001/EXECUTION-RESULT.json"
    $rd = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    $rd.authority_claims[0].work_item_id = "D-999"
    Set-Content -LiteralPath $resultPath -Value ($rd | ConvertTo-Json -Depth 12) -NoNewline

    $r = Invoke-Verify -Dir $dir
    Assert-True "vouch bound to another work item does not promote this one" `
      ((Get-Rules $r.Json) -contains "EXEC-005")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: run record edited after sealing (sidecar now stale) -> EXEC-005
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $relRunRecordPath = New-RealRunRecord -Dir $dir
    $recordFull = Join-Path $dir $relRunRecordPath
    $record = Get-Content -LiteralPath $recordFull -Raw | ConvertFrom-Json
    $record.exit_code = 1
    Set-Content -LiteralPath $recordFull -Value ($record | ConvertTo-Json) -NoNewline
    # Sidecar left untouched -- it still reflects the pre-edit bytes.

    $f = Get-BaseResultFields -Dir $dir
    $doc = [ordered]@{
      contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $f.Digest
      base_sha = [string]$f.Contract.base_sha; head_sha = $f.Head; execution_status = "completed"
      changed_files = @()
      test_evidence = @([ordered]@{ type = "runner-exit-record"; name = "unit tests"; run_record_path = $relRunRecordPath })
    }
    Write-ResultDoc -Dir $dir -Doc $doc | Out-Null
    $r = Invoke-Verify -Dir $dir
    Assert-True "tampered run record: EXEC-005 raised (digest no longer matches)" ((Get-Rules $r.Json) -contains "EXEC-005")
    Assert-True "tampered run record: reason names the mismatch" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "EXEC-005" })[0]).message -match "modified after")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: real sealed record, but bound to a different work item ---------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $relRunRecordPath = New-RealRunRecord -Dir $dir
    $recordFull = Join-Path $dir $relRunRecordPath
    # Re-seal with a different work_item_id, the same way run-execution-command.ps1
    # would if invoked for other work -- proves the binding check, not just presence.
    $record = Get-Content -LiteralPath $recordFull -Raw | ConvertFrom-Json
    $record.work_item_id = "D-999"
    Set-Content -LiteralPath $recordFull -Value ($record | ConvertTo-Json) -NoNewline
    $newDigest = (Get-FileHash -LiteralPath $recordFull -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath "$recordFull.sha256" -Value ($newDigest + "`n") -NoNewline

    $f = Get-BaseResultFields -Dir $dir
    $doc = [ordered]@{
      contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $f.Digest
      base_sha = [string]$f.Contract.base_sha; head_sha = $f.Head; execution_status = "completed"
      changed_files = @()
      test_evidence = @([ordered]@{ type = "runner-exit-record"; name = "unit tests"; run_record_path = $relRunRecordPath })
    }
    Write-ResultDoc -Dir $dir -Doc $doc | Out-Null
    $r = Invoke-Verify -Dir $dir
    Assert-True "run record for wrong work item: EXEC-005 raised" ((Get-Rules $r.Json) -contains "EXEC-005")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: real sealed record with a real nonzero exit code -> EXEC-005 ---
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $previous = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File $runExecutionScript `
      -ProjectPath $dir -WorkItemId "D-001" -Name "unit tests" -Command "exit 1" 2>&1 | Out-Null
    $ErrorActionPreference = $previous
    $recordFile = @(Get-ChildItem -LiteralPath (Join-Path $dir ".execution/D-001/runs") -Filter "*.json" |
      Where-Object { $_.Name -notmatch '\.sha256$' })[0]
    $relRunRecordPath = ".execution/D-001/runs/$($recordFile.Name)"

    $f = Get-BaseResultFields -Dir $dir
    $doc = [ordered]@{
      contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $f.Digest
      base_sha = [string]$f.Contract.base_sha; head_sha = $f.Head; execution_status = "completed"
      changed_files = @()
      test_evidence = @([ordered]@{ type = "runner-exit-record"; name = "unit tests"; run_record_path = $relRunRecordPath })
    }
    Write-ResultDoc -Dir $dir -Doc $doc | Out-Null
    $r = Invoke-Verify -Dir $dir
    Assert-True "real failing command: EXEC-005 raised (sealed exit code was 1)" ((Get-Rules $r.Json) -contains "EXEC-005")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: a passing command that writes to stderr still seals and verifies
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null

    # The command writes to stderr AND exits 0 -- the shape of essentially
    # every real test runner (npm, pytest, jest all emit progress/warnings on
    # stderr while passing). Every other case in this file uses `echo ok` or
    # `exit 1`, neither of which writes to stderr, which is exactly why a real
    # defect here went unnoticed: run-execution-command.ps1 sets
    # ErrorActionPreference = "Stop", and Windows PowerShell 5.1 turns native
    # stderr into a terminating error under "Stop", so on that host the runner
    # would die before sealing a record -- an ordinary passing test suite
    # reported as a crash. Asserting on a stderr-writing command is what keeps
    # that fixed.
    $previous = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File $runExecutionScript `
      -ProjectPath $dir -WorkItemId "D-001" -Name "unit tests" `
      -Command "echo 'warning: noisy but fine' 1>&2; echo ok" 2>&1 | Out-Null
    $ErrorActionPreference = $previous

    $recordFile = @(Get-ChildItem -LiteralPath (Join-Path $dir ".execution/D-001/runs") -Filter "*.json" -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -notmatch '\.sha256$' })[0]
    Assert-True "stderr-writing command: a sealed record was still produced" ($null -ne $recordFile)

    if ($recordFile) {
      $relRunRecordPath = ".execution/D-001/runs/$($recordFile.Name)"
      $stderrRecordDigest = (Get-FileHash -LiteralPath (Join-Path $dir $relRunRecordPath) -Algorithm SHA256).Hash.ToLowerInvariant()
      Set-DecisionLogWithDigest -Dir $dir -Digest $stderrRecordDigest
      $f = Get-BaseResultFields -Dir $dir
      $doc = [ordered]@{
        contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $f.Digest
        base_sha = [string]$f.Contract.base_sha; head_sha = $f.Head; execution_status = "completed"
        changed_files = @()
        test_evidence = @([ordered]@{ type = "runner-exit-record"; name = "unit tests"; run_record_path = $relRunRecordPath })
        authority_claims = @([ordered]@{
          type = "test-evidence-accepted"; actor = "human"; claim = "accepted"
          decision_ref = "DEC-100"; test_name = "unit tests"; evidence_sha256 = $stderrRecordDigest
        })
      }
      Write-ResultDoc -Dir $dir -Doc $doc | Out-Null
      $r = Invoke-Verify -Dir $dir
      Assert-True "stderr-writing command: verdict pass (stderr is not failure)" `
        ($r.Json.execution_verification.verdict -eq "pass") `
        ("verdict=" + $r.Json.execution_verification.verdict + " fails=" + ((Get-Rules $r.Json) -join ","))
    }
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- FATAL fix: ci-check must query live, never trust the result's claim --

# ---- Case: ci-check with no resolvable GitHub remote -> unverified --------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $f = Get-BaseResultFields -Dir $dir
    $doc = [ordered]@{
      contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $f.Digest
      base_sha = [string]$f.Contract.base_sha; head_sha = $f.Head; execution_status = "completed"
      changed_files = @()
      # A disposable fixture repo has no "origin" remote at all -- this is the
      # deterministic, offline-testable half of Test-CiCheckEvidence; a live
      # GitHub-API-verified positive case is out of scope for this offline suite.
      test_evidence = @([ordered]@{ type = "ci-check"; name = "unit tests"; commit_sha = $f.Head; conclusion = "success" })
    }
    Write-ResultDoc -Dir $dir -Doc $doc | Out-Null
    $r = Invoke-Verify -Dir $dir
    $exec005 = (Get-Rules $r.Json) -contains "EXEC-005"
    if (-not $exec005) {
      # Diagnostic dump, not asserted on: this case has failed unexplained on
      # one CI platform before. If it fails again, this prints exactly what
      # Test-CiCheckEvidence actually decided instead of leaving a bare
      # pass/fail to guess from -- see whether gh was found, what remote (if
      # any) resolved, and the full verdict.
      Write-Host "  DIAGNOSTIC: verdict=$($r.Json.execution_verification.verdict)"
      Write-Host "  DIAGNOSTIC: fixture remote (should be none): $(Get-FixtureGit $dir remote -v)"
      Write-Host "  DIAGNOSTIC: gh on PATH: $((Get-Command gh -ErrorAction SilentlyContinue) -ne $null)"
      Write-Host "  DIAGNOSTIC: all results: $($r.Json.results | ConvertTo-Json -Depth 6 -Compress)"
    }
    Assert-True "ci-check no remote: EXEC-005 raised, never a silent pass on the claimed conclusion" $exec005
    Assert-True "ci-check no remote: the result's own claimed conclusion is never read as authoritative" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "EXEC-005" }) | Select-Object -First 1).message -notmatch "success.*success")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- MAJOR fix: contract digest sidecar is mandatory, not best-effort -----

# ---- Case: sidecar deleted after export -> EXEC-002, not a silent pass ----
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir | Out-Null
    Remove-Item -LiteralPath (Join-Path $dir ".execution/D-001/EXECUTION-CONTRACT.json.sha256") -Force

    $r = Invoke-Verify -Dir $dir
    Assert-True "deleted sidecar: EXEC-002 raised" ((Get-Rules $r.Json) -contains "EXEC-002")
    Assert-True "deleted sidecar: verdict names the missing digest, not a pass" `
      ($r.Json.execution_verification.verdict -eq "contract_digest_missing")
    Assert-True "deleted sidecar: exit code is non-zero" ($r.ExitCode -ne 0)
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: sidecar present but empty -> EXEC-002 --------------------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir | Out-Null
    Set-Content -LiteralPath (Join-Path $dir ".execution/D-001/EXECUTION-CONTRACT.json.sha256") -Value "" -NoNewline

    $r = Invoke-Verify -Dir $dir
    Assert-True "empty sidecar: EXEC-002 raised" ((Get-Rules $r.Json) -contains "EXEC-002")
    Assert-True "empty sidecar: verdict names malformed, not tampered or missing" `
      ($r.Json.execution_verification.verdict -eq "contract_digest_malformed")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: sidecar present but not a well-formed digest -> EXEC-002 -------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir | Out-Null
    Set-Content -LiteralPath (Join-Path $dir ".execution/D-001/EXECUTION-CONTRACT.json.sha256") -Value "not-a-digest" -NoNewline

    $r = Invoke-Verify -Dir $dir
    Assert-True "malformed sidecar: EXEC-002 raised" ((Get-Rules $r.Json) -contains "EXEC-002")
    Assert-True "malformed sidecar: verdict is contract_digest_malformed" `
      ($r.Json.execution_verification.verdict -eq "contract_digest_malformed")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: sidecar digest in uppercase / with surrounding whitespace still matches
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir | Out-Null
    $digest = Get-ContractDigest -Dir $dir
    Set-Content -LiteralPath (Join-Path $dir ".execution/D-001/EXECUTION-CONTRACT.json.sha256") -Value "  $($digest.ToUpperInvariant())  `n" -NoNewline

    $r = Invoke-Verify -Dir $dir
    Assert-True "uppercase/whitespace sidecar: still resolves to a pass, not a false tamper report" `
      ($r.Json.execution_verification.verdict -eq "pass") `
      ("verdict=" + $r.Json.execution_verification.verdict)
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- MAJOR fix: human decision_ref must resolve against decision-log.md ---

# ---- Case: decision_ref that does not exist anywhere -> EXEC-007 ----------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{
      authority_claims = @([ordered]@{ type = "release-approval"; actor = "human"; claim = "approved"; decision_ref = "DEC-999-NOT-REAL" })
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "fake decision ref, no decision-log.md at all: EXEC-007 raised" ((Get-Rules $r.Json) -contains "EXEC-007")
    Assert-True "fake decision ref: reason says it did not resolve" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "EXEC-007" })[0]).message -match "could not be resolved")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: decision_ref not shaped like DEC-### -> EXEC-007 ---------------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{
      authority_claims = @([ordered]@{ type = "release-approval"; actor = "human"; claim = "approved"; decision_ref = "see the chat log" })
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "non-DEC decision ref: EXEC-007 raised" ((Get-Rules $r.Json) -contains "EXEC-007")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: decision_ref resolves in a real decision-log.md -> passes ------
{
  $dir = New-ExecFixture
  try {
    # Overwrites the fixture's own decision log, so DEC-100 has to be carried
    # forward here too -- the default result cites it to promote its
    # artifact-observed runner evidence, and dropping it would make this case
    # fail for an unrelated reason (a missing vouch) while appearing to test
    # decision resolution.
    $decisionLog = @(
      "# Decision Log - T",
      "",
      "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
      "|---|---|---|---|---|---|---|---|",
      "| 2026-07-30 | DEC-001 | ship it | A/B | A | because | src | ok |",
      "| 2026-07-30 | DEC-100 | Accept local test artifacts for D-001 | accept / require CI | accept | reviewed by hand | none | test evidence accepted |"
    ) -join "`n"
    Write-ExecFile $dir "decision-log.md" $decisionLog
    & git -C $dir add -A 2>$null | Out-Null; & git -C $dir commit -q -m "record decision" 2>$null | Out-Null

    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    # New-Result produces the run record and rewrites decision-log.md with a
    # DEC-100 row naming that record's digest. Read the digest back so the
    # vouch can bind to it, then restore DEC-001 alongside -- this case is
    # about DEC-001 resolving, so losing it would fail for the wrong reason.
    # One New-Result call, then append the release-approval claim to what it
    # already wrote. Calling it twice would mint a second run record and leave
    # the vouch bound to whichever the directory happened to list first.
    $resultPath = New-Result -Dir $dir
    $resultDoc = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    $claims = @($resultDoc.authority_claims)
    $claims += [pscustomobject]@{ type = "release-approval"; actor = "human"; claim = "approved"; decision_ref = "DEC-001" }
    $resultDoc.authority_claims = $claims
    Set-Content -LiteralPath $resultPath -Value ($resultDoc | ConvertTo-Json -Depth 12) -NoNewline

    # New-Result wrote a decision log carrying DEC-100 with the record's real
    # digest; DEC-001 has to be restored alongside it, since this case is about
    # DEC-001 resolving and losing it would fail for the wrong reason.
    $existingLog = Get-Content -LiteralPath (Join-Path $dir "decision-log.md") -Raw
    Set-Content -LiteralPath (Join-Path $dir "decision-log.md") `
      -Value ($existingLog.TrimEnd() + "`n| 2026-07-30 | DEC-001 | ship it | A/B | A | because | src | ok |") -NoNewline

    $r = Invoke-Verify -Dir $dir
    Assert-True "real decision ref, log committed before the export: verdict pass" `
      ($r.Json.execution_verification.verdict -eq "pass") `
      ("fails=" + ((Get-Rules $r.Json) -join ","))
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: decision_ref resolves, but appears twice (ambiguous) -----------
{
  $dir = New-ExecFixture
  try {
    $decisionLog = @(
      "# Decision Log - T",
      "",
      "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
      "|---|---|---|---|---|---|---|---|",
      "| 2026-07-30 | DEC-001 | first | A | A | x | src | ok |",
      "| 2026-07-30 | DEC-001 | duplicate id | A | A | x | src | ok |"
    ) -join "`n"
    Write-ExecFile $dir "decision-log.md" $decisionLog
    & git -C $dir add -A 2>$null | Out-Null; & git -C $dir commit -q -m "record decision" 2>$null | Out-Null

    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{
      authority_claims = @([ordered]@{ type = "release-approval"; actor = "human"; claim = "approved"; decision_ref = "DEC-001" })
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "ambiguous decision ref (appears twice): EXEC-007 raised" ((Get-Rules $r.Json) -contains "EXEC-007")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- Case: the self-referential attack -- agent forges its own approval ---
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    $f = Get-BaseResultFields -Dir $dir
    $relRunRecordPath = New-RealRunRecord -Dir $dir

    # The attack: within the SAME commit range under verification, the agent
    # adds a decision-log.md row approving its own release, then cites it.
    $decisionLog = @(
      "# Decision Log - T",
      "",
      "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
      "|---|---|---|---|---|---|---|---|",
      "| 2026-07-30 | DEC-001 | forged | A | A | agent wrote this | none | none |"
    ) -join "`n"
    Write-ExecFile $dir "decision-log.md" $decisionLog
    Write-ExecFile $dir "src/payments/app.ts" "implemented"
    & git -C $dir add -A 2>$null | Out-Null
    & git -C $dir commit -q -m "impl + self-forged decision" 2>$null | Out-Null
    $head = (Get-FixtureGit $dir rev-parse HEAD).Trim()

    $doc = [ordered]@{
      contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $f.Digest
      base_sha = [string]$f.Contract.base_sha; head_sha = $head; execution_status = "completed"
      changed_files = @("src/payments/app.ts", "decision-log.md")
      git_actions_performed = @("commit")
      test_evidence = @([ordered]@{ type = "runner-exit-record"; name = "unit tests"; run_record_path = $relRunRecordPath })
      authority_claims = @([ordered]@{ type = "release-approval"; actor = "human"; claim = "approved"; decision_ref = "DEC-001" })
    }
    Write-ResultDoc -Dir $dir -Doc $doc | Out-Null
    $r = Invoke-Verify -Dir $dir
    Assert-True "self-forged decision: EXEC-007 raised even though DEC-001 resolves" `
      ((Get-Rules $r.Json) -contains "EXEC-007")
    Assert-True "self-forged decision: reason names decision-log.md as changed within the verified range" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "EXEC-007" -and $_.artifact -eq "decision-log.md" })[0]).message -match "changed within the commit range")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

# ---- MINOR fix: claimed-not-observed direction -----------------------------

# ---- Case: result claims a changed file git shows no evidence of ----------
{
  $dir = New-ExecFixture
  try {
    Invoke-Export -Dir $dir -Grant "commit" | Out-Null
    New-Result -Dir $dir -Overrides @{
      changed_files = @("src/payments/never-touched.ts")
    } | Out-Null

    $r = Invoke-Verify -Dir $dir
    Assert-True "claimed-not-observed: EXEC-008 raised" ((Get-Rules $r.Json) -contains "EXEC-008")
    Assert-True "claimed-not-observed: message names the false claim" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "EXEC-008" })[0]).message -match "claims a file that git shows no evidence")
  } finally { Remove-ExecFixture $dir }
}.Invoke()

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"
if ($fail -gt 0) { exit 1 }
exit 0
