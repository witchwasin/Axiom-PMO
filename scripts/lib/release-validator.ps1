# Release readiness: open-blocker check, RELEASE.md parsing (rollback plan /
# waiver, missing delivery refs, structured QA/Security review), per-item
# release-scope completion, and the Strict aggregate guardrail check.

function Test-RaidBlocker {
  param([string]$Project, [string]$Gate)

  $raidPath = Join-Path $Project "RAID-log.md"
  if (-not (Test-Path -LiteralPath $raidPath)) { return }

  $raidText = Get-Content -LiteralPath $raidPath -Raw
  $blockerOpen = $raidText -match "(?i)\bblocker\b.*\bopen\b|\bopen\b.*\bblocker\b"
  if ($Gate -eq "Release" -and $blockerOpen) {
    Add-Result FAIL "Open blocker found in RAID-log.md during release validation" "BLOCKER-001"
  } elseif ($blockerOpen) {
    Add-Result WARN "Open blocker found in RAID-log.md" "BLOCKER-001"
  } else {
    Add-Result PASS "No open blocker pattern found" "BLOCKER-001"
  }
}

function Test-ReviewRow {
  param(
    [string]$ReleaseText,
    [string]$ReviewType,
    [string]$RuleId,
    [string]$ApprovalMode,
    [string[]]$DecisionIds,
    $ReleaseRegistry
  )

  $rows = Get-TableRowsAfterHeading $ReleaseText '^##\s+QA\s*/\s*Security Review'
  $row = $rows | Where-Object { $_.'Review Type' -eq $ReviewType } | Select-Object -First 1
  if (-not $row) {
    Add-Result FAIL "$ReviewType review row not found in QA / Security Review table" $RuleId
    return $false
  }

  $invalid = @()
  if ($row.Status -ne "approved") { $invalid += "status" }
  if (Test-PlaceholderValue $row.Reviewer) { $invalid += "reviewer" }
  if (Test-PlaceholderValue $row.Role) { $invalid += "role" }
  if ((Test-PlaceholderValue $row.Date) -or -not (Test-DateValue $row.Date)) { $invalid += "date" }
  if (Test-PlaceholderValue $row.Evidence) {
    $invalid += "evidence"
  } else {
    $ref = Resolve-Reference -Value $row.Evidence -ReferenceTypesConfig $script:referenceTypesConfig -ProjectRoot $script:project -DecisionIds $DecisionIds -TestIds $ReleaseRegistry.TestIds
    if (-not $ref.Type) { $invalid += "evidence_unrecognized_type" }
    elseif (-not $ref.Resolved) { $invalid += "evidence_not_found" }
  }

  if ($invalid.Count -gt 0) {
    Add-Result FAIL "$ReviewType review row has invalid or placeholder fields: $($invalid -join ', ')" $RuleId
    return $false
  }

  $allowedRoles = $script:policy.approval_roles."$ReviewType Approved"
  if ($allowedRoles -and (@($allowedRoles) -notcontains $row.Role)) {
    if ($ApprovalMode -eq "Strict") {
      Add-Result FAIL "$ReviewType reviewer role '$($row.Role)' is not in the allowed role matrix ($($allowedRoles -join ', '))" $RuleId
      return $false
    } else {
      Add-Result WARN "$ReviewType reviewer role '$($row.Role)' is not in the allowed role matrix ($($allowedRoles -join ', '))" $RuleId -Blocking $true
    }
  }

  Add-Result PASS "$ReviewType review is valid" $RuleId
  return $true
}

