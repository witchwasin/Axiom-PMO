# Handoff gate checks (HANDOFF-001..HANDOFF-012).
#
# Scope boundary -- read this before adding a rule here:
#
#   This module checks the *declared contract* and nothing else. It reads what
#   the author wrote in HANDOFF.md, DESIGN/BUILD-SPEC.md, DELIVERY.md, and
#   HANDOFF-REVIEW.json, and verifies that the declarations are complete,
#   internally consistent, resolvable, and owned.
#
#   It must never infer domain meaning. It may not decide that a photo of a
#   vehicle is PII, that a stock feature needs a Receive operation, or that a
#   QR scanner needs a browser camera. Judgements like those are the job of the
#   semantic review (pmo-delivery, recorded in HANDOFF-REVIEW.json); this
#   module's only interest in them is whether the review exists, is current,
#   and has an owner for every finding it raised.
#
#   Concretely: HANDOFF-011 fires when a row the author marked "Contains
#   Sensitive Data = yes" has no classification decision. It does not fire
#   because the row is called "photo".

. (Join-Path $PSScriptRoot "ordinal-sort.ps1")

function Get-HandoffPolicySeverity {
  param(
    $SeverityMap,
    [string]$Mode,
    [string]$Default = "fail"
  )

  $value = $Default
  if ($SeverityMap) {
    $prop = $SeverityMap.PSObject.Properties[$Mode]
    if ($prop) { $value = [string]$prop.Value }
  }
  if ($value -eq "warn") { return "WARN" }
  return "FAIL"
}

function Get-HeadingPattern {
  param(
    [string]$Heading,
    [int]$Level = 2
  )
  $hashes = '#' * $Level
  return ('^\s*' + $hashes + '\s+' + [regex]::Escape($Heading) + '\s*$')
}

# Key/value lines of the form "- Key: value" that appear before the first
# section heading. Used for HANDOFF.md front matter and the Demo Milestone
# Field/Value table alike.
function Get-HandoffMetadata {
  param([string]$Text)

  $meta = @{}
  foreach ($line in ($Text -split "`r?`n")) {
    if ($line -match '^\s*##') { break }
    if ($line -match '^\s*[-*]\s*([^:]+?)\s*:\s*(.*)$') {
      $meta[$Matches[1].Trim()] = $Matches[2].Trim()
    }
  }
  return $meta
}

function Test-GenericOwner {
  param(
    [string]$Value,
    $OwnerPolicy
  )

  $trimmed = "$Value".Trim()
  if ($trimmed.Length -eq 0) { return $true }
  foreach ($token in @($OwnerPolicy.generic_tokens)) {
    if ($trimmed -ieq ([string]$token).Trim()) { return $true }
  }
  return (Test-PlaceholderValue $trimmed)
}

function Get-Sha256Hex {
  param([string]$Text)

  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = $sha.ComputeHash($bytes)
  } finally {
    $sha.Dispose()
  }
  return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
}

# Digest of PROJECT.md's Source Snapshot table. HANDOFF-REVIEW.json records the
# digest it was reasoned against; when the sources move, the recorded digest no
# longer matches and the review is stale. Rows are sorted so that reordering the
# table alone does not invalidate a review.
function Get-SourceSnapshotDigest {
  param([string]$ProjectText)

  $rows = @()
  $rows += Get-TableRowsAfterHeading $ProjectText '^##\s+Source Snapshot'
  $rows += Get-TableRowsAfterHeading $ProjectText '^##\s+Source Inventory'
  if ($rows.Count -eq 0) { return $null }

  $lines = @()
  foreach ($row in $rows) {
    $cells = @($row.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)".Trim() })
    $lines += ($cells -join '|')
  }
  return (Get-Sha256Hex -Text ((Sort-Ordinal -Values ([string[]]$lines)) -join "`n"))
}

# Digest of the governed artifacts the semantic review actually read.
#
# The source-snapshot digest alone is not enough. A reviewer reads DELIVERY.md,
# HANDOFF.md, and BUILD-SPEC.md; rewriting the build sequence or waiving a
# build-spec section afterwards leaves the source snapshot untouched, so the
# review would keep reporting as current while no longer describing the
# artifacts in front of it.
#
# Content is normalized (line endings, trailing whitespace, trailing blank
# lines) so a checkout or an editor's newline habits cannot invalidate a review.
# A file that does not exist contributes an explicit absent marker, so deleting
# a reviewed artifact invalidates the review just as editing it does.
function Get-ReviewInputDigest {
  param(
    [string]$Project,
    $HandoffPolicy
  )

  $files = @($HandoffPolicy.semantic_review.freshness.review_input_files)
  if ($files.Count -eq 0) { return $null }

  $parts = New-Object System.Collections.Generic.List[string]
  foreach ($relative in (Sort-Ordinal -Values ([string[]]$files))) {
    $path = Join-Path $Project $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      $parts.Add("$relative`n<absent>") | Out-Null
      continue
    }
    # -Encoding UTF8 is load-bearing, not tidiness. Windows PowerShell 5.1
    # decodes a BOM-less file with the machine's ANSI code page, so a UTF-8 em
    # dash (E2 80 94) arrives as three Windows-1252 characters instead of one
    # -- a different string, and therefore a different SHA-256, than pwsh 7
    # computes from the identical bytes. A review recorded on one host then
    # reads as stale on the other. See powershell-portability.md section 7.
    $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    if ($null -eq $content) { $content = "" }
    $normalized = ($content -replace "`r`n", "`n") -replace "[ \t]+(?=\n)", ""
    $parts.Add("$relative`n" + $normalized.TrimEnd()) | Out-Null
  }
  return (Get-Sha256Hex -Text ($parts -join "`n--`n"))
}

# Resolve the leading token of a cell as a typed reference.
#
# Decision columns are usually written as a reference plus a human-readable
# gloss ("DEC-003 internal-only, stays on the site network"). Requiring the
# whole cell to be a bare reference would strip that; accepting free text would
# make the column decorative. Requiring the cell to *lead* with a resolvable
# reference keeps both properties.
function Resolve-LeadingReference {
  param(
    [string]$Value,
    $DecisionIds,
    $RequirementIds
  )

  $trimmed = "$Value".Trim()
  if ($trimmed.Length -eq 0) { return $false }

  $token = ($trimmed -split '[\s,;]+')[0].Trim().TrimEnd('.', ':')
  if ($token.Length -eq 0) { return $false }

  $result = Resolve-Reference -Value $token `
    -ReferenceTypesConfig $script:referenceTypesConfig `
    -ProjectRoot $script:project `
    -DecisionIds $DecisionIds `
    -RequirementIds $RequirementIds
  return [bool]$result.Resolved
}

