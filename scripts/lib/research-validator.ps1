# Guided Research MVP (M6) -- RESEARCH-002..RESEARCH-007.
#
# Scope boundary -- read this before adding a rule here:
#
#   Research is optional, shift-left (before Scope approval), and evidence-
#   backed. It is never authority: an AI-authored research conclusion cannot
#   change Scope, requirements, acceptance, or risk on its own -- only a
#   traceable Human decision at Scope can do that (binding design decision D2).
#
#   This module can deterministically prove:
#     - active research produces the governed artifacts (RESEARCH-002);
#     - every material claim maps to a resolvable source with a valid
#       evidence status (RESEARCH-003);
#     - an accepted change proposal cites a named-Human decision; an AI
#       cannot accept its own proposal (RESEARCH-004);
#     - Scope and later gates cannot pass with an unresolved accepted-impact
#       proposal (RESEARCH-005);
#     - provider availability/fallback is recorded truthfully (RESEARCH-006);
#     - external providers cite an approved externalization entry, so a
#       confidential brief carries Human evidence via EXT-002 (RESEARCH-007).
#
#   It never verifies the truth of a claim, downloads anything, or runs a
#   provider. It checks shape, provenance, ownership, and consistency.

function Get-ResearchDeclaredMode {
  param([string]$Project)
  $d = Get-ProjectOrchestrationDeclarations $Project
  return $d.ResearchMode
}

