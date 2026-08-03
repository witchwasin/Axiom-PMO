param(
  [string]$ProjectPath,
  [ValidateSet("Lite", "Standard", "Strict")]
  [string]$Mode = "Standard",
  [ValidateSet("Draft", "Scope", "Design", "Handoff", "Release")]
  [string]$Gate = "Draft",
  [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,

  # Skip running a new validation and only rebuild FAILURE-PATTERNS.json from
  # the events already on disk. This is also what proves the registry is
  # genuinely rebuildable: run once normally, delete the registry, run again
  # with -RebuildOnly, and the output must be byte-for-byte identical.
  [switch]$RebuildOnly,

  [ValidateSet("Text", "Json")]
  [string]$Format = "Text"
)

# Milestone 9: Failure Pattern Registry. An aggregator over diagnostics
# validate-project.ps1 already emits -- no new instrumentation, no new engine.
# See pmo-config/learning-policy.json and research/m7-m9-proposal.md section 4.
#
# Local and opt-in by construction, not by discipline: this script makes no
# network call anywhere in it, and the events directory is git-ignored by
# default (see .gitignore). Nothing here can silently widen that boundary --
# doing so is a separate, future, explicitly authorized milestone.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/pwsh-host.ps1")

$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$policyPath = Join-Path $repo "pmo-config/learning-policy.json"
if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
  throw "Missing runtime learning policy config: $policyPath"
}
$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json

$eventsDir = Join-Path $repo $policy.storage.events_dir
$registryPath = Join-Path $repo $policy.storage.registry_path
$saltPath = Join-Path $repo $policy.storage.salt_path
New-Item -ItemType Directory -Force -Path $eventsDir | Out-Null

function Get-RepositorySalt {
  param([string]$SaltPath)
  if (Test-Path -LiteralPath $SaltPath -PathType Leaf) {
    return (Get-Content -LiteralPath $SaltPath -Raw).Trim()
  }
  $bytes = New-Object byte[] 32
  # RNGCryptoServiceProvider, not RandomNumberGenerator::Fill(): Fill() is a
  # .NET Core 2.1+ API and does not exist in the .NET Framework that Windows
  # PowerShell 5.1 runs on -- a required host for this framework. Using it
  # threw on 5.1 before this function returned, so the entire M9 aggregator
  # produced no events and no registry there, while every pwsh 7 host passed.
  # CI caught it: `pmo-checks` (5.1) failed while the three pwsh 7 jobs were
  # green. Same lesson as docs/architecture/powershell-portability.md records
  # -- an API that resolves on the development host is not evidence it
  # resolves on 5.1.
  $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
  try {
    $rng.GetBytes($bytes)
  } finally {
    $rng.Dispose()
  }
  $salt = ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $SaltPath) | Out-Null
  Set-Content -LiteralPath $SaltPath -Value $salt -NoNewline
  return $salt
}

function Get-ProjectHash {
  param([string]$ProjectAbsolutePath, [string]$Salt)
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes("$Salt|$ProjectAbsolutePath")
  return (($sha256.ComputeHash($bytes)) | ForEach-Object { $_.ToString("x2") }) -join ""
}

# item_id retains its SHAPE (D-###, REQ-###) so a cluster can group "the same
# kind of row" without retaining which specific row -- but only for a shape on
# the allowlist. Sol's independent review found the first version of this
# replaced digits only ('\d+' -> '#'), so a purely alphabetic id such as
# 'ACME-fraud-case' or 'patient-HIV' passed through byte-for-byte unchanged --
# a substitution rule is not an allowlist. An id that does not match any
# allowed pattern is bucketed to "other", the same closed-set treatment
# Get-GovernedArtifactOrOther already gives an unlisted artifact name, never
# partially sanitized and retained.
function ConvertTo-NormalizedItemId {
  param([string]$ItemId, $AllowedPatterns)
  if ([string]::IsNullOrWhiteSpace($ItemId)) { return $null }
  foreach ($pattern in @($AllowedPatterns)) {
    if ($ItemId -match [string]$pattern) {
      return ($ItemId -replace '\d+', '#')
    }
  }
  return "other"
}

function Get-GovernedArtifactOrOther {
  param([string]$Artifact, $Allowlist)
  if ([string]::IsNullOrWhiteSpace($Artifact)) { return $null }
  if (@($Allowlist) -contains $Artifact) { return $Artifact }
  return "other"
}

# execution_path is declared a closed enum in policy but was previously
# copied verbatim from PROJECT.md's regex capture with no validation --
# Sol's independent review found a malformed value (which PATH-001 already
# flags as invalid at validate-project.ps1 level) would still be retained
# into every event from that project. Enum-validated here as well, never
# retained raw.
function ConvertTo-NormalizedExecutionPath {
  param([string]$ExecutionPath, $AllowedValues)
  if (@($AllowedValues) -contains $ExecutionPath) { return $ExecutionPath }
  return "unknown"
}

