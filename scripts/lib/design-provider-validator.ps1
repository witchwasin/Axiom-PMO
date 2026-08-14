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
#       current, including canonical minimum inputs and governed justification
#       for any raw source input (DPROV-002/003);
#     - the cited externalization entry is approved AND binds the provider and
#       the exact outgoing path+digest payload (DPROV-004);
#     - candidate output lives only under the declared OUTPUT/ folder as a
#       declared, digest-current inventory, the preflight speaks for the
#       current manifest and output set, and no Human acceptance is recorded
#       before a passing preflight (DPROV-005);
#     - an AI reviewer cannot mark Human acceptance, Human acceptance cites a
#       resolvable decision, and changed output invalidates a recorded
#       acceptance (DPROV-006);
#     - technical/scope findings are routed through Change Control by their
#       impact/lens (never a self-asserted boolean) and an accepted baseline
#       cannot coexist with an unresolved blocking finding (DPROV-007).
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
      $hash = Get-ArtifactSha256 -Path $file.FullName
      $lines += "$relative|$hash"
    }
  }
  if ($lines.Count -eq 0) { return (Get-Sha256Hex -Text "empty") }
  return (Get-Sha256Hex -Text ((Sort-Ordinal -Values ([string[]]$lines)) -join "`n"))
}

# CR-008: declared output inventory vs the actual OUTPUT/** file set. Every
# declared output must exist under OUTPUT/**, be physically contained, and
# match its recorded digest; every actual file must be declared. Returns a
# list of problem descriptions (never file content).
function Test-DesignOutputInventory {
  param([string]$OutputRoot, $DeclaredOutputs)
  $problems = @()
  $root = [System.IO.Path]::GetFullPath($OutputRoot)
  $actualFiles = @{}
  if (Test-Path -LiteralPath $OutputRoot) {
    foreach ($file in (Get-ChildItem -LiteralPath $OutputRoot -Recurse -File -ErrorAction SilentlyContinue)) {
      if (-not (Test-PhysicalContainment -Path $file.FullName -Root $root)) {
        $problems += "output escapes boundary"
        continue
      }
      $relative = $file.FullName.Substring($root.Length).TrimStart([char]92, [char]47) -replace '\\', '/'
      $actualFiles[$relative.ToLowerInvariant()] = $file.FullName
    }
  }
  $declaredKeys = @()
  foreach ($decl in @($DeclaredOutputs)) {
    $relative = ([string]$decl.path).Trim()
    if (-not $relative -or [System.IO.Path]::IsPathRooted($relative) -or $relative -match '^\.\.[\\/]' -or $relative.StartsWith('/')) {
      $problems += "invalid declared output"
      continue
    }
    $full = [System.IO.Path]::GetFullPath((Join-Path $OutputRoot $relative))
    if (-not (Test-PhysicalContainment -Path $full -Root $root)) {
      $problems += "declared output escapes"
      continue
    }
    $declaredKeys += $relative.ToLowerInvariant()
    if (-not $actualFiles.ContainsKey($relative.ToLowerInvariant())) {
      $problems += "missing declared output"
    } else {
      $actualHash = Get-ArtifactSha256 -Path $actualFiles[$relative.ToLowerInvariant()]
      if ([string]::IsNullOrWhiteSpace([string]$decl.sha256) -or $actualHash -ne ([string]$decl.sha256).ToLowerInvariant()) {
        $problems += "stale declared output digest"
      }
    }
  }
  foreach ($relativeLower in $actualFiles.Keys) {
    if ($declaredKeys -notcontains $relativeLower) { $problems += "undeclared output" }
  }
  return $problems
}

