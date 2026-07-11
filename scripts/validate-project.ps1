param(
  [Parameter(Mandatory = $true)]
  [Alias("Project")]
  [string]$ProjectPath,

  [ValidateSet("Lite", "Standard", "Strict")]
  [string]$Mode = "Standard",

  [ValidateSet("Draft", "Scope", "Design", "Release")]
  [string]$Gate = "Draft",

  [switch]$Release,

  [ValidateSet("Text", "Json")]
  [string]$Format = "Text",

  [switch]$FailOnWarning
)

$ErrorActionPreference = "Stop"

if ($Release) {
  $Gate = "Release"
}

$root = Resolve-Path -LiteralPath $ProjectPath
$project = $root.Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$policyPath = Join-Path $repoRoot "pmo-config/policy.json"
if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
  throw "Missing runtime policy config: $policyPath"
}
$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$policyEnums = $policy.enums

$pass = 0
$warn = 0
$fail = 0
$messages = New-Object System.Collections.Generic.List[object]

function Add-Result {
  param(
    [ValidateSet("PASS", "WARN", "FAIL", "INFO")]
    [string]$Level,
    [string]$Message,
    [string]$RuleId = "GENERAL-001"
  )

  $script:messages.Add([pscustomobject]@{
    level = $Level
    rule_id = $RuleId
    message = $Message
  }) | Out-Null
  switch ($Level) {
    "PASS" { $script:pass++ }
    "WARN" { $script:warn++ }
    "FAIL" { $script:fail++ }
  }
}

function Get-RelativePath {
  param([string]$Path)
  return $Path.Substring($project.Length).TrimStart("\", "/")
}

function Test-UserSourcePath {
  param([string]$RelativePath)
  return ($RelativePath -match '^(source|MOM|REQ|Transcript)[\\/]')
}

function Get-TableRowsAfterHeading {
  param(
    [string]$Text,
    [string]$HeadingPattern
  )

  $lines = $Text -split "`r?`n"
  $start = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $HeadingPattern) {
      $start = $i
      break
    }
  }
  if ($start -lt 0) { return @() }

  $tableLines = @()
  for ($i = $start + 1; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line.Trim().Length -eq 0) {
      if ($tableLines.Count -eq 0) { continue }
      break
    }
    if ($line -match '^\s*#') { break }
    if ($line -match '^\s*\|') {
      $tableLines += $line
      continue
    }
    if ($tableLines.Count -gt 0) { break }
  }
  if ($tableLines.Count -lt 2) { return @() }

  $headerParts = @($tableLines[0] -split '\|')
  $headers = @()
  for ($i = 1; $i -lt ($headerParts.Count - 1); $i++) {
    $headers += $headerParts[$i].Trim()
  }
  $rows = @()
  foreach ($line in ($tableLines | Select-Object -Skip 2)) {
    $cellParts = @($line -split '\|')
    $cells = @()
    for ($i = 1; $i -lt ($cellParts.Count - 1); $i++) {
      $cells += $cellParts[$i].Trim()
    }
    if ($cells.Count -eq 0) { continue }
    $row = [ordered]@{}
    for ($i = 0; $i -lt $headers.Count; $i++) {
      $value = if ($i -lt $cells.Count) { $cells[$i] } else { "" }
      $row[$headers[$i]] = $value
    }
    $rows += [pscustomobject]$row
  }
  return $rows
}

function Get-TableLinesAfterHeading {
  param(
    [string]$Text,
    [string]$HeadingPattern
  )

  $lines = $Text -split "`r?`n"
  $start = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $HeadingPattern) {
      $start = $i
      break
    }
  }
  if ($start -lt 0) { return @() }

  $tableLines = @()
  for ($i = $start + 1; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line.Trim().Length -eq 0) {
      if ($tableLines.Count -eq 0) { continue }
      break
    }
    if ($line -match '^\s*#') { break }
    if ($line -match '^\s*\|') {
      $tableLines += $line
      continue
    }
    if ($tableLines.Count -gt 0) { break }
  }
  return $tableLines
}

function Test-File {
  param(
    [string]$RelativePath,
    [ValidateSet("required", "optional")]
    [string]$Requirement = "required"
  )

  $path = Join-Path $project $RelativePath
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    Add-Result PASS "Found $RelativePath" "STRUCT-001"
    return $true
  }

  if ($Requirement -eq "required") {
    Add-Result FAIL "Missing $RelativePath" "STRUCT-001"
  } else {
    Add-Result INFO "Missing optional file $RelativePath" "STRUCT-001"
  }
  return $false
}

