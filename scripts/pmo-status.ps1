param(
  [Parameter(Mandatory = $true)]
  [Alias("Project")]
  [string]$ProjectPath,

  [ValidateSet("Text", "Json")]
  [string]$Format = "Text"
)

# `axiom status`: a read-only report of where a project stands, so a user
# does not have to re-derive it from README/ROADMAP each time. Everything
# here is derived, never invented:
#   - Execution Path / Governance Mode come straight from PROJECT.md and the
#     validator's own effective-mode resolution (scripts/lib/mode-resolver.ps1).
#   - "Next required" is the first blocking diagnostic the validator itself
#     emits at the next gate -- never a second, independently composed
#     opinion that could disagree with it. If this script and
#     validate-project.ps1 ever say different things, that is a defect in
#     this script, not a second source of truth to reconcile.
# This script never fails a build and never blocks anything; it is reporting
# only, so its own exit code is always 0 (project-not-found aside).

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/pwsh-host.ps1")
. (Join-Path $PSScriptRoot "lib/execution-path-validator.ps1")
. (Join-Path $PSScriptRoot "lib/config-loader.ps1")
. (Join-Path $PSScriptRoot "lib/ordinal-sort.ps1")
. (Join-Path $PSScriptRoot "lib/artifact-hash.ps1")
. (Join-Path $PSScriptRoot "lib/handoff-validator.ps1")
. (Join-Path $PSScriptRoot "lib/design-provider-validator.ps1")

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
  Write-Host "Project directory not found: $ProjectPath"
  exit 1
}
$project = (Resolve-Path -LiteralPath $ProjectPath).Path

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

# Current gate is read from PROJECT.md's own `Status:` line -- the same field
# a human already updates by hand, never inferred by a second heuristic.
function Get-ProjectStatusLine {
  param([string]$ProjectRoot)
  $path = Join-Path $ProjectRoot "PROJECT.md"
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $text = Get-Content -LiteralPath $path -Raw
  if ($text -match '(?m)^\s*>?\s*Status:\s*(.+?)\s*$') { return $Matches[1] }
  return $null
}

$statusToGate = @{
  "draft" = @{ Current = "Draft"; Next = "Scope" }
  "scope-approved" = @{ Current = "Scope"; Next = "Design" }
  "design-ready" = @{ Current = "Design"; Next = "Handoff" }
  "release-approved" = @{ Current = "Release"; Next = $null }
}
$rawStatus = Get-ProjectStatusLine $project
$gateInfo = if ($rawStatus -and $statusToGate.ContainsKey($rawStatus)) { $statusToGate[$rawStatus] } else { $statusToGate["draft"] }
$currentGate = $gateInfo.Current
$checkGate = if ($gateInfo.Next) { $gateInfo.Next } else { $gateInfo.Current }

$declaredPath = Get-ProjectExecutionPath $project
$displayPath = if ($declaredPath) { $declaredPath } else { "development_handoff" }
$orchestration = Get-ProjectOrchestrationDeclarations $project
$researchMode = if ($orchestration.ResearchMode) { $orchestration.ResearchMode } else { "off" }
$researchDepth = if ($orchestration.ResearchDepth) { $orchestration.ResearchDepth } else { "standard" }
$researchProvider = if ($orchestration.ResearchProvider) { $orchestration.ResearchProvider } else { "none" }
$uiDelivery = if ($orchestration.UiDelivery) { $orchestration.UiDelivery } else { "legacy" }

# M7/CR-019: optional-track state is derived from the DECLARED lifecycle and
# recorded evidence -- never invented, and never just file existence.
$manifestPath = Join-Path $project "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json"
$reviewPath = Join-Path $project "DESIGN/CLAUDE-DESIGN/REVIEW.json"
$crPath = Join-Path $project "CHANGE-REQUESTS.json"