function Test-ResearchWorkflow {
  param(
    [string]$Project,
    [string]$Gate,
    $OrchestrationPolicy,
    [string[]]$DecisionIds
  )

  $policy = $OrchestrationPolicy.research
  $mode = Get-ResearchDeclaredMode $Project
  if (-not $mode -or $mode -eq "off") { return }
  if ($Gate -eq "Draft") { return }

  $reportPath = Join-Path $Project ([string]$policy.report_artifact)
  $provenancePath = Join-Path $Project ([string]$policy.provenance_artifact)

  # ---------------------------------------------------------------- RESEARCH-002
  $structureProblems = @()
  if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    $structureProblems += "RESEARCH/RESEARCH.md"
  } else {
    $reportText = Get-Content -LiteralPath $reportPath -Raw
    $requiredSections = @(
      "Research Status and Scope",
      "Problem and Research Questions",
      "Existing Solutions",
      "Feature Parity",
      "Relevant Standards and Regulations",
      "Differentiation and Value Implications",
      "Risks and Unknowns",
      "Impact Assessment",
      "Change Proposals",
      "Explicit Limits and Unanswered Questions"
    )
    foreach ($section in $requiredSections) {
      $pattern = '(?im)^\s*#{1,4}\s*' + [regex]::Escape($section) + '\s*$'
      if ($reportText -notmatch $pattern) { $structureProblems += $section }
    }
  }

  $provenance = $null
  $claims = @()
  if (-not (Test-Path -LiteralPath $provenancePath -PathType Leaf)) {
    $structureProblems += "RESEARCH/PROVENANCE.json"
  } else {
    try { $provenance = Get-Content -LiteralPath $provenancePath -Raw | ConvertFrom-Json } catch {
      Add-Result FAIL "RESEARCH/PROVENANCE.json is not valid JSON" "RESEARCH-002" -Artifact "RESEARCH/PROVENANCE.json"
      return
    }
    if ([string]$provenance.schema_version -ne "1.0") { $structureProblems += "schema_version" }
    $claims = @($provenance.claims)
    if ($claims.Count -eq 0) { $structureProblems += "claims" }
  }

  # ---------------------------------------------------------------- RESEARCH-003
  $provenanceProblems = @()
  $evidenceStatuses = @($script:policyEnums.evidence_statuses)
  if ($evidenceStatuses.Count -eq 0) { $evidenceStatuses = @("verified", "supported", "inferred", "missing", "conflict") }
  $sourcePatterns = @($script:policyEnums.source_ref_patterns)
  if ($sourcePatterns.Count -eq 0) { $sourcePatterns = @('MOM-\d{8}', 'REQ-\d{8}', 'REQ-V\d+', 'TR-\d{8}', 'DEC-\d{3}', 'ISSUE-\d+', 'PR-\d+') }
  foreach ($claim in $claims) {
    $id = [string]$claim.id
    if ($id -notmatch '^RC-\d{3,}$' -or [string]::IsNullOrWhiteSpace([string]$claim.claim) -or [string]::IsNullOrWhiteSpace([string]$claim.report_section)) {
      $provenanceProblems += "claim structure"
      continue
    }
    if (@($evidenceStatuses) -notcontains [string]$claim.evidence_status) {
      $provenanceProblems += "$id evidence_status"
    }
    $sources = @($claim.sources)
    if ($sources.Count -eq 0) {
      $provenanceProblems += "$id no source"
      continue
    }
    $sourceOk = $false
    foreach ($source in $sources) {
      $reference = [string]$source.reference
      if (-not $reference) { continue }
      $resolved = $false
      if ($reference -match '^https?://') { $resolved = $true }
      elseif ($reference -match '^FILE:') {
        $relative = $reference.Substring(5).Trim()
        $full = [System.IO.Path]::GetFullPath((Join-Path $Project $relative))
        $root = [System.IO.Path]::GetFullPath($Project)
        if ($full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar) -and (Test-Path -LiteralPath $full -PathType Leaf)) { $resolved = $true }
      } elseif ($reference -match ($sourcePatterns -join '|')) { $resolved = $true }
      if ($resolved) { $sourceOk = $true }
    }
    if (-not $sourceOk) { $provenanceProblems += "$id unresolvable source" }
  }

  # ---------------------------------------------------------------- RESEARCH-004/005
  $proposalProblems = @()
  $scopeProblems = @()
  $proposalStatuses = @($policy.proposal_statuses)
  $proposalImpacts = @($policy.proposal_impacts)
  if (Test-Path -LiteralPath $reportPath -PathType Leaf) {
    $reportText = Get-Content -LiteralPath $reportPath -Raw
    $rows = @(Get-TableRowsAfterHeading $reportText '(?i)^\s*#{1,4}\s*Change Proposals\s*$')
    foreach ($row in $rows) {
      $proposalId = [string]$row.'Proposal ID'
      $status = ([string]$row.Status).Trim()
      $impact = ([string]$row.Impact).Trim()
      $acceptedImpact = ([string]$row.'Accepted Impact').Trim()
      $owner = [string]$row.'Human Owner'
      $decisionRef = [string]$row.'Decision Ref'

      if ($proposalId -notmatch '^CP-\d{3,}$') { $proposalProblems += "proposal structure"; continue }
      if ($proposalStatuses -notcontains $status) { $proposalProblems += "$proposalId status" }
      if ($proposalImpacts -notcontains $impact) { $proposalProblems += "$proposalId impact" }
      if ([string]::IsNullOrWhiteSpace($owner) -or (Test-GenericOwner -Value $owner -OwnerPolicy $script:handoffPolicy.owner_policy)) { $proposalProblems += "$proposalId owner" }

      if ($status -eq "accepted") {
        $decider = if ($decisionRef -and $DecisionIds -contains $decisionRef) { Get-DecisionDecider -DecisionId $decisionRef } else { $null }
        if (-not $decisionRef -or $DecisionIds -notcontains $decisionRef -or $null -eq $decider -or (Test-GenericOwner -Value $decider -OwnerPolicy $script:handoffPolicy.owner_policy)) {
          $proposalProblems += "$proposalId decision"
        }
      }

      # Scope and later gates cannot pass with an unresolved accepted-impact
      # proposal: the impact is accepted, the proposal itself is not.
      $blocksScope = $acceptedImpact -match '(?i)^\s*yes\b' -or $impact -eq "scope"
      if ($blocksScope -and $status -ne "accepted" -and (@("Scope", "Design", "Handoff", "Release") -contains $Gate)) {
        $scopeProblems += $proposalId
      }
    }
  }

  # ---------------------------------------------------------------- RESEARCH-006
  $providerProblems = @()
  if ($provenance) {
    $providerUsed = [string]$provenance.provider_used
    $providerAvailable = $null
    if ($provenance.PSObject.Properties["provider_available"]) { $providerAvailable = [bool]$provenance.provider_available }
    $fallbackUsed = $null
    if ($provenance.PSObject.Properties["fallback_used"]) { $fallbackUsed = [bool]$provenance.fallback_used }
    if ([string]::IsNullOrWhiteSpace($providerUsed) -or (Test-PlaceholderValue $providerUsed)) {
      $providerProblems += "provider_used"
    }
    if ($providerAvailable -eq $false -and $fallbackUsed -eq $false) {
      # Provider unavailable with no fallback and no stop marker is a
      # fabricated claim of research output.
      $providerProblems += "unavailable without fallback"
    }
    if ($fallbackUsed -eq $true -and $providerAvailable -ne $false) {
      $providerProblems += "fallback without unavailable provider"
    }
  }

  # ---------------------------------------------------------------- RESEARCH-007
  $externalizationProblems = @()
  $externalProviders = @($policy.external_providers)
  $declaredProvider = Get-ProjectOrchestrationDeclarations $Project
  if ($externalProviders -contains $declaredProvider.ResearchProvider) {
    $extRef = ""
    if ($provenance) { $extRef = [string]$provenance.externalization }
    $registryPath = Join-Path $Project ([string]$OrchestrationPolicy.externalization.registry)
    $approvedIds = @()
    if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
      try {
        $extDoc = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
        foreach ($entry in @($extDoc.entries)) {
          if ([string]$entry.status -eq "approved" -and [string]$entry.id -match '^EXT-\d{3,}$') { $approvedIds += [string]$entry.id }
        }
      } catch { }
    }
    if ($extRef -notmatch '^EXT-\d{3,}$' -or ($approvedIds -notcontains $extRef)) {
      $externalizationProblems += "externalization"
    }
  }

  if ($structureProblems.Count) { Add-Result FAIL ("Guided research artifacts are missing or incomplete: " + (($structureProblems | Sort-Object -Unique) -join ", ")) "RESEARCH-002" -Artifact "RESEARCH/RESEARCH.md" }
  else { Add-Result PASS "Guided research artifacts declare the required contract" "RESEARCH-002" }
  if ($provenanceProblems.Count) { Add-Result FAIL ("Research provenance is missing or unresolvable: " + (($provenanceProblems | Sort-Object -Unique) -join ", ")) "RESEARCH-003" -Artifact "RESEARCH/PROVENANCE.json" }
  else { Add-Result PASS "Every material research claim maps to a resolvable source" "RESEARCH-003" }
  if ($proposalProblems.Count) { Add-Result FAIL ("Research change proposals lack valid Human decisions: " + (($proposalProblems | Sort-Object -Unique) -join ", ")) "RESEARCH-004" -Artifact "RESEARCH/RESEARCH.md" -Field "Change Proposals" }
  else { Add-Result PASS "Research change proposals carry valid Human decision evidence" "RESEARCH-004" }
  if ($scopeProblems.Count) { Add-Result FAIL ("Scope cannot be approved with unresolved accepted-impact research proposals: " + (($scopeProblems | Sort-Object -Unique) -join ", ")) "RESEARCH-005" -Artifact "RESEARCH/RESEARCH.md" -Field "Change Proposals" }
  elseif ($claims.Count -gt 0) { Add-Result PASS "No unresolved accepted-impact research proposal blocks this gate" "RESEARCH-005" }
  if ($providerProblems.Count) { Add-Result FAIL ("Research provider availability is not recorded truthfully: " + (($providerProblems | Sort-Object -Unique) -join ", ")) "RESEARCH-006" -Artifact "RESEARCH/PROVENANCE.json" }
  else { Add-Result PASS "Research provider availability and fallback are recorded truthfully" "RESEARCH-006" }
  if ($externalizationProblems.Count) { Add-Result FAIL "External research providers must cite an approved externalization entry" "RESEARCH-007" -Artifact "RESEARCH/PROVENANCE.json" -Field "externalization" }
  else { Add-Result PASS "Research provider usage cites approved externalization evidence" "RESEARCH-007" }
}
