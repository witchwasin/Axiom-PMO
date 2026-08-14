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
#     - active research produces the governed artifacts with all required
#       sections and a well-formed Impact Assessment (RESEARCH-002);
#     - every material claim maps to a resolvable source: URLs, contained
#       FILE: refs, MOM/REQ refs present in the Source Snapshot or source/**
#       artifacts, DEC refs in the decision registry, and TR/ISSUE/PR refs
#       that appear in the project record (RESEARCH-003);
#     - an accepted or rejected change proposal cites a named-Human decision;
#       an AI cannot dispose of its own proposal (RESEARCH-004);
#     - Scope and later gates cannot pass with an unresolved (proposed)
#       accepted-impact proposal (RESEARCH-005);
#     - provider availability/fallback is recorded truthfully (RESEARCH-006);
#     - external providers cite an approved externalization entry whose
#       provider matches the declared research provider (RESEARCH-007).
#
#   It never verifies the truth of a claim, downloads anything, or runs a
#   provider. It checks shape, provenance, ownership, and consistency.

function Get-ResearchDeclaredMode {
  param([string]$Project)
  $d = Get-ProjectOrchestrationDeclarations $Project
  return $d.ResearchMode
}

# Resolvable MOM/REQ source ids: rows in PROJECT.md's Source Snapshot table
# plus ids found in source/** filenames. DEC refs resolve through the decision
# registry passed in as DecisionIds. This anchors repo-local references so a
# forged MOM-99999999 cannot pass as "resolved".
function Get-ResearchSnapshotIds {
  param([string]$Project)
  $ids = @()
  $projectMd = Join-Path $Project "PROJECT.md"
  if (Test-Path -LiteralPath $projectMd -PathType Leaf) {
    try {
      $text = Get-Content -LiteralPath $projectMd -Raw -Encoding UTF8
      foreach ($row in @(Get-TableRowsAfterHeading $text '(?i)^\s*#{1,4}\s*Source Snapshot\s*$')) {
        $first = $null
        $prop = $row.PSObject.Properties[0]
        if ($prop) { $first = [string]$prop.Value }
        $byName = $row.PSObject.Properties["Source ID"]
        if ($byName) { $first = [string]$byName.Value }
        if (-not [string]::IsNullOrWhiteSpace($first)) { $ids += $first.Trim() }
      }
    } catch { }
  }
  $sourceRoot = Join-Path $Project "source"
  if (Test-Path -LiteralPath $sourceRoot -PathType Container) {
    foreach ($file in (Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -ErrorAction SilentlyContinue)) {
      foreach ($m in [regex]::Matches($file.Name, '([A-Z]{2,6}-\d{6,8})')) {
        $ids += $m.Groups[1].Value
      }
    }
  }
  return ($ids | Sort-Object -Unique)
}

function Get-ProjectTextCache {
  param([string]$Project)
  $parts = @()
  foreach ($relative in @("PROJECT.md", "source/")) {
    $path = Join-Path $Project $relative
    if (Test-Path -LiteralPath $path) {
      try {
        $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop
        if ($content) { $parts += $content }
      } catch { }
    }
  }
  return ($parts -join "`n")
}

function Test-ResearchSourceResolvable {
  param([string]$Reference, [string]$Project, [string[]]$SnapshotIds, [string[]]$DecisionIds, [string]$ProjectText)
  $reference = ([string]$Reference).Trim()
  if (-not $reference) { return $false }
  if ($reference -match '^https?://') { return $true }
  if ($reference -match '^FILE:') {
    $relative = $reference.Substring(5).Trim()
    if (-not $relative) { return $false }
    $full = [System.IO.Path]::GetFullPath((Join-Path $Project $relative))
    $root = [System.IO.Path]::GetFullPath($Project)
    # CR-017: the referenced file must physically live inside the project.
    return (Test-PhysicalContainment -Path $full -Root $root) -and (Test-Path -LiteralPath $full -PathType Leaf)
  }
  if ($reference -match '^DEC-\d{3,}$') { return $DecisionIds -contains $reference }
  if ($reference -match '^(MOM|REQ)-[A-Za-z0-9_]+') { return $SnapshotIds -contains $reference }
  # TR/ISSUE/PR references resolve when they appear somewhere in the project
  # record; the repository cannot verify external systems, only the record.
  if ($reference -match '^(TR|ISSUE|PR)-\S+') {
    return (-not [string]::IsNullOrWhiteSpace($ProjectText)) -and $ProjectText -match [regex]::Escape($reference)
  }
  return $false
}

