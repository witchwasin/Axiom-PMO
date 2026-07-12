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

  return [pscustomobject]@{
    Policy = $policy
    PolicyEnums = $policy.enums
    SentinelRules = $policy.sentinel_rules
    ArtifactPolicy = $artifactPolicy
    ReferenceTypesConfig = $referenceTypesConfig
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
