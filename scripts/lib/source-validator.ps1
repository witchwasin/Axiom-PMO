# Source classification, PROJECT.md scope/requirement checks, placeholder
# scanning, sensitive-filename scanning, and broken-link checks. Consistently
# treats source/MOM/REQ/Transcript/Others as user-owned: never edited, and
# never allowed to block Release just because a client file has a TODO.

function Test-UserSourcePath {
  param([string]$RelativePath)
  return ($RelativePath -match '^(source|MOM|REQ|Transcript|Others)[\\/]')
}

function Test-GovernedPlaceholders {
  param($GovernedFiles, [string]$Gate)

  $placeholderHits = @()
  foreach ($file in $GovernedFiles) {
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
}

function Test-ProjectSourceSection {
  param(
    [string]$ProjectText,
    [string]$Mode,
    [string]$Gate,
    [string]$SourceRefRegex,
    $PolicyEnums,
    [string[]]$DecisionIds
  )

  $projectTaskSource = $null
  if ($ProjectText -match '(?m)^\s*>?\s*Task source:\s*(file|github)\s*$') {
    $projectTaskSource = $Matches[1]
    Add-Result PASS "Task source is declared" "TASK-001"
  } else {
    $taskSourceLevel = if ($Gate -eq "Release") { "FAIL" } else { "WARN" }
    Add-Result $taskSourceLevel "Task source is not declared as file or github" "TASK-001"
  }

  if ($ProjectText -match "## Source Snapshot") {
    if ($ProjectText -match "Last Synced At|synced_at") {
      Add-Result PASS "Source Snapshot section exists" "SOURCE-002"
    } else {
      Add-Result WARN "Source Snapshot exists but does not show sync time" "SOURCE-002"
    }
  } else {
    Add-Result WARN "Source Snapshot section is missing; PROJECT.md may become stale" "SOURCE-002"
  }

  $projectReqIds = @()
  $projectBusinessIds = @()
  $reqRows = Get-TableRowsAfterHeading $ProjectText '^###\s+In Scope'
  if ($reqRows.Count -eq 0) {
    $noReqLevel = if ($Gate -eq "Draft") { "INFO" } else { "FAIL" }
    Add-Result $noReqLevel "No REQ-### entries found in PROJECT.md" "SOURCE-001"
  } else {
    $projectReqIds = Get-IdsFromRows $reqRows
    $duplicateIds = $projectReqIds | Group-Object | Where-Object { $_.Count -gt 1 }
    if ($duplicateIds.Count -gt 0) {
      Add-Result FAIL "Duplicate requirement IDs: $($duplicateIds.Name -join ', ')" "SOURCE-003"
    }

    $missingSource = $reqRows | Where-Object { $_.'Source Ref' -notmatch $SourceRefRegex }
    $validEvidence = @($PolicyEnums.evidence_statuses)
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
  $sourceRows += Get-TableRowsAfterHeading $ProjectText '^##\s+Source Snapshot'
  $sourceRows += Get-TableRowsAfterHeading $ProjectText '^##\s+Source Inventory'
  $projectSourceIds = @($sourceRows | Where-Object { $_.'Source ID' } | ForEach-Object { $_.'Source ID'.Trim() } | Sort-Object -Unique)
  $projectBusinessIds = Get-IdsFromRows (Get-TableRowsAfterHeading $ProjectText '^##\s+Business Rules')

  $requireDecisionEvidence = ($Mode -ne "Lite")
  if ($Gate -in @("Scope", "Design", "Release")) {
    Test-Approval $ProjectText "Scope Approved" $DecisionIds $requireDecisionEvidence $Mode
  }
  if ($Gate -in @("Design", "Release") -and $Mode -ne "Lite") {
    Test-Approval $ProjectText "Design Ready" $DecisionIds $requireDecisionEvidence $Mode
  }
  if ($Gate -eq "Release") {
    Test-Approval $ProjectText "Release Approved" $DecisionIds $requireDecisionEvidence $Mode
  }

  if ($Mode -ne "Lite" -and $projectSourceIds.Count -gt 0 -and $reqRows.Count -gt 0) {
    $missingSourceIds = @()
    foreach ($row in $reqRows) {
      $refMatches = [regex]::Matches($row.'Source Ref', $SourceRefRegex)
      foreach ($refMatch in $refMatches) {
        $value = $refMatch.Value
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

  return [pscustomobject]@{
    ProjectReqIds = $projectReqIds
    ProjectBusinessIds = $projectBusinessIds
    ProjectTaskSource = $projectTaskSource
    ProjectSourceIds = $projectSourceIds
  }
}

function Test-SensitiveFilenames {
  param($AllProjectFiles)

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
  foreach ($file in $AllProjectFiles) {
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
}

function Find-BrokenLinks {
  param($Files)
  $hits = @()
  foreach ($file in $Files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    $linkMatches = [regex]::Matches($content, "\[[^\]]+\]\((?!https?://)([^)#]+)(?:#[^)]+)?\)")
    foreach ($linkMatch in $linkMatches) {
      $target = $linkMatch.Groups[1].Value
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

function Test-Links {
  param($GovernedFiles, $UserSourceFiles, [string]$Gate)

  $linkHits = Find-BrokenLinks $GovernedFiles
  if ($linkHits.Count -eq 0) {
    Add-Result PASS "No broken local markdown links found" "LINK-001"
  } else {
    $linkLevel = if ($Gate -eq "Release") { "FAIL" } else { "WARN" }
    Add-Result $linkLevel ("Broken local links: " + (($linkHits | Select-Object -First 8) -join ", ")) "LINK-001"
  }

  $sourceLinkHits = Find-BrokenLinks $UserSourceFiles
  if ($sourceLinkHits.Count -eq 0) {
    Add-Result INFO "No broken user-source links found" "SOURCE-LINK-001"
  } else {
    # User-owned source cannot be edited by policy; a broken link there is informational only.
    Add-Result WARN ("Broken user-source links: " + (($sourceLinkHits | Select-Object -First 8) -join ", ")) "SOURCE-LINK-001" -Blocking $false
  }
}
