# Externalization Gate MVP (M4) -- EXT-001..EXT-004.
#
# Scope boundary -- read this before adding a rule here:
#
#   This module records and checks the project's OWN declarations about data
#   leaving the governed boundary. It is an honest, provider-neutral registry,
#   explicitly not an enterprise DLP system: it cannot detect semantic trade
#   secrets, cannot enforce provider-account or retention policy, and never
#   echoes a detected value in a diagnostic.
#
#   What it CAN prove deterministically:
#     - every transfer entry carries the required contract fields (EXT-001);
#     - Confidential/Restricted transfers (and any transfer whose scan was not
#       clean) carry a named Human reviewer and a resolvable decision (EXT-002);
#     - a declared "clean" scan is honest -- re-scanning the declared outgoing
#       artifacts with the configured secret patterns must agree (EXT-003);
#     - declared outgoing artifact paths resolve inside the project and their
#       recorded SHA-256 digests are current (EXT-004).
#
#   It never decides that a particular value IS sensitive. It checks the
#   declared classification and the declared scan result against what the
#   configured patterns actually match in the declared outgoing files. Values
#   themselves are never placed in a diagnostic message.

function Get-ExternalizationRegistryPath {
  param([string]$Project, $OrchestrationPolicy)
  return Join-Path $Project ([string]$OrchestrationPolicy.externalization.registry)
}

# Re-scan a set of project-relative artifact paths with the configured secret
# patterns plus the policy's sensitive path patterns. Returns $true when any
# pattern matches. Never returns the matched value -- callers only learn
# whether a finding exists, which is all a diagnostic may say.
function Test-ExternalizationScanFinding {
  param(
    [string]$Project,
    [string[]]$ArtifactPaths,
    $SecretPatterns,
    [string[]]$SensitivePathPatterns
  )

  foreach ($relative in $ArtifactPaths) {
    $normalized = $relative -replace '\\', '/'
    foreach ($pathPattern in $SensitivePathPatterns) {
      $pattern = $pathPattern -replace '\.', '\.' -replace '\*', '.*'
      if ($normalized -match "(?i)^$pattern$") { return $true }
    }

    $full = [System.IO.Path]::GetFullPath((Join-Path $Project $relative))
    $root = [System.IO.Path]::GetFullPath($Project)
    if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar)) { continue }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }

    try {
      $content = Get-Content -LiteralPath $full -Raw -Encoding UTF8 -ErrorAction Stop
    } catch {
      # Binary files (png, zip, ...) may not decode as text; the scan records
      # only what the configured text patterns can see. Never fail the project
      # because a binary artifact cannot be scanned as UTF-8.
      continue
    }
    if ($null -eq $content) { continue }
    foreach ($entry in @($SecretPatterns)) {
      if ($content -match ([string]$entry.pattern)) { return $true }
    }
  }
  return $false
}

