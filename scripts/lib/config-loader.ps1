# Loads pmo-config/*.json runtime policy and exposes value/placeholder
# validators that are driven by that config (sentinel rules, source_ref
# patterns). Throws if a required config file is missing -- runtime config is
# the single source of truth, there is no silent fallback to hardcoded values.

function Import-PmoConfig {
  param([string]$RepoRoot)

  $policyPath = Join-Path $RepoRoot "pmo-config/policy.json"
  if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
    throw "Missing runtime policy config: $policyPath"
  }
  $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json

  $artifactPolicyPath = Join-Path $RepoRoot "pmo-config/artifact-policy.json"
  if (-not (Test-Path -LiteralPath $artifactPolicyPath -PathType Leaf)) {
    throw "Missing runtime artifact policy config: $artifactPolicyPath"
  }
  $artifactPolicy = Get-Content -LiteralPath $artifactPolicyPath -Raw | ConvertFrom-Json

  $referenceTypesPath = Join-Path $RepoRoot "pmo-config/reference-types.json"
  if (-not (Test-Path -LiteralPath $referenceTypesPath -PathType Leaf)) {
    throw "Missing runtime reference-types config: $referenceTypesPath"
  }
  $referenceTypesConfig = Get-Content -LiteralPath $referenceTypesPath -Raw | ConvertFrom-Json

  # The rule catalog is a runtime input, not just doctor documentation: it
  # supplies the `suggestion` and `documentation_url` carried on every
  # structured diagnostic. Loading it here keeps one parse per run and keeps
  # the "no silent fallback" rule -- a missing catalog is a hard error.
  $validationRulesPath = Join-Path $RepoRoot "pmo-config/validation-rules.json"
  if (-not (Test-Path -LiteralPath $validationRulesPath -PathType Leaf)) {
    throw "Missing runtime validation-rules config: $validationRulesPath"
  }
  $validationRules = Get-Content -LiteralPath $validationRulesPath -Raw | ConvertFrom-Json

  $handoffPolicyPath = Join-Path $RepoRoot "pmo-config/handoff-policy.json"
  if (-not (Test-Path -LiteralPath $handoffPolicyPath -PathType Leaf)) {
    throw "Missing runtime handoff policy config: $handoffPolicyPath"
  }
  $handoffPolicy = Get-Content -LiteralPath $handoffPolicyPath -Raw | ConvertFrom-Json

  $orchestrationPolicyPath = Join-Path $RepoRoot "pmo-config/orchestration-policy.json"
  if (-not (Test-Path -LiteralPath $orchestrationPolicyPath -PathType Leaf)) {
    throw "Missing runtime orchestration policy config: $orchestrationPolicyPath"
  }
  $orchestrationPolicy = Get-Content -LiteralPath $orchestrationPolicyPath -Raw | ConvertFrom-Json

  return [pscustomobject]@{
    Policy = $policy
    PolicyEnums = $policy.enums
    SentinelRules = $policy.sentinel_rules
    ArtifactPolicy = $artifactPolicy
    ReferenceTypesConfig = $referenceTypesConfig
    ValidationRules = $validationRules
    HandoffPolicy = $handoffPolicy
    OrchestrationPolicy = $orchestrationPolicy
  }
}

function Test-PlaceholderValue {
  param([string]$Value)

  $trimmed = $Value.Trim()
  if ($trimmed.Length -eq 0) { return $true }
  # not_required is a placeholder by default; it is only accepted where
  # policy.json sentinel_rules explicitly allows it (see Test-FieldValue).
  if ($trimmed -eq "not_required") { return $true }
  if ($trimmed -eq "-") { return $true }
  return ($trimmed -match "<[^>]+>|TODO|TBD|YYYY-MM-DD|ISO-8601|pending|n/a")
}

function Test-FieldValue {
  param(
    [string]$FieldName,
    [string]$Value,
    [string]$FieldMode
  )

  $trimmed = "$Value".Trim()
  if ($trimmed -eq "not_required") {
    $rule = $script:sentinelRules.not_required
    if ($rule -and (@($rule.allowed_fields) -contains $FieldName) -and (@($rule.allowed_modes) -contains $FieldMode)) {
      return $false
    }
    return $true
  }
  return (Test-PlaceholderValue $Value)
}

