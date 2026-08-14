# Claude Design optional workflow (M5) -- DPROV-002..DPROV-007.
#
# Scope boundary -- read this before adding a rule here:
#
#   This module governs the handoff AND return workflow around a
#   Human-operated design provider (Claude Design). No provider API is
#   invoked or required: the manifest, output folder, deterministic preflight,
#   and review manifest are repository artifacts the Human workflow produces.
#
#   It can deterministically prove:
#     - the INPUT-MANIFEST.json contract is complete and its input digests are
#       current (DPROV-002/003);
#     - an approved externalization entry is cited whenever the provider
#       receives project content (DPROV-004);
#     - candidate output lives only under the declared OUTPUT/ folder and no
#       Human acceptance is recorded before a passing preflight (DPROV-005);
#     - an AI reviewer cannot mark Human acceptance, Human acceptance cites a
#       resolvable decision, and changed output invalidates a recorded
#       acceptance (DPROV-006);
#     - technical findings are routed through Change Control (DPROV-007).
#
#   It never judges UX/UI/business fit. That is the semantic reconciliation
#   (pmo-design) and the Human review recorded in REVIEW.json; this module
#   only checks that the review happened, is current, and is owned.
#
#   Repository source names are templates/DESIGN-PROVIDER-INPUT.json and
#   templates/DESIGN-PROVIDER-REVIEW.json. Projects materialize them as
#   DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json and
#   DESIGN/CLAUDE-DESIGN/REVIEW.json -- the two names never coexist.

function Get-DesignProviderManifestPath {
  param([string]$Project, $OrchestrationPolicy)
  return Join-Path $Project ([string]$OrchestrationPolicy.ui_delivery.input_manifest)
}

function Get-DesignProviderOutputRoot {
  param([string]$Project, $OrchestrationPolicy)
  return Join-Path $Project ([string]$OrchestrationPolicy.ui_delivery.output_root)
}

# Combined digest of the declared input set: sorted "path|sha256" lines.
function Get-DesignInputCombinedDigest {
  param($Inputs)
  $lines = @()
  foreach ($input in @($Inputs)) {
    $lines += ([string]$input.path).Trim() + "|" + ([string]$input.sha256).Trim()
  }
  return (Get-Sha256Hex -Text ((Sort-Ordinal -Values ([string[]]$lines)) -join "`n"))
}

# Digest of every file currently under the output folder, sorted by relative
# path. A changed, added, or removed output invalidates it -- the recorded
# preflight/review only speaks for the output set it saw.
function Get-DesignOutputSetDigest {
  param([string]$OutputRoot)
  $lines = @()
  if (Test-Path -LiteralPath $OutputRoot) {
    $prefix = (Resolve-Path -LiteralPath $OutputRoot).Path
    foreach ($file in (Get-ChildItem -LiteralPath $OutputRoot -Recurse -File -ErrorAction SilentlyContinue | Sort-Object FullName)) {
      $relative = $file.FullName.Substring($prefix.Length).TrimStart([char]92, [char]47) -replace '\\', '/'
      $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
      $lines += "$relative|$hash"
    }
  }
  if ($lines.Count -eq 0) { return (Get-Sha256Hex -Text "empty") }
  return (Get-Sha256Hex -Text ((Sort-Ordinal -Values ([string[]]$lines)) -join "`n"))
}