# Decider recorded against a decision-log row, or $null when the row does not
# exist. The column name varies a little across template generations, so the
# last non-empty cell that is not the id, date, or rationale is used as a
# fallback only when no explicit decider column is present.
function Get-DecisionDecider {
  param([string]$DecisionId)

  $path = Join-Path $script:project "decision-log.md"
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }

  $rows = @(Get-TableRowsAfterHeading (Get-Content -LiteralPath $path -Raw) '^#\s+Decision Log')
  if ($rows.Count -eq 0) {
    $rows = @(Get-TableRowsAfterHeading (Get-Content -LiteralPath $path -Raw) '^##?\s+')
  }
  foreach ($row in $rows) {
    if ("$($row.ID)".Trim() -ne $DecisionId) { continue }
    foreach ($column in @("Decided By", "Owner", "Approved By", "Decider")) {
      $prop = $row.PSObject.Properties[$column]
      if ($prop -and -not [string]::IsNullOrWhiteSpace("$($prop.Value)")) {
        return "$($prop.Value)".Trim()
      }
    }
    # The row exists but names nobody.
    return ""
  }
  return $null
}


# ---------------------------------------------------------------- HANDOFF-013
# Header row of the first pipe table under a heading, or $null when there is no
# table there.
function Get-TableHeaderCells {
  param(
    [string]$Text,
    [string]$Heading,
    [int]$Level = 2
  )

  $lines = @(Get-TableLinesAfterHeading $Text (Get-HeadingPattern -Heading $Heading -Level $Level))
  if ($lines.Count -lt 2) { return $null }

  $parts = @($lines[0] -split '\|')
  $cells = @()
  for ($i = 1; $i -lt ($parts.Count - 1); $i++) { $cells += $parts[$i].Trim() }
  return $cells
}

