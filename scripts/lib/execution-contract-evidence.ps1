# Real test-evidence verification (M5, FATAL fix).
#
# execution-contract-schema.ps1's Resolve-TestEvidenceEntries deliberately
# stops at "does this entry have the right fields" -- it is a pure parser,
# same as the rest of that file. This file does the part that actually opens
# files, hashes bytes, parses XML, and queries a live API: the part that was
# entirely missing from the first implementation, which is why an agent could
# satisfy `runner-exit-record` by typing `{"command": "npm test", "exit_code":
# 0, "recorded_by": "axiom-runner"}` and having it accepted as verified. That
# was Sol's FATAL finding, confirmed against the actual code: no
# Get-FileHash, no XML parse, no API call anywhere in the adapter resolver.
#
# Every Test-*Evidence function here returns the same shape:
#   [pscustomobject]@{ Verified = $true|$false; Reason = <string, when false>
#                      EvidenceDigest = <the digest of the exact bytes this
#                                        adapter verified, when Verified> }
# and every one defaults to Verified = $false on any ambiguity. An adapter
# that cannot independently confirm something reports "unverified," never a
# silent pass -- the same standard scope-diff-git-adapter.ps1 and
# execution-contract-git.ps1 already hold themselves to for infrastructure
# failures.

# --- junit-artifact -----------------------------------------------------

function Test-JUnitEvidence {
  param($Entry, [Parameter(Mandatory = $true)][string]$ProjectPath)

  $result = [pscustomobject]@{ Verified = $false; Reason = $null; EvidenceDigest = $null }
  $relPath = [string]$Entry.Raw.path
  $claimedSha = [string]$Entry.Raw.sha256

  # Containment: identical pattern to reference-resolver.ps1's FILE:
  # reference check (REF-002) -- an absolute path is rejected outright, and a
  # relative path that canonicalizes outside the project root is a
  # containment breach even if something happens to exist at that location.
  # Reused deliberately rather than re-invented: this is the third file in
  # this framework that needs "does this path stay inside the project,"
  # after SCOPE-DIFF's exemption patterns and the FILE: reference type, and a
  # fourth slightly-different implementation would be a fourth place to get
  # subtly wrong.
  if ($relPath -match '^[/\\]' -or $relPath -match '^[A-Za-z]:[\\/]?') {
    $result.Reason = "path '$relPath' is absolute; junit-artifact paths must be relative to the project root"
    return $result
  }
  $rootFull = [System.IO.Path]::GetFullPath($ProjectPath)
  $sep = [System.IO.Path]::DirectorySeparatorChar
  $resolvedFull = [System.IO.Path]::GetFullPath((Join-Path $ProjectPath $relPath))
  if (($resolvedFull -ne $rootFull) -and -not $resolvedFull.StartsWith($rootFull + $sep)) {
    $result.Reason = "path '$relPath' escapes the project root -- containment breach"
    return $result
  }
  if (-not (Test-Path -LiteralPath $resolvedFull -PathType Leaf)) {
    $result.Reason = "no file at '$relPath'"
    return $result
  }

  # Real hash of the real file, not the agent's claim about the file.
  $actualSha = (Get-FileHash -LiteralPath $resolvedFull -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualSha -ne $claimedSha.ToLowerInvariant()) {
    $result.Reason = "the file's actual SHA-256 ($actualSha) does not match the claimed sha256 ($claimedSha)"
    return $result
  }

  # Safe XML parse: DTD processing prohibited and no external resolver, so a
  # crafted JUnit file cannot pull in an external entity (XXE) or trigger a
  # billion-laughs-style expansion. JUnit XML needs neither DOCTYPE nor
  # external entities to be valid, so prohibiting both costs nothing real.
  $settings = New-Object System.Xml.XmlReaderSettings
  $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
  $settings.XmlResolver = $null
  $doc = New-Object System.Xml.XmlDocument
  try {
    $reader = [System.Xml.XmlReader]::Create($resolvedFull, $settings)
    try { $doc.Load($reader) } finally { $reader.Close() }
  } catch {
    $result.Reason = "the file's contents are not parseable as XML: $($_.Exception.Message)"
    return $result
  }

  # A JUnit document is either a single <testsuite> or a <testsuites> wrapper
  # around one or more. Sum failures+errors across every testsuite found
  # either way -- one root-level check misses the multi-suite case entirely.
  $suites = @($doc.SelectNodes("//testsuite"))
  if ($suites.Count -eq 0) {
    $result.Reason = "no <testsuite> element found -- not a JUnit XML document"
    return $result
  }
  $totalTests = 0
  $totalFailures = 0
  $totalErrors = 0
  foreach ($suite in $suites) {
    $totalTests += [int](Get-XmlIntAttribute $suite "tests")
    $totalFailures += [int](Get-XmlIntAttribute $suite "failures")
    $totalErrors += [int](Get-XmlIntAttribute $suite "errors")
  }
  if ($totalTests -eq 0) {
    $result.Reason = "the JUnit report has zero recorded tests -- an empty report is not evidence a test suite ran"
    return $result
  }
  if (($totalFailures + $totalErrors) -gt 0) {
    $result.Reason = "the JUnit report itself records $totalFailures failure(s) and $totalErrors error(s) -- a failing run is not evidence of a passing test"
    return $result
  }

  $result.Verified = $true
  # The digest of the bytes actually hashed, so a human vouch can bind to
  # this exact artifact rather than to "some test evidence existed".
  $result.EvidenceDigest = $actualSha
  return $result
}

