param(
  [Parameter(Mandatory = $true)]
  [Alias("Project")]
  [string]$ProjectPath,

  [ValidateSet("Lite", "Standard", "Strict")]
  [string]$Mode = "Standard",

  [ValidateSet("Text", "Json")]
  [string]$Format = "Text"
)

# Handoff readiness assessment.
#
# This is a reporting tool, not a gate. It runs the Handoff gate, reads the
# semantic review, and answers a more useful question than pass/fail:
#
#   Ready to Start Development?  Ready to Integrate?  Ready to Demo?
#
# Those are different answers. An unresolved serving model for a scanner blocks
# the demonstration and does not stop anyone writing domain logic today. A
# single verdict forces a choice between stalling a team that could be working
# and promising a demo that will not happen.
#
# The score exists to make a trend visible across projects. It is capped hard
# whenever the underlying evidence is weak, and it is not an approval. Nobody
# may pass a gate, release a build, or accept a risk on the strength of a
# number produced here. See docs/concepts/human-authority.md.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/pwsh-host.ps1")
. (Join-Path $PSScriptRoot "lib/config-loader.ps1")
. (Join-Path $PSScriptRoot "lib/markdown-table-parser.ps1")
. (Join-Path $PSScriptRoot "lib/result-writer.ps1")
. (Join-Path $PSScriptRoot "lib/handoff-validator.ps1")

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$project = (Resolve-Path -LiteralPath $ProjectPath).Path

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

$cfg = Import-PmoConfig -RepoRoot $repoRoot
$handoffPolicy = $cfg.HandoffPolicy
$scorePolicy = $handoffPolicy.score

# ---------------------------------------------------------------- gate results
$validatorArgs = @(
  "-NoProfile", "-ExecutionPolicy", "Bypass",
  "-File", (Join-Path $repoRoot "scripts/validate-project.ps1"),
  "-ProjectPath", $project, "-Mode", $Mode, "-Gate", "Handoff", "-Format", "Json"
)
$previous = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$validatorOutput = & $pwshExe @validatorArgs 2>$null
$validatorExit = $LASTEXITCODE
$ErrorActionPreference = $previous

$gate = $null
try {
  $gate = ($validatorOutput | Out-String) | ConvertFrom-Json
} catch {
  $gate = $null
}
if (-not $gate) {
  Write-Host "Handoff validation did not produce parseable output for $project"
  exit 1
}

$results = @($gate.results)
$failures = @($results | Where-Object { $_.level -eq "FAIL" })
$warnings = @($results | Where-Object { $_.level -eq "WARN" })
$deterministicFail = ($failures.Count -gt 0)

# ---------------------------------------------------------------- review state
$reviewPolicy = $handoffPolicy.semantic_review
$reviewPath = Join-Path $project ([string]$reviewPolicy.artifact)
$review = $null
$reviewPresent = Test-Path -LiteralPath $reviewPath -PathType Leaf
if ($reviewPresent) {
  try { $review = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json } catch { $review = $null }
}

$projectText = ""
$projectFile = Join-Path $project "PROJECT.md"
if (Test-Path -LiteralPath $projectFile -PathType Leaf) {
  # Explicit UTF-8 so this digest matches the one the validator and
  # handoff-digest.ps1 compute; 5.1 would decode a BOM-less file as ANSI.
  # See powershell-portability.md section 7.
  $projectText = Get-Content -LiteralPath $projectFile -Raw -Encoding UTF8
}
$currentSourceDigest = Get-SourceSnapshotDigest -ProjectText $projectText
$currentInputDigest = Get-ReviewInputDigest -Project $project -HandoffPolicy $handoffPolicy
$recordedSourceDigest = ""
$recordedInputDigest = ""
if ($review) {
  $recordedSourceDigest = "$($review.source_snapshot.digest)".Trim().ToLowerInvariant()
  $recordedInputDigest = "$($review.review_inputs.digest)".Trim().ToLowerInvariant()
}
# Stale either way: the sources the requirements came from moved, or a governed
# artifact the reviewer actually read moved.
$sourceStale = ($review -and $currentSourceDigest -and $recordedSourceDigest -and ($currentSourceDigest -ne $recordedSourceDigest))
$inputStale = ($review -and $currentInputDigest -and $recordedInputDigest -and ($currentInputDigest -ne $recordedInputDigest))
$reviewStale = [bool]($sourceStale -or $inputStale)
$reviewUsable = ($null -ne $review) -and (-not $reviewStale) -and [bool]$recordedSourceDigest -and [bool]$recordedInputDigest