# Compare a table's header against the columns the policy declares.
#
# Reading cells by name means a renamed or reordered column does not error --
# `$row.'Blocking Point'` simply resolves to an empty string, and the gate then
# reports "no valid blocking point" about a cell the author filled in. Naming
# the header mismatch turns a misleading downstream complaint into one accurate
# diagnostic.
function Test-TableHeader {
  param(
    [string]$Text,
    [string]$Heading,
    [int]$Level,
    [string[]]$Expected,
    [string]$Artifact,
    $HandoffPolicy
  )

  $policy = $HandoffPolicy.table_headers
  if (-not $policy -or -not $policy.enforce) { return $true }
  if ($null -eq $Expected -or $Expected.Count -eq 0) { return $true }

  $actual = Get-TableHeaderCells -Text $Text -Heading $Heading -Level $Level
  # No table at all is a different rule's finding (HANDOFF-002 / HANDOFF-005).
  if ($null -eq $actual) { return $true }

  $expectedList = [string[]]@($Expected)
  if (($actual -join '|') -eq ($expectedList -join '|')) { return $true }

  # Distinguish the two failures: a reordered header is a different mistake
  # from a renamed or missing one, and the fix differs.
  $sameSet = ((Sort-Ordinal -Values ([string[]]$actual)) -join '|') -eq
             ((Sort-Ordinal -Values $expectedList) -join '|')
  if ($sameSet -and $policy.order_matters) {
    Add-Result FAIL "Table '$Heading' has the declared columns in a different order (expected: $($expectedList -join ' | '))" "HANDOFF-013" $true `
      -Artifact $Artifact -Field $Heading
    return $false
  }

  $missing = @($expectedList | Where-Object { $actual -notcontains $_ })
  $unexpected = @($actual | Where-Object { $expectedList -notcontains $_ })
  $detail = @()
  if ($missing.Count -gt 0) { $detail += "missing: " + ($missing -join ', ') }
  if ($unexpected.Count -gt 0) { $detail += "unexpected: " + ($unexpected -join ', ') }

  Add-Result FAIL "Table '$Heading' header does not match the declared columns ($($detail -join '; '))" "HANDOFF-013" $true `
    -Artifact $Artifact -Field $Heading
  return $false
}

# ---------------------------------------------------------------- HANDOFF-014
# The project's own name for itself, taken from PROJECT.md's heading.
function Get-DeclaredProjectCode {
  param(
    [string]$ProjectText,
    $HandoffPolicy
  )

  $pattern = [string]$HandoffPolicy.project_identity.authority_pattern
  if ([string]::IsNullOrWhiteSpace($pattern)) { return $null }
  if ($ProjectText -match "(?m)$pattern") { return $Matches[1].Trim() }
  return $null
}

function Test-HandoffReadiness {
  param(
    [string]$Project,
    [string]$Mode,
    [string]$Gate,
    $HandoffPolicy,
    $PolicyEnums,
    $WorkItems,
    $DeliveryIds,
    $ProjectReqIds,
    $DecisionIds,
    [string]$ProjectText
  )

  $ownerPolicy = $HandoffPolicy.owner_policy
  $ownerLevel = Get-HandoffPolicySeverity -SeverityMap $ownerPolicy.severity_by_mode -Mode $Mode
  # Ownership is checked in five places across two artifacts. Counting the
  # problems lets the summary PASS be suppressed when any of them fired --
  # otherwise a report shows "[FAIL] HANDOFF-003 ... no named owner" three lines
  # above "[PASS] HANDOFF-003 ... has a named owner", which reads as a bug.
  $script:handoffOwnerProblems = 0
  # Set by Test-BuildSpec, which runs in its own function; the HANDOFF.md side
  # tracks its own local flag.
  $script:handoffHeaderOk = $true
  $handoffDoc = $HandoffPolicy.handoff_document
  $handoffPath = Join-Path $Project "HANDOFF.md"

  if (-not (Test-Path -LiteralPath $handoffPath -PathType Leaf)) {
    Add-Result FAIL "HANDOFF.md is required at the Handoff gate but was not found" "HANDOFF-001" $true `
      -Artifact "HANDOFF.md"
    return
  }
  $handoffText = Get-Content -LiteralPath $handoffPath -Raw

  # ---------------------------------------------------------------- HANDOFF-001
  # Metadata contract: who is handing over, to what target, by when.
  $meta = Get-HandoffMetadata -Text $handoffText
  $metaProblems = @()
  $handoffTarget = ""
  foreach ($field in @($handoffDoc.metadata_fields)) {
    $key = [string]$field.key
    $isRequired = $false
    if ($field.required) { $isRequired = [bool]$field.required }
    if ($field.required_modes) { $isRequired = (@($field.required_modes) -contains $Mode) }
    if (-not $isRequired) { continue }

    if (-not $meta.ContainsKey($key)) {
      $metaProblems += $key
      continue
    }
    $value = [string]$meta[$key]
    if (Test-PlaceholderValue $value) {
      $metaProblems += $key
      continue
    }
    if ($field.owner_field -and (Test-GenericOwner -Value $value -OwnerPolicy $ownerPolicy)) {
      Add-Result $ownerLevel "Handoff metadata '$key' is a generic placeholder, not a named person" "HANDOFF-003" $true `
        -Artifact "HANDOFF.md" -Field $key
      $script:handoffOwnerProblems++
    }
    if ($key -eq "Handoff Target") { $handoffTarget = $value.ToLowerInvariant() }

    # A metadata field that is filled in but wrong is worse than a blank one:
    # it reads as settled. Each of these is checkable against something the
    # project already declares.
    if ($key -eq "Mode" -and $value -ne $Mode) {
      $metaProblems += "$key says '$value' but the effective mode is '$Mode'"
    }
    if ($key -eq "Horizon" -and -not (Test-DateValue $value)) {
      $metaProblems += "$key '$value' is not an ISO-8601 date (yyyy-MM-dd)"
    }
    if ($key -eq "Build Spec Ref" -and -not (Test-Path -LiteralPath (Join-Path $Project $value) -PathType Leaf)) {
      $metaProblems += "$key points at '$value', which does not exist"
    }
  }
  if ($metaProblems.Count -gt 0) {
    Add-Result FAIL ("HANDOFF.md metadata is incomplete: " + ($metaProblems -join ', ')) "HANDOFF-001" $true `
      -Artifact "HANDOFF.md"
  } else {
    Add-Result PASS "HANDOFF.md declares complete handoff metadata" "HANDOFF-001"
  }

  # ---------------------------------------------------------------- HANDOFF-014
  # A handoff sheet that names a different project than PROJECT.md is the
  # signature of a project started by copying another. Every other check passes,
  # and a later reader cannot tell which of the two documents is wrong.
  Test-HandoffProjectIdentity -Project $Project -ProjectText $ProjectText -Metadata $meta -HandoffPolicy $HandoffPolicy

  if ($handoffTarget -and (@($HandoffPolicy.handoff_targets) -notcontains $handoffTarget)) {
    Add-Result FAIL "Handoff Target '$handoffTarget' is not one of: $(@($HandoffPolicy.handoff_targets) -join ', ')" "HANDOFF-001" $true `
      -Artifact "HANDOFF.md" -Field "Handoff Target"
  }

  $buildSpecRequired = @($HandoffPolicy.required_artifacts.$Mode) -contains "DESIGN/BUILD-SPEC.md"
  $buildSpecPath = Join-Path $Project "DESIGN/BUILD-SPEC.md"
  $buildSpecExists = Test-Path -LiteralPath $buildSpecPath -PathType Leaf
  if ($buildSpecRequired -and -not $buildSpecExists) {
    Add-Result FAIL "DESIGN/BUILD-SPEC.md is required for $Mode handoff but was not found" "HANDOFF-001" $true `
      -Artifact "DESIGN/BUILD-SPEC.md"
  }

  # ---------------------------------------------------------------- HANDOFF-002
  # Scope contract: what is being built now, what is explicitly not, and what
  # constrains it. "Nothing deferred" is a valid answer, but it has to be
  # written down -- an empty section is silence, not a decision.
  $sectionRows = @{}
  $headerOk = $true
  foreach ($section in @($handoffDoc.sections)) {
    $heading = [string]$section.heading
    $rows = @(Get-TableRowsAfterHeading $handoffText (Get-HeadingPattern -Heading $heading -Level 2))
    $sectionRows[$heading] = $rows

    if ($section.table -and $section.columns) {
      if (-not (Test-TableHeader -Text $handoffText -Heading $heading -Level 2 `
          -Expected ([string[]]@($section.columns)) -Artifact "HANDOFF.md" -HandoffPolicy $HandoffPolicy)) {
        $headerOk = $false
      }
    }

    $applies = $true
    if ($section.required_targets) {
      $applies = (@($section.required_targets) -contains $handoffTarget)
    } elseif ($section.required -ne $true) {
      $applies = $false
    }
    if (-not $applies) { continue }

    $minRows = 0
    if ($null -ne $section.min_rows) { $minRows = [int]$section.min_rows }

    if ($rows.Count -ge [Math]::Max($minRows, 1)) { continue }

    if ($rows.Count -eq 0 -and $minRows -eq 0 -and $section.allow_explicit_none) {
      # An explicit "none" line under the heading is the author saying "I
      # considered this and there is nothing"; a blank section is not.
      $body = Get-SectionBody -Text $handoffText -Heading $heading -Level 2
      $noneToken = [string]$handoffDoc.deferred_explicit_none_token
      if ($body -and ($body -match ('(?im)^\s*' + [regex]::Escape($noneToken) + '\b'))) {
        continue
      }
    }

    $ruleId = if ($section.rule) { [string]$section.rule } else { "HANDOFF-002" }
    Add-Result FAIL "HANDOFF.md section '$heading' has no entries and no explicit 'none' declaration" $ruleId $true `
      -Artifact "HANDOFF.md" -Field $heading
  }

  $buildNowRows = @($sectionRows["Build Now"])
  $unresolvedBuildNow = @()
  foreach ($row in $buildNowRows) {
    foreach ($ref in (Split-ReferenceValues $row.'Work Item Ref')) {
      if (@($DeliveryIds) -notcontains $ref) { $unresolvedBuildNow += $ref }
    }
    if (Test-GenericOwner -Value $row.Owner -OwnerPolicy $ownerPolicy) {
      Add-Result $ownerLevel "Build Now item '$($row.Item)' has no named owner" "HANDOFF-003" $true `
        -Artifact "HANDOFF.md" -ItemId ([string]$row.Item) -Field "Owner"
      $script:handoffOwnerProblems++
    }
  }
  if ($unresolvedBuildNow.Count -gt 0) {
    Add-Result FAIL ("Build Now references work items that do not exist in DELIVERY.md: " + ((Sort-OrdinalUnique -Values ([string[]]$unresolvedBuildNow)) -join ', ')) "HANDOFF-002" $true `
      -Artifact "HANDOFF.md" -Field "Work Item Ref"
  } elseif ($buildNowRows.Count -gt 0) {
    Add-Result PASS "Build Now scope resolves to declared work items" "HANDOFF-002"
  }

  # ---------------------------------------------------------------- HANDOFF-003
  # Every work item that Build Now points at needs a real owner in DELIVERY.md
  # too -- naming an owner in the handoff sheet but leaving the board's Owner
  # column as "Dev Team" is exactly the ambiguity this rule exists to catch.
  $buildNowRefs = @()
  foreach ($row in $buildNowRows) { $buildNowRefs += (Split-ReferenceValues $row.'Work Item Ref') }
  $buildNowRefs = @(Sort-OrdinalUnique -Values ([string[]]$buildNowRefs))
  $unownedItems = @()
  foreach ($item in @($WorkItems)) {
    if ($buildNowRefs -notcontains $item.ID) { continue }
    if (Test-GenericOwner -Value $item.Owner -OwnerPolicy $ownerPolicy) { $unownedItems += $item.ID }
  }
  if ($unownedItems.Count -gt 0) {
    Add-Result $ownerLevel ("Work items in the handoff scope have no named owner: " + ($unownedItems -join ', ')) "HANDOFF-003" $true `
      -Artifact "DELIVERY.md" -Field "Owner"
    $script:handoffOwnerProblems++
  }

  # ---------------------------------------------------------------- HANDOFF-004
  Test-HandoffBuildSequence -HandoffText $handoffText -Rows @($sectionRows["Build Sequence and Dependencies"]) `
    -BuildNowRefs $buildNowRefs -DeliveryIds $DeliveryIds -OwnerPolicy $ownerPolicy -OwnerLevel $ownerLevel

  if ($script:handoffOwnerProblems -eq 0) {
    Add-Result PASS "Every owner in the handoff scope names a person, in HANDOFF.md and DELIVERY.md" "HANDOFF-003"
  }

  # ---------------------------------------------------------------- HANDOFF-009
  Test-HandoffOpenActions -Rows @($sectionRows["Open Actions"]) -HandoffPolicy $HandoffPolicy `
    -OwnerPolicy $ownerPolicy -OwnerLevel $ownerLevel

  # ---------------------------------------------------------------- HANDOFF-008
  if (@($handoffDoc.demo_milestone_fields) -and (@("demo", "pilot") -contains $handoffTarget)) {
    Test-HandoffDemoMilestone -Rows @($sectionRows["Demo Milestone"]) -HandoffPolicy $HandoffPolicy `
      -OwnerPolicy $ownerPolicy
  }

  # ---------------------------------------------------------------- HANDOFF-012
  Test-HandoffEnvironmentMatrix -Rows @($sectionRows["Environment and Device Matrix"]) -HandoffPolicy $HandoffPolicy -DecisionIds $DecisionIds

  # ------------------------------------------------- HANDOFF-005/006/007/011/012
  if ($buildSpecExists) {
    Test-BuildSpec -Project $Project -Mode $Mode -HandoffTarget $handoffTarget -HandoffPolicy $HandoffPolicy `
      -ProjectReqIds $ProjectReqIds -DecisionIds $DecisionIds
  }

  if ($headerOk -and $script:handoffHeaderOk) {
    Add-Result PASS "Every governed table header matches the columns the policy declares" "HANDOFF-013"
  }

  # ---------------------------------------------------------------- HANDOFF-010
  Test-HandoffSemanticReview -Project $Project -Mode $Mode -HandoffPolicy $HandoffPolicy -ProjectText $ProjectText -DecisionIds $DecisionIds
}

