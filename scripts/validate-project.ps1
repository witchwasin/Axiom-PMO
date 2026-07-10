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
    if ($lines[$i].Trim().Length -eq 0) {
      if ($tableLines.Count -eq 0) { continue }
      break
    }
    if ($lines[$i] -match '^\s*#') { break }
    if ($lines[$i] -match '^\s*\|') { $tableLines += $lines[$i] }
  }
  if ($tableLines.Count -lt 2) { return @() }

  $headers = @($tableLines[0] -split '\|' | Select-Object -Skip 1 | Select-Object -First (($tableLines[0] -split '\|').Count - 2) | ForEach-Object { $_.Trim() })
  $rows = @()
  foreach ($line in ($tableLines | Select-Object -Skip 2)) {
    $cells = @($line -split '\|' | Select-Object -Skip 1 | Select-Object -First (($line -split '\|').Count - 2) | ForEach-Object { $_.Trim() })
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

function Test-Approval {
  param(
    [string]$ProjectText,
    [string]$GateName
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

  if ($invalid.Count -gt 0) {
    Add-Result FAIL "$GateName approval has invalid or placeholder fields: $($invalid -join ', ')" "APPROVAL-002"
    return
  }

  Add-Result PASS "$GateName approval is valid" "APPROVAL-002"
}

# Required files by mode/gate.
Test-File "PROJECT.md" | Out-Null

if ($Mode -eq "Lite") {
  Test-File "DELIVERY.md" "optional" | Out-Null
} else {
  Test-File "DELIVERY.md" | Out-Null
}

if ($Gate -eq "Release" -or $Mode -ne "Lite") {
  Test-File "RELEASE.md" | Out-Null
} else {
  Test-File "RELEASE.md" "optional" | Out-Null
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

$textFiles = Get-ChildItem -LiteralPath $project -Recurse -File -Include *.md,*.yaml,*.yml,*.puml,*.html -ErrorAction SilentlyContinue

$placeholderHits = @()
foreach ($file in $textFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
  if ($content -match "<[^>\r\n]+>|TODO|TBD") {
    $placeholderHits += $file.FullName.Substring($project.Length).TrimStart("\", "/")
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
if ($projectText) {
  $projectTaskSource = $null
  if ($projectText -match '(?m)^\s*>?\s*Task source:\s*(file|github)\s*$') {
    $projectTaskSource = $Matches[1]
    Add-Result PASS "Task source is declared" "TASK-001"
  } else {
    Add-Result WARN "Task source is not declared as file or github" "TASK-001"
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
    Add-Result WARN "No REQ-### entries found in PROJECT.md" "SOURCE-001"
  } else {
    $ids = @($reqRows | ForEach-Object { $_.ID })
    $duplicateIds = $ids | Group-Object | Where-Object { $_.Count -gt 1 }
    if ($duplicateIds.Count -gt 0) {
      Add-Result FAIL "Duplicate requirement IDs: $($duplicateIds.Name -join ', ')" "SOURCE-003"
    }

    $missingSource = $reqRows | Where-Object { $_.'Source Ref' -notmatch "MOM-\d{8}|REQ-\d{8}|TR-\d{8}|DEC-\d{3}|source_ref" }
    $validEvidence = @("verified", "supported", "inferred", "missing", "conflict")
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

  if ($Gate -in @("Scope", "Design", "Release")) {
    Test-Approval $projectText "Scope Approved"
  }
  if ($Gate -in @("Design", "Release")) {
    Test-Approval $projectText "Design Ready"
  }
  if ($Gate -eq "Release") {
    Test-Approval $projectText "Release Approved"
  }
}

$deliveryPath = Join-Path $project "DELIVERY.md"
if (Test-Path -LiteralPath $deliveryPath) {
  $deliveryText = Get-Content -LiteralPath $deliveryPath -Raw
  $deliveryTaskSource = $null
  if ($deliveryText -match '(?m)^\s*-\s*Task source of truth:\s*`?(file|github)`?\s*$') {
    $deliveryTaskSource = $Matches[1]
    Add-Result PASS "Delivery task source of truth is explicit" "TASK-001"
  } else {
    Add-Result WARN "Delivery task source of truth should be file or github" "TASK-001"
  }

  if ($projectTaskSource -and $deliveryTaskSource -and $projectTaskSource -ne $deliveryTaskSource) {
    Add-Result FAIL "PROJECT.md task source ($projectTaskSource) does not match DELIVERY.md task source ($deliveryTaskSource)" "TASK-002"
  }

  if ($deliveryText -match "\|\s*Mode\s*\|" -and $deliveryText -match "\|\s*Strict Trigger\s*\|" -and $deliveryText -match "\|\s*Mode Reason\s*\|" -and $deliveryText -match "\|\s*Mode Approved By\s*\|" -and $deliveryText -match "\|\s*Review Stage\s*\|" -and $deliveryText -match "\|\s*Evidence Ref\s*\|") {
    Add-Result PASS "Delivery work items include mode, strict trigger, reason, approval, review, and evidence fields" "WORKITEM-001"
  } else {
    Add-Result WARN "Delivery work items should include Mode, Strict Trigger, Mode Reason, Mode Approved By, Review Stage, and Evidence Ref" "WORKITEM-001"
  }

  $workItems = Get-TableRowsAfterHeading $deliveryText '^##\s+Work Items'
  foreach ($item in $workItems) {
    $requiredFields = @("ID", "Mode", "Mode Reason", "Mode Approved By", "Requirement Ref", "Design Ref", "Acceptance Criteria", "Test Checklist", "Owner", "Status", "Review Stage", "Evidence Ref")
    $blankFields = $requiredFields | Where-Object { -not $item.$_ -or (Test-PlaceholderValue $item.$_) }
    if ($blankFields.Count -gt 0) {
      Add-Result WARN "$($item.ID) has missing work item fields: $($blankFields -join ', ')" "WORKITEM-001"
    }
    if ($item.'Strict Trigger' -and $item.'Strict Trigger' -ne "none" -and $item.Mode -ne "Strict") {
      Add-Result FAIL "$($item.ID) has strict trigger but mode is $($item.Mode)" "STRICT-001"
    }
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

$releasePath = Join-Path $project "RELEASE.md"
if ($Gate -eq "Release" -and (Test-Path -LiteralPath $releasePath)) {
  $releaseText = Get-Content -LiteralPath $releasePath -Raw
  if ($releaseText -match "(?s)##\s+Structured Rollback Plan.*\|\s*Trigger\s*\|\s*Owner\s*\|\s*Steps\s*\|\s*Verification\s*\|\s*Evidence Ref\s*\|") {
    Add-Result PASS "Release includes structured rollback plan" "RELEASE-001"
  } elseif ($releaseText -match "Rollback") {
    Add-Result WARN "Release includes rollback notes but not a structured rollback table" "RELEASE-001"
  } else {
    Add-Result FAIL "Release gate requires structured rollback notes" "RELEASE-001"
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
foreach ($file in Get-ChildItem -LiteralPath $project -Recurse -File -ErrorAction SilentlyContinue) {
  $relative = $file.FullName.Substring($project.Length).TrimStart("\", "/")
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

$linkHits = @()
foreach ($file in $textFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
  $matches = [regex]::Matches($content, "\[[^\]]+\]\((?!https?://)([^)#]+)(?:#[^)]+)?\)")
  foreach ($match in $matches) {
    $target = $match.Groups[1].Value
    if ($target -match "^\s*$|^mailto:") { continue }
    $base = Split-Path -Parent $file.FullName
    $resolved = Join-Path $base $target
    if (-not (Test-Path -LiteralPath $resolved)) {
      $linkHits += "$($file.Name) -> $target"
    }
  }
}

if ($linkHits.Count -eq 0) {
  Add-Result PASS "No broken local markdown links found" "LINK-001"
} else {
  $linkLevel = if ($Gate -eq "Release") { "FAIL" } else { "WARN" }
  Add-Result $linkLevel ("Broken local links: " + (($linkHits | Select-Object -First 8) -join ", ")) "LINK-001"
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