function Test-ExternalizationRegistry {
  param(
    [string]$Project,
    [string]$Gate,
    $OrchestrationPolicy,
    [string[]]$DecisionIds
  )

  $policy = $OrchestrationPolicy.externalization
  $path = Get-ExternalizationRegistryPath -Project $Project -OrchestrationPolicy $OrchestrationPolicy
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return }
  if ($Gate -eq "Draft") { return }

  try { $doc = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json } catch {
    Add-Result FAIL "EXTERNALIZATION.json is not valid JSON" "EXT-001" -Artifact "EXTERNALIZATION.json"
    return
  }
  $entries = @($doc.entries)
  if ([string]$doc.schema_version -ne "1.0" -or $entries.Count -eq 0) {
    Add-Result FAIL "EXTERNALIZATION.json has no supported registry entries" "EXT-001" -Artifact "EXTERNALIZATION.json"
    return
  }

  $structureProblems = @()
  $authorityProblems = @()
  $scanProblems = @()
  $freshnessProblems = @()
  $humanReviewRequired = @($policy.human_review_required)
  $secretPatterns = @($policy.secret_patterns)
  $sensitivePathPatterns = @($script:policyEnums.sensitive_paths)
  if ($sensitivePathPatterns.Count -eq 0) {
    $sensitivePathPatterns = @(".env", ".env.*", "*.pem", "*.key", "*.pfx", "*.p12", "id_rsa", "id_ed25519")
  }

  foreach ($entry in $entries) {
    $id = [string]$entry.id
    $required = @("id", "purpose", "provider", "provider_type", "outgoing_artifacts", "classification", "minimization_redaction", "scan_result", "human_review_required", "status", "recorded_at")
    $missing = @()
    foreach ($field in $required) {
      $prop = $entry.PSObject.Properties[$field]
      if (-not $prop) { $missing += $field; continue }
      # Array/object values (outgoing_artifacts) and DateTime values
      # (recorded_at) are checked by their own rules below; converting them to
      # [string] would either produce whitespace or a culture-local rendering.
      if ($prop.Value -is [System.Array] -or $prop.Value -is [PSCustomObject] -or $prop.Value -is [datetime]) { continue }
      if ([string]::IsNullOrWhiteSpace([string]$entry.$field)) { $missing += $field }
    }
    $idBad = $id -notmatch '^EXT-\d{3,}$'
    if ($idBad -or $missing.Count -gt 0) { $structureProblems += $(if ($id) { $id } else { "unnamed entry" }); continue }

    if (@($policy.provider_types) -notcontains [string]$entry.provider_type) { $structureProblems += "$id provider_type" }
    if (@($policy.classifications) -notcontains [string]$entry.classification) { $structureProblems += "$id classification" }
    if (@($policy.scan_results) -notcontains [string]$entry.scan_result) { $structureProblems += "$id scan_result" }
    if (@($policy.statuses) -notcontains [string]$entry.status) { $structureProblems += "$id status" }
    if ($entry.PSObject.Properties["network_transfer_occurred"] -and [string]$entry.network_transfer_occurred -notmatch '(?i)^(true|false)$') { $structureProblems += "$id network_transfer_occurred" }
    $recordedOk = $false
    if ($entry.recorded_at -is [datetime]) { $recordedOk = $true }
    elseif ([string]$entry.recorded_at -match '^\d{4}-\d{2}-\d{2}T' -or (Test-DateValue ([string]$entry.recorded_at))) { $recordedOk = $true }
    if (-not $recordedOk) { $structureProblems += "$id recorded_at" }
    if ([string]::IsNullOrWhiteSpace([string]$entry.minimization_redaction) -or (Test-PlaceholderValue ([string]$entry.minimization_redaction))) { $structureProblems += "$id minimization" }
    if ([string]::IsNullOrWhiteSpace([string]$entry.purpose) -or (Test-PlaceholderValue ([string]$entry.purpose))) { $structureProblems += "$id purpose" }

    $artifactRefs = @($entry.outgoing_artifacts)
    if ($artifactRefs.Count -eq 0) {
      $structureProblems += "$id outgoing_artifacts"
      continue
    }
    $resolvedArtifacts = @()
    foreach ($ref in $artifactRefs) {
      $relative = [string]$ref.path
      if (-not $relative -or [System.IO.Path]::IsPathRooted($relative) -or $relative -match '^\.\.[\\/]') {
        $structureProblems += "$id artifact ref"; continue
      }
      $full = [System.IO.Path]::GetFullPath((Join-Path $Project $relative))
      $root = [System.IO.Path]::GetFullPath($Project)
      if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar) -or -not (Test-Path -LiteralPath $full -PathType Leaf)) {
        $structureProblems += "$id artifact ref"; continue
      }
      $resolvedArtifacts += $relative
      $claimed = [string]$ref.sha256
      if ($claimed -notmatch '^[a-fA-F0-9]{64}$') {
        $freshnessProblems += "$id digest"
      } elseif ((Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant() -ne $claimed.ToLowerInvariant()) {
        $freshnessProblems += $id
      }
    }

    $requiresHuman = (@($humanReviewRequired) -contains [string]$entry.classification) -or
      (@("finding", "not_run") -contains [string]$entry.scan_result) -or
      ([string]$entry.status -eq "approved")
    $declaredRequiresHuman = $false
    if ($entry.PSObject.Properties["human_review_required"]) {
      $declaredRequiresHuman = [bool]$entry.human_review_required
    }
    if ($requiresHuman -and -not $declaredRequiresHuman) {
      $authorityProblems += "$id review flag"
    }
    if ($requiresHuman) {
      $reviewer = [string]$entry.reviewer
      $decisionRef = [string]$entry.decision_ref
      $decider = if ($decisionRef -and $DecisionIds -contains $decisionRef) { Get-DecisionDecider -DecisionId $decisionRef } else { $null }
      if ([string]::IsNullOrWhiteSpace($reviewer) -or (Test-GenericOwner -Value $reviewer -OwnerPolicy $script:handoffPolicy.owner_policy)) { $authorityProblems += "$id reviewer" }
      if (-not $decisionRef -or $DecisionIds -notcontains $decisionRef -or $null -eq $decider -or (Test-GenericOwner -Value $decider -OwnerPolicy $script:handoffPolicy.owner_policy)) { $authorityProblems += "$id decision" }
    } elseif ([string]$entry.status -eq "approved" -and -not $declaredRequiresHuman) {
      $authorityProblems += "$id approval"
    }

    # Scan honesty: a declared "clean" scan must agree with a deterministic
    # re-scan of the declared outgoing artifacts. A finding must never be
    # echoed into a diagnostic -- only its existence is reportable.
    if ([string]$entry.scan_result -eq "clean" -and
        (Test-ExternalizationScanFinding -Project $Project -ArtifactPaths ([string[]]$resolvedArtifacts) -SecretPatterns $secretPatterns -SensitivePathPatterns $sensitivePathPatterns)) {
      $scanProblems += $id
    }
  }

  if ($structureProblems.Count) { Add-Result FAIL ("Externalization registry has invalid entries: " + (($structureProblems | Sort-Object -Unique) -join ", ")) "EXT-001" -Artifact "EXTERNALIZATION.json" }
  else { Add-Result PASS "Externalization registry structure and artifact references are valid" "EXT-001" }
  if ($authorityProblems.Count) { Add-Result FAIL ("Externalization entries lack required Human evidence: " + (($authorityProblems | Sort-Object -Unique) -join ", ")) "EXT-002" -Artifact "EXTERNALIZATION.json" }
  else { Add-Result PASS "Required externalization transfers carry named-Human decision evidence" "EXT-002" }
  if ($scanProblems.Count) { Add-Result FAIL ("Declared clean scan does not match a deterministic re-scan of outgoing artifacts: " + (($scanProblems | Sort-Object -Unique) -join ", ")) "EXT-003" -Artifact "EXTERNALIZATION.json" }
  else { Add-Result PASS "Declared externalization scan results match a deterministic re-scan" "EXT-003" }
  if ($freshnessProblems.Count) { Add-Result FAIL ("Externalization artifact digests are missing or stale: " + (($freshnessProblems | Sort-Object -Unique) -join ", ")) "EXT-004" -Artifact "EXTERNALIZATION.json" }
  else { Add-Result PASS "Externalization artifact digests are current" "EXT-004" }
}