# Research lifecycle: off | incomplete | in_progress | complete | stopped.
$researchState = "off"
$researchStopped = $false
if ($researchMode -ne "off") {
  $provPath = Join-Path $project "RESEARCH/PROVENANCE.json"
  $reportPath = Join-Path $project "RESEARCH/RESEARCH.md"
  if (-not (Test-Path -LiteralPath $provPath -PathType Leaf) -or -not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    $researchState = "incomplete"
  } else {
    try {
      $prov = Get-Content -LiteralPath $provPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $rs = ([string]$prov.research_status).Trim()
      if ($rs -eq "stopped") { $researchState = "stopped"; $researchStopped = $true }
      elseif ($rs -eq "complete") { $researchState = "complete" }
      elseif ($rs -eq "in_progress") { $researchState = "in_progress" }
      else { $researchState = "incomplete" }
    } catch { $researchState = "incomplete" }
  }
}

# UI delivery lifecycle: not_applicable | not_started | preparing |
# awaiting_review | accepted | revision_required | rejected | invalid_review.
# Provider review freshness: missing | current | stale | failed.
$uiDeliveryState = "not_applicable"
$providerReviewState = "missing"
if ($uiDelivery -eq "claude_design") {
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    $uiDeliveryState = "not_started"
  } else {
    $uiDeliveryState = "preparing"
    if (Test-Path -LiteralPath $reviewPath -PathType Leaf) {
      try {
        $review = Get-Content -LiteralPath $reviewPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $preflightPassed = $review.preflight -and [string]$review.preflight.status -eq "passed"
        # Freshness: does the recorded preflight speak for the CURRENT manifest
        # and output set? Recompute with the shared canonical hashing helper.
        $manifestCurrent = $false
        $outputsCurrent = $false
        try {
          $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
          $manifestDigest = Get-DesignInputCombinedDigest -Inputs @($manifest.inputs)
          $manifestCurrent = ([string]$review.preflight.manifest_digest -eq $manifestDigest)
          $outputRoot = Join-Path $project "DESIGN/CLAUDE-DESIGN/OUTPUT"
          $outputsCurrent = ([string]$review.preflight.outputs_digest -eq (Get-DesignOutputSetDigest -OutputRoot $outputRoot))
        } catch { }
        if (-not $preflightPassed) { $providerReviewState = "failed" }
        elseif ($manifestCurrent -and $outputsCurrent) { $providerReviewState = "current" }
        else { $providerReviewState = "stale" }
        if ($review.acceptance -and [string]$review.acceptance.decision) {
          $uiDeliveryState = ([string]$review.acceptance.decision).Trim()
        } else {
          $uiDeliveryState = "awaiting_review"
        }
      } catch { $uiDeliveryState = "invalid_review" }
    }
  }
}

# Open governed changes: every NON-TERMINAL change (proposed or approved). An
# approved-but-unimplemented change must not disappear from the count.
$openGovernedChanges = 0
if (Test-Path -LiteralPath $crPath -PathType Leaf) {
  try {
    $crDoc = Get-Content -LiteralPath $crPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $openGovernedChanges = @($crDoc.changes | Where-Object { @("proposed", "approved") -contains ([string]$_.status) }).Count
  } catch {
    # Unparseable registry: report -1 so the reader knows the count is unknown.
    $openGovernedChanges = -1
  }
}

# Same Continue/try/finally guard scripts/new-project.ps1 already uses around
# its own Draft-validation call: this script sets Stop, and Windows
# PowerShell 5.1 turns a child's stderr into a terminating error under Stop
# even for informational output.
$previousEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $rawOutput = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts/validate-project.ps1") -ProjectPath $project -Gate $checkGate -Format Json 2>$null
} finally {
  $ErrorActionPreference = $previousEap
}

$resultJson = $null
try { $resultJson = ($rawOutput -join "`n") | ConvertFrom-Json } catch { $resultJson = $null }

$nextFinding = $null
if ($resultJson -and $resultJson.results) {
  $nextFinding = $resultJson.results | Where-Object { $_.level -eq "FAIL" -and $_.blocking } | Select-Object -First 1
  if (-not $nextFinding) {
    $nextFinding = $resultJson.results | Where-Object { $_.level -eq "WARN" -and $_.blocking } | Select-Object -First 1
  }
}