$openStatuses = @($handoffPolicy.semantic_review.closure_policy.open_statuses)
$openFindings = @()
if ($review) {
  $openFindings = @(@($review.findings) | Where-Object { $openStatuses -contains "$($_.status)" })
}

# Open actions declared in HANDOFF.md are blockers too.
#
# The review is not the only place a team records what is unresolved. HANDOFF.md
# has an Open Actions table with the same blocking-point vocabulary, and it is
# usually where the operational blockers live -- a device that has not arrived,
# a certificate that is not installed. Reading only the review means a project
# can close every finding, leave both demo actions open, and be told it is
# ready to demo.
$openActions = @()
$handoffPath = Join-Path $project "HANDOFF.md"
if (Test-Path -LiteralPath $handoffPath -PathType Leaf) {
  $handoffText = Get-Content -LiteralPath $handoffPath -Raw
  $actionRows = @(Get-TableRowsAfterHeading $handoffText (Get-HeadingPattern -Heading "Open Actions" -Level 2))
  foreach ($row in $actionRows) {
    $status = "$($row.Status)".Trim().ToLowerInvariant()
    if ($openStatuses -notcontains $status) { continue }
    $openActions += [pscustomobject]@{
      finding_id = "$($row.'Action ID')".Trim()
      severity = "action"
      blocking_point = "$($row.'Blocking Point')".Trim()
      owner = "$($row.Owner)".Trim()
      artifact = "HANDOFF.md"
      origin = "open_action"
    }
  }
}

# Deduplicate: a review finding that points at an action id is the same blocker
# seen from two documents, and counting it twice would overstate the problem.
$findingIds = @($openFindings | ForEach-Object { "$($_.finding_id)".Trim() })
$findingItemIds = @($openFindings | ForEach-Object { "$($_.item_id)".Trim() } | Where-Object { $_ })
$uniqueActions = @($openActions | Where-Object {
  ($findingIds -notcontains $_.finding_id) -and ($findingItemIds -notcontains $_.finding_id)
})

$allBlockers = @()
$allBlockers += @($openFindings | ForEach-Object {
  [pscustomobject]@{
    finding_id = "$($_.finding_id)".Trim()
    severity = "$($_.severity)"
    blocking_point = "$($_.blocking_point)"
    owner = "$($_.owner)"
    artifact = "$($_.artifact)"
    origin = "review_finding"
  }
})
$allBlockers += $uniqueActions

# ---------------------------------------------------------------- stage verdicts
# A stage is blocked by any open blocker whose blocking point is at or before
# that stage, and by any deterministic FAIL (which always blocks everything).
$stageBlockers = [ordered]@{}
foreach ($stageProp in $handoffPolicy.stage_blocking_map.PSObject.Properties) {
  $stage = $stageProp.Name
  $points = @($stageProp.Value)
  $stageBlockers[$stage] = @($allBlockers | Where-Object { $points -contains "$($_.blocking_point)" })
}

$contractValid = -not $deterministicFail

# Three states, not two.
#
# Without a usable review there are no *recorded* findings, which is not the
# same as there being none. Returning $true here would turn an absence of
# evidence into evidence of absence -- a machine consumer reading `verdicts`
# would see six greens on a project nobody has read. $null means "cannot be
# determined from the available evidence", and `verdict_reasons` says why.
function Get-StageVerdict {
  param([string]$Stage)
  if (-not $script:contractValid) { return $false }
  if (@($script:stageBlockers[$Stage]).Count -gt 0) { return $false }
  if (-not $script:reviewUsable) { return $null }
  return $true
}

function Get-StageReason {
  param([string]$Stage)
  if (-not $script:contractValid) { return "blocked: the contract has deterministic failures" }
  $blockers = @($script:stageBlockers[$Stage])
  if ($blockers.Count -gt 0) {
    return "blocked by " + (@($blockers | ForEach-Object { $_.finding_id }) -join ", ")
  }
  if (-not $script:reviewUsable) {
    if ($null -eq $script:review) { return "unknown: no semantic review has been recorded" }
    if ($script:reviewStale) { return "unknown: the semantic review is stale" }
    return "unknown: the semantic review does not record both freshness digests"
  }
  return "no recorded blocker"
}

