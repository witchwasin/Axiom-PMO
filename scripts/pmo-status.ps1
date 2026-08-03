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

if ($Format -eq "Json") {
  [pscustomobject]@{
    schema_version = "1.0"
    project = $project
    execution_path = $displayPath
    execution_path_declared = [bool]$declaredPath
    governance_mode = if ($resultJson) { $resultJson.effective_mode } else { $null }
    current_gate = $currentGate
    checked_gate = $checkGate
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
  Write-Host "Current Gate:    $currentGate"
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