# --- 1. Record this run's diagnostics as one immutable event file ----------

if (-not $RebuildOnly) {
  if (-not $ProjectPath) {
    throw "aggregate-diagnostics.ps1 requires -ProjectPath unless -RebuildOnly is set."
  }
  $project = (Resolve-Path -LiteralPath $ProjectPath).Path
  $pwshExe = Get-PowerShellHost
  if (-not $pwshExe) {
    Write-Host (Get-PowerShellHostMissingMessage)
    exit 127
  }

  $previousEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $rawOutput = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/validate-project.ps1") -ProjectPath $project -Mode $Mode -Gate $Gate -Format Json 2>$null
  } finally {
    $ErrorActionPreference = $previousEap
  }
  $envelope = $null
  try { $envelope = ($rawOutput -join "`n") | ConvertFrom-Json } catch { $envelope = $null }
  if (-not $envelope -or -not $envelope.results) {
    throw "aggregate-diagnostics.ps1: validate-project.ps1 produced no parseable diagnostics for $project."
  }

  $salt = Get-RepositorySalt -SaltPath $saltPath
  $projectHash = Get-ProjectHash -ProjectAbsolutePath $project -Salt $salt
  $executionPathMatch = $null
  $projectMdPath = Join-Path $project "PROJECT.md"
  if (Test-Path -LiteralPath $projectMdPath) {
    $projectText = Get-Content -LiteralPath $projectMdPath -Raw
    if ($projectText -match '(?m)^\s*>?\s*Execution path:\s*(.+?)\s*$') { $executionPathMatch = $Matches[1] }
  }
  if (-not $executionPathMatch) { $executionPathMatch = "development_handoff" }
  $executionPathMatch = ConvertTo-NormalizedExecutionPath -ExecutionPath $executionPathMatch -AllowedValues $policy.execution_path_allowed_values

  $commitHash = $null
  $previousEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $commitOut = & git -C $project rev-parse HEAD 2>$null
  $ErrorActionPreference = $previousEap
  if ($LASTEXITCODE -eq 0 -and $commitOut) { $commitHash = ([string]$commitOut).Trim() }

  $runId = [System.Guid]::NewGuid().ToString("N")
  $timestamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
  $eventFile = Join-Path $eventsDir "$timestamp-$runId.jsonl"

  $allowlist = @($policy.governed_artifact_allowlist)
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($row in $envelope.results) {
    if ($row.level -ne "WARN" -and $row.level -ne "FAIL") { continue }
    $event = [ordered]@{
      schema_version = "1.0"
      recorded_at = [DateTime]::UtcNow.ToString("o")
      run_id = $runId
      rule_id = [string]$row.rule_id
      level = [string]$row.level
      blocking = [bool]$row.blocking
      mode = [string]$envelope.effective_mode
      gate = [string]$envelope.gate
      execution_path = $executionPathMatch
      artifact = (Get-GovernedArtifactOrOther -Artifact ([string]$row.artifact) -Allowlist $allowlist)
      item_id = (ConvertTo-NormalizedItemId -ItemId ([string]$row.item_id) -AllowedPatterns $policy.item_id_allowed_patterns)
      project_hash = $projectHash
      commit_hash = $commitHash
    }
    $lines.Add(($event | ConvertTo-Json -Depth 6 -Compress)) | Out-Null
  }
  # Written once, in full, then never reopened -- this is what makes two
  # concurrent runs unable to collide: they always write to two different
  # files (the run_id in the filename is unique per run), never the same one.
  Set-Content -LiteralPath $eventFile -Value ($lines -join "`n") -NoNewline
}

# --- 2. Rebuild FAILURE-PATTERNS.json from every event file on disk --------
#
# Always a full rebuild from the events directory, never an incremental
# update to the existing registry file -- that is what makes the registry
# provably derived rather than itself a second source of truth. A corrupted
# or deleted registry is a re-run of this step, not a data-loss event.

$allEvents = New-Object System.Collections.Generic.List[object]
Get-ChildItem -LiteralPath $eventsDir -Filter "*.jsonl" -File | Sort-Object Name | ForEach-Object {
  $content = Get-Content -LiteralPath $_.FullName
  foreach ($line in $content) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try { $allEvents.Add(($line | ConvertFrom-Json)) | Out-Null } catch { }
  }
}