$verdicts = [ordered]@{
  "Contract Valid" = $contractValid
  "Ready to Start Development" = (Get-StageVerdict "Ready to Start Development")
  "Ready to Integrate" = (Get-StageVerdict "Ready to Integrate")
  "Ready to Demo" = (Get-StageVerdict "Ready to Demo")
  "Ready for UAT" = (Get-StageVerdict "Ready for UAT")
  "Ready for Release" = (Get-StageVerdict "Ready for Release")
}

$verdictReasons = [ordered]@{
  "Contract Valid" = $(if ($contractValid) { "no deterministic failures" } else { "$($failures.Count) deterministic FAIL diagnostic(s)" })
}
foreach ($stage in @("Ready to Start Development", "Ready to Integrate", "Ready to Demo", "Ready for UAT", "Ready for Release")) {
  $verdictReasons[$stage] = (Get-StageReason $stage)
}

# ---------------------------------------------------------------- scoring
# Each dimension starts at full marks and loses them for evidence that is
# actually missing. A dimension is never awarded points for something the
# project did not declare.
function Get-DimensionPoints {
  param([string]$Id)
  $dimension = @($scorePolicy.dimensions | Where-Object { $_.id -eq $Id })
  if ($dimension.Count -eq 0) { return 0 }
  return [int]$dimension[0].points
}

function Get-RuleHitCount {
  param([string[]]$RuleIds, [string]$Level = "FAIL")
  return @($results | Where-Object { $RuleIds -contains $_.rule_id -and $_.level -eq $Level }).Count
}

# Losing a fixed fraction per distinct failing rule keeps one badly-filled table
# from zeroing a whole dimension, while still making repeated gaps hurt.
function Get-DimensionScore {
  param([string]$Id, [string[]]$RuleIds)
  $points = Get-DimensionPoints -Id $Id
  $distinctFailingRules = @($results |
    Where-Object { $RuleIds -contains $_.rule_id -and $_.level -eq "FAIL" } |
    ForEach-Object { $_.rule_id } | Sort-Object -Unique).Count
  if ($distinctFailingRules -eq 0) { return $points }
  $penalty = [Math]::Ceiling($points * 0.5 * $distinctFailingRules)
  return [Math]::Max(0, $points - $penalty)
}

$dimensionScores = [ordered]@{
  "source_scope_integrity" = (Get-DimensionScore "source_scope_integrity" @("SOURCE-001", "SOURCE-002", "SOURCE-003", "EVIDENCE-001", "HANDOFF-002"))
  "requirement_design_traceability" = (Get-DimensionScore "requirement_design_traceability" @("REF-001", "RTM-001", "RTM-002", "HANDOFF-001"))
  "engineering_contract" = (Get-DimensionScore "engineering_contract" @("HANDOFF-005"))
  "acceptance_seed_testability" = (Get-DimensionScore "acceptance_seed_testability" @("HANDOFF-006", "HANDOFF-007"))
  "dependency_owner_capacity" = (Get-DimensionScore "dependency_owner_capacity" @("HANDOFF-003", "HANDOFF-004", "HANDOFF-009"))
  "security_privacy_environment" = (Get-DimensionScore "security_privacy_environment" @("HANDOFF-011", "HANDOFF-012"))
  "demo_operational_readiness" = (Get-DimensionScore "demo_operational_readiness" @("HANDOFF-008"))
}

# An open review finding is missing evidence just as surely as a missing table
# is. Without this, a project whose own review says the demo will not work still
# reports a perfect score, because no deterministic rule fired. Each open
# finding is charged to the dimension that owns its lens.
$lensMap = $scorePolicy.lens_dimension_map
$penaltyBySeverity = $scorePolicy.open_finding_penalty
foreach ($finding in $openFindings) {
  $lens = "$($finding.lens)"
  $lensProp = $lensMap.PSObject.Properties[$lens]
  if (-not $lensProp) { continue }
  $dimensionId = [string]$lensProp.Value
  if (-not $dimensionScores.Contains($dimensionId)) { continue }

  $severityProp = $penaltyBySeverity.PSObject.Properties["$($finding.severity)"]
  if (-not $severityProp) { continue }
  $penalty = [int]$severityProp.Value
  $dimensionScores[$dimensionId] = [Math]::Max(0, [int]$dimensionScores[$dimensionId] - $penalty)
}