function Test-DateValue {
  param([string]$Value)

  $trimmed = $Value.Trim()
  $parsed = New-Object DateTime
  return [DateTime]::TryParseExact(
    $trimmed,
    "yyyy-MM-dd",
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::None,
    [ref]$parsed
  )
}

function Test-PlaceholderContent {
  param(
    [string]$Content,
    [string]$Extension
  )
  if ($Extension -eq ".html") {
    return ($Content -match "{{[^}]+}}|<PLACEHOLDER:[^>]+>|TODO|TBD")
  }
  return ($Content -match "<[^>\r\n]+>|TODO|TBD")
}

function Get-PolicySourceRefRegex {
  $patterns = @($script:policyEnums.source_ref_patterns)
  if ($patterns.Count -eq 0) {
    $patterns = @('MOM-\d{8}', 'REQ-\d{8}', 'REQ-V\d+', 'TR-\d{8}', 'DEC-\d{3}', 'ISSUE-\d+', 'PR-\d+', 'source_ref')
  }
  return ($patterns -join "|")
}

# Optional workflow declarations live here because they are config-backed
# project metadata, not a fifth domain validator. Keeping the reader beside
# Import-PmoConfig also preserves the four-module growth budget for the
# actual optional domains (change, externalization, design provider, research).
function Get-ProjectOrchestrationDeclarations {
  param([string]$ProjectRoot)
  $path = Join-Path $ProjectRoot "PROJECT.md"
  $text = if (Test-Path -LiteralPath $path -PathType Leaf) { Get-Content -LiteralPath $path -Raw } else { "" }

  $values = @{}
  foreach ($name in @("Research mode", "Research depth", "Research provider", "UI delivery")) {
    $match = [regex]::Match($text, ("(?m)^\s*>?\s*" + [regex]::Escape($name) + ":\s*(.+?)\s*$"))
    $values[$name] = if ($match.Success) { $match.Groups[1].Value.Trim() } else { $null }
  }

  return [pscustomobject]@{
    ResearchMode = $values["Research mode"]
    ResearchDepth = $values["Research depth"]
    ResearchProvider = $values["Research provider"]
    UiDelivery = $values["UI delivery"]
  }
}

function Test-OrchestrationDeclarations {
  param([string]$Project, [string]$Gate, $OrchestrationPolicy)
  $d = Get-ProjectOrchestrationDeclarations $Project

  if ($d.ResearchMode) {
    $valid = @($OrchestrationPolicy.research.modes)
    if ($valid -notcontains $d.ResearchMode) {
      Add-Result FAIL "PROJECT.md Research mode is not recognized" "RESEARCH-001" -Artifact "PROJECT.md" -Field "Research mode"
    } else {
      $badDepth = (-not $d.ResearchDepth) -or (@($OrchestrationPolicy.research.depths) -notcontains $d.ResearchDepth)
      $badProvider = (-not $d.ResearchProvider) -or (@($OrchestrationPolicy.research.providers) -notcontains $d.ResearchProvider)
      if ($badDepth -or $badProvider) {
        Add-Result FAIL "PROJECT.md research declarations are incomplete or invalid" "RESEARCH-001" -Artifact "PROJECT.md"
      } elseif ($d.ResearchMode -eq "off" -and $d.ResearchProvider -ne "none") {
        Add-Result FAIL "Research mode off requires Research provider none" "RESEARCH-001" -Artifact "PROJECT.md" -Field "Research provider"
      } elseif ($d.ResearchMode -ne "off" -and $d.ResearchProvider -eq "none") {
        Add-Result FAIL "Enabled research requires a provider declaration" "RESEARCH-001" -Artifact "PROJECT.md" -Field "Research provider"
      }
    }
  }

  if ($d.UiDelivery -and (@($OrchestrationPolicy.ui_delivery.values) -notcontains $d.UiDelivery)) {
    Add-Result FAIL "PROJECT.md UI delivery is not recognized" "DPROV-001" -Artifact "PROJECT.md" -Field "UI delivery"
  }

  return $d
}
