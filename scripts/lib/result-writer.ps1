# Shared result accumulator (Add-Result) plus final exit-code computation and
# Text/JSON output formatting. Every other module calls Add-Result to append
# to the single ordered result list that becomes the JSON `results` array /
# text report -- order of calls is the order of output, so callers must not
# be reordered relative to the original monolith without re-verifying the
# golden master.
#
# Diagnostic contract (v1.1, see pmo-config/diagnostics-schema.json and
# docs/reference/diagnostics-contract.md):
#
#   schema_version     always emitted, identifies this row's shape
#   level              PASS | WARN | FAIL | INFO      (v1.0, unchanged)
#   rule_id            catalog rule id                (v1.0, unchanged)
#   message            human-readable summary         (v1.0, unchanged)
#   blocking           bool                           (v1.0, unchanged)
#   artifact           project-relative file the finding is about, or null
#   item_id            work item / requirement / row id, or null
#   field              column or section within the artifact, or null
#   suggestion         how to fix it, or null
#   documentation_url  link to the rule's doc page, or null
#
# The four v1.0 fields keep their names, meanings, and relative order, so a
# v1.0 consumer reading this output sees exactly what it saw before. Everything
# else is additive. Fields that do not apply are emitted as null rather than
# omitted: a consumer can then index every row the same way instead of
# probing for key presence.
#
# suggestion/documentation_url are NOT written at the call site by default --
# they are looked up from pmo-config/validation-rules.json by rule id, so the
# remediation text for a rule lives in one place. A call site may override
# either when it can say something more specific than the catalog entry.
#
# Sensitive-data policy: `message`, `suggestion`, and `field` must never echo
# requirement prose, approval evidence text, customer identifiers, or any
# source-file content. Refer to a location (artifact + item_id + field) and let
# the reader open the artifact. Ids and column names are safe; row values are
# not.

$script:DiagnosticsSchemaVersion = "1.1"

function Get-DiagnosticsSchemaVersion {
  return $script:DiagnosticsSchemaVersion
}

# Resolve a rule's catalog metadata. Returns $null when the catalog is absent
# (pmo-doctor DOCTOR-007 is what guarantees it is complete; the validator must
# not invent remediation text for an unknown rule).
function Get-RuleCatalogEntry {
  param([string]$RuleId)

  if (-not $script:ruleCatalog) { return $null }
  if (-not $script:ruleCatalog.rules) { return $null }
  $prop = $script:ruleCatalog.rules.PSObject.Properties[$RuleId]
  if (-not $prop) { return $null }
  return $prop.Value
}

function Resolve-RuleDocumentationUrl {
  param([string]$RuleId)

  $entry = Get-RuleCatalogEntry -RuleId $RuleId
  if (-not $entry) { return $null }
  if (-not $entry.documentation) { return $null }

  $base = $null
  if ($script:ruleCatalog.documentation_base_url) {
    $base = [string]$script:ruleCatalog.documentation_base_url
  }
  if ([string]::IsNullOrWhiteSpace($base)) { return [string]$entry.documentation }
  return ($base.TrimEnd('/') + '/' + ([string]$entry.documentation).TrimStart('/'))
}

function Resolve-RuleSuggestion {
  param([string]$RuleId)

  $entry = Get-RuleCatalogEntry -RuleId $RuleId
  if (-not $entry) { return $null }
  if ([string]::IsNullOrWhiteSpace([string]$entry.suggestion)) { return $null }
  return [string]$entry.suggestion
}

