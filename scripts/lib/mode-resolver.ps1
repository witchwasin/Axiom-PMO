# Effective mode resolution: CLI -Mode may upgrade a project's enforcement
# level but must never silently downgrade it. Closes the bypass where
# `-Mode Lite` on a Strict project skipped every Strict guardrail (RTM, RAID,
# decision-log, STRICT-002).

function Get-ProjectDefaultMode {
  param([string]$ProjectRoot)
  $path = Join-Path $ProjectRoot "PROJECT.md"
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $text = Get-Content -LiteralPath $path -Raw
  if ($text -match '(?m)^\s*>?\s*Default mode:\s*(.+?)\s*$') {
    return $Matches[1]
  }
  return $null
}

function Get-DeliveryModeSignals {
  param([string]$ProjectRoot, $Rank)
  $result = [pscustomobject]@{ HighestMode = $null; HasStrictTrigger = $false; StrictTriggerItem = $null }
  $path = Join-Path $ProjectRoot "DELIVERY.md"
  if (-not (Test-Path -LiteralPath $path)) { return $result }
  $text = Get-Content -LiteralPath $path -Raw
  $rows = Get-TableRowsAfterHeading $text '^##\s+Work Items'
  $highest = 0
  foreach ($row in $rows) {
    if ($Rank.ContainsKey($row.Mode) -and $Rank[$row.Mode] -gt $highest) { $highest = $Rank[$row.Mode] }
    if ($row.'Strict Trigger' -and $row.'Strict Trigger' -ne "none" -and -not $result.HasStrictTrigger) {
      $result.HasStrictTrigger = $true
      $result.StrictTriggerItem = $row.ID
    }
  }
  if ($highest -gt 0) {
    $result.HighestMode = @($Rank.Keys | Where-Object { $Rank[$_] -eq $highest })[0]
  }
  return $result
}

function Resolve-EffectiveMode {
  param(
    [string]$Project,
    [string]$RequestedMode,
    [string]$Gate
  )

  $modeRank = @{ "Lite" = 1; "Standard" = 2; "Strict" = 3 }
  $projectDefaultModeRaw = Get-ProjectDefaultMode $Project
  if ($projectDefaultModeRaw -and -not $modeRank.ContainsKey($projectDefaultModeRaw)) {
    Add-Result WARN "PROJECT.md Default mode '$projectDefaultModeRaw' is not a recognized mode (Lite/Standard/Strict)" "MODE-002"
  }
  $deliverySignals = Get-DeliveryModeSignals $Project $modeRank
  $effectiveMode = $RequestedMode
  $effectiveReasons = @()
  if ($projectDefaultModeRaw -and $modeRank.ContainsKey($projectDefaultModeRaw) -and $modeRank[$projectDefaultModeRaw] -gt $modeRank[$effectiveMode]) {
    $effectiveMode = $projectDefaultModeRaw
    $effectiveReasons += "PROJECT.md Default mode is $projectDefaultModeRaw"
  }
  if ($deliverySignals.HighestMode -and $modeRank[$deliverySignals.HighestMode] -gt $modeRank[$effectiveMode]) {
    $effectiveMode = $deliverySignals.HighestMode
    $effectiveReasons += "highest work item mode is $($deliverySignals.HighestMode)"
  }
  if ($deliverySignals.HasStrictTrigger -and $modeRank["Strict"] -gt $modeRank[$effectiveMode]) {
    $effectiveMode = "Strict"
    $effectiveReasons += "work item $($deliverySignals.StrictTriggerItem) has a strict trigger"
  }

  if ($modeRank[$effectiveMode] -gt $modeRank[$RequestedMode]) {
    $modeLevel = if ($Gate -eq "Release") { "FAIL" } else { "WARN" }
    Add-Result $modeLevel "Requested mode $RequestedMode cannot be used; effective mode is $effectiveMode ($($effectiveReasons -join '; '))" "MODE-001"
    if ($deliverySignals.HasStrictTrigger -and $effectiveMode -eq "Strict") {
      Add-Result INFO "Strict escalation triggered by work item $($deliverySignals.StrictTriggerItem)" "MODE-003"
    }
  } else {
    Add-Result PASS "Effective mode ($effectiveMode) matches requested mode ($RequestedMode)" "MODE-001"
  }

  return [pscustomobject]@{ EffectiveMode = $effectiveMode }
}
