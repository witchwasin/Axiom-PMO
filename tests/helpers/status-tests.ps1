param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")
$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

# CR-019: `axiom status` must report the DECLARED lifecycle and freshness of
# the optional tracks -- not mere file existence -- and expose an explicit
# next Human or automated action. These tests mutate a temporary copy only.

function Invoke-StatusJson {
  param([string]$Repo, [string]$Project)
  $output = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Repo "scripts/pmo-status.ps1") -ProjectPath $Project -Format Json
  $code = $LASTEXITCODE
  $json = $null
  try { $json = ($output | Out-String) | ConvertFrom-Json } catch { throw "No JSON (exit $code): $($output | Out-String)" }
  return $json
}

function Assert-StatusField {
  param($Json, [string]$Name, [string]$Field, [string]$Expected)
  $actual = [string]$Json.$Field
  if ($actual -ne $Expected) {
    throw ("{0}: {1} = '{2}', expected '{3}'" -f $Name, $Field, $actual, $Expected)
  }
  Write-Host ("[PASS] {0}: {1} = {2}" -f $Name, $Field, $Expected)
}

$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pmo status " + [guid]::NewGuid().ToString("N"))
$tempRepo = Join-Path $workRoot "repo"
try {
  New-Item -ItemType Directory -Force -Path $tempRepo | Out-Null
  foreach ($item in Get-ChildItem -LiteralPath $RepoPath -Force) {
    if ($item.Name -eq ".git") { continue }
    Copy-Item -LiteralPath $item.FullName -Destination $tempRepo -Recurse -Force
  }
  $active = Join-Path $tempRepo "examples/OPTIONAL-TRACKS"

  # 1. Baseline: accepted provider review, current digests, completed research.
  $s = Invoke-StatusJson $tempRepo $active
  Assert-StatusField $s "baseline" "research_state" "complete"
  Assert-StatusField $s "baseline" "ui_delivery_state" "accepted"
  Assert-StatusField $s "baseline" "provider_review_state" "current"
  Assert-StatusField $s "baseline" "open_governed_changes" "0"
  if ([string]$s.next_action -notmatch "Handoff") { throw "baseline next_action should name the Handoff gate: $($s.next_action)" }
  Write-Host "[PASS] baseline next_action names the next gate"

  # 2. Stale provider review: preflight no longer speaks for the manifest.
  $reviewPath = Join-Path $active "DESIGN/CLAUDE-DESIGN/REVIEW.json"
  $reviewDoc = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json
  $reviewDoc.preflight.manifest_digest = "0" * 64
  $reviewDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reviewPath -Encoding utf8
  $s = Invoke-StatusJson $tempRepo $active
  Assert-StatusField $s "stale review" "provider_review_state" "stale"
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/REVIEW.json") -Destination $reviewPath -Force

  # 3. Missing provider review: manifest prepared, nothing returned yet.
  Remove-Item -LiteralPath $reviewPath -Force
  $s = Invoke-StatusJson $tempRepo $active
  Assert-StatusField $s "missing review" "provider_review_state" "missing"
  Assert-StatusField $s "missing review" "ui_delivery_state" "preparing"
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/REVIEW.json") -Destination $reviewPath -Force

  # 4. Stopped research: the state and next action reflect the stop, never a
  # silently completed pass.
  $provPath = Join-Path $active "RESEARCH/PROVENANCE.json"
  $provDoc = Get-Content -LiteralPath $provPath -Raw | ConvertFrom-Json
  $provDoc.research_status = "stopped"
  $provDoc | Add-Member -NotePropertyName stop_reason -NotePropertyValue "Research provider unavailable and no fallback configured" -Force
  $provDoc | Add-Member -NotePropertyName next_action -NotePropertyValue "Human decides whether to defer research or proceed without it" -Force
  $provDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $provPath -Encoding utf8
  $s = Invoke-StatusJson $tempRepo $active
  Assert-StatusField $s "stopped research" "research_state" "stopped"
  if ([string]$s.next_action -notmatch "stopped") { throw "stopped research next_action should mention the stop: $($s.next_action)" }
  Write-Host "[PASS] stopped research next_action is actionable"
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/RESEARCH/PROVENANCE.json") -Destination $provPath -Force

  # 5. Approved-but-unimplemented change: must be counted, not disappear.
  $crPath = Join-Path $active "CHANGE-REQUESTS.json"
  $crDoc = Get-Content -LiteralPath $crPath -Raw | ConvertFrom-Json
  $crDoc.changes[0].status = "approved"
  $crDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $crPath -Encoding utf8
  $s = Invoke-StatusJson $tempRepo $active
  Assert-StatusField $s "approved change" "open_governed_changes" "1"
  if ([string]$s.next_action -notmatch "change") { throw "next_action should mention the open change: $($s.next_action)" }
  Write-Host "[PASS] approved-but-unimplemented change counted and actionable"
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/CHANGE-REQUESTS.json") -Destination $crPath -Force

  # 6. Text format still reports the same lifecycle facts.
  $text = (& $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/pmo-status.ps1") -ProjectPath $active 2>&1) | Out-String
  if ($text -notmatch "Research:        guided \(standard, feyman\) - complete") { throw "text status did not report completed research: $text" }
  if ($text -notmatch "UI Delivery:     claude_design - accepted") { throw "text status did not report accepted review: $text" }
  if ($text -notmatch "Next action:") { throw "text status has no explicit next action" }
  Write-Host "[PASS] text status reports lifecycle and next action"

  Write-Host "[PASS] status lifecycle tests completed"
} finally {
  if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }
}