# An open action costs points too. Blocking a stage without moving the score
# produced the contradiction "Ready to Demo: NO" printed directly above
# "Score: 100 / 100" -- a number that disagrees with the verdict above it is
# worse than no number, because the number is what gets pasted into a status
# report. Charged to the dimension its blocking point belongs to.
$blockingDimensionMap = $scorePolicy.blocking_point_dimension_map
$actionPenalty = [int]$scorePolicy.open_action_penalty.points
foreach ($action in @($allBlockers | Where-Object { $_.origin -eq "open_action" })) {
    $pointProp = $blockingDimensionMap.PSObject.Properties["$($action.blocking_point)"]
    if (-not $pointProp) { continue }
    $dimensionId = [string]$pointProp.Value
    # non_blocking maps to null: tracked, blocks nothing, costs nothing.
    if ([string]::IsNullOrWhiteSpace($dimensionId)) { continue }
    if (-not $dimensionScores.Contains($dimensionId)) { continue }
    $dimensionScores[$dimensionId] = [Math]::Max(0, [int]$dimensionScores[$dimensionId] - $actionPenalty)
}

$rawScore = 0
foreach ($value in $dimensionScores.Values) { $rawScore += [int]$value }

# ---------------------------------------------------------------- score caps
# Caps exist because a high score computed from thin evidence is worse than no
# score: it reads as reassurance. Each cap names the evidence that is missing.
$appliedCaps = @()
$score = $rawScore

if (-not $reviewUsable) {
  $reason = if (-not $reviewPresent) { "semantic review is missing" }
            elseif (-not $review) { "semantic review does not parse" }
            else { "semantic review is stale" }
  $appliedCaps += [pscustomobject]@{ id = "review_absent_or_stale"; max_score = 70; reason = $reason }
  $score = [Math]::Min($score, 70)
}

$hasOwnerOrSequenceGap = ((Get-RuleHitCount @("HANDOFF-003")) -gt 0) -or ((Get-RuleHitCount @("HANDOFF-004")) -gt 0)
if ($hasOwnerOrSequenceGap) {
  $appliedCaps += [pscustomobject]@{ id = "missing_owner_or_sequence"; max_score = 69; reason = "a work item has no named owner, or the build sequence is not executable as declared" }
  $score = [Math]::Min($score, 69)
}

$openCriticalBeforeBuild = @($openFindings | Where-Object {
  "$($_.severity)" -eq "critical" -and "$($_.blocking_point)" -eq "before_build"
})
if ($openCriticalBeforeBuild.Count -gt 0) {
  $ids = (@($openCriticalBeforeBuild | ForEach-Object { $_.finding_id }) -join ", ")
  $appliedCaps += [pscustomobject]@{ id = "open_before_build_critical"; max_score = 49; reason = "open critical finding(s) block before_build: $ids" }
  $score = [Math]::Min($score, 49)
}

$overallVerdict = "READY"
if ($deterministicFail) {
  $overallVerdict = "BLOCKED"
  $appliedCaps += [pscustomobject]@{ id = "deterministic_fail"; max_score = $null; reason = "$($failures.Count) deterministic FAIL diagnostic(s)" }
} elseif ($verdicts["Ready to Start Development"] -eq $false) {
  # An explicit false outranks an unknown: a recorded blocker is more
  # actionable news than an unrecorded review.
  $overallVerdict = "NOT READY TO BUILD"
} elseif (-not $reviewUsable) {
  $overallVerdict = "CONTRACT VALID, NOT REVIEWED"
} elseif ($verdicts["Ready to Demo"] -eq $false) {
  $overallVerdict = "READY TO BUILD, NOT READY TO DEMO"
}