function Test-ResearchWorkflow {
  param(
    [string]$Project,
    [string]$Gate,
    $OrchestrationPolicy,
    $Policy,
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
  $reportText = ""
  if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    $structureProblems += "RESEARCH/RESEARCH.md"
  } else {
    $reportText = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8
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
  $claimIds = @()
  if (-not (Test-Path -LiteralPath $provenancePath -PathType Leaf)) {
    $structureProblems += "RESEARCH/PROVENANCE.json"
  } else {
    try { $provenance = Get-Content -LiteralPath $provenancePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
      Add-Result FAIL "RESEARCH/PROVENANCE.json is not valid JSON" "RESEARCH-002" -Artifact "RESEARCH/PROVENANCE.json"
      return
    }
    if ([string]$provenance.schema_version -ne "1.0") { $structureProblems += "schema_version" }
    $claims = @($provenance.claims)
    if ($claims.Count -eq 0) { $structureProblems += "claims" }
    foreach ($claim in $claims) { if ([string]$claim.id -match '^RC-\d{3,}$') { $claimIds += [string]$claim.id } }
  }

  # ---------------------------------------------------------------- RESEARCH-003
  $provenanceProblems = @()
  $evidenceStatuses = @($script:policyEnums.evidence_statuses)
  if ($evidenceStatuses.Count -eq 0) { $evidenceStatuses = @("verified", "supported", "inferred", "missing", "conflict") }
  $snapshotIds = Get-ResearchSnapshotIds -Project $Project
  $projectText = Get-ProjectTextCache -Project $Project
  $reportHeadings = @()
  foreach ($line in ($reportText -split "`r?`n")) {
    if ($line -match '^\s*#{1,4}\s+(.+?)\s*$') { $reportHeadings += $Matches[1].Trim() }
  }
  foreach ($claim in $claims) {
    $id = [string]$claim.id
    if ($id -notmatch '^RC-\d{3,}$' -or [string]::IsNullOrWhiteSpace([string]$claim.claim) -or [string]::IsNullOrWhiteSpace([string]$claim.report_section)) {
      $provenanceProblems += "claim structure"
      continue
    }
    if (@($evidenceStatuses) -notcontains [string]$claim.evidence_status) {
      $provenanceProblems += "$id evidence_status"
    }
    # CR-013: the report section a claim feeds must actually exist as a heading.
    if ($reportHeadings -notcontains ([string]$claim.report_section).Trim()) {
      $provenanceProblems += "$id report_section"
    }
    $sources = @($claim.sources)
    if ($sources.Count -eq 0) {
      $provenanceProblems += "$id no source"
      continue
    }
    $sourceOk = $false
    foreach ($source in $sources) {
      $reference = [string]$source.reference
      if (Test-ResearchSourceResolvable -Reference $reference -Project $Project -SnapshotIds $snapshotIds -DecisionIds $DecisionIds -ProjectText $projectText) { $sourceOk = $true }
      $title = [string]$source.title
      $issuer = [string]$source.issuer
      if ([string]::IsNullOrWhiteSpace($title) -or (Test-PlaceholderValue $title) -or
          [string]::IsNullOrWhiteSpace($issuer) -or (Test-PlaceholderValue $issuer)) {
        $provenanceProblems += "$id source metadata"
      }
    }
    if (-not $sourceOk) { $provenanceProblems += "$id unresolvable source" }
  }

  # ---------------------------------------------------------------- RESEARCH-004/005
  # CR-011/012: Impact Assessment rows are real evidence. An accepted impact
  # must resolve through a Change Proposal with a Human disposition; accepted
  # and rejected proposals both need a named Human owner and a resolvable
  # decision; only unresolved (proposed) proposals block Scope.
  $proposalProblems = @()
  $scopeProblems = @()
  $impactProblems = @()
  $proposalStatuses = @($policy.proposal_statuses)
  $proposalImpacts = @($policy.proposal_impacts)
  $proposalIds = @()
  $proposalByStatus = @{}
  if (Test-Path -LiteralPath $reportPath -PathType Leaf) {
    $reportText = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8
    foreach ($row in @(Get-TableRowsAfterHeading $reportText '(?i)^\s*#{1,4}\s*Change Proposals\s*$')) {
      $proposalId = [string]$row.'Proposal ID'
      $status = ([string]$row.Status).Trim()
      $impact = ([string]$row.Impact).Trim()
      $acceptedImpact = ([string]$row.'Accepted Impact').Trim()
      $owner = [string]$row.'Human Owner'
      $decisionRef = [string]$row.'Decision Ref'

      if ($proposalId -match '^CP-\d{3,}$') { $proposalIds += $proposalId; $proposalByStatus[$proposalId] = $status }
      if ($proposalId -notmatch '^CP-\d{3,}$') { $proposalProblems += "proposal structure"; continue }
      if ($proposalStatuses -notcontains $status) { $proposalProblems += "$proposalId status" }
      if ($proposalImpacts -notcontains $impact) { $proposalProblems += "$proposalId impact" }
      if ([string]::IsNullOrWhiteSpace($owner) -or (Test-GenericOwner -Value $owner -OwnerPolicy $script:handoffPolicy.owner_policy)) { $proposalProblems += "$proposalId owner" }

      # CR-012: accepted AND rejected are Human dispositions and need a
      # resolvable decision; proposed remains unresolved.
      if ($status -eq "accepted" -or $status -eq "rejected") {
        $decider = if ($decisionRef -and $DecisionIds -contains $decisionRef) { Get-DecisionDecider -DecisionId $decisionRef } else { $null }
        if (-not $decisionRef -or $DecisionIds -notcontains $decisionRef -or $null -eq $decider -or (Test-GenericOwner -Value $decider -OwnerPolicy $script:handoffPolicy.owner_policy)) {
          $proposalProblems += "$proposalId decision"
        }
      }

      # CR-004: only genuinely unresolved (proposed) proposals block Scope.
      $blocksScope = $acceptedImpact -match '(?i)^\s*yes\b' -or $impact -eq "scope"
      if ($blocksScope -and $status -eq "proposed" -and (@("Scope", "Design", "Handoff", "Release") -contains $Gate)) {
        $scopeProblems += $proposalId
      }
    }

    # CR-011: Impact Assessment rows -- finding refs must be real claims; an
    # accepted impact must resolve through a Change Proposal with a Human
    # disposition (accepted or rejected), never an AI conclusion alone.
    foreach ($row in @(Get-TableRowsAfterHeading $reportText '(?i)^\s*#{1,4}\s*Impact Assessment\s*$')) {
      $findingRef = ([string]$row.'Finding Ref').Trim()
      $mapsTo = ([string]$row.'Maps To').Trim()
      $proposedImpact = ([string]$row.'Proposed Impact').Trim()
      $status = ([string]$row.Status).Trim()
      $changeProposal = ([string]$row.'Change Proposal').Trim()

      if ($findingRef -notmatch '^RC-\d{3,}$') { $impactProblems += "impact finding ref"; continue }
      if ($claimIds -notcontains $findingRef) { $impactProblems += "$findingRef unknown claim" }
      if ([string]::IsNullOrWhiteSpace($mapsTo) -or (Test-PlaceholderValue $mapsTo)) { $impactProblems += "$findingRef maps_to" }
      if ([string]::IsNullOrWhiteSpace($proposedImpact) -or (Test-PlaceholderValue $proposedImpact)) { $impactProblems += "$findingRef impact" }
      if ($proposalStatuses -notcontains $status) { $impactProblems += "$findingRef status" }

      if ($status -eq "accepted") {
        if ($changeProposal -notmatch '^CP-\d{3,}$') {
          $impactProblems += "$findingRef no proposal"
        } elseif ($proposalIds -notcontains $changeProposal -or @("accepted", "rejected") -notcontains $proposalByStatus[$changeProposal]) {
          $impactProblems += "$findingRef undecided proposal"
        }
      }
    }
  }

  # ---------------------------------------------------------------- RESEARCH-006
  $providerProblems = @()
  if ($provenance) {
    $providerUsed = [string]$provenance.provider_used
    $providerAvailableProp = $provenance.PSObject.Properties["provider_available"]
    $fallbackUsedProp = $provenance.PSObject.Properties["fallback_used"]
    if ([string]::IsNullOrWhiteSpace($providerUsed) -or (Test-PlaceholderValue $providerUsed)) {
      $providerProblems += "provider_used"
    }
    # CR-013: the provider booleans are part of the contract and must be real
    # JSON booleans.
    if (-not $providerAvailableProp -or $providerAvailableProp.Value -isnot [bool]) { $providerProblems += "provider_available" }
    if (-not $fallbackUsedProp -or $fallbackUsedProp.Value -isnot [bool]) { $providerProblems += "fallback_used" }
    $providerAvailable = $null
    if ($providerAvailableProp) { $providerAvailable = [bool]$providerAvailableProp.Value }
    $fallbackUsed = $null
    if ($fallbackUsedProp) { $fallbackUsed = [bool]$fallbackUsedProp.Value }
    if ($providerAvailable -eq $false -and $fallbackUsed -eq $false) {
      # Provider unavailable with no fallback and no stop marker is a
      # fabricated claim of research output.
      $providerProblems += "unavailable without fallback"
    }
    if ($fallbackUsed -eq $true -and $providerAvailable -ne $false) {
      $providerProblems += "fallback without unavailable provider"
    }
    if ($provenance.PSObject.Properties["retrieved_at"]) {
      $retrievedAt = $provenance.retrieved_at
      if (-not ($retrievedAt -is [datetime]) -and ([string]$retrievedAt -notmatch '^\d{4}-\d{2}-\d{2}T' -and -not (Test-DateValue ([string]$retrievedAt)))) {
        $providerProblems += "retrieved_at"
      }
    }
  }

  # ---------------------------------------------------------------- RESEARCH-007
  $externalizationProblems = @()
  $externalProviders = @($policy.external_providers)
  $declaredProvider = (Get-ProjectOrchestrationDeclarations $Project).ResearchProvider
  if ($externalProviders -contains $declaredProvider) {
    $extRef = ""
    if ($provenance) { $extRef = [string]$provenance.externalization }
    $approvedExt = $null
    $registryPath = Join-Path $Project ([string]$OrchestrationPolicy.externalization.registry)
    if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
      try {
        $extDoc = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($entry in @($extDoc.entries)) {
          if ([string]$entry.status -eq "approved" -and [string]$entry.id -eq $extRef) { $approvedExt = $entry }
        }
      } catch { }
    }
    if ($null -eq $approvedExt) {
      $externalizationProblems += "externalization"
    } else {
      # CR-010: the externalization entry must name the provider being used.
      $providerUsed = ""
      if ($provenance) { $providerUsed = ([string]$provenance.provider_used).Trim() }
      $extProvider = ([string]$approvedExt.provider).Trim()
      $providerOk = ($providerUsed.Length -gt 0 -and $extProvider.Length -gt 0 -and
        ($extProvider.IndexOf($providerUsed, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
         $providerUsed.IndexOf($extProvider, [System.StringComparison]::OrdinalIgnoreCase) -ge 0))
      if (-not $providerOk) { $externalizationProblems += "provider mismatch" }
    }
  }

  if ($structureProblems.Count) { Add-Result FAIL ("Guided research artifacts are missing or incomplete: " + (($structureProblems | Sort-Object -Unique) -join ", ")) "RESEARCH-002" -Artifact "RESEARCH/RESEARCH.md" }
  else { Add-Result PASS "Guided research artifacts declare the required contract" "RESEARCH-002" }
  if ($provenanceProblems.Count) { Add-Result FAIL ("Research provenance is missing or unresolvable: " + (($provenanceProblems | Sort-Object -Unique) -join ", ")) "RESEARCH-003" -Artifact "RESEARCH/PROVENANCE.json" }
  else { Add-Result PASS "Every material research claim maps to a resolvable source" "RESEARCH-003" }
  if ($proposalProblems.Count -or $impactProblems.Count) { Add-Result FAIL ("Research change proposals or impact assessments lack valid Human decisions: " + (($proposalProblems + $impactProblems | Sort-Object -Unique) -join ", ")) "RESEARCH-004" -Artifact "RESEARCH/RESEARCH.md" -Field "Change Proposals" }
  else { Add-Result PASS "Research change proposals carry valid Human decision evidence" "RESEARCH-004" }
  if ($scopeProblems.Count) { Add-Result FAIL ("Scope cannot be approved with unresolved accepted-impact research proposals: " + (($scopeProblems | Sort-Object -Unique) -join ", ")) "RESEARCH-005" -Artifact "RESEARCH/RESEARCH.md" -Field "Change Proposals" }
  elseif ($claims.Count -gt 0) { Add-Result PASS "No unresolved accepted-impact research proposal blocks this gate" "RESEARCH-005" }
  if ($providerProblems.Count) { Add-Result FAIL ("Research provider availability is not recorded truthfully: " + (($providerProblems | Sort-Object -Unique) -join ", ")) "RESEARCH-006" -Artifact "RESEARCH/PROVENANCE.json" }
  else { Add-Result PASS "Research provider availability and fallback are recorded truthfully" "RESEARCH-006" }
  if ($externalizationProblems.Count) { Add-Result FAIL ("External research providers must cite a binding approved externalization entry: " + (($externalizationProblems | Sort-Object -Unique) -join ", ")) "RESEARCH-007" -Artifact "RESEARCH/PROVENANCE.json" -Field "externalization" }
  else { Add-Result PASS "Research provider usage cites approved externalization evidence" "RESEARCH-007" }
}