function Test-Dir {
  param(
    [string]$RelativePath,
    [ValidateSet("required", "optional")]
    [string]$Requirement = "optional"
  )

  $path = Join-Path $project $RelativePath
  if (Test-Path -LiteralPath $path -PathType Container) {
    Add-Result PASS "Found $RelativePath/" "STRUCT-001"
    return $true
  }

  if ($Requirement -eq "required") {
    Add-Result FAIL "Missing $RelativePath/" "STRUCT-001"
  } else {
    Add-Result INFO "Missing optional directory $RelativePath/" "STRUCT-001"
  }
  return $false
}

function Get-ProjectText {
  $path = Join-Path $project "PROJECT.md"
  if (Test-Path -LiteralPath $path) {
    return Get-Content -LiteralPath $path -Raw
  }
  return ""
}

function Test-PlaceholderValue {
  param([string]$Value)

  $trimmed = $Value.Trim()
  if ($trimmed.Length -eq 0) { return $true }
  if ($trimmed -eq "not_required") { return $false }
  if ($trimmed -eq "-") { return $true }
  return ($trimmed -match "<[^>]+>|TODO|TBD|YYYY-MM-DD|ISO-8601|pending|n/a")
}

function Test-DateValue {
  param([string]$Value)

  $trimmed = $Value.Trim()
  $parsed = New-Object DateTime
  return [DateTime]::TryParseExact(
    $trimmed,
    "yyyy-MM-dd",
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::None,
    [ref]$parsed
  )
}

function Test-PlaceholderContent {
  param(
    [string]$Content,
    [string]$Extension
  )
  if ($Extension -eq ".html") {
    return ($Content -match "{{[^}]+}}|<PLACEHOLDER:[^>]+>|TODO|TBD")
  }
  return ($Content -match "<[^>\r\n]+>|TODO|TBD")
}

function Get-PolicySourceRefRegex {
  $patterns = @($policyEnums.source_ref_patterns)
  if ($patterns.Count -eq 0) {
    $patterns = @('MOM-\d{8}', 'REQ-\d{8}', 'REQ-V\d+', 'TR-\d{8}', 'DEC-\d{3}', 'ISSUE-\d+', 'PR-\d+', 'source_ref')
  }
  return ($patterns -join "|")
}

function Get-IdsFromRows {
  param($Rows)
  return @($Rows | Where-Object { $_.ID } | ForEach-Object { $_.ID.Trim() })
}

function Get-DecisionIds {
  $path = Join-Path $project "decision-log.md"
  if (-not (Test-Path -LiteralPath $path)) { return @() }
  $text = Get-Content -LiteralPath $path -Raw
  return @(($text | Select-String -Pattern 'DEC-\d{3}' -AllMatches).Matches | ForEach-Object { $_.Value } | Sort-Object -Unique)
}

