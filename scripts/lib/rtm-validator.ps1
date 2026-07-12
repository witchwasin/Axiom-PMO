# Release registry (Release ID + declared TEST-### rows) and row-by-row
# RTM.json traceability validation: every requirement needs its own complete,
# resolvable chain (design/delivery/test/evidence/release), not just "the
# word delivery_ref appears somewhere in the file".

function Get-ReleaseRegistry {
  param([string]$ReleaseText)
  $result = [pscustomobject]@{ ReleaseId = $null; TestIds = @() }
  if (-not $ReleaseText) { return $result }
  if ($ReleaseText -match '(?m)^\s*>?\s*Release ID:\s*(REL-\d{3})\s*$') {
    $result.ReleaseId = $Matches[1]
  }
  $testRows = Get-TableRowsAfterHeading $ReleaseText '^##\s+Test Summary'
  $result.TestIds = @($testRows | Where-Object { $_.ID } | ForEach-Object { $_.ID.Trim() } | Where-Object { $_ -match '^TEST-\d{3}$' })
  return $result
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