# CR-019: an explicit, human-readable next action -- either a Human gate or an
# automated step -- derived from the declared lifecycle, not a second opinion.
$nextAction = $null
if ($researchMode -ne "off") {
  if ($researchState -eq "incomplete" -or $researchState -eq "in_progress") {
    $nextAction = "Human: complete or stop guided research before Scope approval"
  } elseif ($researchState -eq "stopped") {
    $nextAction = "Human: decide the stopped research outcome or turn research off"
  }
}
if (-not $nextAction -and $uiDelivery -eq "claude_design") {
  if ($uiDeliveryState -eq "preparing") {
    $nextAction = "Human: run Claude Design and return candidate output to DESIGN/CLAUDE-DESIGN/OUTPUT"
  } elseif ($uiDeliveryState -eq "awaiting_review") {
    $nextAction = "Human: record provider preflight and acceptance in DESIGN/CLAUDE-DESIGN/REVIEW.json"
  } elseif ($uiDeliveryState -eq "revision_required") {
    $nextAction = "Human: return revised output to the provider and re-run the preflight"
  } elseif ($uiDeliveryState -eq "rejected") {
    $nextAction = "Human: decide how to proceed after the rejected provider review"
  } elseif ($uiDeliveryState -eq "accepted" -and $providerReviewState -ne "current") {
    $nextAction = "Automated: re-run the deterministic preflight; the recorded review is stale"
  }
}
if (-not $nextAction -and $openGovernedChanges -gt 0) {
  $nextAction = "Human: resolve $openGovernedChanges open governed change(s) before the next gate"
}
if (-not $nextAction -and $nextFinding) {
  $nextAction = "Automated: resolve blocking diagnostic $($nextFinding.rule_id) before $checkGate"
}
if (-not $nextAction -and $checkGate) {
  $nextAction = "Automated: run validate-project.ps1 at the $checkGate gate"
}

if ($Format -eq "Json") {
  [pscustomobject]@{
    schema_version = "1.1"
    project = $project
    execution_path = $displayPath
    execution_path_declared = [bool]$declaredPath
    governance_mode = if ($resultJson) { $resultJson.effective_mode } else { $null }
    research_mode = $researchMode
    research_depth = $researchDepth
    research_provider = $researchProvider
    research_state = $researchState
    ui_delivery = $uiDelivery
    ui_delivery_state = $uiDeliveryState
    provider_review_state = $providerReviewState
    open_governed_changes = $openGovernedChanges
    current_gate = $currentGate
    checked_gate = $checkGate
    next_action = $nextAction
    next_required = $nextFinding
  } | ConvertTo-Json -Depth 6
} else {
  Write-Host "Axiom-PMO Project Status: $project"
  Write-Host ""
  $pathSuffix = if (-not $declaredPath) { " (default, not declared)" } else { "" }
  Write-Host "Execution Path:  $displayPath$pathSuffix"
  if ($resultJson) {
    Write-Host "Governance Mode: $($resultJson.effective_mode)"
  }
  Write-Host "Research:        $researchMode ($researchDepth, $researchProvider) - $researchState"
  Write-Host "UI Delivery:     $uiDelivery - $uiDeliveryState (provider review: $providerReviewState)"
  Write-Host "Open Changes:    $openGovernedChanges"
  Write-Host "Current Gate:    $currentGate"
  if ($nextAction) {
    Write-Host "Next action:     $nextAction"
  }
  Write-Host ""
  if ($nextFinding) {
    Write-Host "Next required:   $($nextFinding.message)  [$($nextFinding.rule_id)]"
    if ($nextFinding.suggestion) {
      Write-Host "                 fix: $($nextFinding.suggestion)"
    }
  } else {
    Write-Host "Next required:   No blocking findings at the $checkGate gate."
  }
}

exit 0