function Test-ReleaseArtifact {
  param(
    [string]$Project,
    [string]$Mode,
    [string]$Gate,
    [string[]]$DeliveryIds,
    [string[]]$DecisionIds
  )

  $releaseText = ""
  $releasePath = Join-Path $Project "RELEASE.md"
  $releaseRegistry = [pscustomobject]@{ ReleaseId = $null; TestIds = @() }
  if (-not ($Gate -eq "Release" -and (Test-Path -LiteralPath $releasePath))) {
    return [pscustomobject]@{ ReleaseText = $releaseText; ReleaseRegistry = $releaseRegistry }
  }

  $releaseText = Get-Content -LiteralPath $releasePath -Raw
  $releaseRegistry = Get-ReleaseRegistry $releaseText

  # P3.3: structured rollback, with a Lite waiver alternative
  # (rollback_required: false + change_type + reason + approver) instead of a
  # full row-by-row plan -- valid only for change types on the config allowlist.
  $rollbackSectionLines = Get-TableLinesAfterHeading $releaseText '^##\s+Structured Rollback Plan'
  $waiverMatch = [regex]::Match($releaseText, '(?ms)^##\s+Structured Rollback Plan\s*(.*?)(?=^##\s|\z)')
  $waiver = $null
  if ($waiverMatch.Success -and $waiverMatch.Groups[1].Value -match '(?m)^\s*rollback_required:\s*false\s*$') {
    $section = $waiverMatch.Groups[1].Value
    $waiver = [pscustomobject]@{
      ChangeType = if ($section -match '(?m)^\s*change_type:\s*(.+?)\s*$') { $Matches[1] } else { "" }
      Reason = if ($section -match '(?m)^\s*reason:\s*(.+?)\s*$') { $Matches[1] } else { "" }
      Approver = if ($section -match '(?m)^\s*approver:\s*(.+?)\s*$') { $Matches[1] } else { "" }
    }
  }

  if ($waiver) {
    $waiverRule = $script:policy.rollback_waiver
    $waiverAllowedModes = if ($waiverRule) { @($waiverRule.allowed_modes) } else { @() }
    $waiverAllowedTypes = if ($waiverRule) { @($waiverRule.allowed_change_types) } else { @() }
    $waiverInvalid = @()
    if ($waiverAllowedModes -notcontains $Mode) { $waiverInvalid += "mode $Mode is not allowed to waive rollback" }
    if ($waiverAllowedTypes -notcontains $waiver.ChangeType) { $waiverInvalid += "change_type '$($waiver.ChangeType)' is not on the waiver allowlist" }
    if (Test-PlaceholderValue $waiver.Reason) { $waiverInvalid += "reason is missing" }
    if (Test-PlaceholderValue $waiver.Approver) { $waiverInvalid += "approver is missing" }
    if ($waiverInvalid.Count -eq 0) {
      Add-Result PASS "Release rollback is validly waived (change_type=$($waiver.ChangeType))" "RELEASE-001"
    } else {
      Add-Result FAIL "Release rollback waiver is invalid: $($waiverInvalid -join '; ')" "RELEASE-001"
    }
  } else {
    $rollbackDataRows = @()
    $badRollbackRows = @()
    if ($rollbackSectionLines.Count -ge 3) {
      foreach ($line in ($rollbackSectionLines | Select-Object -Skip 2)) {
        $parts = @($line -split '\|')
        $cells = @()
        for ($i = 1; $i -lt ($parts.Count - 1); $i++) {
          $cells += $parts[$i].Trim()
        }
        if ($cells.Count -lt 5) {
          $badRollbackRows += $line
          continue
        }
        $rollbackDataRows += $line
        if ((Test-PlaceholderValue $cells[0]) -or
          (Test-PlaceholderValue $cells[1]) -or
          (Test-PlaceholderValue $cells[2]) -or
          (Test-PlaceholderValue $cells[3]) -or
          (Test-PlaceholderValue $cells[4])) {
          $badRollbackRows += $line
        }
      }
    }
    if ($rollbackDataRows.Count -gt 0 -and $badRollbackRows.Count -eq 0) {
      Add-Result PASS "Release includes structured rollback plan" "RELEASE-001"
    } else {
      Add-Result FAIL "Release rollback table is missing or has empty rows" "RELEASE-001"
    }
  }

  $scopeMatches = [regex]::Matches($releaseText, '\bD-\d{3}\b')
  $missingReleaseRefs = @()
  foreach ($scopeMatch in $scopeMatches) {
    if ($DeliveryIds -notcontains $scopeMatch.Value) { $missingReleaseRefs += $scopeMatch.Value }
  }
  $missingReleaseRefs = @($missingReleaseRefs | Sort-Object -Unique)
  if ($missingReleaseRefs.Count -gt 0) {
    Add-Result FAIL "Release references missing delivery item(s): $($missingReleaseRefs -join ', ')" "REF-001"
  }

  # P3.2: structured QA/Security review, replacing the old "the word qa/security
  # appears somewhere in DELIVERY.md" regex. Lite is exempt (test evidence in
  # the Test Summary table is sufficient); Standard requires QA; Strict requires
  # QA and Security.
  if ($Mode -ne "Lite") {
    Test-ReviewRow $releaseText "QA" "QA-REVIEW-001" $Mode $DecisionIds $releaseRegistry | Out-Null
    if ($Mode -eq "Strict") {
      Test-ReviewRow $releaseText "Security" "SECURITY-REVIEW-001" $Mode $DecisionIds $releaseRegistry | Out-Null
    }
  }

  return [pscustomobject]@{ ReleaseText = $releaseText; ReleaseRegistry = $releaseRegistry }
}