function Add-Result {
  param(
    [ValidateSet("PASS", "WARN", "FAIL", "INFO")]
    [string]$Level,
    [string]$Message,
    [string]$RuleId = "GENERAL-001",
    [bool]$Blocking = $true,

    # Structured context. All optional and all positioned after $Blocking so
    # that every existing positional call site -- Add-Result FAIL "msg" "RULE"
    # and Add-Result $level "msg" "RULE" $false -- keeps working untouched.
    [string]$Artifact = $null,
    [string]$ItemId = $null,
    [string]$Field = $null,
    [string]$Suggestion = $null,
    [string]$DocumentationUrl = $null
  )

  # PASS/INFO rows describe something that is already correct; attaching
  # "how to fix it" text to them would be noise, and would make a consumer
  # that filters on `suggestion -ne null` pick up healthy rows.
  $resolvedSuggestion = $Suggestion
  if ([string]::IsNullOrWhiteSpace($resolvedSuggestion) -and ($Level -eq "WARN" -or $Level -eq "FAIL")) {
    $resolvedSuggestion = Resolve-RuleSuggestion -RuleId $RuleId
  }

  $resolvedDocUrl = $DocumentationUrl
  if ([string]::IsNullOrWhiteSpace($resolvedDocUrl) -and ($Level -eq "WARN" -or $Level -eq "FAIL")) {
    $resolvedDocUrl = Resolve-RuleDocumentationUrl -RuleId $RuleId
  }

  $script:messages.Add([pscustomobject]@{
    schema_version = $script:DiagnosticsSchemaVersion
    level = $Level
    rule_id = $RuleId
    message = $Message
    blocking = $Blocking
    artifact = (ConvertTo-NullIfBlank $Artifact)
    item_id = (ConvertTo-NullIfBlank $ItemId)
    field = (ConvertTo-NullIfBlank $Field)
    suggestion = (ConvertTo-NullIfBlank $resolvedSuggestion)
    documentation_url = (ConvertTo-NullIfBlank $resolvedDocUrl)
  }) | Out-Null
  switch ($Level) {
    "PASS" { $script:pass++ }
    "WARN" { $script:warn++; if ($Blocking) { $script:warnBlocking++ } }
    "FAIL" { $script:fail++ }
  }
}

# An empty string and "field does not apply" are different states in the
# contract; collapse the former into the latter so the JSON never carries "".
function ConvertTo-NullIfBlank {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
  return $Value
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
    [int]$ExitCode,
    # Optional, additive envelope field. Deliberately NOT following the
    # per-diagnostic-row "always present, sometimes null" policy: that policy
    # is frozen for the results[] row shape (see the schema comment above).
    # scope_diff is a whole different thing -- an opt-in check that most
    # invocations of this script never ask for -- so when it was not
    # requested the key is omitted entirely rather than emitted as null.
    # Omitting it (instead of always adding it, even as null) is what keeps
    # every existing golden-master JSON fixture byte-for-byte unchanged for
    # every call site that does not pass -ScopeDiffBase/-ScopeDiffHead.
    $ScopeDiff = $null
  )

  if ($Format -eq "Json") {
    $envelope = [ordered]@{
      schema_version = $script:DiagnosticsSchemaVersion
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
    }
    if ($null -ne $ScopeDiff) {
      $envelope["scope_diff"] = $ScopeDiff
    }
    [pscustomobject]$envelope | ConvertTo-Json -Depth 6
  } else {
    Write-Host "Axiom-PMO Project Validation: $Project"
    Write-Host "Requested Mode: $RequestedMode"
    Write-Host "Detected Project Mode: $EffectiveMode"
    Write-Host "Effective Mode: $EffectiveMode"
    Write-Host "Gate=$Gate"
    Write-Host ""
    $Messages | ForEach-Object {
      $tag = if ($_.level -eq "WARN" -and -not $_.blocking) { " (non-blocking)" } else { "" }
      Write-Host "[$($_.level)] $($_.rule_id) $($_.message)$tag"
      # Text output stays a one-line-per-result report for PASS/INFO. Only
      # actionable rows get the extra indented context, so a green run reads
      # exactly as it did in v1.0.
      if ($_.level -eq "WARN" -or $_.level -eq "FAIL") {
        $location = @()
        if ($_.artifact) { $location += $_.artifact }
        if ($_.item_id) { $location += $_.item_id }
        if ($_.field) { $location += "field: $($_.field)" }
        if ($location.Count -gt 0) {
          Write-Host "        where: $($location -join ' / ')"
        }
        if ($_.suggestion) {
          Write-Host "        fix:   $($_.suggestion)"
        }
        if ($_.documentation_url) {
          Write-Host "        docs:  $($_.documentation_url)"
        }
      }
    }
    Write-Host ""
    Write-Host "Summary: PASS=$Pass WARN=$Warn ($WarnBlocking blocking) FAIL=$Fail"
    if ($null -ne $ScopeDiff) {
      Write-Host ""
      Write-Host "Scope-diff: $($ScopeDiff.base_sha) -> $($ScopeDiff.head_sha), verdict=$($ScopeDiff.verdict)"
      Write-Host "  approved include: $($ScopeDiff.approved_include -join ', ')"
      if ($ScopeDiff.approved_exclude.Count -gt 0) {
        Write-Host "  approved exclude: $($ScopeDiff.approved_exclude -join ', ')"
      }
      Write-Host "  in scope: $($ScopeDiff.changed_in_scope.Count)  out of scope: $($ScopeDiff.changed_out_of_scope.Count)  excluded: $($ScopeDiff.changed_excluded.Count)  exempt: $($ScopeDiff.exempt.Count)"
    }
  }
}