# Raw text between a heading and the next heading of the same or higher level.
function Get-SectionBody {
  param(
    [string]$Text,
    [string]$Heading,
    [int]$Level = 2
  )

  $lines = $Text -split "`r?`n"
  $pattern = Get-HeadingPattern -Heading $Heading -Level $Level
  $start = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $pattern) { $start = $i; break }
  }
  if ($start -lt 0) { return $null }

  $body = @()
  for ($i = $start + 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match ('^\s*#{1,' + $Level + '}\s+')) { break }
    $body += $lines[$i]
  }
  return ($body -join "`n")
}

function Test-HandoffProjectIdentity {
  param(
    [string]$Project,
    [string]$ProjectText,
    $Metadata,
    $HandoffPolicy
  )

  $policy = $HandoffPolicy.project_identity
  if (-not $policy -or -not $policy.enforce) { return }

  $declared = Get-DeclaredProjectCode -ProjectText $ProjectText -HandoffPolicy $HandoffPolicy
  if ([string]::IsNullOrWhiteSpace($declared)) {
    # PROJECT.md has no identifying heading. That is a shape problem for the
    # project template, not something this rule can adjudicate.
    return
  }

  $mismatches = @()
  foreach ($target in @($policy.cross_checked)) {
    $artifact = [string]$target.artifact
    $field = [string]$target.field
    $actual = $null

    if ([string]$target.kind -eq "metadata") {
      if ($Metadata.ContainsKey($field)) { $actual = [string]$Metadata[$field] }
    } else {
      $path = Join-Path $Project $artifact
      if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
      try {
        $doc = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $prop = $doc.PSObject.Properties[$field]
        if ($prop) { $actual = [string]$prop.Value }
      } catch {
        # Unparseable JSON is HANDOFF-010's finding, not this rule's.
        continue
      }
    }

    if ([string]::IsNullOrWhiteSpace($actual)) { continue }
    if ($actual.Trim() -cne $declared) {
      $mismatches += [pscustomobject]@{ Artifact = $artifact; Field = $field; Value = $actual.Trim() }
    }
  }

  if ($mismatches.Count -gt 0) {
    foreach ($m in $mismatches) {
      Add-Result FAIL "$($m.Artifact) names project '$($m.Value)' but PROJECT.md declares '$declared'" "HANDOFF-014" $true `
        -Artifact $m.Artifact -Field $m.Field
    }
  } else {
    Add-Result PASS "Handoff artifacts agree with PROJECT.md on the project code" "HANDOFF-014"
  }
}

function Test-HandoffBuildSequence {
  param(
    [string]$HandoffText,
    $Rows,
    $BuildNowRefs,
    $DeliveryIds,
    $OwnerPolicy,
    [string]$OwnerLevel
  )

  $rows = @($Rows)
  if ($rows.Count -eq 0) { return }

  $problems = @()
  $stepOf = @{}
  $seenSteps = @{}

  foreach ($row in $rows) {
    $step = "$($row.Step)".Trim()
    if ($step -notmatch '^\d+$') {
      $problems += "step '$step' is not a number"
      continue
    }
    if ($seenSteps.ContainsKey($step)) {
      $problems += "step $step is used more than once"
    }
    $seenSteps[$step] = $true
    foreach ($ref in (Split-ReferenceValues $row.'Work Item Ref')) {
      $stepOf[$ref] = [int]$step
    }
  }

  foreach ($row in $rows) {
    $refs = @(Split-ReferenceValues $row.'Work Item Ref')
    foreach ($ref in $refs) {
      if (@($DeliveryIds) -notcontains $ref) {
        $problems += "$ref is sequenced but is not a DELIVERY.md work item"
      }
    }
    if (Test-GenericOwner -Value $row.Owner -OwnerPolicy $OwnerPolicy) {
      Add-Result $OwnerLevel "Build sequence step $($row.Step) has no named owner" "HANDOFF-003" $true `
        -Artifact "HANDOFF.md" -ItemId ("step " + [string]$row.Step) -Field "Owner"
      $script:handoffOwnerProblems++
    }

    $dependsRaw = "$($row.'Depends On')".Trim()
    if ($dependsRaw.Length -eq 0 -or (Test-PlaceholderValue $dependsRaw)) {
      $problems += "step $($row.Step) does not declare its dependencies (use 'none' when there are none)"
      continue
    }
    if ($dependsRaw -ieq "none") { continue }

    $consumerStep = if ($refs.Count -gt 0 -and $stepOf.ContainsKey($refs[0])) { $stepOf[$refs[0]] } else { $null }
    foreach ($dep in (Split-ReferenceValues $dependsRaw)) {
      if (-not $stepOf.ContainsKey($dep)) {
        $problems += "step $($row.Step) depends on $dep, which is not scheduled anywhere in the sequence"
        continue
      }
      # The TestBiz failure mode: an item depends on a shared prerequisite that
      # is scheduled to be built after it. The validator can prove this from
      # the declared step numbers alone.
      if ($null -ne $consumerStep -and $stepOf[$dep] -ge $consumerStep) {
        $problems += "step $($row.Step) depends on $dep, which is scheduled at step $($stepOf[$dep]) (not before it)"
      }
    }
  }

  foreach ($ref in @($BuildNowRefs)) {
    if (-not $stepOf.ContainsKey($ref)) {
      $problems += "$ref is in Build Now but has no place in the build sequence"
    }
  }

  if ($problems.Count -gt 0) {
    foreach ($problem in (Sort-OrdinalUnique -Values ([string[]]$problems))) {
      Add-Result FAIL "Build sequence is not executable as declared: $problem" "HANDOFF-004" $true `
        -Artifact "HANDOFF.md" -Field "Build Sequence and Dependencies"
    }
  } else {
    Add-Result PASS "Build sequence is complete and dependency-ordered" "HANDOFF-004"
  }
}

function Test-HandoffOpenActions {
  param(
    $Rows,
    $HandoffPolicy,
    $OwnerPolicy,
    [string]$OwnerLevel
  )

  $rows = @($Rows)
  if ($rows.Count -eq 0) {
    Add-Result PASS "No open actions declared at handoff" "HANDOFF-009"
    return
  }

  $validPoints = @($HandoffPolicy.blocking_points)
  $problems = 0
  foreach ($row in $rows) {
    $actionId = "$($row.'Action ID')".Trim()
    $point = "$($row.'Blocking Point')".Trim()
    if ($point.Length -eq 0 -or (Test-PlaceholderValue $point) -or ($validPoints -notcontains $point)) {
      Add-Result FAIL "Open action $actionId has no valid blocking point (expected one of: $($validPoints -join ', '))" "HANDOFF-009" $true `
        -Artifact "HANDOFF.md" -ItemId $actionId -Field "Blocking Point"
      $problems++
    }
    if (Test-GenericOwner -Value $row.Owner -OwnerPolicy $OwnerPolicy) {
      Add-Result FAIL "Open action $actionId has no named owner" "HANDOFF-009" $true `
        -Artifact "HANDOFF.md" -ItemId $actionId -Field "Owner"
      $problems++
    }
  }
  if ($problems -eq 0) {
    Add-Result PASS "Every open action has an owner and a blocking point" "HANDOFF-009"
  }
}

function Test-HandoffDemoMilestone {
  param(
    $Rows,
    $HandoffPolicy,
    $OwnerPolicy
  )

  $lookup = @{}
  foreach ($row in @($Rows)) {
    $key = "$($row.Field)".Trim()
    if ($key.Length -gt 0) { $lookup[$key] = "$($row.Value)".Trim() }
  }

  $missing = @()
  foreach ($field in @($HandoffPolicy.handoff_document.demo_milestone_fields)) {
    $key = [string]$field.key
    if (-not $field.required) { continue }
    if (-not $lookup.ContainsKey($key) -or (Test-PlaceholderValue $lookup[$key])) {
      $missing += $key
      continue
    }
    if ($field.owner_field -and (Test-GenericOwner -Value $lookup[$key] -OwnerPolicy $OwnerPolicy)) {
      $missing += "$key (generic, not a named person)"
    }
  }

  if ($missing.Count -gt 0) {
    Add-Result FAIL ("Demo milestone is not operable as declared -- missing: " + ($missing -join ', ')) "HANDOFF-008" $true `
      -Artifact "HANDOFF.md" -Field "Demo Milestone"
  } else {
    Add-Result PASS "Demo milestone declares device, integrator, capacity, and reset path" "HANDOFF-008"
  }
}

function Test-HandoffEnvironmentMatrix {
  param(
    $Rows,
    $HandoffPolicy,
    $DecisionIds
  )

  $rows = @($Rows)
  if ($rows.Count -eq 0) { return }

  $unresolved = @($HandoffPolicy.environment_capabilities.unresolved_tokens)
  $problems = @()
  foreach ($row in $rows) {
    $env = "$($row.Environment)".Trim()
    foreach ($column in @("Serving Model", "Decision Ref")) {
      $value = "$($row.$column)".Trim()
      $isUnresolved = ($value.Length -eq 0) -or (Test-PlaceholderValue $value)
      foreach ($token in $unresolved) {
        if ($value -ieq ([string]$token).Trim()) { $isUnresolved = $true }
      }
      if ($isUnresolved) {
        $problems += @{ Env = $env; Column = $column; Reason = "is unresolved" }
        continue
      }
      # "Decision Ref" is a reference column. Free text there means the decision
      # was described rather than recorded, and nothing can be traced back to it.
      if ($column -eq "Decision Ref" -and -not (Resolve-LeadingReference -Value $value -DecisionIds $DecisionIds)) {
        $problems += @{ Env = $env; Column = $column; Reason = "does not lead with a resolvable reference" }
      }
    }
  }

  if ($problems.Count -gt 0) {
    foreach ($problem in $problems) {
      Add-Result FAIL "Environment '$($problem.Env)' $($problem.Column) $($problem.Reason); a developer cannot pick a runtime from this" "HANDOFF-012" $true `
        -Artifact "HANDOFF.md" -ItemId $problem.Env -Field $problem.Column
    }
  } else {
    Add-Result PASS "Environment and device matrix declares a resolved serving model for every environment" "HANDOFF-012"
  }
}

function Test-BuildSpec {
  param(
    [string]$Project,
    [string]$Mode,
    [string]$HandoffTarget,
    $HandoffPolicy,
    $ProjectReqIds,
    $DecisionIds
  )

  $spec = $HandoffPolicy.build_spec
  $text = Get-Content -LiteralPath (Join-Path $Project "DESIGN/BUILD-SPEC.md") -Raw
  $statusMarker = [string]$spec.status_marker
  $rationaleMarker = [string]$spec.rationale_marker
  $minWords = [int]$spec.not_required_policy.min_rationale_words

  $sectionProblems = @()
  foreach ($section in @($spec.sections)) {
    $heading = [string]$section.heading
    $applies = $false
    if ($section.required_modes -and (@($section.required_modes) -contains $Mode)) { $applies = $true }
    if ($section.required_targets -and (@($section.required_targets) -contains $HandoffTarget)) { $applies = $true }
    if (-not $applies) { continue }

    $body = Get-SectionBody -Text $text -Heading $heading -Level 3
    if ($null -eq $body) {
      $sectionProblems += "'$heading' is missing"
      continue
    }

    $status = $null
    if ($body -match ('(?im)^\s*' + [regex]::Escape($statusMarker) + '\s*:\s*(\S+)\s*$')) {
      $status = $Matches[1].Trim().ToLowerInvariant()
    }
    if (-not $status) {
      $sectionProblems += "'$heading' does not declare a $statusMarker line"
      continue
    }
    if (@($spec.status_values) -notcontains $status) {
      $sectionProblems += "'$heading' has $statusMarker '$status', expected one of: $(@($spec.status_values) -join ', ')"
      continue
    }

    if ($status -eq "not_required") {
      # not_required is a governed waiver, not an escape hatch: the policy has
      # to permit it for this section, and the author has to say why.
      if (-not $section.allow_not_required) {
        $sectionProblems += "'$heading' is marked not_required but policy does not allow waiving it"
        continue
      }
      $rationale = ""
      if ($body -match ('(?im)^\s*' + [regex]::Escape($rationaleMarker) + '\s*:\s*(.+)$')) {
        $rationale = $Matches[1].Trim()
      }
      if ($rationale.Length -eq 0 -or (Test-PlaceholderValue $rationale)) {
        $sectionProblems += "'$heading' is marked not_required without a $rationaleMarker"
      } elseif (@($rationale -split '\s+').Count -lt $minWords) {
        $sectionProblems += "'$heading' has a $rationaleMarker shorter than $minWords words"
      }
      continue
    }

    # status = specified
    $contentLines = @($body -split "`r?`n" | Where-Object {
      $trimmed = $_.Trim()
      $trimmed.Length -gt 0 -and $trimmed -notmatch ('^' + [regex]::Escape($statusMarker) + '\s*:')
    })
    if ($contentLines.Count -eq 0) {
      $sectionProblems += "'$heading' is marked specified but has no content"
      continue
    }
    if ($section.table) {
      $rows = @(Get-TableRowsAfterHeading $text (Get-HeadingPattern -Heading $heading -Level 3))
      if ($rows.Count -eq 0) {
        $sectionProblems += "'$heading' is marked specified but its table has no rows"
      }
      if ($section.columns) {
        if (-not (Test-TableHeader -Text $text -Heading $heading -Level 3 `
            -Expected ([string[]]@($section.columns)) -Artifact "DESIGN/BUILD-SPEC.md" -HandoffPolicy $HandoffPolicy)) {
          $script:handoffHeaderOk = $false
        }
      }
    }
  }

  if ($sectionProblems.Count -gt 0) {
    foreach ($problem in $sectionProblems) {
      Add-Result FAIL "BUILD-SPEC section $problem" "HANDOFF-005" $true -Artifact "DESIGN/BUILD-SPEC.md"
    }
  } else {
    Add-Result PASS "BUILD-SPEC declares every section required for $Mode handoff" "HANDOFF-005"
  }

  Test-BuildSpecAcceptanceCases -Text $text -HandoffPolicy $HandoffPolicy -ProjectReqIds $ProjectReqIds
  Test-BuildSpecDataInventory -Text $text -HandoffPolicy $HandoffPolicy -DecisionIds $DecisionIds
  Test-BuildSpecCapabilities -Text $text -HandoffPolicy $HandoffPolicy -DecisionIds $DecisionIds
}

