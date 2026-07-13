# DELIVERY.md work-item table validation: header contract, per-item enum and
# reference checks, and the Lite "must have DELIVERY.md or a Work Item
# section" structural requirement at Release.

function Get-DesignPathFromRef {
  param([string]$Value)
  $match = [regex]::Match($Value, '(DESIGN[\\/][^\s,|]+?\.(puml|md|html))')
  if ($match.Success) { return $match.Groups[1].Value }
  return ""
}

function Test-DeliveryWorkItems {
  param(
    [string]$Project,
    [string]$DeliveryPath,
    [string]$Gate,
    $PolicyEnums,
    [string[]]$ProjectReqIds,
    [string[]]$ProjectBusinessIds,
    [string]$ProjectTaskSource
  )

  $deliveryText = $null
  $workItems = @()
  $deliveryIds = @()

  if (Test-Path -LiteralPath $DeliveryPath) {
    $deliveryText = Get-Content -LiteralPath $DeliveryPath -Raw
    $deliveryTaskSource = $null
    if ($deliveryText -match '(?m)^\s*-\s*Task source of truth:\s*`?(file|github)`?\s*$') {
      $deliveryTaskSource = $Matches[1]
      Add-Result PASS "Delivery task source of truth is explicit" "TASK-001"
    } else {
      $deliveryTaskSourceLevel = if ($Gate -eq "Release") { "FAIL" } else { "WARN" }
      Add-Result $deliveryTaskSourceLevel "Delivery task source of truth should be file or github" "TASK-001"
    }

    if ($ProjectTaskSource -and $deliveryTaskSource -and $ProjectTaskSource -ne $deliveryTaskSource) {
      Add-Result FAIL "PROJECT.md task source ($ProjectTaskSource) does not match DELIVERY.md task source ($deliveryTaskSource)" "TASK-002"
    }

    if ($deliveryText -match "\|\s*Mode\s*\|" -and $deliveryText -match "\|\s*Strict Trigger\s*\|" -and $deliveryText -match "\|\s*Mode Reason\s*\|" -and $deliveryText -match "\|\s*Mode Approved By\s*\|" -and $deliveryText -match "\|\s*Review Stage\s*\|" -and $deliveryText -match "\|\s*Evidence Ref\s*\|") {
      Add-Result PASS "Delivery work items include mode, strict trigger, reason, approval, review, and evidence fields" "WORKITEM-001"
    } else {
      $headerLevel = if ($Gate -eq "Release") { "FAIL" } else { "WARN" }
      Add-Result $headerLevel "Delivery work items should include Mode, Strict Trigger, Mode Reason, Mode Approved By, Review Stage, and Evidence Ref" "WORKITEM-001"
    }

    $workItems = Get-TableRowsAfterHeading $deliveryText '^##\s+Work Items'
    $deliveryIds = Get-IdsFromRows $workItems
    foreach ($item in $workItems) {
      $requiredFields = @("ID", "Mode", "Mode Reason", "Mode Approved By", "Requirement Ref", "Design Ref", "Acceptance Criteria", "Test Checklist", "Owner", "Status", "Review Stage", "Evidence Ref")
      $blankFields = $requiredFields | Where-Object { -not $item.$_ -or (Test-FieldValue $_ $item.$_ $item.Mode) }
      if ($blankFields.Count -gt 0) {
        $workItemLevel = if ($Gate -eq "Release") { "FAIL" } else { "WARN" }
        Add-Result $workItemLevel "$($item.ID) has missing work item fields: $($blankFields -join ', ')" "WORKITEM-001"
      }
      if (@($PolicyEnums.modes) -notcontains $item.Mode) {
        Add-Result FAIL "$($item.ID) has invalid Mode: $($item.Mode)" "ENUM-001"
      }
      if (@($PolicyEnums.statuses) -notcontains $item.Status) {
        Add-Result FAIL "$($item.ID) has invalid Status: $($item.Status)" "ENUM-001"
      }
      if (@($PolicyEnums.review_stages) -notcontains $item.'Review Stage') {
        Add-Result FAIL "$($item.ID) has invalid Review Stage: $($item.'Review Stage')" "ENUM-001"
      }
      if ($item.'Strict Trigger' -and $item.'Strict Trigger' -ne "none" -and @($PolicyEnums.strict_triggers) -notcontains $item.'Strict Trigger') {
        Add-Result FAIL "$($item.ID) has invalid Strict Trigger: $($item.'Strict Trigger')" "ENUM-001"
      }
      if ($item.'Strict Trigger' -and $item.'Strict Trigger' -ne "none" -and $item.Mode -ne "Strict") {
        Add-Result FAIL "$($item.ID) has strict trigger but mode is $($item.Mode)" "STRICT-001"
      }

      foreach ($ref in Split-ReferenceValues $item.'Requirement Ref') {
        $refId = ([regex]::Match($ref, '\b(REQ-\d{3}|BR-\d{3})\b')).Value
        if ($refId -and ($ProjectReqIds + $ProjectBusinessIds) -notcontains $refId) {
          Add-Result FAIL "$($item.ID) references missing requirement/business rule: $refId" "REF-001"
        }
      }

      foreach ($designRef in Split-ReferenceValues $item.'Design Ref') {
        if ($designRef -eq "not_required" -and -not (Test-FieldValue "Design Ref" $designRef $item.Mode)) { continue }
        $designPath = Get-DesignPathFromRef $designRef
        if ($designPath -and -not (Test-Path -LiteralPath (Join-Path $Project $designPath) -PathType Leaf)) {
          Add-Result FAIL "$($item.ID) references missing design file: $designPath" "REF-001"
        }
        if ($item.Mode -ne "Lite" -and -not $designPath) {
          Add-Result FAIL "$($item.ID) is missing a resolvable design reference" "REF-001"
        }
      }
    }
  }

  # H1: Lite Release now requires DELIVERY.md via the artifact matrix
  # (pmo-config/artifact-policy.json), like every other mode. The previous
  # escape hatch here accepted any PROJECT.md merely *containing the words*
  # "work item" — which left $workItems empty and silently skipped every
  # Release completion check (RELEASE-STATUS-001 / TEST-EVIDENCE-001 /
  # REVIEW-001). A one-file DELIVERY.md is not heavy for Lite; an
  # unparseable work-item claim is not evidence.

  return [pscustomobject]@{
    DeliveryText = $deliveryText
    WorkItems = $workItems
    DeliveryIds = $deliveryIds
  }
}