$byRule = @{}
foreach ($event in $allEvents) {
  $ruleId = [string]$event.rule_id
  if (-not $byRule.ContainsKey($ruleId)) {
    $byRule[$ruleId] = [ordered]@{
      rule_id = $ruleId
      count = 0
      run_ids = New-Object System.Collections.Generic.HashSet[string]
      commits = New-Object System.Collections.Generic.HashSet[string]
      projects = New-Object System.Collections.Generic.HashSet[string]
      item_id_patterns = New-Object System.Collections.Generic.HashSet[string]
      first_seen = $event.recorded_at
      last_seen = $event.recorded_at
    }
  }
  $entry = $byRule[$ruleId]
  $entry.count++
  if ($event.run_id) { [void]$entry.run_ids.Add([string]$event.run_id) }
  if ($event.commit_hash) { [void]$entry.commits.Add([string]$event.commit_hash) }
  if ($event.project_hash) { [void]$entry.projects.Add([string]$event.project_hash) }
  if ($event.item_id) { [void]$entry.item_id_patterns.Add([string]$event.item_id) }
  if ($event.recorded_at -lt $entry.first_seen) { $entry.first_seen = $event.recorded_at }
  if ($event.recorded_at -gt $entry.last_seen) { $entry.last_seen = $event.recorded_at }
}

$clusters = @()
foreach ($ruleId in ($byRule.Keys | Sort-Object)) {
  $e = $byRule[$ruleId]
  $clusters += [ordered]@{
    rule_id = $e.rule_id
    count = $e.count
    distinct_run_ids = $e.run_ids.Count
    distinct_commits = $e.commits.Count
    distinct_projects = $e.projects.Count
    distinct_item_id_patterns = @($e.item_id_patterns | Sort-Object)
    first_seen = $e.first_seen
    last_seen = $e.last_seen
    disposition = "undetermined"
  }
}

$registry = [ordered]@{
  schema_version = "1.0"
  generated_at = [DateTime]::UtcNow.ToString("o")
  rebuilt_from_event_count = $allEvents.Count
  clusters = $clusters
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $registryPath) | Out-Null
Set-Content -LiteralPath $registryPath -Value ($registry | ConvertTo-Json -Depth 8) -NoNewline

# --- 3. Candidates: only for clusters crossing the multi-dimensional threshold, never a raw count ---

$threshold = $policy.clustering.candidate_threshold
$candidatesDir = Join-Path $repo ".axiom/learning/candidates"
$newCandidates = @()
foreach ($cluster in $clusters) {
  $daysSpan = 0
  try {
    $daysSpan = ([DateTime]$cluster.last_seen - [DateTime]$cluster.first_seen).TotalDays
  } catch { $daysSpan = 0 }
  $crosses = ($cluster.distinct_projects -ge $threshold.min_distinct_projects) -and
             ($cluster.distinct_commits -ge $threshold.min_distinct_commits) -and
             ($daysSpan -ge $threshold.min_days_span)
  if ($crosses) { $newCandidates += $cluster }
}

if ($newCandidates.Count -gt 0) {
  New-Item -ItemType Directory -Force -Path $candidatesDir | Out-Null
  foreach ($cluster in $newCandidates) {
    $candidateId = "IMP-$($cluster.rule_id)"
    $candidate = [ordered]@{
      schema_version = "1.0"
      candidate_id = $candidateId
      generated_at = [DateTime]::UtcNow.ToString("o")
      trigger = [ordered]@{
        rule_id = $cluster.rule_id
        distinct_projects = $cluster.distinct_projects
        distinct_commits = $cluster.distinct_commits
        distinct_run_ids = $cluster.distinct_run_ids
        days_span = [Math]::Round(([DateTime]$cluster.last_seen - [DateTime]$cluster.first_seen).TotalDays, 1)
      }
      disposition_summary = [ordered]@{ true_defect = 0; false_positive = 0; user_error = 0; undetermined = $cluster.count }
      hypothesis = "Recurring $($cluster.rule_id) across $($cluster.distinct_projects) projects and $($cluster.distinct_commits) commits. Disposition not yet reviewed -- see disposition_summary."
      recommended_remedies = @()
      authority_required = "Human Owner"
      # AI-authored candidates may only ever carry this status. Any other
      # value requires a DEC-### recorded by a human -- enforced by review,
      # not by this script, which never writes anything but "proposed".
      status = "proposed"
    }
    Set-Content -LiteralPath (Join-Path $candidatesDir "$candidateId.json") -Value ($candidate | ConvertTo-Json -Depth 8) -NoNewline
  }
}

if ($Format -eq "Json") {
  Write-Output ($registry | ConvertTo-Json -Depth 8)
} else {
  Write-Host "Axiom-PMO Failure Pattern Registry"
  Write-Host "  events dir : $eventsDir ($($allEvents.Count) events)"
  Write-Host "  registry   : $registryPath"
  Write-Host ""
  foreach ($cluster in $clusters) {
    Write-Host "$($cluster.rule_id): $($cluster.count) event(s), $($cluster.distinct_projects) project(s), $($cluster.distinct_commits) commit(s)"
  }
  if ($newCandidates.Count -gt 0) {
    Write-Host ""
    Write-Host "New improvement candidates: $(($newCandidates | ForEach-Object { $_.rule_id }) -join ', ')"
  }
}

exit 0