function Test-ReleaseScopeCompletion {
  param(
    $WorkItems,
    [string]$ReleaseText,
    [string]$Mode,
    [string]$Gate,
    [string[]]$DecisionIds,
    $ReleaseRegistry
  )

  # P3.1: work-item completion at Release. Every in-scope work item must be
  # Done, reviewed, and have resolvable test/evidence proof before Release; the
  # existing "Release Scope" table (Deliverable/Requirement Ref/Included?/Notes)
  # is the exclusion mechanism for items intentionally left out of this release.
  # [bool]$WorkItems short-circuits $null/empty before the @() count check --
  # PowerShell's @() wrapping of a $null *parameter* (bound via -WorkItems)
  # behaves differently from a $null script variable and yields Count=1, not
  # 0, so @($WorkItems).Count alone is not a safe emptiness test here.
  if (-not ($Gate -eq "Release" -and [bool]$WorkItems -and @($WorkItems).Count -gt 0)) { return }

  $releaseScopeRows = @()
  if ($ReleaseText) {
    $releaseScopeRows = @(Get-TableRowsAfterHeading $ReleaseText '^##\s+Release Scope')
  }
  foreach ($item in @($WorkItems)) {
    $scopeRow = $releaseScopeRows | Where-Object { $_.Deliverable -eq $item.ID } | Select-Object -First 1
    $included = $true
    if ($scopeRow) {
      $included = ($scopeRow.'Included?' -ne "no")
    } elseif ($releaseScopeRows.Count -gt 0) {
      Add-Result FAIL "$($item.ID) is not listed in the Release Scope table" "RELEASE-SCOPE-001"
      continue
    }

    if (-not $included) {
      if (Test-PlaceholderValue $scopeRow.Notes) {
        Add-Result FAIL "$($item.ID) is excluded from release scope but Notes does not state a reason" "RELEASE-SCOPE-001"
      } else {
        Add-Result PASS "$($item.ID) is intentionally excluded from release scope" "RELEASE-SCOPE-001"
      }
      continue
    }

    if ($item.Status -ne "Done") {
      Add-Result FAIL "$($item.ID) is in release scope but Status is '$($item.Status)', not Done" "RELEASE-STATUS-001"
    }
    if ($Mode -ne "Lite" -and $item.'Review Stage' -eq "none") {
      Add-Result FAIL "$($item.ID) is in release scope but has no Review Stage" "REVIEW-001"
    }
    if (Test-PlaceholderValue $item.'Test Checklist') {
      Add-Result FAIL "$($item.ID) is in release scope but Test Checklist is empty" "TEST-EVIDENCE-001"
    }
    if ($Mode -ne "Lite") {
      $itemEvidence = Resolve-Reference -Value $item.'Evidence Ref' -ReferenceTypesConfig $script:referenceTypesConfig -ProjectRoot $script:project -DecisionIds $DecisionIds -TestIds $ReleaseRegistry.TestIds
      if (-not $itemEvidence.Type -or -not $itemEvidence.Resolved) {
        Add-Result FAIL "$($item.ID) is in release scope but Evidence Ref '$($item.'Evidence Ref')' does not resolve to a real reference" "TEST-EVIDENCE-001"
      }
    } elseif (Test-PlaceholderValue $item.'Evidence Ref') {
      Add-Result FAIL "$($item.ID) is in release scope but Evidence Ref is empty" "TEST-EVIDENCE-001"
    }
  }
}

function Test-StrictReleaseGuardrails {
  param(
    [string]$Project,
    [string]$Mode,
    [string]$Gate,
    [string[]]$ProjectReqIds,
    [string[]]$DeliveryIds,
    [string[]]$DecisionIds,
    $ReleaseRegistry
  )

  if (-not ($Mode -eq "Strict" -and $Gate -eq "Release")) { return }

  $strictMissing = @()
  if (-not (Test-Path -LiteralPath (Join-Path $Project "RTM.json") -PathType Leaf)) {
    $strictMissing += "RTM.json"
  }
  if (-not (Test-Path -LiteralPath (Join-Path $Project "RAID-log.md") -PathType Leaf)) {
    $strictMissing += "RAID-log.md"
  }
  if (-not (Test-Path -LiteralPath (Join-Path $Project "decision-log.md") -PathType Leaf)) {
    $strictMissing += "decision-log.md"
  }
  # QA/security review and release verification evidence are now enforced by
  # the structured QA-REVIEW-001 / SECURITY-REVIEW-001 / TEST-EVIDENCE-001
  # checks above (real table rows, not "the word qa appears somewhere").

  Test-RtmTraceability -Project $Project -ProjectReqIds $ProjectReqIds -DeliveryIds $DeliveryIds -DecisionIds $DecisionIds -ReleaseRegistry $ReleaseRegistry

  if ($strictMissing.Count -gt 0) {
    Add-Result FAIL "Strict release is missing required guardrails: $($strictMissing -join ', ')" "STRICT-002"
  } else {
    Add-Result PASS "Strict release includes traceability, review, and release evidence guardrails" "STRICT-002"
  }
}
