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
$sentinelRules = $policy.sentinel_rules

$artifactPolicyPath = Join-Path $repoRoot "pmo-config/artifact-policy.json"
if (-not (Test-Path -LiteralPath $artifactPolicyPath -PathType Leaf)) {
  throw "Missing runtime artifact policy config: $artifactPolicyPath"
}
$artifactPolicy = Get-Content -LiteralPath $artifactPolicyPath -Raw | ConvertFrom-Json

$pass = 0
$warn = 0
$warnBlocking = 0
$fail = 0
$messages = New-Object System.Collections.Generic.List[object]

function Add-Result {
  param(
    [ValidateSet("PASS", "WARN", "FAIL", "INFO")]
    [string]$Level,
    [string]$Message,
    [string]$RuleId = "GENERAL-001",
    [bool]$Blocking = $true
  )

  $script:messages.Add([pscustomobject]@{
    level = $Level
    rule_id = $RuleId
    message = $Message
    blocking = $Blocking
  }) | Out-Null
  switch ($Level) {
    "PASS" { $script:pass++ }
    "WARN" { $script:warn++; if ($Blocking) { $script:warnBlocking++ } }
    "FAIL" { $script:fail++ }
  }
}

function Get-RelativePath {
  param([string]$Path)
  return $Path.Substring($project.Length).TrimStart("\", "/")
}

function Test-UserSourcePath {
  param([string]$RelativePath)
  return ($RelativePath -match '^(source|MOM|REQ|Transcript|Others)[\\/]')
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
  # not_required is a placeholder by default; it is only accepted where
  # policy.json sentinel_rules explicitly allows it (see Test-FieldValue).
  if ($trimmed -eq "not_required") { return $true }
  if ($trimmed -eq "-") { return $true }
  return ($trimmed -match "<[^>]+>|TODO|TBD|YYYY-MM-DD|ISO-8601|pending|n/a")
}

function Test-FieldValue {
  param(
    [string]$FieldName,
    [string]$Value,
    [string]$FieldMode
  )

  $trimmed = "$Value".Trim()
  if ($trimmed -eq "not_required") {
    $rule = $script:sentinelRules.not_required
    if ($rule -and (@($rule.allowed_fields) -contains $FieldName) -and (@($rule.allowed_modes) -contains $FieldMode)) {
      return $false
    }
    return $true
  }
  return (Test-PlaceholderValue $Value)
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

function Get-ProjectDefaultMode {
  param([string]$ProjectRoot)
  $path = Join-Path $ProjectRoot "PROJECT.md"
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $text = Get-Content -LiteralPath $path -Raw
  if ($text -match '(?m)^\s*>?\s*Default mode:\s*(.+?)\s*$') {
    return $Matches[1]
  }
  return $null
}

function Get-DeliveryModeSignals {
  param([string]$ProjectRoot, $Rank)
  $result = [pscustomobject]@{ HighestMode = $null; HasStrictTrigger = $false; StrictTriggerItem = $null }
  $path = Join-Path $ProjectRoot "DELIVERY.md"
  if (-not (Test-Path -LiteralPath $path)) { return $result }
  $text = Get-Content -LiteralPath $path -Raw
  $rows = Get-TableRowsAfterHeading $text '^##\s+Work Items'
  $highest = 0
  foreach ($row in $rows) {
    if ($Rank.ContainsKey($row.Mode) -and $Rank[$row.Mode] -gt $highest) { $highest = $Rank[$row.Mode] }
    if ($row.'Strict Trigger' -and $row.'Strict Trigger' -ne "none" -and -not $result.HasStrictTrigger) {
      $result.HasStrictTrigger = $true
      $result.StrictTriggerItem = $row.ID
    }
  }
  if ($highest -gt 0) {
    $result.HighestMode = @($Rank.Keys | Where-Object { $Rank[$_] -eq $highest })[0]
  }
  return $result
}

# Effective mode: CLI -Mode may upgrade but never silently downgrade a project.
# This closes the bypass where `-Mode Lite` on a Strict project skipped every
# Strict guardrail (RTM, RAID, decision-log, STRICT-002).
$modeRank = @{ "Lite" = 1; "Standard" = 2; "Strict" = 3 }
$requestedMode = $Mode
$projectDefaultModeRaw = Get-ProjectDefaultMode $project
if ($projectDefaultModeRaw -and -not $modeRank.ContainsKey($projectDefaultModeRaw)) {
  Add-Result WARN "PROJECT.md Default mode '$projectDefaultModeRaw' is not a recognized mode (Lite/Standard/Strict)" "MODE-002"
}
$deliverySignals = Get-DeliveryModeSignals $project $modeRank
$effectiveMode = $requestedMode
$effectiveReasons = @()
if ($projectDefaultModeRaw -and $modeRank.ContainsKey($projectDefaultModeRaw) -and $modeRank[$projectDefaultModeRaw] -gt $modeRank[$effectiveMode]) {
  $effectiveMode = $projectDefaultModeRaw
  $effectiveReasons += "PROJECT.md Default mode is $projectDefaultModeRaw"
}
if ($deliverySignals.HighestMode -and $modeRank[$deliverySignals.HighestMode] -gt $modeRank[$effectiveMode]) {
  $effectiveMode = $deliverySignals.HighestMode
  $effectiveReasons += "highest work item mode is $($deliverySignals.HighestMode)"
}
if ($deliverySignals.HasStrictTrigger -and $modeRank["Strict"] -gt $modeRank[$effectiveMode]) {
  $effectiveMode = "Strict"
  $effectiveReasons += "work item $($deliverySignals.StrictTriggerItem) has a strict trigger"
}

if ($modeRank[$effectiveMode] -gt $modeRank[$requestedMode]) {
  $modeLevel = if ($Gate -eq "Release") { "FAIL" } else { "WARN" }
  Add-Result $modeLevel "Requested mode $requestedMode cannot be used; effective mode is $effectiveMode ($($effectiveReasons -join '; '))" "MODE-001"
  if ($deliverySignals.HasStrictTrigger -and $effectiveMode -eq "Strict") {
    Add-Result INFO "Strict escalation triggered by work item $($deliverySignals.StrictTriggerItem)" "MODE-003"
  }
} else {
  Add-Result PASS "Effective mode ($effectiveMode) matches requested mode ($requestedMode)" "MODE-001"
}
$Mode = $effectiveMode

Test-File "PROJECT.md" | Out-Null

# Mode x Gate artifact matrix (pmo-config/artifact-policy.json) drives which
# artifacts are required at each (effective mode, gate) combination, instead of
# always requiring Standard/Strict artifacts regardless of gate (e.g. a Standard
# project at Draft no longer needs RELEASE.md/DELIVERY.md to exist yet).
$matrixRequired = @()
$modeMatrix = $artifactPolicy.artifact_matrix.$Mode
if ($modeMatrix -and $modeMatrix.$Gate) {
  $matrixRequired = @($modeMatrix.$Gate)
}

$allTrackedArtifacts = @("DELIVERY.md", "RELEASE.md", "RAID-log.md", "decision-log.md", "DESIGN")
foreach ($artifact in $allTrackedArtifacts) {
  $requirement = if ($matrixRequired -contains $artifact) { "required" } else { "optional" }
  if ($artifact -eq "DESIGN") {
    Test-Dir "DESIGN" $requirement | Out-Null
  } else {
    Test-File $artifact $requirement | Out-Null
  }
}
if ($Mode -eq "Strict") {
  Test-File "RTM.json" "optional" | Out-Null
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
    $blankFields = $requiredFields | Where-Object { -not $item.$_ -or (Test-FieldValue $_ $item.$_ $item.Mode) }
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
      if ($designRef -eq "not_required" -and -not (Test-FieldValue "Design Ref" $designRef $item.Mode)) { continue }
      $designPath = Get-DesignPathFromRef $designRef
      if ($designPath -and -not (Test-Path -LiteralPath (Join-Path $project $designPath) -PathType Leaf)) {
        Add-Result FAIL "$($item.ID) references missing design file: $designPath" "REF-001"
      }
      if ($item.Mode -ne "Lite" -and -not $designPath) {
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
  if (-not (Test-Path -LiteralPath (Join-Path $project "RTM.json") -PathType Leaf)) {
    $strictMissing += "RTM.json"
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

  # Row-by-row RTM.json validation: every requirement needs its own complete,
  # resolvable chain (design/delivery/test/evidence/release), not just "the
  # word delivery_ref appears somewhere in the file".
  $rtmPath = Join-Path $project "RTM.json"
  if (Test-Path -LiteralPath $rtmPath -PathType Leaf) {
    $releaseRegistry = Get-ReleaseRegistry $releaseText
    $rtmRaw = Get-Content -LiteralPath $rtmPath -Raw
    $rtmDoc = $null
    try { $rtmDoc = $rtmRaw | ConvertFrom-Json } catch { $rtmDoc = $null }

    if (-not $rtmDoc -or -not $rtmDoc.schema_version -or -not $rtmDoc.traceability -or @($rtmDoc.traceability).Count -eq 0) {
      Add-Result FAIL "RTM.json is empty, invalid, or missing schema_version/traceability" "RTM-001"
    } else {
      $rows = @($rtmDoc.traceability)
      $rtmReqIds = @($rows | Where-Object { $_.requirement_id } | ForEach-Object { $_.requirement_id } | Sort-Object -Unique)

      foreach ($reqId in $projectReqIds) {
        if ($rtmReqIds -notcontains $reqId) {
          Add-Result FAIL "RTM missing requirement: $reqId" "RTM-002"
        }
      }
      foreach ($rtmReqId in $rtmReqIds) {
        if ($projectReqIds -notcontains $rtmReqId) {
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

        if (-not $row.delivery_ref -or ($deliveryIds -notcontains $row.delivery_ref)) {
          Add-Result FAIL "RTM row $rid has a broken delivery_ref: $($row.delivery_ref)" "RTM-003"
        }
        if (-not $row.test_ref -or ($releaseRegistry.TestIds -notcontains $row.test_ref)) {
          Add-Result FAIL "RTM row $rid has a broken test_ref: $($row.test_ref)" "RTM-004"
        }
        $evidenceOk = $row.evidence_ref -and (-not (Test-PlaceholderValue $row.evidence_ref)) -and (
          $row.evidence_ref -notmatch '^DEC-\d{3}$' -or ($decisionIds -contains $row.evidence_ref)
        )
        if (-not $evidenceOk) {
          Add-Result FAIL "RTM row $rid has a broken or missing evidence_ref: $($row.evidence_ref)" "RTM-005"
        }
        if (-not $row.release_ref -or -not $releaseRegistry.ReleaseId -or $row.release_ref -ne $releaseRegistry.ReleaseId) {
          Add-Result FAIL "RTM row $rid has a broken release_ref: $($row.release_ref)" "RTM-006"
        }
      }
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

$sensitiveHitsGoverned = @()
$sensitiveHitsSource = @()
foreach ($file in $allProjectFiles) {
  $relative = Get-RelativePath $file.FullName
  foreach ($pattern in $sensitivePatterns) {
    if ($relative -match $pattern) {
      if (Test-UserSourcePath $relative) { $sensitiveHitsSource += $relative } else { $sensitiveHitsGoverned += $relative }
      break
    }
  }
}

if ($sensitiveHitsGoverned.Count -eq 0) {
  Add-Result PASS "No obvious sensitive filenames found in governed files" "SENSITIVE-001"
} else {
  Add-Result WARN ("Potential sensitive filenames: " + (($sensitiveHitsGoverned | Select-Object -First 8) -join ", ")) "SENSITIVE-001" -Blocking $true
}
if ($sensitiveHitsSource.Count -gt 0) {
  # User-owned source cannot be edited/renamed by policy; surface but never block Release.
  Add-Result WARN ("Potential sensitive filenames in user-owned source (informational, does not block): " + (($sensitiveHitsSource | Select-Object -First 8) -join ", ")) "SENSITIVE-001" -Blocking $false
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
  # User-owned source cannot be edited by policy; a broken link there is informational only.
  Add-Result WARN ("Broken user-source links: " + (($sourceLinkHits | Select-Object -First 8) -join ", ")) "SOURCE-LINK-001" -Blocking $false
}

$exitCode = 0
if ($fail -gt 0) {
  $exitCode = 1
} elseif ($FailOnWarning -and $warnBlocking -gt 0) {
  $exitCode = 2
}

if ($Format -eq "Json") {
  [pscustomobject]@{
    project = $project
    requested_mode = $requestedMode
    effective_mode = $effectiveMode
    gate = $Gate
    summary = [pscustomobject]@{
      pass = $pass
      warn = $warn
      warn_blocking = $warnBlocking
      fail = $fail
      exit_code = $exitCode
    }
    results = $messages
  } | ConvertTo-Json -Depth 6
} else {
  Write-Host "PMO Project Validation: $project"
  Write-Host "Requested Mode: $requestedMode"
  Write-Host "Detected Project Mode: $effectiveMode"
  Write-Host "Effective Mode: $effectiveMode"
  Write-Host "Gate=$Gate"
  Write-Host ""
  $messages | ForEach-Object {
    $tag = if ($_.level -eq "WARN" -and -not $_.blocking) { " (non-blocking)" } else { "" }
    Write-Host "[$($_.level)] $($_.rule_id) $($_.message)$tag"
  }
  Write-Host ""
  Write-Host "Summary: PASS=$pass WARN=$warn ($warnBlocking blocking) FAIL=$fail"
}

if ($exitCode -ne 0) {
  exit $exitCode
}

exit 0
