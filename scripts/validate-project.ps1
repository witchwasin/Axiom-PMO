param(
  [Parameter(Mandatory = $true)]
  [Alias("Project")]
  [string]$ProjectPath,

  [ValidateSet("Lite", "Standard", "Strict")]
  [string]$Mode = "Standard",

  [ValidateSet("Draft", "Scope", "Design", "Release")]
  [string]$Gate = "Draft",

  [switch]$Release
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
$messages = New-Object System.Collections.Generic.List[string]

function Add-Result {
  param(
    [ValidateSet("PASS", "WARN", "FAIL", "INFO")]
    [string]$Level,
    [string]$Message
  )

  $script:messages.Add("[$Level] $Message") | Out-Null
  switch ($Level) {
    "PASS" { $script:pass++ }
    "WARN" { $script:warn++ }
    "FAIL" { $script:fail++ }
  }
}

function Test-File {
  param(
    [string]$RelativePath,
    [ValidateSet("required", "optional")]
    [string]$Requirement = "required"
  )

  $path = Join-Path $project $RelativePath
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    Add-Result PASS "Found $RelativePath"
    return $true
  }

  if ($Requirement -eq "required") {
    Add-Result FAIL "Missing $RelativePath"
  } else {
    Add-Result WARN "Missing optional file $RelativePath"
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
    Add-Result PASS "Found $RelativePath/"
    return $true
  }

  if ($Requirement -eq "required") {
    Add-Result FAIL "Missing $RelativePath/"
  } else {
    Add-Result WARN "Missing optional directory $RelativePath/"
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

  $escapedGate = [regex]::Escape($GateName)
  $line = ($ProjectText -split "`n") | Where-Object { $_ -match "\|\s*$escapedGate\s*\|" } | Select-Object -First 1
  if (-not $line) {
    Add-Result FAIL "Approval row not found for $GateName"
    return
  }

  $parts = @($line -split "\|" | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
  if ($parts.Count -lt 4) {
    Add-Result FAIL "$GateName approval row is not fully populated"
    return
  }

  $approver = $parts[1]
  $date = $parts[2]
  $evidence = $parts[3]
  $invalid = @()

  if (Test-PlaceholderValue $approver) { $invalid += "approver" }
  if ((Test-PlaceholderValue $date) -or -not (Test-DateValue $date)) { $invalid += "date" }
  if (Test-PlaceholderValue $evidence) { $invalid += "evidence" }

  if ($invalid.Count -gt 0) {
    Add-Result FAIL "$GateName approval has invalid or placeholder fields: $($invalid -join ', ')"
    return
  }

  Add-Result PASS "$GateName approval is valid"
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
  Add-Result PASS "No placeholder/TODO/TBD markers found"
} elseif ($Gate -eq "Draft") {
  Add-Result INFO ("Draft placeholders found in: " + (($placeholderHits | Select-Object -First 8) -join ", "))
} elseif ($Gate -eq "Release") {
  Add-Result FAIL ("Release gate has placeholder/TODO/TBD markers in: " + (($placeholderHits | Select-Object -First 8) -join ", "))
} else {
  Add-Result WARN ("Placeholder/TODO/TBD markers found in: " + (($placeholderHits | Select-Object -First 8) -join ", "))
}

$projectText = Get-ProjectText
if ($projectText) {
  $projectTaskSource = $null
  if ($projectText -match "Task source:\s*(file|github)") {
    $projectTaskSource = $Matches[1]
    Add-Result PASS "Task source is declared"
  } else {
    Add-Result WARN "Task source is not declared as file or github"
  }

  if ($projectText -match "## Source Snapshot") {
    if ($projectText -match "Last Synced At|synced_at") {
      Add-Result PASS "Source Snapshot section exists"
    } else {
      Add-Result WARN "Source Snapshot exists but does not show sync time"
    }
  } else {
    Add-Result WARN "Source Snapshot section is missing; PROJECT.md may become stale"
  }

  $sourcePath = Join-Path $project "source"
  $projectFile = Join-Path $project "PROJECT.md"
  if ((Test-Path -LiteralPath $sourcePath -PathType Container) -and (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
    $projectUpdated = (Get-Item -LiteralPath $projectFile).LastWriteTime
    $newerSources = Get-ChildItem -LiteralPath $sourcePath -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $projectUpdated }
    if ($newerSources.Count -gt 0) {
      Add-Result WARN "Source files may be newer than PROJECT.md; refresh Source Snapshot"
    }
  }

  $reqLines = ($projectText -split "`n") | Where-Object { $_ -match "^\|\s*REQ-\d{3}\s*\|" }
  if ($reqLines.Count -eq 0) {
    Add-Result WARN "No REQ-### entries found in PROJECT.md"
  } else {
    $missingSource = $reqLines | Where-Object { $_ -notmatch "MOM-\d{8}|REQ-\d{8}|TR-\d{8}|DEC-\d{3}|source_ref|Source Ref" }
    $missingEvidence = $reqLines | Where-Object { $_ -notmatch "verified|supported|inferred|missing|conflict|Evidence Status" }

    $missingLevel = if ($Gate -eq "Release") { "FAIL" } else { "WARN" }

    if ($missingSource.Count -eq 0) {
      Add-Result PASS "Requirement lines include source references"
    } else {
      Add-Result $missingLevel "$($missingSource.Count) requirement line(s) may be missing source_ref"
    }

    if ($missingEvidence.Count -eq 0) {
      Add-Result PASS "Requirement lines include evidence status"
    } else {
      Add-Result $missingLevel "$($missingEvidence.Count) requirement line(s) may be missing evidence status"
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
  if ($deliveryText -match "Task source of truth:\s*`?(file|github)`?") {
    $deliveryTaskSource = $Matches[1]
    Add-Result PASS "Delivery task source of truth is explicit"
  } else {
    Add-Result WARN "Delivery task source of truth should be file or github"
  }

  if ($projectTaskSource -and $deliveryTaskSource -and $projectTaskSource -ne $deliveryTaskSource) {
    Add-Result FAIL "PROJECT.md task source ($projectTaskSource) does not match DELIVERY.md task source ($deliveryTaskSource)"
  }

  if ($deliveryText -match "\|\s*Mode\s*\|" -and $deliveryText -match "\|\s*Mode Reason\s*\|" -and $deliveryText -match "\|\s*Mode Approved By\s*\|" -and $deliveryText -match "\|\s*Review Stage\s*\|" -and $deliveryText -match "\|\s*PR / Evidence\s*\|") {
    Add-Result PASS "Delivery work items include mode, reason, approval, review, and evidence fields"
  } else {
    Add-Result WARN "Delivery work items should include Mode, Mode Reason, Mode Approved By, Review Stage, and PR / Evidence"
  }

  $workItemLines = ($deliveryText -split "`n") | Where-Object { $_ -match "^\|\s*D-\d{3}\s*\|" }
  $strictTriggerLines = $workItemLines | Where-Object { $_ -match "Payment|PII|Authentication|Authorization|Permission|External Integration|Production Data Migration" }
  if ($strictTriggerLines.Count -gt 0 -and $deliveryText -notmatch "\|\s*D-\d{3}\s*\|\s*Strict\s*\|") {
    Add-Result WARN "Potential strict trigger found in work items but no Strict work item detected"
  }
}

$raidPath = Join-Path $project "RAID-log.md"
if (Test-Path -LiteralPath $raidPath) {
  $raidText = Get-Content -LiteralPath $raidPath -Raw
  $blockerOpen = $raidText -match "(?i)\bblocker\b.*\bopen\b|\bopen\b.*\bblocker\b"
  if ($Gate -eq "Release" -and $blockerOpen) {
    Add-Result FAIL "Open blocker found in RAID-log.md during release validation"
  } elseif ($blockerOpen) {
    Add-Result WARN "Open blocker found in RAID-log.md"
  } else {
    Add-Result PASS "No open blocker pattern found"
  }
}

$releasePath = Join-Path $project "RELEASE.md"
if ($Gate -eq "Release" -and (Test-Path -LiteralPath $releasePath)) {
  $releaseText = Get-Content -LiteralPath $releasePath -Raw
  if ($releaseText -match "Rollback") {
    Add-Result PASS "Release includes rollback notes"
  } else {
    Add-Result FAIL "Release gate requires rollback notes"
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
  Add-Result PASS "No obvious sensitive filenames found"
} else {
  Add-Result WARN ("Potential sensitive filenames: " + (($sensitiveHits | Select-Object -First 8) -join ", "))
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
  Add-Result PASS "No broken local markdown links found"
} else {
  $linkLevel = if ($Gate -eq "Release") { "FAIL" } else { "WARN" }
  Add-Result $linkLevel ("Broken local links: " + (($linkHits | Select-Object -First 8) -join ", "))
}

Write-Host "PMO Project Validation: $project"
Write-Host "Mode=$Mode Gate=$Gate"
Write-Host ""
$messages | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "Summary: PASS=$pass WARN=$warn FAIL=$fail"

if ($fail -gt 0) {
  exit 1
}

exit 0