function Test-DesignProviderWorkflow {
  param(
    [string]$Project,
    [string]$Gate,
    $OrchestrationPolicy,
    [string[]]$DecisionIds
  )

  $policy = $OrchestrationPolicy.ui_delivery
  $manifestPath = Get-DesignProviderManifestPath -Project $Project -OrchestrationPolicy $OrchestrationPolicy
  $manifestExists = Test-Path -LiteralPath $manifestPath -PathType Leaf
  $declared = Get-ProjectOrchestrationDeclarations $Project
  $trackActive = $manifestExists
  $requiredAtGate = (-not $manifestExists) -and ([string]$declared.UiDelivery -eq "claude_design") -and (@("Handoff", "Release") -contains $Gate)

  if (-not $trackActive -and -not $requiredAtGate) { return }

  if (-not $manifestExists) {
    Add-Result FAIL "Claude Design is the declared UI delivery path but DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json is missing" "DPROV-002" -Artifact "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json"
    return
  }

  try { $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json } catch {
    Add-Result FAIL "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json is not valid JSON" "DPROV-002" -Artifact "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json"
    return
  }

  # ---------------------------------------------------------------- DPROV-002
  $structureProblems = @()
  $required = @("project_code", "provider", "purpose", "externalization", "generated_at", "inputs", "combined_digest")
  foreach ($field in $required) {
    $prop = $manifest.PSObject.Properties[$field]
    if (-not $prop) { $structureProblems += $field; continue }
    # Array values (inputs) and DateTime values (generated_at) are checked by
    # their own rules; [string] would render them as whitespace or in a
    # culture-local format.
    if ($prop.Value -is [System.Array] -or $prop.Value -is [datetime]) { continue }
    if ([string]::IsNullOrWhiteSpace([string]$manifest.$field)) { $structureProblems += $field }
  }
  $inputs = @($manifest.inputs)
  if ($inputs.Count -eq 0) { $structureProblems += "inputs" }
  foreach ($input in $inputs) {
    if ([string]::IsNullOrWhiteSpace([string]$input.path) -or [string]::IsNullOrWhiteSpace([string]$input.sha256)) { $structureProblems += "input ref" }
  }
  $generatedOk = $false
  if ($manifest.generated_at -is [datetime]) { $generatedOk = $true }
  elseif ([string]$manifest.generated_at -match '^\d{4}-\d{2}-\d{2}T') { $generatedOk = $true }
  if (-not $generatedOk) { $structureProblems += "generated_at" }

  # ---------------------------------------------------------------- DPROV-003
  $freshnessProblems = @()
  foreach ($input in $inputs) {
    $relative = [string]$input.path
    if (-not $relative -or [System.IO.Path]::IsPathRooted($relative) -or $relative -match '^\.\.[\\/]') {
      $freshnessProblems += "input path"; continue
    }
    $full = [System.IO.Path]::GetFullPath((Join-Path $Project $relative))
    $root = [System.IO.Path]::GetFullPath($Project)
    if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar) -or -not (Test-Path -LiteralPath $full -PathType Leaf)) {
      $freshnessProblems += $relative
      continue
    }
    $claimed = [string]$input.sha256
    if ($claimed -notmatch '^[a-fA-F0-9]{64}$' -or
        (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant() -ne $claimed.ToLowerInvariant()) {
      $freshnessProblems += $relative
    }
  }
  $declaredCombined = [string]$manifest.combined_digest
  if ($freshnessProblems.Count -eq 0) {
    $recomputedCombined = Get-DesignInputCombinedDigest -Inputs $inputs
    if ($declaredCombined -notmatch '^[a-fA-F0-9]{64}$' -or $recomputedCombined -ne $declaredCombined.ToLowerInvariant()) {
      $freshnessProblems += "combined_digest"
    }
  }

  # ---------------------------------------------------------------- DPROV-004
  $externalizationProblems = @()
  $extRef = [string]$manifest.externalization
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

  # ---------------------------------------------------------------- DPROV-005/006
  $reviewPath = Join-Path $Project ([string]$policy.review_manifest)
  $preflightProblems = @()
  $authorityProblems = @()
  if (Test-Path -LiteralPath $reviewPath -PathType Leaf) {
    $review = $null
    try { $review = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json } catch {
      Add-Result FAIL "DESIGN/CLAUDE-DESIGN/REVIEW.json is not valid JSON" "DPROV-005" -Artifact "DESIGN/CLAUDE-DESIGN/REVIEW.json"
      return
    }
    $preflight = $review.preflight
    $acceptance = $review.acceptance
    $outputRoot = Get-DesignProviderOutputRoot -Project $Project -OrchestrationPolicy $OrchestrationPolicy

    if (-not $preflight -or [string]$preflight.status -notmatch '^(passed|failed)$') {
      $preflightProblems += "preflight"
    } elseif ([string]$preflight.status -eq "failed") {
      $preflightProblems += "preflight failed"
    } else {
      if ([string]::IsNullOrWhiteSpace([string]$preflight.outputs_digest)) { $preflightProblems += "outputs_digest" }
      elseif (($null -ne $acceptance) -and [string]$acceptance.decision) {
        # A recorded acceptance for output the preflight did not see is stale.
        $currentOutputs = Get-DesignOutputSetDigest -OutputRoot $outputRoot
        if ([string]$preflight.outputs_digest -ne $currentOutputs) { $preflightProblems += "stale outputs" }
      }
    }

    # Any review decision recorded before a passing preflight is rejected.
    if ($acceptance -and [string]$acceptance.decision -and
        (-not $preflight -or [string]$preflight.status -ne "passed")) {
      $preflightProblems += "review before preflight"
    }

    $outputProblems = @()
    if (Test-Path -LiteralPath $outputRoot) {
      $outputPrefix = (Resolve-Path -LiteralPath $outputRoot).Path
      foreach ($file in (Get-ChildItem -LiteralPath $outputRoot -Recurse -File -ErrorAction SilentlyContinue)) {
        # Outputs must stay inside the declared folder; containment is
        # guaranteed by the rooted walk above, so this is a structural claim
        # about the contract, not a traversal check.
        if (-not $file.FullName.StartsWith($outputPrefix)) { $outputProblems += $file.FullName }
      }
    }
    if ($outputProblems.Count -gt 0) { $preflightProblems += "output outside folder" }

    if ($acceptance -and [string]$acceptance.decision) {
      $decision = [string]$acceptance.decision
      if (@($policy.acceptance_decisions) -notcontains $decision) { $authorityProblems += "decision" }
      $kind = [string]$acceptance.reviewer_kind
      if (@($policy.reviewer_kinds) -notcontains $kind) { $authorityProblems += "reviewer_kind" }
      $reviewer = [string]$acceptance.reviewer
      $decisionRef = [string]$acceptance.decision_ref
      if ([string]::IsNullOrWhiteSpace($reviewer) -or (Test-GenericOwner -Value $reviewer -OwnerPolicy $script:handoffPolicy.owner_policy)) { $authorityProblems += "reviewer" }
      if ($decision -eq "accepted" -and $kind -eq "ai") { $authorityProblems += "AI acceptance" }
      $decider = if ($decisionRef -and $DecisionIds -contains $decisionRef) { Get-DecisionDecider -DecisionId $decisionRef } else { $null }
      if (-not $decisionRef -or $DecisionIds -notcontains $decisionRef -or $null -eq $decider -or (Test-GenericOwner -Value $decider -OwnerPolicy $script:handoffPolicy.owner_policy)) { $authorityProblems += "decision_ref" }
    }
  }

  # ---------------------------------------------------------------- DPROV-007
  $changeControlProblems = @()
  $registryPath = Join-Path $Project "CHANGE-REQUESTS.json"
  $routedFindingIds = @()
  if (Test-Path -LiteralPath $reviewPath -PathType Leaf) {
    $review = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json
    foreach ($finding in @($review.findings)) {
      if ($finding.PSObject.Properties["routes_to_change_control"] -and [bool]$finding.routes_to_change_control) {
        $routedFindingIds += [string]$finding.id
      }
    }
  }
  if ($routedFindingIds.Count -gt 0) {
    $registrySummaries = @()
    if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
      try {
        $crDoc = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
        foreach ($change in @($crDoc.changes)) { $registrySummaries += [string]$change.summary }
      } catch { }
    }
    foreach ($findingId in $routedFindingIds) {
      if ($findingId -and -not ($registrySummaries | Where-Object { $_ -match [regex]::Escape($findingId) })) {
        $changeControlProblems += $findingId
      }
    }
  }

  if ($structureProblems.Count) { Add-Result FAIL ("Design provider input manifest is incomplete: " + (($structureProblems | Sort-Object -Unique) -join ", ")) "DPROV-002" -Artifact "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json" }
  else { Add-Result PASS "Design provider input manifest declares the required contract" "DPROV-002" }
  if ($freshnessProblems.Count) { Add-Result FAIL ("Design provider manifest references or digests are invalid or stale: " + (($freshnessProblems | Sort-Object -Unique) -join ", ")) "DPROV-003" -Artifact "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json" }
  else { Add-Result PASS "Design provider manifest references and digests are current" "DPROV-003" }
  if ($externalizationProblems.Count) { Add-Result FAIL "Design provider manifest must cite an approved externalization entry" "DPROV-004" -Artifact "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json" -Field "externalization" }
  else { Add-Result PASS "Design provider manifest cites an approved externalization entry" "DPROV-004" }
  if ($preflightProblems.Count) { Add-Result FAIL ("Design provider preflight or output contract is invalid: " + (($preflightProblems | Sort-Object -Unique) -join ", ")) "DPROV-005" -Artifact "DESIGN/CLAUDE-DESIGN/REVIEW.json" }
  elseif (-not (Test-Path -LiteralPath $reviewPath -PathType Leaf)) { Add-Result PASS "No design provider review recorded yet (preflight not required before review exists)" "DPROV-005" }
  else { Add-Result PASS "Design provider preflight and output placement are valid" "DPROV-005" }
  if ($authorityProblems.Count) { Add-Result FAIL ("Design provider review authority is invalid: " + (($authorityProblems | Sort-Object -Unique) -join ", ")) "DPROV-006" -Artifact "DESIGN/CLAUDE-DESIGN/REVIEW.json" }
  elseif (-not (Test-Path -LiteralPath $reviewPath -PathType Leaf)) { Add-Result PASS "No design provider review recorded yet" "DPROV-006" }
  else { Add-Result PASS "Design provider review carries valid Human acceptance evidence" "DPROV-006" }
  if ($changeControlProblems.Count) { Add-Result FAIL ("Design provider technical findings are not routed through Change Control: " + (($changeControlProblems | Sort-Object -Unique) -join ", ")) "DPROV-007" -Artifact "DESIGN/CLAUDE-DESIGN/REVIEW.json" }
  elseif ($routedFindingIds.Count -gt 0) { Add-Result PASS "Design provider technical findings are routed through Change Control" "DPROV-007" }
  else { Add-Result PASS "No design provider finding requires Change Control routing" "DPROV-007" }
}