function Test-BuildSpecAcceptanceCases {
  param(
    [string]$Text,
    $HandoffPolicy,
    $ProjectReqIds
  )

  $rows = @(Get-TableRowsAfterHeading $Text (Get-HeadingPattern -Heading "Acceptance Cases" -Level 3))
  if ($rows.Count -eq 0) { return }

  $classes = @($HandoffPolicy.acceptance_cases.execution_classes)
  $missingClass = 0
  $missingFixture = 0

  foreach ($row in $rows) {
    $caseId = "$($row.'Case ID')".Trim()

    # A case that cites a requirement nobody declared is untraceable: it cannot
    # be shown to cover anything, and it will not appear in an RTM.
    $requirementRef = "$($row.'Requirement Ref')".Trim()
    $unresolvedReqs = @()
    foreach ($ref in (Split-ReferenceValues $requirementRef)) {
      if (@($ProjectReqIds) -notcontains $ref) { $unresolvedReqs += $ref }
    }
    if ($requirementRef.Length -eq 0 -or (Test-PlaceholderValue $requirementRef)) {
      Add-Result FAIL "Acceptance case $caseId cites no requirement" "HANDOFF-006" $true `
        -Artifact "DESIGN/BUILD-SPEC.md" -ItemId $caseId -Field "Requirement Ref"
      $missingClass++
    } elseif ($unresolvedReqs.Count -gt 0) {
      Add-Result FAIL ("Acceptance case $caseId cites requirements not declared in PROJECT.md: " + ($unresolvedReqs -join ', ')) "HANDOFF-006" $true `
        -Artifact "DESIGN/BUILD-SPEC.md" -ItemId $caseId -Field "Requirement Ref"
      $missingClass++
    }

    $execution = "$($row.Execution)".Trim().ToLowerInvariant()
    if ($execution.Length -eq 0 -or ($classes -notcontains $execution)) {
      Add-Result FAIL "Acceptance case $caseId has no execution class (expected one of: $($classes -join ', '))" "HANDOFF-006" $true `
        -Artifact "DESIGN/BUILD-SPEC.md" -ItemId $caseId -Field "Execution"
      $missingClass++
    }

    # A case that cannot be reached from the declared seed data cannot be run
    # on demo day, whoever runs it.
    $fixture = "$($row.'Fixture / Seed')".Trim()
    if ($fixture.Length -eq 0 -or (Test-PlaceholderValue $fixture)) {
      Add-Result FAIL "Acceptance case $caseId declares no seed or fixture strategy" "HANDOFF-007" $true `
        -Artifact "DESIGN/BUILD-SPEC.md" -ItemId $caseId -Field "Fixture / Seed"
      $missingFixture++
    }
    $reset = "$($row.Reset)".Trim()
    if ($reset.Length -eq 0 -or (Test-PlaceholderValue $reset)) {
      Add-Result FAIL "Acceptance case $caseId declares no reset strategy" "HANDOFF-007" $true `
        -Artifact "DESIGN/BUILD-SPEC.md" -ItemId $caseId -Field "Reset"
      $missingFixture++
    }
  }

  if ($missingClass -eq 0) {
    Add-Result PASS "Every acceptance case is classified automated or manual" "HANDOFF-006"
  }
  if ($missingFixture -eq 0) {
    Add-Result PASS "Every acceptance case declares seed and reset strategy" "HANDOFF-007"
  }
}

function Test-BuildSpecDataInventory {
  param(
    [string]$Text,
    $HandoffPolicy,
    $DecisionIds
  )

  $rows = @(Get-TableRowsAfterHeading $Text (Get-HeadingPattern -Heading "Security, Privacy and Data Inventory" -Level 3))
  if ($rows.Count -eq 0) { return }

  $yesValues = @($HandoffPolicy.sensitive_data.declared_yes_values)
  $noValues = @($HandoffPolicy.sensitive_data.declared_no_values)
  $requireExplicit = [bool]$HandoffPolicy.sensitive_data.requires_explicit_declaration
  $problems = 0
  foreach ($row in $rows) {
    $element = "$($row.'Data Element')".Trim()
    $declared = "$($row.'Contains Sensitive Data')".Trim().ToLowerInvariant()
    $isSensitive = $false
    $isNotSensitive = $false
    foreach ($value in $yesValues) {
      if ($declared -eq ([string]$value).ToLowerInvariant()) { $isSensitive = $true }
    }
    foreach ($value in $noValues) {
      if ($declared -eq ([string]$value).ToLowerInvariant()) { $isNotSensitive = $true }
    }

    # "maybe", "unclear", or blank is an *undeclared* classification, not a
    # negative one. Treating anything-that-is-not-yes as no let a row opt out
    # of this rule by being vague -- the exact move a data inventory exists to
    # prevent. The author still decides; the validator only insists that they do.
    if ($requireExplicit -and -not $isSensitive -and -not $isNotSensitive) {
      Add-Result FAIL "Data element '$element' does not declare whether it contains sensitive data (expected one of: $((@($yesValues) + @($noValues)) -join ', '))" "HANDOFF-011" $true `
        -Artifact "DESIGN/BUILD-SPEC.md" -ItemId $element -Field "Contains Sensitive Data"
      $problems++
      continue
    }

    # The author's own declaration is the trigger. The validator does not read
    # the element's name and decide for itself whether it is sensitive.
    if (-not $isSensitive) { continue }

    foreach ($column in @("Classification Decision", "Retention Decision")) {
      $value = "$($row.$column)".Trim()
      if ($value.Length -eq 0 -or (Test-PlaceholderValue $value)) {
        Add-Result FAIL "Data element '$element' is declared sensitive but has no $column" "HANDOFF-011" $true `
          -Artifact "DESIGN/BUILD-SPEC.md" -ItemId $element -Field $column
        $problems++
      } elseif (-not (Resolve-LeadingReference -Value $value -DecisionIds $DecisionIds)) {
        # Prose describing a decision is not a decision. The cell may carry a
        # human-readable gloss, but it has to lead with something traceable.
        Add-Result FAIL "Data element '$element' $column '$value' does not lead with a resolvable decision reference" "HANDOFF-011" $true `
          -Artifact "DESIGN/BUILD-SPEC.md" -ItemId $element -Field $column
        $problems++
      }
    }
  }

  if ($problems -eq 0) {
    Add-Result PASS "Every data element declared sensitive carries a classification and retention decision" "HANDOFF-011"
  }
}

