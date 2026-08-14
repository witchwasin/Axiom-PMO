function Test-ChangeControlRegistry {
  param(
    [string]$Project,
    [string]$Gate,
    $OrchestrationPolicy,
    [string]$Mode,
    [string]$ExecutionPath,
    [string[]]$ProjectReqIds,
    [string[]]$DecisionIds
  )

  $path = Join-Path $Project "CHANGE-REQUESTS.json"
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return }
  if ($Gate -eq "Draft") { return }
  try { $doc = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json } catch {
    Add-Result FAIL "CHANGE-REQUESTS.json is not valid JSON" "CHANGE-001" -Artifact "CHANGE-REQUESTS.json"
    return
  }
  $changes = @($doc.changes)
  if ($doc.schema_version -ne "1.0" -or $changes.Count -eq 0) {
    Add-Result FAIL "CHANGE-REQUESTS.json has no supported registry entries" "CHANGE-001" -Artifact "CHANGE-REQUESTS.json"
    return
  }

  $structureProblems = @()
  $authorityProblems = @()
  $blocking = @()
  $downstreamProblems = @()
  $blockingClassifications = @($OrchestrationPolicy.change_control.blocking_by_mode.$Mode)
  if ($blockingClassifications.Count -eq 0) { $blockingClassifications = @($OrchestrationPolicy.change_control.blocking_classifications) }

  function Test-CurrentDigestReference {
    param($Reference, [switch]$ExecutionContract)
    $relative = [string]$Reference.path
    $claimed = [string]$Reference.sha256
    if (-not $relative -or [System.IO.Path]::IsPathRooted($relative) -or $relative -match '^\.\.[\\/]') { return $false }
    if ($ExecutionContract -and (($relative -replace '\\', '/') -notmatch '^\.execution/[^/]+/EXECUTION-CONTRACT\.json$')) { return $false }
    $full = [System.IO.Path]::GetFullPath((Join-Path $Project $relative))
    $root = [System.IO.Path]::GetFullPath($Project)
    if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar) -or -not (Test-Path -LiteralPath $full -PathType Leaf)) { return $false }
    if ($claimed -notmatch '^[a-fA-F0-9]{64}$') { return $false }
    return ((Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant() -eq $claimed.ToLowerInvariant())
  }

  foreach ($change in $changes) {
    $id = [string]$change.id
    $required = @("id", "detected_at", "source", "classification", "summary", "reason", "affected_requirements", "affected_artifacts", "scope_impact", "acceptance_impact", "mode_impact", "status", "owner")
    $missing = @($required | Where-Object { -not $change.PSObject.Properties[$_] -or [string]::IsNullOrWhiteSpace([string]$change.$_) })
    if ($id -notmatch '^CR-\d{3,}$' -or $missing.Count -gt 0) { $structureProblems += $(if ($id) { $id } else { "unnamed entry" }); continue }
    if (@($OrchestrationPolicy.change_control.sources) -notcontains [string]$change.source) { $structureProblems += "$id source" }
    if (@($OrchestrationPolicy.change_control.classifications) -notcontains [string]$change.classification) { $structureProblems += "$id classification" }
    if (@($OrchestrationPolicy.change_control.statuses) -notcontains [string]$change.status) { $structureProblems += "$id status" }
    if (@($OrchestrationPolicy.change_control.mode_impacts) -notcontains [string]$change.mode_impact) { $structureProblems += "$id mode impact" }
    foreach ($req in @($change.affected_requirements)) {
      if ($ProjectReqIds -notcontains [string]$req) { $structureProblems += "$id requirement ref" }
    }
    foreach ($artifact in @($change.affected_artifacts)) {
      $relative = [string]$artifact
      if ([System.IO.Path]::IsPathRooted($relative) -or $relative -match '^\.\.[\\/]') { $structureProblems += "$id artifact ref"; continue }
      $candidate = [System.IO.Path]::GetFullPath((Join-Path $Project $relative))
      $root = [System.IO.Path]::GetFullPath($Project)
      if (-not $candidate.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar) -or -not (Test-Path -LiteralPath $candidate)) { $structureProblems += "$id artifact ref" }
    }

    if (Test-GenericOwner -Value ([string]$change.owner) -OwnerPolicy $script:handoffPolicy.owner_policy) { $authorityProblems += "$id owner" }
    if (@("approved", "implemented", "rejected", "superseded") -contains [string]$change.status) {
      $decisionRef = [string]$change.decision_ref
      $decider = if ($decisionRef -and $DecisionIds -contains $decisionRef) { Get-DecisionDecider -DecisionId $decisionRef } else { $null }
      if (-not $decisionRef -or $DecisionIds -notcontains $decisionRef -or $null -eq $decider -or (Test-GenericOwner -Value $decider -OwnerPolicy $script:handoffPolicy.owner_policy)) { $authorityProblems += "$id decision" }
    }

    $hasDownstreamImpact = ([bool]$change.scope_impact) -or ([bool]$change.acceptance_impact) -or ([string]$change.mode_impact -ne "none")
    if ([string]$change.status -eq "implemented" -and $hasDownstreamImpact) {
      $validation = $change.downstream_validation
      $invalid = (-not $validation -or [string]$validation.status -ne "current")
      $artifactRefs = if ($validation) { @($validation.artifacts) } else { @() }
      if ($artifactRefs.Count -eq 0 -or @($artifactRefs | Where-Object { -not (Test-CurrentDigestReference $_) }).Count -gt 0) { $invalid = $true }
      if ($ExecutionPath -eq "governed_ai_execution") {
        $contractRefs = if ($validation) { @($validation.execution_contracts) } else { @() }
        if ($contractRefs.Count -eq 0 -or @($contractRefs | Where-Object { -not (Test-CurrentDigestReference $_ -ExecutionContract) }).Count -gt 0) { $invalid = $true }
      }
      if ($invalid) { $downstreamProblems += $id }
    }

    if (($blockingClassifications -contains [string]$change.classification) -and @("implemented", "rejected", "superseded") -notcontains [string]$change.status) { $blocking += $id }
  }

  if ($structureProblems.Count) { Add-Result FAIL ("Change registry has invalid entries: " + (($structureProblems | Sort-Object -Unique) -join ", ")) "CHANGE-001" -Artifact "CHANGE-REQUESTS.json" }
  else { Add-Result PASS "Change registry structure and references are valid" "CHANGE-001" }
  if ($authorityProblems.Count) { Add-Result FAIL ("Change decisions or owners are invalid: " + (($authorityProblems | Sort-Object -Unique) -join ", ")) "CHANGE-002" -Artifact "CHANGE-REQUESTS.json" }
  elseif (@($changes | Where-Object { @("approved", "implemented", "rejected", "superseded") -contains $_.status }).Count) { Add-Result PASS "Governed change dispositions carry named-Human decision evidence" "CHANGE-002" }
  if (($Gate -eq "Handoff" -or $Gate -eq "Release") -and ($blocking.Count -or $downstreamProblems.Count)) {
    $ids = @($blocking + $downstreamProblems | Sort-Object -Unique)
    Add-Result FAIL ("Unresolved or stale governed changes: " + ($ids -join ", ")) "CHANGE-003" -Artifact "CHANGE-REQUESTS.json"
  }
}
