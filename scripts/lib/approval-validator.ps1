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