function Get-XmlIntAttribute {
  param($Node, [string]$Name)
  $attr = $Node.Attributes[$Name]
  if (-not $attr) { return 0 }
  $parsed = 0
  if ([int]::TryParse($attr.Value, [ref]$parsed)) { return $parsed }
  return 0
}

# --- ci-check -------------------------------------------------------------

# Parses `owner/repo` out of a git remote URL in either form
# (git@github.com:owner/repo.git or https://github.com/owner/repo[.git]).
# Returns $null on anything else -- a non-GitHub remote is a real "cannot
# verify," not an error.
function Get-GitHubOwnerRepo {
  param([string]$RemoteUrl)
  if ([string]::IsNullOrWhiteSpace($RemoteUrl)) { return $null }
  if ($RemoteUrl -match 'github\.com[:/]([^/]+)/([^/.]+?)(\.git)?$') {
    return "$($Matches[1])/$($Matches[2])"
  }
  return $null
}

# Runs a native command and returns its stdout, with stderr discarded and
# $LASTEXITCODE preserved, without letting the command's stderr terminate the
# caller.
#
# This exists because of a real crash, not defensiveness. Windows PowerShell
# 5.1 turns any native command's stderr into a *terminating* error when
# $ErrorActionPreference is "Stop" -- which verify-execution-result.ps1 sets
# -- and `2>$null` does not prevent it there (only in pwsh 7). `git remote
# get-url origin` on a repository with no remote writes "error: No such
# remote 'origin'" to stderr, so the entire verification script died before
# emitting any JSON: a user on Windows PowerShell 5.1 whose result carried a
# ci-check entry got a crash instead of an "unverified" verdict. Caught by
# CI on the 5.1 leg only, after the same failure mode had already been fixed
# once in tests/helpers/execution-contract-tests.ps1 -- the lesson did not
# transfer to product code the first time, hence a named helper rather than
# another inline save/restore to forget.
function Invoke-NativeCapture {
  param([scriptblock]$Command)
  $previousEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & $Command 2>$null
    return [pscustomobject]@{ Output = $output; ExitCode = $LASTEXITCODE }
  } finally {
    $ErrorActionPreference = $previousEap
  }
}