function Test-BuildSpecCapabilities {
  param(
    [string]$Text,
    $HandoffPolicy,
    $DecisionIds
  )

  $rows = @(Get-TableRowsAfterHeading $Text (Get-HeadingPattern -Heading "Target Devices and Runtime Capabilities" -Level 3))
  if ($rows.Count -eq 0) { return }

  $unresolved = @($HandoffPolicy.environment_capabilities.unresolved_tokens)
  $problems = 0
  foreach ($row in $rows) {
    $capability = "$($row.Capability)".Trim()
    foreach ($column in @("Serving Model", "Environment Decision")) {
      $value = "$($row.$column)".Trim()
      $bad = ($value.Length -eq 0) -or (Test-PlaceholderValue $value)
      foreach ($token in $unresolved) {
        if ($value -ieq ([string]$token).Trim()) { $bad = $true }
      }
      if ($bad) {
        Add-Result FAIL "Runtime capability '$capability' has an unresolved $column" "HANDOFF-012" $true `
          -Artifact "DESIGN/BUILD-SPEC.md" -ItemId $capability -Field $column
        $problems++
      } elseif ($column -eq "Environment Decision" -and -not (Resolve-LeadingReference -Value $value -DecisionIds $DecisionIds)) {
        Add-Result FAIL "Runtime capability '$capability' $column '$value' does not lead with a resolvable decision reference" "HANDOFF-012" $true `
          -Artifact "DESIGN/BUILD-SPEC.md" -ItemId $capability -Field $column
        $problems++
      }
    }
  }

  if ($problems -eq 0) {
    Add-Result PASS "Every declared runtime capability has a resolved serving model and environment decision" "HANDOFF-012"
  }
}

