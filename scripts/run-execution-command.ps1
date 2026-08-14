param(
  [Parameter(Mandatory = $true)]
  [Alias("Project")]
  [string]$ProjectPath,

  [Parameter(Mandatory = $true)]
  [string]$WorkItemId,

  # Must match a required_tests entry name in the contract, so verification
  # can bind this record to the specific test it is evidence for.
  [Parameter(Mandatory = $true)]
  [string]$Name,

  [Parameter(Mandatory = $true)]
  [string]$Command,

  # Relative to ProjectPath. Validated to stay inside it -- see the
  # containment check below, the same pattern reference-resolver.ps1 uses for
  # FILE: references (REF-002).
  [string]$WorkingDirectory = ".",

  [string]$ContractPath = $null
)

# The strongest evidence source in Milestone 5's MVP, per
# docs/architecture/execution-contract-verification.md section 4.3 -- and the one
# that was, until this fix, entirely unbuilt. An EXECUTION-RESULT.json
# claiming a `runner-exit-record` used to require nothing but the agent
# typing plausible field values. This script is what makes the claim real:
# it is Axiom's own process that runs the command, observes the real exit
# code, and seals a record of what happened -- not the agent describing what
# it says happened.
#
# What "sealed" means here, precisely, because overselling it would be its
# own violation of this framework's own honesty standard: the record is a
# plain JSON file plus a `.sha256` sidecar of its exact bytes, written by
# THIS script at the moment it captured the real exit code -- the identical
# file+sidecar pattern EXECUTION-CONTRACT.json already uses, deliberately
# reused rather than inventing a second scheme. That choice is not
# incidental: an earlier draft of this script self-embedded a digest inside
# the record by re-serializing its own fields with ConvertTo-Json, which is
# exactly the mistake this milestone's own CI just spent three iterations
# catching elsewhere -- ConvertTo-Json's spacing differs between Windows
# PowerShell 5.1 and PowerShell 7 (see the tamper-test fix in this
# repository's history), so a digest recomputed by re-serializing rather
# than by re-hashing raw file bytes would fail to reproduce across hosts for
# reasons that have nothing to do with tampering. Hashing the file's stored
# bytes, the same way the contract digest already does, has no such
# dependency.
#
# It is not cryptographic proof against an actor with unrestricted
# filesystem access who edits both the record and its sidecar together --
# nothing self-hosted can be, without external attestation infrastructure
# this MVP does not have. What it defeats is the actual FATAL gap Independent AI Reviewer's
# review found: an agent typing a plausible-looking JSON object by hand,
# with no script ever having actually run the command.

$ErrorActionPreference = "Stop"

# scope-diff-matcher.ps1 first: Read-ExecutionContract (in the file below)
# validates allowed_paths with Test-ScopeGlobSyntax, defined there.
. (Join-Path $PSScriptRoot "lib/scope-diff-matcher.ps1")
. (Join-Path $PSScriptRoot "lib/execution-contract-schema.ps1")

function Fail-Run {
  param([string]$Message)
  Write-Host "RUN FAILED: $Message"
  exit 1
}

$project = (Resolve-Path -LiteralPath $ProjectPath).Path

if (-not $ContractPath) {
  $ContractPath = Join-Path (Join-Path (Join-Path $project ".execution") $WorkItemId) "EXECUTION-CONTRACT.json"
}
$contract = Read-ExecutionContract -Path $ContractPath
if (-not $contract.Present) { Fail-Run "No execution contract at $ContractPath. A run record must be bound to an exported contract's digest." }
if (-not $contract.Valid) { Fail-Run "Execution contract is invalid: $($contract.Error)" }
$sidecarPath = "$ContractPath.sha256"
if (-not (Test-Path -LiteralPath $sidecarPath -PathType Leaf)) { Fail-Run "No digest sidecar at $sidecarPath. Export the contract with axiom export before running evidence against it." }
# Explicit $null check: see execution-contract-validator.ps1's identical fix
# for why a [string] cast alone is not reliable here on an empty file.
$sidecarRawText = Get-Content -LiteralPath $sidecarPath -Raw
$sidecarDigest = if ($null -eq $sidecarRawText) { "" } else { $sidecarRawText.Trim().ToLowerInvariant() }
if ($sidecarDigest -ne $contract.Digest) { Fail-Run "The contract's digest does not match its sidecar -- it was modified after export. Re-export before recording evidence against it." }

# --- containment: WorkingDirectory must stay inside the project root -------
$rootFull = [System.IO.Path]::GetFullPath($project)
$sep = [System.IO.Path]::DirectorySeparatorChar
if ($WorkingDirectory -match '^[/\\]' -or $WorkingDirectory -match '^[A-Za-z]:[\\/]?') {
  Fail-Run "-WorkingDirectory must be relative to the project, not absolute: $WorkingDirectory"
}
$cwdFull = [System.IO.Path]::GetFullPath((Join-Path $project $WorkingDirectory))
if (($cwdFull -ne $rootFull) -and -not $cwdFull.StartsWith($rootFull + $sep)) {
  Fail-Run "-WorkingDirectory escapes the project root: $WorkingDirectory"
}
if (-not (Test-Path -LiteralPath $cwdFull -PathType Container)) {
  Fail-Run "-WorkingDirectory does not exist: $WorkingDirectory"
}
$cwdRelative = if ($cwdFull -eq $rootFull) { "." } else { ($cwdFull.Substring($rootFull.Length).TrimStart($sep) -replace [regex]::Escape([string]$sep), '/') }

