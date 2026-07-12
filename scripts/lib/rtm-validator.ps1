# Release registry (Release ID + declared TEST-### rows) and row-by-row
# RTM.json traceability validation: every requirement needs its own complete,
# resolvable chain (design/delivery/test/evidence/release), not just "the
# word delivery_ref appears somewhere in the file".

function Get-ReleaseRegistry {
  param([string]$ReleaseText)
  $result = [pscustomobject]@{ ReleaseId = $null; TestIds = @(); TestRows = @() }
  if (-not $ReleaseText) { return $result }
  if ($ReleaseText -match '(?m)^\s*>?\s*Release ID:\s*(REL-\d{3})\s*$') {
    $result.ReleaseId = $Matches[1]
  }
  $testRows = @(Get-TableRowsAfterHeading $ReleaseText '^##\s+Test Summary')
  $result.TestRows = @($testRows | Where-Object { $_.ID -match '^TEST-\d{3}$' })
  $result.TestIds = @($result.TestRows | ForEach-Object { $_.ID.Trim() })
  return $result
}

function Test-TestSummary {
  # H2: a Test Summary row that still says "pending" (or is blank/failed) must
  # not let a Release pass just because a TEST-### id exists somewhere in the
  # table -- Get-ReleaseRegistry used to collect only ids, never Result or
  # Evidence, so an all-pending Test Summary was indistinguishable from an
  # all-passed one to every other check. "skipped" is allowed only with a
  # real reason in Notes (same shape as the Lite rollback waiver).
  param(
    $ReleaseRegistry,
    [string]$Project,
    [string[]]$DecisionIds
  )

  foreach ($row in @($ReleaseRegistry.TestRows)) {
    $result = "$($row.Result)".Trim().ToLowerInvariant()
    if ($result -eq "skipped") {
      if (Test-PlaceholderValue $row.Notes) {
        Add-Result FAIL "$($row.ID) is marked skipped but Notes does not state a reason" "TEST-RESULT-001"
      } else {
        Add-Result PASS "$($row.ID) is validly skipped (reason recorded)" "TEST-RESULT-001"
      }
      continue
    }
    if ($result -ne "passed") {
      Add-Result FAIL "$($row.ID) has Result '$($row.Result)', expected passed (or skipped with a reason in Notes)" "TEST-RESULT-001"
      continue
    }
    if (Test-PlaceholderValue $row.Evidence) {
      Add-Result FAIL "$($row.ID) is passed but Evidence is empty" "TEST-EVIDENCE-002"
      continue
    }
    $ref = Resolve-Reference -Value $row.Evidence -ReferenceTypesConfig $script:referenceTypesConfig -ProjectRoot $Project -DecisionIds $DecisionIds
    if (-not $ref.Type -or -not $ref.Resolved) {
      Add-Result FAIL "$($row.ID) is passed but Evidence '$($row.Evidence)' does not resolve to a real reference" "TEST-EVIDENCE-002"
    } else {
      Add-Result PASS "$($row.ID) is passed with resolvable evidence" "TEST-EVIDENCE-002"
    }
  }
}

function Test-RtmTraceability {
  param(
    [string]$Project,
    [string[]]$ProjectReqIds,
    [string[]]$DeliveryIds,
    [string[]]$DecisionIds,
    $ReleaseRegistry
  )

  $rtmPath = Join-Path $Project "RTM.json"
  if (-not (Test-Path -LiteralPath $rtmPath -PathType Leaf)) { return }

  $rtmRaw = Get-Content -LiteralPath $rtmPath -Raw
  $rtmDoc = $null
  try { $rtmDoc = $rtmRaw | ConvertFrom-Json } catch { $rtmDoc = $null }

  if (-not $rtmDoc -or -not $rtmDoc.schema_version -or -not $rtmDoc.traceability -or @($rtmDoc.traceability).Count -eq 0) {
    Add-Result FAIL "RTM.json is empty, invalid, or missing schema_version/traceability" "RTM-001"
    return
  }

  $rows = @($rtmDoc.traceability)
  $rtmReqIds = @($rows | Where-Object { $_.requirement_id } | ForEach-Object { $_.requirement_id } | Sort-Object -Unique)

  foreach ($reqId in $ProjectReqIds) {
    if ($rtmReqIds -notcontains $reqId) {
      Add-Result FAIL "RTM missing requirement: $reqId" "RTM-002"
    }
  }
  foreach ($rtmReqId in $rtmReqIds) {
    if ($ProjectReqIds -notcontains $rtmReqId) {
      Add-Result FAIL "RTM traceability row references a requirement not in PROJECT.md: $rtmReqId" "RTM-007"
    }
  }

  $seen = @{}
  foreach ($row in $rows) {
    $rid = "$($row.requirement_id)"
    if ($rid -and $seen.ContainsKey($rid)) {
      Add-Result FAIL "RTM has a duplicate traceability row for: $rid" "RTM-007"
    }
    if ($rid) { $seen[$rid] = $true }

    if (-not $row.delivery_ref -or ($DeliveryIds -notcontains $row.delivery_ref)) {
      Add-Result FAIL "RTM row $rid has a broken delivery_ref: $($row.delivery_ref)" "RTM-003"
    }
    if (-not $row.test_ref -or ($ReleaseRegistry.TestIds -notcontains $row.test_ref)) {
      Add-Result FAIL "RTM row $rid has a broken test_ref: $($row.test_ref)" "RTM-004"
    }
    $evidenceOk = $row.evidence_ref -and (-not (Test-PlaceholderValue $row.evidence_ref)) -and (
      $row.evidence_ref -notmatch '^DEC-\d{3}$' -or ($DecisionIds -contains $row.evidence_ref)
    )
    if (-not $evidenceOk) {
      Add-Result FAIL "RTM row $rid has a broken or missing evidence_ref: $($row.evidence_ref)" "RTM-005"
    }
    if (-not $row.release_ref -or -not $ReleaseRegistry.ReleaseId -or $row.release_ref -ne $ReleaseRegistry.ReleaseId) {
      Add-Result FAIL "RTM row $rid has a broken release_ref: $($row.release_ref)" "RTM-006"
    }
  }
}