function Test-CiCheckEvidence {
  param($Entry, [Parameter(Mandatory = $true)][string]$GitRepoRoot)

  $result = [pscustomobject]@{ Verified = $false; Reason = $null; EvidenceDigest = $null }
  $name = [string]$Entry.Raw.name
  $commitSha = [string]$Entry.Raw.commit_sha
  if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($commitSha)) {
    $result.Reason = "missing name or commit_sha"
    return $result
  }

  # No `conclusion` read from $Entry.Raw here, ever -- the whole point of this
  # adapter is to not trust the result's own claim about the outcome. Only
  # the API response's conclusion is consulted, below.

  $ghCommand = Get-Command "gh" -ErrorAction SilentlyContinue
  if (-not $ghCommand) {
    $result.Reason = "no GitHub API context available (gh CLI not found on PATH) -- cannot independently verify, so this is unverified rather than a pass"
    return $result
  }

  $remote = Invoke-NativeCapture { git -C $GitRepoRoot remote get-url origin }
  $remoteUrl = $remote.Output
  if ($remoteUrl -is [array]) { $remoteUrl = $remoteUrl[0] }
  if ($remote.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace([string]$remoteUrl)) {
    $result.Reason = "could not resolve a git remote to query -- cannot independently verify"
    return $result
  }
  $ownerRepo = Get-GitHubOwnerRepo -RemoteUrl ([string]$remoteUrl)
  if (-not $ownerRepo) {
    $result.Reason = "the git remote is not a recognizable GitHub URL -- cannot independently verify"
    return $result
  }

  $apiPath = "repos/$ownerRepo/commits/$commitSha/check-runs"
  $api = Invoke-NativeCapture { gh api $apiPath }
  if ($api.ExitCode -ne 0) {
    $result.Reason = "the GitHub API query for commit $commitSha failed -- cannot independently verify (network, auth, or the commit is not on GitHub)"
    return $result
  }
  $raw = $api.Output

  try {
    $data = ($raw | Out-String) | ConvertFrom-Json
  } catch {
    $result.Reason = "the GitHub API response could not be parsed"
    return $result
  }

  $matchingRuns = @($data.check_runs | Where-Object { [string]$_.name -eq $name })
  if ($matchingRuns.Count -eq 0) {
    $result.Reason = "no check run named '$name' was found for commit $commitSha"
    return $result
  }

  # A commit can carry several check runs with the same name -- a re-run, or
  # two workflow runs triggered on the same SHA (a push plus a manual
  # dispatch, say). Taking $matchingRuns[0] made the verdict depend on
  # whichever the API happened to list first, so the same evidence could
  # verify or not verify between two invocations. That is not a theoretical
  # ordering worry: this adapter's own live test hit it, picking a completed
  # successful run during discovery and an in-flight one (conclusion "")
  # a moment later.
  #
  # Resolved conservatively, in the same spirit as the ambiguity rule for
  # DEC-### references: every completed run under that name must agree, and
  # a name with any non-success completed run does not verify -- a
  # "somewhere it passed" reading would let an actor re-run a job until one
  # attempt went green and then cite the name.
  $completedRuns = @($matchingRuns | Where-Object { [string]$_.status -eq "completed" })
  if ($completedRuns.Count -eq 0) {
    $inFlight = @($matchingRuns | ForEach-Object { [string]$_.status }) -join ", "
    $result.Reason = "check run '$name' on commit $commitSha has not completed (status: $inFlight) -- an unfinished check is not evidence of a passing test"
    return $result
  }

  $nonSuccess = @($completedRuns | Where-Object { [string]$_.conclusion -ne "success" })
  if ($nonSuccess.Count -gt 0) {
    $conclusions = @($completedRuns | ForEach-Object { [string]$_.conclusion }) -join ", "
    if ($completedRuns.Count -gt 1) {
      $result.Reason = "commit $commitSha has $($completedRuns.Count) completed check runs named '$name' and they do not all report success (observed: $conclusions). A name that passed on one attempt and failed on another is not evidence."
    } else {
      $result.Reason = "the check run's conclusion, as observed via the GitHub API, is '$conclusions', not success"
    }
    return $result
  }

  $result.Verified = $true
  return $result
}

# --- runner-exit-record ----------------------------------------------------