function Test-DesignProviderWorkflow {
  param(
    [string]$Project,
    [string]$Gate,
    $OrchestrationPolicy,
    $Policy,
    [string[]]$DecisionIds
  )

  $policy = $OrchestrationPolicy.ui_delivery
  $manifestPath = Get-DesignProviderManifestPath -Project $Project -OrchestrationPolicy $OrchestrationPolicy
  $manifestExists = Test-Path -LiteralPath $manifestPath -PathType Leaf
  $declared = Get-ProjectOrchestrationDeclarations $Project
  $trackActive = $manifestExists
  $requiredAtGate = (-not $manifestExists) -and ([string]$declared.UiDelivery -eq "claude_design") -and (@("Handoff", "Release") -contains $Gate)

  if (-not $trackActive -and -not $requiredAtGate) { return }
  # CR-014: the generator materializes placeholder manifests at Draft; those
  # are scaffolding, not a live track, so Draft stays tolerant of them.
  if ($Gate -eq "Draft") { return }

  if (-not $manifestExists) {
    Add-Result FAIL "Claude Design is the declared UI delivery path but DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json is missing" "DPROV-002" -Artifact "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json"
    return
  }

  try { $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
    Add-Result FAIL "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json is not valid JSON" "DPROV-002" -Artifact "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json"
    return
  }

  $reviewPath = Join-Path $Project ([string]$policy.review_manifest)
  $reviewExists = Test-Path -LiteralPath $reviewPath -PathType Leaf
  $outputRoot = Get-DesignProviderOutputRoot -Project $Project -OrchestrationPolicy $OrchestrationPolicy

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

  # CR-010: canonical minimum inputs -- PROJECT.md is always required; the
  # BUILD-SPEC is required when it exists. A raw source/** input needs an
  # explicit governed justification.
  $inputPaths = @($inputs | ForEach-Object { ([string]$_.path).Trim() })
  if ($inputPaths -notcontains "PROJECT.md") { $structureProblems += "missing PROJECT.md input" }
  if ((Test-Path -LiteralPath (Join-Path $Project "DESIGN/BUILD-SPEC.md") -PathType Leaf) -and ($inputPaths -notcontains "DESIGN/BUILD-SPEC.md")) {
    $structureProblems += "missing BUILD-SPEC input"
  }
  foreach ($input in $inputs) {
    $relative = ([string]$input.path).Trim()
    if (($relative -match '^(source/|\./source/|\.\.|/|\./)') -and [string]::IsNullOrWhiteSpace([string]$input.governed_justification)) {
      $structureProblems += "raw source input without justification"
    }
  }

  # ---------------------------------------------------------------- DPROV-003
  $freshnessProblems = @()
  $root = [System.IO.Path]::GetFullPath($Project)
  foreach ($input in $inputs) {
    $relative = [string]$input.path
    if (-not $relative -or [System.IO.Path]::IsPathRooted($relative) -or $relative -match '^\.\.[\\/]') {
      $freshnessProblems += "input path"; continue
    }
    $full = [System.IO.Path]::GetFullPath((Join-Path $Project $relative))
    # CR-017: physical containment -- a manifest input that symlinks out of
    # the project is rejected and never hashed.
    if (-not (Test-PhysicalContainment -Path $full -Root $root) -or -not (Test-Path -LiteralPath $full -PathType Leaf)) {
      $freshnessProblems += $relative
      continue
    }
    $claimed = [string]$input.sha256
    if ($claimed -notmatch '^[a-fA-F0-9]{64}$' -or
        (Get-ArtifactSha256 -Path $full) -ne $claimed.ToLowerInvariant()) {
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
  # CR-010: the manifest must cite an APPROVED externalization entry that
  # binds the same provider and carries the exact outgoing path+digest set.
  $externalizationProblems = @()
  $extRef = [string]$manifest.externalization
  $registryPath = Join-Path $Project ([string]$OrchestrationPolicy.externalization.registry)
  $approvedExt = $null
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
    $manifestProvider = ([string]$manifest.provider).Trim()
    $extProvider = ([string]$approvedExt.provider).Trim()
    $providerOk = ($extProvider.Length -gt 0 -and $manifestProvider.Length -gt 0 -and
      ($extProvider.IndexOf($manifestProvider, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
       $manifestProvider.IndexOf($extProvider, [System.StringComparison]::OrdinalIgnoreCase) -ge 0))
    if (-not $providerOk) { $externalizationProblems += "provider mismatch" }
    $extPayload = @{}
    foreach ($ref in @($approvedExt.outgoing_artifacts)) {
      $extPayload[([string]$ref.path).Trim().ToLowerInvariant()] = ([string]$ref.sha256).Trim().ToLowerInvariant()
    }
    foreach ($input in $inputs) {
      $pathKey = ([string]$input.path).Trim().ToLowerInvariant()
      $hash = ([string]$input.sha256).Trim().ToLowerInvariant()
      if (-not $extPayload.ContainsKey($pathKey) -or $extPayload[$pathKey] -ne $hash) {
        $externalizationProblems += "payload $(([string]$input.path).Trim())"
      }
    }
  }

  # ---------------------------------------------------------------- DPROV-005/006
  $preflightProblems = @()
  $authorityProblems = @()
  $review = $null
  $acceptance = $null
  if ($reviewExists) {
    try { $review = Get-Content -LiteralPath $reviewPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
      Add-Result FAIL "DESIGN/CLAUDE-DESIGN/REVIEW.json is not valid JSON" "DPROV-005" -Artifact "DESIGN/CLAUDE-DESIGN/REVIEW.json"
      return
    }
    $preflight = $review.preflight
    $acceptance = $review.acceptance
    $declaredOutputs = @($review.outputs)

    if (-not $preflight -or [string]$preflight.status -notmatch '^(passed|failed)$') {
      $preflightProblems += "preflight"
    } elseif ([string]$preflight.status -eq "failed") {
      $preflightProblems += "preflight failed"
    } else {
      # CR-001: the preflight must speak for the CURRENT manifest, not a stale
      # combined digest the provider no longer received.
      if ($freshnessProblems.Count -eq 0) {
        $declaredManifestDigest = [string]$preflight.manifest_digest
        if ($declaredManifestDigest -notmatch '^[a-fA-F0-9]{64}$' -or
            $declaredManifestDigest.ToLowerInvariant() -ne $declaredCombined.ToLowerInvariant()) {
          $preflightProblems += "stale manifest_digest"
        }
      }
      # CR-008: the recorded output set digest must be current, the declared
      # output inventory must match the actual OUTPUT/** file set, and a
      # reviewed provider must have produced something.
      $currentOutputs = Get-DesignOutputSetDigest -OutputRoot $outputRoot
      if ([string]::IsNullOrWhiteSpace([string]$preflight.outputs_digest) -or
          $preflight.outputs_digest.ToLowerInvariant() -ne $currentOutputs) {
        $preflightProblems += "stale outputs"
      }
      $inventoryProblems = @(Test-DesignOutputInventory -OutputRoot $outputRoot -DeclaredOutputs $declaredOutputs)
      $preflightProblems += $inventoryProblems
      if ($declaredOutputs.Count -eq 0) { $preflightProblems += "empty output inventory" }
    }

    # Any review decision recorded before a passing preflight is rejected.
    if ($acceptance -and [string]$acceptance.decision -and
        (-not $preflight -or [string]$preflight.status -ne "passed")) {
      $preflightProblems += "review before preflight"
    }
  } elseif (@("Handoff", "Release") -contains $Gate) {
    # CR-007: the provider review must exist and be accepted before the final
    # gates; absence of REVIEW.json at Handoff/Release is a hard failure.
    $preflightProblems += "review missing at $Gate"
  }

  if ($reviewExists) {
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
    # CR-007: at Handoff/Release the acceptance must be "accepted" by a Human.
    if (@("Handoff", "Release") -contains $Gate) {
      if (-not $acceptance -or [string]$acceptance.decision -ne "accepted") {
        $authorityProblems += "acceptance not accepted at $Gate"
      } elseif ([string]$acceptance.reviewer_kind -ne "human") {
        $authorityProblems += "acceptance not human at $Gate"
      }
    }
  }

  # ---------------------------------------------------------------- DPROV-007
  # CR-009: routing is DERIVED from impact/lens -- a self-asserted boolean is
  # never trusted. An accepted baseline cannot coexist with an unresolved
  # technical/scope finding or an unrouted one.
  $changeControlProblems = @()
  $findings = @()
  if ($reviewExists -and $review) { $findings = @($review.findings) }
  $registryIds = @()
  $registrySummaries = @()
  $registryPath = Join-Path $Project "CHANGE-REQUESTS.json"
  if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
    try {
      $crDoc = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($change in @($crDoc.changes)) {
        if ([string]$change.id) { $registryIds += [string]$change.id }
        if ([string]$change.summary) { $registrySummaries += [string]$change.summary }
      }
    } catch { }
  }
  $openBlockingFinding = $false
  foreach ($finding in $findings) {
    $findingId = [string]$finding.id
    $lens = [string]$finding.lens
    $impact = [string]$finding.impact
    $findingStatus = [string]$finding.status
    $summary = [string]$finding.summary
    $owner = [string]$finding.owner
    $decisionRef = [string]$finding.decision_ref
    if ($findingId -notmatch '^DP-\d{3,}$' -or
        @($policy.finding_lenses) -notcontains $lens -or
        @($policy.finding_impacts) -notcontains $impact -or
        @($policy.finding_statuses) -notcontains $findingStatus -or
        [string]::IsNullOrWhiteSpace($summary) -or (Test-PlaceholderValue $summary) -or
        [string]::IsNullOrWhiteSpace($owner) -or (Test-GenericOwner -Value $owner -OwnerPolicy $script:handoffPolicy.owner_policy)) {
      $changeControlProblems += "finding schema"
      continue
    }
    if ($findingStatus -eq "resolved") {
      $decider = if ($decisionRef -and $DecisionIds -contains $decisionRef) { Get-DecisionDecider -DecisionId $decisionRef } else { $null }
      if (-not $decisionRef -or $DecisionIds -notcontains $decisionRef -or $null -eq $decider -or (Test-GenericOwner -Value $decider -OwnerPolicy $script:handoffPolicy.owner_policy)) {
        $changeControlProblems += "$findingId resolution"
      }
    }
    # Derived routing: technical/scope impact OR lens must route to Change
    # Control. The change registry must mention the finding.
    $mustRoute = (@("technical", "scope") -contains $impact) -or (@("technical", "scope") -contains $lens)
    if ($mustRoute) {
      $routed = $false
      foreach ($id in $registryIds) {
        if ($id -and $summary -match [regex]::Escape($id)) { $routed = $true }
      }
      foreach ($entrySummary in $registrySummaries) {
        if ($entrySummary -match [regex]::Escape($findingId)) { $routed = $true }
      }
      if (-not $routed) { $changeControlProblems += "$findingId not routed" }
      if ($findingStatus -ne "resolved") { $openBlockingFinding = $true }
    }
  }
  if ($reviewExists -and $acceptance -and [string]$acceptance.decision -eq "accepted" -and $openBlockingFinding) {
    $changeControlProblems += "accepted with open blocking finding"
  }

  if ($structureProblems.Count) { Add-Result FAIL ("Design provider input manifest is incomplete: " + (($structureProblems | Sort-Object -Unique) -join ", ")) "DPROV-002" -Artifact "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json" }
  else { Add-Result PASS "Design provider input manifest declares the required contract" "DPROV-002" }
  if ($freshnessProblems.Count) { Add-Result FAIL ("Design provider manifest references or digests are invalid or stale: " + (($freshnessProblems | Sort-Object -Unique) -join ", ")) "DPROV-003" -Artifact "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json" }
  else { Add-Result PASS "Design provider manifest references and digests are current" "DPROV-003" }
  if ($externalizationProblems.Count) { Add-Result FAIL ("Design provider manifest externalization binding is invalid: " + (($externalizationProblems | Sort-Object -Unique) -join ", ")) "DPROV-004" -Artifact "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json" -Field "externalization" }
  else { Add-Result PASS "Design provider manifest cites a binding approved externalization entry" "DPROV-004" }
  if ($preflightProblems.Count) { Add-Result FAIL ("Design provider preflight or output contract is invalid: " + (($preflightProblems | Sort-Object -Unique) -join ", ")) "DPROV-005" -Artifact "DESIGN/CLAUDE-DESIGN/REVIEW.json" }
  elseif (-not $reviewExists) { Add-Result PASS "No design provider review recorded yet (preflight not required before review exists)" "DPROV-005" }
  else { Add-Result PASS "Design provider preflight and output placement are valid" "DPROV-005" }
  if ($authorityProblems.Count) { Add-Result FAIL ("Design provider review authority is invalid: " + (($authorityProblems | Sort-Object -Unique) -join ", ")) "DPROV-006" -Artifact "DESIGN/CLAUDE-DESIGN/REVIEW.json" }
  elseif (-not $reviewExists) { Add-Result PASS "No design provider review recorded yet" "DPROV-006" }
  else { Add-Result PASS "Design provider review carries valid Human acceptance evidence" "DPROV-006" }
  if ($changeControlProblems.Count) { Add-Result FAIL ("Design provider findings violate Change Control routing: " + (($changeControlProblems | Sort-Object -Unique) -join ", ")) "DPROV-007" -Artifact "DESIGN/CLAUDE-DESIGN/REVIEW.json" }
  else { Add-Result PASS "Design provider findings are routed through Change Control" "DPROV-007" }
}