# ---------------------------------------------------------------- output
if ($Format -eq "Json") {
  $dimensionOut = @()
  foreach ($dimension in @($scorePolicy.dimensions)) {
    $dimensionOut += [pscustomobject]@{
      id = [string]$dimension.id
      title = [string]$dimension.title
      points = [int]$dimension.points
      awarded = [int]$dimensionScores[[string]$dimension.id]
    }
  }
  # Deliberately not cast to [bool]: $null is a third state meaning "cannot be
  # determined", and casting would silently render it as false.
  $verdictOut = [ordered]@{}
  foreach ($key in $verdicts.Keys) { $verdictOut[$key] = $verdicts[$key] }
  $reasonOut = [ordered]@{}
  foreach ($key in $verdictReasons.Keys) { $reasonOut[$key] = [string]$verdictReasons[$key] }

  $blockersOut = @()
  foreach ($blocker in $allBlockers) {
    $blockersOut += [pscustomobject]@{
      finding_id = [string]$blocker.finding_id
      severity = [string]$blocker.severity
      blocking_point = [string]$blocker.blocking_point
      owner = [string]$blocker.owner
      artifact = [string]$blocker.artifact
      origin = [string]$blocker.origin
    }
  }

  [pscustomobject]@{
    schema_version = (Get-DiagnosticsSchemaVersion)
    project = $project
    mode = $Mode
    gate = "Handoff"
    gate_exit_code = $validatorExit
    verdict = $overallVerdict
    verdicts = [pscustomobject]$verdictOut
    verdict_reasons = [pscustomobject]$reasonOut
    verdict_states = "true = no recorded blocker; false = a recorded blocker; null = cannot be determined, see verdict_reasons"
    score = [pscustomobject]@{
      raw = $rawScore
      awarded = $score
      total = [int]$scorePolicy.total
      dimensions = $dimensionOut
      caps_applied = $appliedCaps
      disclaimer = [string]$scorePolicy.disclaimer
    }
    semantic_review = [pscustomobject]@{
      present = $reviewPresent
      usable = $reviewUsable
      stale = [bool]$reviewStale
      stale_reason = $(if ($sourceStale) { "source snapshot changed" } elseif ($inputStale) { "a reviewed artifact changed" } else { $null })
      reviewer_kind = if ($review) { [string]$review.reviewer_kind } else { $null }
      is_approval = $false
      open_blockers = $blockersOut
    }
    deterministic = [pscustomobject]@{
      fail = $failures.Count
      warn = $warnings.Count
    }
  } | ConvertTo-Json -Depth 8
  exit 0
}

Write-Host "Axiom-PMO Handoff Readiness: $project"
Write-Host "Mode: $Mode"
Write-Host ""
Write-Host "Verdict: $overallVerdict"
Write-Host ""
foreach ($key in $verdicts.Keys) {
  $value = $verdicts[$key]
  $mark = if ($null -eq $value) { "  ?" } elseif ($value) { "YES" } else { "NO " }
  Write-Host ("  {0}  {1,-28} {2}" -f $mark, $key, $verdictReasons[$key])
}
if (@($verdicts.Values | Where-Object { $null -eq $_ }).Count -gt 0) {
  Write-Host ""
  Write-Host "  ? means the evidence to answer does not exist yet -- not that the answer is no."
}

$blockedStages = @($verdicts.Keys | Where-Object { -not $verdicts[$_] -and $_ -ne "Contract Valid" })
if ($deterministicFail) {
  Write-Host ""
  Write-Host "Blocking before anything else (deterministic):"
  foreach ($failure in $failures) {
    $where = @()
    if ($failure.artifact) { $where += $failure.artifact }
    if ($failure.item_id) { $where += $failure.item_id }
    $location = if ($where.Count -gt 0) { " (" + ($where -join " / ") + ")" } else { "" }
    Write-Host "  - [$($failure.rule_id)]$location $($failure.message)"
  }
}

if ($allBlockers.Count -gt 0) {
  Write-Host ""
  Write-Host "Open blockers by blocking point:"
  foreach ($point in @($handoffPolicy.blocking_points)) {
    $atPoint = @($allBlockers | Where-Object { "$($_.blocking_point)" -eq $point })
    if ($atPoint.Count -eq 0) { continue }
    Write-Host "  $point"
    foreach ($blocker in $atPoint) {
      $source = if ($blocker.origin -eq "open_action") { "HANDOFF.md open action" } else { "review finding" }
      Write-Host "    - $($blocker.finding_id) [$($blocker.severity)] owner: $($blocker.owner)  ($source)"
    }
  }
}

Write-Host ""
Write-Host "Score: $score / $($scorePolicy.total)"
foreach ($dimension in @($scorePolicy.dimensions)) {
  $awarded = [int]$dimensionScores[[string]$dimension.id]
  Write-Host ("  {0,3} / {1,-3}  {2}" -f $awarded, [int]$dimension.points, [string]$dimension.title)
}
if ($appliedCaps.Count -gt 0) {
  Write-Host ""
  Write-Host "Caps applied (raw score was $rawScore):"
  foreach ($cap in $appliedCaps) {
    $limit = if ($null -eq $cap.max_score) { "verdict BLOCKED" } else { "max $($cap.max_score)" }
    Write-Host "  - $($cap.id): $limit -- $($cap.reason)"
  }
}

Write-Host ""
Write-Host $scorePolicy.disclaimer
if (-not $reviewUsable) {
  Write-Host "The semantic review is not usable, so nothing here reflects a reader's judgement of whether the plan makes sense."
}

exit 0