# --- run it, for real --------------------------------------------------------
# Genuinely spawned as a child process through the platform shell -- not
# Invoke-Expression, which runs $Command as PowerShell code IN THIS PROCESS.
# That distinction is not stylistic: `exit 0` inside a command a real test
# runner might emit (or a script calling `exit` for its own reasons) would
# terminate Invoke-Expression's host process -- this script -- before it ever
# reached the code that writes the sealed record, silently discarding the
# very exit code it was supposed to capture. Found by actually running this
# script against `exit 0`, not reasoned about in advance. A child process's
# exit only ends the child; $LASTEXITCODE after `&` reliably reflects it on
# every supported host.
$onWindows = ($PSVersionTable.PSEdition -eq "Desktop") -or ($IsWindows -eq $true)
$shellExe = if ($onWindows) { "cmd.exe" } else { "/bin/sh" }
$shellArgs = if ($onWindows) { @("/c", $Command) } else { @("-c", $Command) }

# Output captured, never persisted raw -- only its digest is sealed into the
# record, so a secret a test happens to print does not end up committed in
# .execution/.
#
# $ErrorActionPreference drops to "Continue" for the duration of the child
# process, and this is load-bearing rather than tidiness. This script sets
# "Stop" at the top, and Windows PowerShell 5.1 converts *any* native
# command's stderr into a terminating error under "Stop" -- `2>&1` merges the
# streams but does not stop the conversion there. The entire point of this
# script is running someone's test command, and real test runners (npm,
# pytest, jest) write progress and warnings to stderr constantly, so on 5.1
# this would have killed the runner before it captured the exit code or
# sealed a record -- turning an ordinary passing test suite into a crash.
#
# The local test suite never caught it because its fixture commands are
# `echo ok` and `exit 1`, neither of which writes to stderr. Found by
# auditing for this failure mode after the same class of bug broke the
# ci-check adapter on the 5.1 CI leg; it is the third time this specific
# PowerShell 5.1 behaviour has caused a defect in this milestone, which is
# why every native invocation in M5 now carries an explicit guard.
$previousLocation = Get-Location
Set-Location -LiteralPath $cwdFull
$startedAt = [DateTimeOffset]::UtcNow.ToString("o")
$previousEap = $ErrorActionPreference
try {
  $ErrorActionPreference = "Continue"
  $output = & $shellExe @shellArgs 2>&1
  $capturedText = ($output | Out-String)
  $exitCode = [int]$LASTEXITCODE
} finally {
  $ErrorActionPreference = $previousEap
  Set-Location -LiteralPath $previousLocation
}
$endedAt = [DateTimeOffset]::UtcNow.ToString("o")

$stdoutBytes = [System.Text.Encoding]::UTF8.GetBytes($capturedText)
$stdoutSha256 = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($stdoutBytes)).Replace("-", "").ToLowerInvariant()

$runId = [System.Guid]::NewGuid().ToString()
$record = [ordered]@{
  run_id = $runId
  work_item_id = $WorkItemId
  contract_sha256 = $contract.Digest
  command = $Command
  cwd = $cwdRelative
  exit_code = $exitCode
  started_at = $startedAt
  ended_at = $endedAt
  stdout_sha256 = $stdoutSha256
  sealed_by = "axiom-runner"
}

$runsDir = Join-Path (Join-Path (Join-Path $project ".execution") $WorkItemId) "runs"
New-Item -ItemType Directory -Path $runsDir -Force | Out-Null
$recordPath = Join-Path $runsDir "$runId.json"
$json = ($record | ConvertTo-Json -Depth 12)
$json = ($json -replace "`r`n", "`n")
if (-not $json.EndsWith("`n")) { $json += "`n" }
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($recordPath, $json, $utf8NoBom)

# Sidecar of the record file's own stored bytes -- written from the file
# that now sits on disk, the same order of operations
# export-execution-contract.ps1 uses for the contract, so recomputing this
# digest at verification time is a plain file re-hash, never a
# re-serialization.
$recordDigest = Get-ExecutionFileDigest -Path $recordPath
[System.IO.File]::WriteAllText("$recordPath.sha256", ($recordDigest + "`n"), $utf8NoBom)

$relRecordPath = ".execution/$WorkItemId/runs/$runId.json"

Write-Host "Command run and sealed"
Write-Host "  command    : $Command"
Write-Host "  cwd        : $cwdRelative"
Write-Host "  exit code  : $exitCode"
Write-Host "  record     : $recordPath"
Write-Host ""
if ($exitCode -eq 0) {
  Write-Host "Add this to EXECUTION-RESULT.json's test_evidence:"
  Write-Host "  { `"type`": `"runner-exit-record`", `"name`": `"$Name`", `"run_record_path`": `"$relRecordPath`" }"
} else {
  Write-Host "Exit code was non-zero -- verification will reject this record for any required test that names it."
}

exit $exitCode