function Split-ReferenceValues {
  param([string]$Value)
  if (-not $Value) { return @() }
  return @($Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}

function Get-DesignPathFromRef {
  param([string]$Value)
  $match = [regex]::Match($Value, '(DESIGN[\\/][^\s,|]+?\.(puml|md|html))')
  if ($match.Success) { return $match.Groups[1].Value }
  return ""
}

function Test-Approval {
  param(
    [string]$ProjectText,
    [string]$GateName,
    [string[]]$DecisionIds = @(),
    [bool]$RequireEvidenceExists = $false
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
  if ($RequireEvidenceExists -and $evidence -match '^DEC-\d{3}$' -and ($DecisionIds -notcontains $evidence)) { $invalid += "evidence_not_found" }

  if ($invalid.Count -gt 0) {
    Add-Result FAIL "$GateName approval has invalid or placeholder fields: $($invalid -join ', ')" "APPROVAL-002"
    return
  }

  Add-Result PASS "$GateName approval is valid" "APPROVAL-002"
}

Test-File "PROJECT.md" | Out-Null

if ($Mode -eq "Lite") {
  Test-File "DELIVERY.md" "optional" | Out-Null
  Test-File "RELEASE.md" "optional" | Out-Null
} else {
  Test-File "DELIVERY.md" | Out-Null
  Test-File "RELEASE.md" | Out-Null
}

if ($Mode -eq "Strict") {
  Test-File "RAID-log.md" | Out-Null
  Test-File "decision-log.md" | Out-Null
  Test-File "RTM.yaml" "optional" | Out-Null
} else {
  Test-File "RAID-log.md" "optional" | Out-Null
  Test-File "decision-log.md" "optional" | Out-Null
}

if ($Gate -in @("Design", "Release") -and $Mode -ne "Lite") {
  Test-Dir "DESIGN" "required" | Out-Null
} else {
  Test-Dir "DESIGN" "optional" | Out-Null
}
Test-Dir "source" "optional" | Out-Null

$allProjectFiles = Get-ChildItem -LiteralPath $project -Recurse -File -ErrorAction SilentlyContinue
$allTextFiles = @($allProjectFiles | Where-Object { $_.Extension -in @(".md", ".yaml", ".yml", ".puml", ".html") })
$governedFiles = @($allTextFiles | Where-Object { -not (Test-UserSourcePath (Get-RelativePath $_.FullName)) })
$userSourceFiles = @($allTextFiles | Where-Object { Test-UserSourcePath (Get-RelativePath $_.FullName) })
$sourceRefRegex = Get-PolicySourceRefRegex
$decisionIds = Get-DecisionIds

$placeholderHits = @()
foreach ($file in $governedFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
  if (Test-PlaceholderContent $content $file.Extension) {
    $placeholderHits += Get-RelativePath $file.FullName
  }
}

if ($placeholderHits.Count -eq 0) {
  Add-Result PASS "No placeholder/TODO/TBD markers found" "PLACEHOLDER-001"
} elseif ($Gate -eq "Draft") {
  Add-Result INFO ("Draft placeholders found in: " + (($placeholderHits | Select-Object -First 8) -join ", ")) "PLACEHOLDER-001"
} elseif ($Gate -eq "Release") {
  Add-Result FAIL ("Release gate has placeholder/TODO/TBD markers in: " + (($placeholderHits | Select-Object -First 8) -join ", ")) "PLACEHOLDER-001"
} else {
  Add-Result WARN ("Placeholder/TODO/TBD markers found in: " + (($placeholderHits | Select-Object -First 8) -join ", ")) "PLACEHOLDER-001"
}

$projectText = Get-ProjectText
$projectReqIds = @()
$projectSourceIds = @()
$projectBusinessIds = @()
if ($projectText) {
  $projectTaskSource = $null
  if ($projectText -match '(?m)^\s*>?\s*Task source:\s*(file|github)\s*$') {
    $projectTaskSource = $Matches[1]
    Add-Result PASS "Task source is declared" "TASK-001"
  } else {
    $taskSourceLevel = if ($Gate -eq "Release") { "FAIL" } else { "WARN" }
    Add-Result $taskSourceLevel "Task source is not declared as file or github" "TASK-001"
  }

  if ($projectText -match "## Source Snapshot") {
    if ($projectText -match "Last Synced At|synced_at") {
      Add-Result PASS "Source Snapshot section exists" "SOURCE-002"
    } else {
      Add-Result WARN "Source Snapshot exists but does not show sync time" "SOURCE-002"
    }
  } else {
    Add-Result WARN "Source Snapshot section is missing; PROJECT.md may become stale" "SOURCE-002"
  }

  $reqRows = Get-TableRowsAfterHeading $projectText '^###\s+In Scope'
  if ($reqRows.Count -eq 0) {
    $noReqLevel = if ($Gate -eq "Draft") { "INFO" } else { "FAIL" }
    Add-Result $noReqLevel "No REQ-### entries found in PROJECT.md" "SOURCE-001"
  } else {
    $projectReqIds = Get-IdsFromRows $reqRows
    $duplicateIds = $projectReqIds | Group-Object | Where-Object { $_.Count -gt 1 }
    if ($duplicateIds.Count -gt 0) {
      Add-Result FAIL "Duplicate requirement IDs: $($duplicateIds.Name -join ', ')" "SOURCE-003"
    }

    $missingSource = $reqRows | Where-Object { $_.'Source Ref' -notmatch $sourceRefRegex }
    $validEvidence = @($policyEnums.evidence_statuses)
    $missingEvidence = $reqRows | Where-Object { $validEvidence -notcontains $_.'Evidence Status' }
    $missingLevel = if ($Gate -eq "Release") { "FAIL" } else { "WARN" }

    if ($missingSource.Count -eq 0) {
      Add-Result PASS "Requirement lines include source references" "SOURCE-001"
    } else {
      Add-Result $missingLevel "$($missingSource.Count) requirement line(s) may be missing source_ref" "SOURCE-001"
    }

    if ($missingEvidence.Count -eq 0) {
      Add-Result PASS "Requirement lines include valid evidence status" "EVIDENCE-001"
    } else {
      Add-Result $missingLevel "$($missingEvidence.Count) requirement line(s) may be missing or invalid evidence status" "EVIDENCE-001"
    }
  }

  $sourceRows = @()
  $sourceRows += Get-TableRowsAfterHeading $projectText '^##\s+Source Snapshot'
  $sourceRows += Get-TableRowsAfterHeading $projectText '^##\s+Source Inventory'
  $projectSourceIds = @($sourceRows | Where-Object { $_.'Source ID' } | ForEach-Object { $_.'Source ID'.Trim() } | Sort-Object -Unique)
  $projectBusinessIds = Get-IdsFromRows (Get-TableRowsAfterHeading $projectText '^##\s+Business Rules')

  $requireDecisionEvidence = ($Mode -ne "Lite")
  if ($Gate -in @("Scope", "Design", "Release")) {
    Test-Approval $projectText "Scope Approved" $decisionIds $requireDecisionEvidence
  }
  if ($Gate -in @("Design", "Release") -and $Mode -ne "Lite") {
    Test-Approval $projectText "Design Ready" $decisionIds $requireDecisionEvidence
  }
  if ($Gate -eq "Release") {
    Test-Approval $projectText "Release Approved" $decisionIds $requireDecisionEvidence
  }

  if ($Mode -ne "Lite" -and $projectSourceIds.Count -gt 0 -and $reqRows.Count -gt 0) {
    $missingSourceIds = @()
    foreach ($row in $reqRows) {
      $matches = [regex]::Matches($row.'Source Ref', $sourceRefRegex)
      foreach ($match in $matches) {
        $value = $match.Value
        if ($value -match '^(MOM|REQ|TR)-' -and ($projectSourceIds -notcontains $value)) {
          $missingSourceIds += $value
        }
      }
    }
    $missingSourceIds = @($missingSourceIds | Sort-Object -Unique)
    if ($missingSourceIds.Count -gt 0) {
      Add-Result FAIL "Source references not found in Source Inventory/Snapshot: $($missingSourceIds -join ', ')" "REF-001"
    }
  }
}

$deliveryPath = Join-Path $project "DELIVERY.md"
$deliveryIds = @()
if (Test-Path -LiteralPath $deliveryPath) {
  $deliveryText = Get-Content -LiteralPath $deliveryPath -Raw
  $deliveryTaskSource = $null
  if ($deliveryText -match '(?m)^\s*-\s*Task source of truth:\s*`?(file|github)`?\s*$') {
    $deliveryTaskSource = $Matches[1]
    Add-Result PASS "Delivery task source of truth is explicit" "TASK-001"
  } else {
    $deliveryTaskSourceLevel = if ($Gate -eq "Release") { "FAIL" } else { "WARN" }
    Add-Result $deliveryTaskSourceLevel "Delivery task source of truth should be file or github" "TASK-001"
  }

  if ($projectTaskSource -and $deliveryTaskSource -and $projectTaskSource -ne $deliveryTaskSource) {
    Add-Result FAIL "PROJECT.md task source ($projectTaskSource) does not match DELIVERY.md task source ($deliveryTaskSource)" "TASK-002"
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
    $blankFields = $requiredFields | Where-Object { -not $item.$_ -or (Test-PlaceholderValue $item.$_) }
    if ($blankFields.Count -gt 0) {
      $workItemLevel = if ($Gate -eq "Release") { "FAIL" } else { "WARN" }
      Add-Result $workItemLevel "$($item.ID) has missing work item fields: $($blankFields -join ', ')" "WORKITEM-001"
    }
    if (@($policyEnums.modes) -notcontains $item.Mode) {
      Add-Result FAIL "$($item.ID) has invalid Mode: $($item.Mode)" "ENUM-001"
    }
    if (@($policyEnums.statuses) -notcontains $item.Status) {
      Add-Result FAIL "$($item.ID) has invalid Status: $($item.Status)" "ENUM-001"
    }
    if (@($policyEnums.review_stages) -notcontains $item.'Review Stage') {
      Add-Result FAIL "$($item.ID) has invalid Review Stage: $($item.'Review Stage')" "ENUM-001"
    }
    if ($item.'Strict Trigger' -and $item.'Strict Trigger' -ne "none" -and @($policyEnums.strict_triggers) -notcontains $item.'Strict Trigger') {
      Add-Result FAIL "$($item.ID) has invalid Strict Trigger: $($item.'Strict Trigger')" "ENUM-001"
    }
    if ($item.'Strict Trigger' -and $item.'Strict Trigger' -ne "none" -and $item.Mode -ne "Strict") {
      Add-Result FAIL "$($item.ID) has strict trigger but mode is $($item.Mode)" "STRICT-001"
    }

    foreach ($ref in Split-ReferenceValues $item.'Requirement Ref') {
      $refId = ([regex]::Match($ref, '\b(REQ-\d{3}|BR-\d{3})\b')).Value
      if ($refId -and ($projectReqIds + $projectBusinessIds) -notcontains $refId) {
        Add-Result FAIL "$($item.ID) references missing requirement/business rule: $refId" "REF-001"
      }
    }

    foreach ($designRef in Split-ReferenceValues $item.'Design Ref') {
      if ($designRef -eq "not_required" -and $Mode -eq "Lite") { continue }
      $designPath = Get-DesignPathFromRef $designRef
      if ($designPath -and -not (Test-Path -LiteralPath (Join-Path $project $designPath) -PathType Leaf)) {
        Add-Result FAIL "$($item.ID) references missing design file: $designPath" "REF-001"
      }
      if ($Mode -ne "Lite" -and -not $designPath) {
        Add-Result FAIL "$($item.ID) is missing a resolvable design reference" "REF-001"
      }
    }
  }
}

if ($Mode -eq "Lite" -and $Gate -eq "Release") {
  if (-not (Test-Path -LiteralPath $deliveryPath) -and $projectText -notmatch '(?i)work item') {
    Add-Result FAIL "Lite release requires DELIVERY.md or a Work Item section in PROJECT.md" "STRUCT-001"
  }
}

$raidPath = Join-Path $project "RAID-log.md"
if (Test-Path -LiteralPath $raidPath) {
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

$releaseText = ""
$releasePath = Join-Path $project "RELEASE.md"
if ($Gate -eq "Release" -and (Test-Path -LiteralPath $releasePath)) {
  $releaseText = Get-Content -LiteralPath $releasePath -Raw
  $rollbackLines = Get-TableLinesAfterHeading $releaseText '^##\s+Structured Rollback Plan'
  $rollbackDataRows = @()
  $badRollbackRows = @()
  if ($rollbackLines.Count -ge 3) {
    foreach ($line in ($rollbackLines | Select-Object -Skip 2)) {
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

  $scopeMatches = [regex]::Matches($releaseText, '\bD-\d{3}\b')
  $missingReleaseRefs = @()
  foreach ($match in $scopeMatches) {
    if ($deliveryIds -notcontains $match.Value) { $missingReleaseRefs += $match.Value }
  }
  $missingReleaseRefs = @($missingReleaseRefs | Sort-Object -Unique)
  if ($missingReleaseRefs.Count -gt 0) {
    Add-Result FAIL "Release references missing delivery item(s): $($missingReleaseRefs -join ', ')" "REF-001"
  }
}

if ($Mode -eq "Strict" -and $Gate -eq "Release") {
  $strictMissing = @()
  if (-not (Test-Path -LiteralPath (Join-Path $project "RTM.yaml") -PathType Leaf)) {
    $strictMissing += "RTM.yaml"
  }
  if (-not (Test-Path -LiteralPath (Join-Path $project "RAID-log.md") -PathType Leaf)) {
    $strictMissing += "RAID-log.md"
  }
  if (-not (Test-Path -LiteralPath (Join-Path $project "decision-log.md") -PathType Leaf)) {
    $strictMissing += "decision-log.md"
  }
  if (-not $deliveryText -or $deliveryText -notmatch "(?i)\|\s*(qa|security)\s*\|") {
    $strictMissing += "QA/security review stage"
  }
  if (-not $releaseText -or $releaseText -notmatch "(?i)Evidence Ref|manual security review|QA") {
    $strictMissing += "release verification evidence"
  }

  $rtmPath = Join-Path $project "RTM.yaml"
  if (Test-Path -LiteralPath $rtmPath -PathType Leaf) {
    $rtmText = Get-Content -LiteralPath $rtmPath -Raw
    $rtmReqIds = @(([regex]::Matches($rtmText, 'requirement_id:\s*(REQ-\d{3})')) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    foreach ($reqId in $projectReqIds) {
      if ($rtmReqIds -notcontains $reqId) {
        Add-Result FAIL "RTM missing requirement: $reqId" "RTM-001"
      }
    }
    if ($rtmReqIds.Count -eq 0 -or $rtmText -notmatch 'delivery_ref:\s*\S+' -or $rtmText -notmatch 'test_ref:\s*\S+' -or $rtmText -notmatch 'release_ref:\s*\S+') {
      Add-Result FAIL "Strict RTM is empty or missing delivery/test/release refs" "RTM-001"
    }
  }

  if ($strictMissing.Count -gt 0) {
    Add-Result FAIL "Strict release is missing required guardrails: $($strictMissing -join ', ')" "STRICT-002"
  } else {
    Add-Result PASS "Strict release includes traceability, review, and release evidence guardrails" "STRICT-002"
  }
}

$sensitivePatterns = @(
  "\.env$",
  "\.env\.",
  "API[_-]?KEY",
  "SECRET",
  "TOKEN",
  "PASSWORD",
  "\.wav$",
  "\.mp3$",
  "\.m4a$",
  "Pricing",
  "Quotation"
)

$sensitiveHits = @()
foreach ($file in $allProjectFiles) {
  $relative = Get-RelativePath $file.FullName
  foreach ($pattern in $sensitivePatterns) {
    if ($relative -match $pattern) {
      $sensitiveHits += $relative
      break
    }
  }
}

if ($sensitiveHits.Count -eq 0) {
  Add-Result PASS "No obvious sensitive filenames found" "SENSITIVE-001"
} else {
  Add-Result WARN ("Potential sensitive filenames: " + (($sensitiveHits | Select-Object -First 8) -join ", ")) "SENSITIVE-001"
}

function Find-BrokenLinks {
  param($Files)
  $hits = @()
  foreach ($file in $Files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    $matches = [regex]::Matches($content, "\[[^\]]+\]\((?!https?://)([^)#]+)(?:#[^)]+)?\)")
    foreach ($match in $matches) {
      $target = $match.Groups[1].Value
      if ($target -match "^\s*$|^mailto:") { continue }
      $base = Split-Path -Parent $file.FullName
      $resolved = Join-Path $base $target
      if (-not (Test-Path -LiteralPath $resolved)) {
        $hits += "$($file.Name) -> $target"
      }
    }
  }
  return $hits
}

$linkHits = Find-BrokenLinks $governedFiles
if ($linkHits.Count -eq 0) {
  Add-Result PASS "No broken local markdown links found" "LINK-001"
} else {
  $linkLevel = if ($Gate -eq "Release") { "FAIL" } else { "WARN" }
  Add-Result $linkLevel ("Broken local links: " + (($linkHits | Select-Object -First 8) -join ", ")) "LINK-001"
}

$sourceLinkHits = Find-BrokenLinks $userSourceFiles
if ($sourceLinkHits.Count -eq 0) {
  Add-Result INFO "No broken user-source links found" "SOURCE-LINK-001"
} else {
  $sourceLinkLevel = if ($Gate -eq "Draft") { "INFO" } else { "WARN" }
  Add-Result $sourceLinkLevel ("Broken user-source links: " + (($sourceLinkHits | Select-Object -First 8) -join ", ")) "SOURCE-LINK-001"
}

$exitCode = 0
if ($fail -gt 0) {
  $exitCode = 1
} elseif ($FailOnWarning -and $warn -gt 0) {
  $exitCode = 2
}

if ($Format -eq "Json") {
  [pscustomobject]@{
    project = $project
    mode = $Mode
    gate = $Gate
    summary = [pscustomobject]@{
      pass = $pass
      warn = $warn
      fail = $fail
      exit_code = $exitCode
    }
    results = $messages
  } | ConvertTo-Json -Depth 6
} else {
  Write-Host "PMO Project Validation: $project"
  Write-Host "Mode=$Mode Gate=$Gate"
  Write-Host ""
  $messages | ForEach-Object { Write-Host "[$($_.level)] $($_.rule_id) $($_.message)" }
  Write-Host ""
  Write-Host "Summary: PASS=$pass WARN=$warn FAIL=$fail"
}

if ($exitCode -ne 0) {
  exit $exitCode
}

exit 0