function Test-HandoffSemanticReview {
  param(
    [string]$Project,
    [string]$Mode,
    $HandoffPolicy,
    [string]$ProjectText,
    $DecisionIds
  )

  $reviewPolicy = $HandoffPolicy.semantic_review
  $reviewPath = Join-Path $Project ([string]$reviewPolicy.artifact)
  $missingLevel = Get-HandoffPolicySeverity -SeverityMap $reviewPolicy.severity_when_missing -Mode $Mode -Default "warn"
  $isRequired = (@($reviewPolicy.required_modes) -contains $Mode)

  if (-not (Test-Path -LiteralPath $reviewPath -PathType Leaf)) {
    if ($isRequired) {
      Add-Result $missingLevel "$($reviewPolicy.artifact) is missing; handoff readiness rests on deterministic checks alone" "HANDOFF-010" $true `
        -Artifact ([string]$reviewPolicy.artifact)
    } else {
      Add-Result INFO "$($reviewPolicy.artifact) is not present and not required for $Mode" "HANDOFF-010"
    }
    return
  }

  $review = $null
  try {
    $review = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json
  } catch {
    Add-Result FAIL "$($reviewPolicy.artifact) is not valid JSON" "HANDOFF-010" $true `
      -Artifact ([string]$reviewPolicy.artifact)
    return
  }

  $problems = @()
  if ("$($review.schema_version)" -ne [string]$reviewPolicy.schema_version) {
    $problems += "schema_version is '$($review.schema_version)', expected '$($reviewPolicy.schema_version)'"
  }
  if (@($reviewPolicy.reviewer_kinds) -notcontains "$($review.reviewer_kind)") {
    $problems += "reviewer_kind '$($review.reviewer_kind)' is not one of: $(@($reviewPolicy.reviewer_kinds) -join ', ')"
  }

  # Every lens in the policy must have been looked through. A review that
  # silently skipped a lens is not a completed review.
  $policyLensIds = @($reviewPolicy.lenses | ForEach-Object { [string]$_.id })
  $reviewedLensIds = @(@($review.lenses) | ForEach-Object { [string]$_.lens })
  $missingLenses = @($policyLensIds | Where-Object { $reviewedLensIds -notcontains $_ })
  $unknownLenses = @($reviewedLensIds | Where-Object { $_ -and ($policyLensIds -notcontains $_) })
  if ($missingLenses.Count -gt 0) {
    $problems += "lenses not reviewed: " + ($missingLenses -join ', ')
  }
  if ($unknownLenses.Count -gt 0) {
    $problems += "unknown review lenses: " + ((Sort-OrdinalUnique -Values ([string[]]$unknownLenses)) -join ', ')
  }

  $validSeverities = @($reviewPolicy.finding_severities)
  $validStatuses = @($reviewPolicy.finding_statuses)
  $validPoints = @($HandoffPolicy.blocking_points)
  $closure = $reviewPolicy.closure_policy
  if (-not $closure) {
    throw "handoff-policy.json semantic_review is missing closure_policy; refusing to guess who may close a finding."
  }
  $openStatuses = @($closure.open_statuses)
  $aiClosable = @($closure.ai_closable_statuses)
  $humanOnlyLenses = @($closure.human_only_close_lenses)
  $needsDecisionRef = @($closure.statuses_requiring_decision_ref)
  $reviewerIsAi = ("$($review.reviewer_kind)" -eq "ai")

  foreach ($finding in @($review.findings)) {
    $id = "$($finding.finding_id)".Trim()
    if ($id.Length -eq 0) { $problems += "a finding has no finding_id"; continue }

    $lens = "$($finding.lens)".Trim()
    $status = "$($finding.status)".Trim()

    if ($validSeverities -notcontains "$($finding.severity)") {
      $problems += "$id has severity '$($finding.severity)'"
    }
    if ($validStatuses -notcontains $status) {
      $problems += "$id has status '$status'"
    }
    if ($validPoints -notcontains "$($finding.blocking_point)") {
      $problems += "$id has blocking_point '$($finding.blocking_point)'"
    }
    # A finding filed under a lens nobody reviews is unreachable: it would never
    # be revisited when that lens is re-run.
    if ($lens.Length -eq 0 -or ($policyLensIds -notcontains $lens)) {
      $problems += "$id is filed under unknown lens '$lens'"
    }
    if (Test-GenericOwner -Value $finding.owner -OwnerPolicy $HandoffPolicy.owner_policy) {
      $problems += "$id has no named owner"
    }
    if (@($finding.evidence_refs).Count -eq 0) {
      $problems += "$id cites no evidence"
    }
    if ([string]::IsNullOrWhiteSpace("$($finding.suggestion)")) {
      $problems += "$id offers no suggestion"
    }

    # ---- closure authority -------------------------------------------------
    # Everything below only applies to a finding somebody claims is no longer
    # open. This is the part that has to be enforced here rather than in the
    # skill prompt: an instruction an agent can ignore is not a control.
    if ($openStatuses -contains $status) { continue }

    $decisionRef = "$($finding.decision_ref)".Trim()
    if ($needsDecisionRef -contains $status) {
      if ($decisionRef.Length -eq 0) {
        $problems += "$id is '$status' with no decision_ref -- a finding is only closed by a decision somebody recorded"
      } elseif (-not (Resolve-LeadingReference -Value $decisionRef -DecisionIds $DecisionIds)) {
        $problems += "$id is '$status' but decision_ref '$decisionRef' does not resolve"
      }
    }

    if ($reviewerIsAi) {
      if ($humanOnlyLenses -contains $lens) {
        $problems += "$id is '$status' under lens '$lens', which only a human may close -- an AI reviewer must leave it open and name the person who decides"
      } elseif ($aiClosable -notcontains $status) {
        $problems += "$id is '$status', which an AI reviewer may not set (allowed: $($aiClosable -join ', '))"
      }
    }

    # reviewer_kind is a self-declaration, and no offline validator can prove
    # who typed a JSON field. What can be checked is whether the closure is
    # anchored to a governed artifact a person is accountable for: a human-only
    # finding must cite a DEC-### that exists in decision-log.md with a named
    # decider. Writing "human" in reviewer_kind buys nothing on its own.
    if ($humanOnlyLenses -contains $lens -and $closure.human_only_requires_decision_log_entry) {
      if ($decisionRef -notmatch '(DEC-\d{3})') {
        $problems += "$id is '$status' under human-only lens '$lens' and cites no decision-log entry -- closure there must reference a DEC-### somebody signed"
      } else {
        $decisionId = $Matches[1]
        $decider = Get-DecisionDecider -DecisionId $decisionId
        if ($null -eq $decider) {
          $problems += "$id cites $decisionId, which is not a row in decision-log.md"
        } elseif (Test-GenericOwner -Value $decider -OwnerPolicy $HandoffPolicy.owner_policy) {
          $problems += "$id closes a human-only lens against $decisionId, whose decider is '$decider' rather than a named person"
        }
      }
    }
  }

  # ---- freshness -----------------------------------------------------------
  # Two digests, because a review goes stale two different ways: the material
  # the requirements came from can change, and the governed artifacts the
  # reviewer actually read can change. Hashing only the first lets someone
  # rewrite the build sequence after review and keep a clean bill of health.
  $staleLevel = Get-HandoffPolicySeverity -SeverityMap $reviewPolicy.freshness.stale_severity -Mode $Mode -Default "warn"
  # Tracked so the summary PASS below cannot claim the review "is current"
  # three lines under a WARN saying it is stale.
  $isStale = $false

  $currentSourceDigest = Get-SourceSnapshotDigest -ProjectText $ProjectText
  $recordedSourceDigest = "$($review.source_snapshot.digest)".Trim().ToLowerInvariant()
  if (-not $recordedSourceDigest) {
    $problems += "source_snapshot.digest is not recorded, so freshness cannot be checked"
  } elseif ($currentSourceDigest -and ($currentSourceDigest -ne $recordedSourceDigest)) {
    Add-Result $staleLevel "$($reviewPolicy.artifact) is stale: it was recorded against a different Source Snapshot than PROJECT.md currently declares" "HANDOFF-010" $true `
      -Artifact ([string]$reviewPolicy.artifact) -Field "source_snapshot.digest"
    $isStale = $true
  }

  $currentInputDigest = Get-ReviewInputDigest -Project $Project -HandoffPolicy $HandoffPolicy
  $recordedInputDigest = "$($review.review_inputs.digest)".Trim().ToLowerInvariant()
  if (-not $recordedInputDigest) {
    $problems += "review_inputs.digest is not recorded, so changes to the reviewed artifacts cannot be detected"
  } elseif ($currentInputDigest -and ($currentInputDigest -ne $recordedInputDigest)) {
    Add-Result $staleLevel "$($reviewPolicy.artifact) is stale: a governed artifact it reviewed has changed since it was recorded" "HANDOFF-010" $true `
      -Artifact ([string]$reviewPolicy.artifact) -Field "review_inputs.digest"
    $isStale = $true
  }

  if ($problems.Count -gt 0) {
    foreach ($problem in $problems) {
      Add-Result FAIL "Semantic handoff review is incomplete: $problem" "HANDOFF-010" $true `
        -Artifact ([string]$reviewPolicy.artifact)
    }
  } elseif (-not $isStale) {
    $openCritical = @(@($review.findings) | Where-Object {
      "$($_.status)" -eq "open" -and "$($_.severity)" -eq "critical"
    })
    Add-Result PASS "Semantic handoff review covers all $($policyLensIds.Count) lenses, is current against both digests, and closes nothing without a decision" "HANDOFF-010"
    if ($openCritical.Count -gt 0) {
      # Reported, not fatal to the gate: an open critical finding may block a
      # later stage (demo, UAT) without blocking the start of development.
      # scripts/assess-handoff.ps1 is what turns these into stage verdicts.
      Add-Result WARN ("Semantic review has $($openCritical.Count) open critical finding(s): " + (@($openCritical | ForEach-Object { "$($_.finding_id) [$($_.blocking_point)]" }) -join ', ')) "HANDOFF-010" $true `
        -Artifact ([string]$reviewPolicy.artifact)
    }
  }
}
