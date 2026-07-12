# Shared result accumulator (Add-Result) plus final exit-code computation and
# Text/JSON output formatting. Every other module calls Add-Result to append
# to the single ordered result list that becomes the JSON `results` array /
# text report -- order of calls is the order of output, so callers must not
# be reordered relative to the original monolith without re-verifying the
# golden master.

function Add-Result {
  param(
    [ValidateSet("PASS", "WARN", "FAIL", "INFO")]
    [string]$Level,
    [string]$Message,
    [string]$RuleId = "GENERAL-001",
    [bool]$Blocking = $true
  )

  $script:messages.Add([pscustomobject]@{
    level = $Level
    rule_id = $RuleId
    message = $Message
    blocking = $Blocking
  }) | Out-Null
  switch ($Level) {
    "PASS" { $script:pass++ }
    "WARN" { $script:warn++; if ($Blocking) { $script:warnBlocking++ } }
    "FAIL" { $script:fail++ }
  }
}

function Get-ExitCode {
  param(
    [int]$Fail,
    [int]$WarnBlocking,
    [switch]$FailOnWarning
  )

  if ($Fail -gt 0) { return 1 }
  if ($FailOnWarning -and $WarnBlocking -gt 0) { return 2 }
  return 0
}

function Write-ValidationOutput {
  param(
    [string]$Format,
    [string]$Project,
    [string]$RequestedMode,
    [string]$EffectiveMode,
    [string]$Gate,
    [int]$Pass,
    [int]$Warn,
    [int]$WarnBlocking,
    [int]$Fail,
    $Messages,
    [int]$ExitCode
  )

  if ($Format -eq "Json") {
    [pscustomobject]@{
      project = $Project
      requested_mode = $RequestedMode
      effective_mode = $EffectiveMode
      gate = $Gate
      summary = [pscustomobject]@{
        pass = $Pass
        warn = $Warn
        warn_blocking = $WarnBlocking
        fail = $Fail
        exit_code = $ExitCode
      }
      results = $Messages
    } | ConvertTo-Json -Depth 6
  } else {
    Write-Host "PMO Project Validation: $Project"
    Write-Host "Requested Mode: $RequestedMode"
    Write-Host "Detected Project Mode: $EffectiveMode"
    Write-Host "Effective Mode: $EffectiveMode"
    Write-Host "Gate=$Gate"
    Write-Host ""
    $Messages | ForEach-Object {
      $tag = if ($_.level -eq "WARN" -and -not $_.blocking) { " (non-blocking)" } else { "" }
      Write-Host "[$($_.level)] $($_.rule_id) $($_.message)$tag"
    }
    Write-Host ""
    Write-Host "Summary: PASS=$Pass WARN=$Warn ($WarnBlocking blocking) FAIL=$Fail"
  }
}
