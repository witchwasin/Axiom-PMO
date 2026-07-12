# Typed reference resolver (P2.2). Classifies an evidence/reference string
# against pmo-config/reference-types.json and, for locally-resolvable types,
# checks whether it actually resolves -- so free text like "approved-by-email"
# or "some-proof" is distinguishable from a real, checkable reference.
#
# Usage: dot-source this file, then call Resolve-Reference.

function Get-ReferenceType {
  param(
    [string]$Value,
    $ReferenceTypesConfig
  )
  if (-not $Value) { return $null }
  $trimmed = $Value.Trim()
  foreach ($prop in $ReferenceTypesConfig.reference_types.PSObject.Properties) {
    if ($trimmed -match $prop.Value) { return $prop.Name }
  }
  return $null
}

function Resolve-Reference {
  param(
    [string]$Value,
    $ReferenceTypesConfig,
    [string]$ProjectRoot,
    # $null (default) means "caller did not supply this ID set" -> shape-match
    # is accepted without a resolution check. An empty array means "caller
    # supplied the set and it is genuinely empty" -> nothing can resolve.
    $DecisionIds = $null,
    $RequirementIds = $null,
    $DeliveryIds = $null,
    $TestIds = $null,
    [string]$ReleaseId = $null
  )

  $result = [pscustomobject]@{
    Value = $Value
    Type = $null
    Resolved = $false
    ExternallyUnverified = $false
  }

  $trimmed = "$Value".Trim()
  if ($trimmed.Length -eq 0) { return $result }

  $type = Get-ReferenceType $trimmed $ReferenceTypesConfig
  $result.Type = $type
  if (-not $type) { return $result }

  $externalTypes = @($ReferenceTypesConfig.externally_unverified_types)
  if ($externalTypes -contains $type) {
    $result.ExternallyUnverified = $true
    $result.Resolved = $true
    return $result
  }

  switch ($type) {
    "decision" { $result.Resolved = if ($null -eq $DecisionIds) { $true } else { @($DecisionIds) -contains $trimmed } }
    "requirement" { $result.Resolved = if ($null -eq $RequirementIds) { $true } else { @($RequirementIds) -contains $trimmed } }
    "delivery" { $result.Resolved = if ($null -eq $DeliveryIds) { $true } else { @($DeliveryIds) -contains $trimmed } }
    "test" { $result.Resolved = if ($null -eq $TestIds) { $true } else { @($TestIds) -contains $trimmed } }
    "release" { $result.Resolved = if ($null -eq $ReleaseId) { $true } else { $trimmed -eq $ReleaseId } }
    "file" {
      $filePath = $trimmed.Substring(5)
      $result.Resolved = (Test-Path -LiteralPath (Join-Path $ProjectRoot $filePath) -PathType Leaf)
    }
    default { $result.Resolved = $false }
  }

  return $result
}