function Test-RunnerExitEvidence {
  param(
    $Entry,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [Parameter(Mandatory = $true)][string]$ContractSha256,
    [Parameter(Mandatory = $true)][string]$WorkItemId
  )

  $result = [pscustomobject]@{ Verified = $false; Reason = $null; EvidenceDigest = $null }
  $relPath = [string]$Entry.Raw.run_record_path
  if ([string]::IsNullOrWhiteSpace($relPath)) {
    $result.Reason = "no run_record_path -- a runner-exit-record must point at the sealed file scripts/run-execution-command.ps1 produced, not describe its own command/exit_code inline"
    return $result
  }

  # Same containment pattern as the JUnit adapter and REF-002.
  if ($relPath -match '^[/\\]' -or $relPath -match '^[A-Za-z]:[\\/]?') {
    $result.Reason = "run_record_path '$relPath' is absolute; it must be relative to the project root"
    return $result
  }
  $rootFull = [System.IO.Path]::GetFullPath($ProjectPath)
  $sep = [System.IO.Path]::DirectorySeparatorChar
  $recordFull = [System.IO.Path]::GetFullPath((Join-Path $ProjectPath $relPath))
  if (($recordFull -ne $rootFull) -and -not $recordFull.StartsWith($rootFull + $sep)) {
    $result.Reason = "run_record_path '$relPath' escapes the project root -- containment breach"
    return $result
  }
  if (-not (Test-Path -LiteralPath $recordFull -PathType Leaf)) {
    $result.Reason = "no run record found at '$relPath' -- scripts/run-execution-command.ps1 must be run to produce one before it can be cited"
    return $result
  }
  $sidecarFull = "$recordFull.sha256"
  if (-not (Test-Path -LiteralPath $sidecarFull -PathType Leaf)) {
    $result.Reason = "run record at '$relPath' has no .sha256 sidecar -- an unsealed record is not evidence"
    return $result
  }

  # Explicit $null check, not a [string] cast: Get-Content -Raw on a
  # zero-byte file returns $null, and casting that specific null does not
  # reliably yield a real .NET string on every host (confirmed by direct
  # repro -- see execution-contract-validator.ps1's identical fix for the
  # contract sidecar, same crash class, found the same way).
  $sidecarRaw = Get-Content -LiteralPath $sidecarFull -Raw
  $sidecarText = if ($null -eq $sidecarRaw) { "" } else { $sidecarRaw.Trim().ToLowerInvariant() }
  $actualDigest = (Get-FileHash -LiteralPath $recordFull -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($sidecarText -ne $actualDigest) {
    $result.Reason = "the run record's contents do not match its sealed digest -- it was modified after scripts/run-execution-command.ps1 wrote it"
    return $result
  }

  $record = $null
  try {
    $record = Get-Content -LiteralPath $recordFull -Raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    $result.Reason = "the run record is not valid JSON"
    return $result
  }

  if ([string]$record.sealed_by -ne "axiom-runner") {
    $result.Reason = "the run record's sealed_by is not 'axiom-runner'"
    return $result
  }
  if ([string]$record.work_item_id -ne $WorkItemId) {
    $result.Reason = "the run record is bound to work item '$($record.work_item_id)', not '$WorkItemId' -- evidence for different work cannot satisfy this contract"
    return $result
  }
  if ([string]$record.contract_sha256 -ne $ContractSha256) {
    $result.Reason = "the run record is bound to a different contract digest -- it was not produced against the contract being verified"
    return $result
  }
  $exitCode = $null
  if (-not [int]::TryParse([string]$record.exit_code, [ref]$exitCode)) {
    $result.Reason = "the run record's exit_code is not a valid integer"
    return $result
  }
  if ($exitCode -ne 0) {
    $result.Reason = "the sealed exit code was $exitCode, not 0"
    return $result
  }

  $result.Verified = $true
  # The record file's own digest -- already recomputed above and matched
  # against its sidecar, so this is the byte-exact identity of the record a
  # human vouch has to name.
  $result.EvidenceDigest = $actualDigest
  return $result
}

# --- orchestration ----------------------------------------------------------

# One entry point the validator calls per test_evidence entry, so EXEC-005's
# logic in execution-contract-validator.ps1 does not need to know which
# adapter does what -- it asks this function "is this verified," and gets a
# reason when the answer is no.
function Test-EvidenceEntryVerified {
  param(
    $Entry,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [Parameter(Mandatory = $true)][string]$GitRepoRoot,
    [Parameter(Mandatory = $true)][string]$ContractSha256,
    [Parameter(Mandatory = $true)][string]$WorkItemId
  )

  if (-not $Entry.Known) {
    return [pscustomobject]@{ Verified = $false; Reason = "unrecognized evidence type '$($Entry.Type)'" }
  }
  if (-not $Entry.FieldsPresent) {
    return [pscustomobject]@{ Verified = $false; Reason = "missing required field(s): $($Entry.MissingFields -join ', ')" }
  }

  switch ($Entry.Type) {
    "junit-artifact" { return Test-JUnitEvidence -Entry $Entry -ProjectPath $ProjectPath }
    "ci-check" { return Test-CiCheckEvidence -Entry $Entry -GitRepoRoot $GitRepoRoot }
    "runner-exit-record" { return Test-RunnerExitEvidence -Entry $Entry -ProjectPath $ProjectPath -ContractSha256 $ContractSha256 -WorkItemId $WorkItemId }
    default { return [pscustomobject]@{ Verified = $false; Reason = "'$($Entry.Type)' is not independently verifiable by design (agent-claimed evidence)" } }
  }
}
