# Approval gate validation (Scope Approved / Design Ready / Release Approved
# rows in PROJECT.md's Approvals table) and decision-log ID lookup used as
# resolvable evidence for those approvals.

function Get-DecisionIds {
  $path = Join-Path $script:project "decision-log.md"
  if (-not (Test-Path -LiteralPath $path)) { return @() }
  $text = Get-Content -LiteralPath $path -Raw
  return @(($text | Select-String -Pattern 'DEC-\d{3}' -AllMatches).Matches | ForEach-Object { $_.Value } | Sort-Object -Unique)
}

function Test-Approval {
  param(
    [string]$ProjectText,
    [string]$GateName,
    [string[]]$DecisionIds = @(),
    [bool]$RequireEvidenceExists = $false,
    [string]$ApprovalMode = "Standard"
  )

  $approvalRows = Get-TableRowsAfterHeading $ProjectText '^##\s+Approvals'
  $row = $approvalRows | Where-Object { $_.Gate -eq $GateName } | Select-Object -First 1
  if (-not $row) {
    Add-Result FAIL "Approval row not found for $GateName" "APPROVAL-001"
    return
  }

  $status = $row.'Approval Status'
  $approver = $row.Approver
  $role = $row.Role
  $date = $row.Date
  $evidence = $row.Evidence
  $invalid = @()

  if ($status -ne "approved") { $invalid += "approval_status" }
  if (Test-PlaceholderValue $approver) { $invalid += "approver" }
  if (Test-PlaceholderValue $role) { $invalid += "role" }
  if ((Test-PlaceholderValue $date) -or -not (Test-DateValue $date)) { $invalid += "date" }
  if (Test-PlaceholderValue $evidence) { $invalid += "evidence" }
  if ($RequireEvidenceExists -and -not (Test-PlaceholderValue $evidence)) {
    # Beyond "not empty" -- evidence must be a recognized, typed reference
    # (DEC-###, ISSUE:n, URL:..., FILE:path that exists, etc.), not arbitrary
    # prose like "approved-by-email" or "some-proof".
    $ref = Resolve-Reference -Value $evidence -ReferenceTypesConfig $script:referenceTypesConfig -ProjectRoot $script:project -DecisionIds $DecisionIds
    # A FILE: reference that escapes the project root is a containment breach.
    if ($ref.PathEscaped) {
      Add-Result FAIL "$GateName approval evidence '$evidence' points outside the project root" "REF-002"
      return
    }
    # An external link (URL:/ISSUE:/CI:) has a valid shape and even "resolves",
    # but this offline validator cannot prove a human decided anything behind it.
    # It is not acceptable as approval evidence at Standard/Strict; Lite still
    # permits light evidence through the WARN path below.
    if ($ref.ExternallyUnverified) {
      Add-Result FAIL "$GateName approval evidence '$evidence' is an external reference the validator cannot verify as a decision" "APPROVAL-004"
      return
    }
    if (-not $ref.Type) {
      $invalid += "evidence_unrecognized_type"
    } elseif (-not $ref.Resolved) {
      $invalid += "evidence_not_found"
    }
  }

  if ($invalid.Count -gt 0) {
    Add-Result FAIL "$GateName approval has invalid or placeholder fields: $($invalid -join ', ')" "APPROVAL-002"
    return
  }

  # FIX B: a generic group ("Dev Team", "Engineering") is not a named approver.
  # The same owner_policy HANDOFF-003 uses for handoff owners applies to who
  # signed off a gate: WARN-blocking at Lite, FAIL at Standard/Strict. The
  # placeholder check above already caught blanks and TBD-style sentinels.
  if (-not (Test-PlaceholderValue $approver)) {
    if (Test-GenericOwner -Value $approver -OwnerPolicy $script:handoffPolicy.owner_policy) {
      $ownerLevel = Get-HandoffPolicySeverity -SeverityMap $script:handoffPolicy.owner_policy.severity_by_mode -Mode $ApprovalMode
      if ($ownerLevel -eq "FAIL") {
        Add-Result FAIL "$GateName approver '$approver' is a generic group, not a named person" "APPROVAL-005"
        return
      }
      Add-Result WARN "$GateName approver '$approver' is a generic group, not a named person" "APPROVAL-005" -Blocking $true
    }
  }

  # H4: Lite skips the hard typed-evidence FAIL above ($RequireEvidenceExists
  # is false for Lite), but its evidence must still be a checkable reference,
  # not unverifiable prose like "approved-by-chat". Unrecognized/unresolvable
  # Lite evidence is WARN_BLOCKING -- surfaced and blocks -FailOnWarning,
  # without forcing a hard FAIL -- exactly what P2.2 specified.
  if (-not $RequireEvidenceExists -and -not (Test-PlaceholderValue $evidence)) {
    $liteRef = Resolve-Reference -Value $evidence -ReferenceTypesConfig $script:referenceTypesConfig -ProjectRoot $script:project -DecisionIds $DecisionIds
    if (-not $liteRef.Type -or -not $liteRef.Resolved) {
      Add-Result WARN "$GateName approval evidence '$evidence' is not a resolvable reference (use DEC-###, ISSUE:n, FILE:path, URL:...)" "APPROVAL-002" -Blocking $true
      Add-Result PASS "$GateName approval is valid" "APPROVAL-002"
      return
    }
  }

  # Role matrix (pmo-config/policy.json approval_roles): small teams often wear
  # multiple hats, so a role mismatch is not blocking at Standard -- it is
  # surfaced but does not fail Release -- and only hard-blocks at Strict.
  $allowedRoles = $script:policy.approval_roles.$GateName
  if ($allowedRoles -and -not (Test-PlaceholderValue $role) -and (@($allowedRoles) -notcontains $role)) {
    if ($ApprovalMode -eq "Strict") {
      Add-Result FAIL "$GateName approver role '$role' is not in the allowed role matrix ($($allowedRoles -join ', '))" "APPROVAL-003"
      return
    } elseif ($ApprovalMode -ne "Lite") {
      Add-Result WARN "$GateName approver role '$role' is not in the allowed role matrix ($($allowedRoles -join ', '))" "APPROVAL-003" -Blocking $true
    }
  }

  Add-Result PASS "$GateName approval is valid" "APPROVAL-002"
}
