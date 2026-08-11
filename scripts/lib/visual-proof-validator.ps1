# Conditional Visual Proof validation for Milestone 10.
#
# This module deliberately verifies only repository facts: whether a project
# chose the creative-direction path, whether the proof record is structurally
# complete, whether its local captures exist and hash correctly, and whether
# the review still describes the artifacts in front of the reviewer. It never
# tries to infer pixels, judge taste, or turn a reviewer record into approval.

function Get-VisualProofSeverity {
  param(
    $SeverityMap,
    [string]$Mode,
    [string]$Default = "fail"
  )

  $value = $Default
  if ($SeverityMap) {
    $property = $SeverityMap.PSObject.Properties[$Mode]
    if ($property) { $value = [string]$property.Value }
  }
  if ($value -eq "warn") { return "WARN" }
  return "FAIL"
}

function Test-VisualProofActivated {
  param(
    [string]$Project,
    $VisualProofPolicy
  )

  foreach ($relative in @($VisualProofPolicy.activation.required_artifacts)) {
    if (-not (Test-Path -LiteralPath (Join-Path $Project ([string]$relative)) -PathType Leaf)) {
      return $false
    }
  }
  return $true
}

function Get-VisualProofTextSha256 {
  param([string]$Text)

  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = $sha.ComputeHash($bytes)
  } finally {
    $sha.Dispose()
  }
  return (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
}

function Get-VisualProofNormalizedTextHash {
  param([string]$Path)

  $content = Get-Content -LiteralPath $Path -Raw
  if ($null -eq $content) { $content = "" }
  $normalized = ($content -replace "`r`n", "`n") -replace "[ \t]+(?=\n)", ""
  return (Get-VisualProofTextSha256 -Text $normalized.TrimEnd())
}

function Get-VisualProofFileHash {
  param([string]$Path)

  return ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant())
}

function Get-VisualProofRelativePath {
  param(
    [string]$Project,
    [string]$Path
  )

  $projectRoot = (Resolve-Path -LiteralPath $Project).Path.TrimEnd([char[]]@([char]'\', [char]'/')).Replace([char]'\', [char]'/')
  $resolved = (Resolve-Path -LiteralPath $Path).Path.Replace([char]'\', [char]'/')
  $projectPrefix = $projectRoot + "/"
  if ($resolved -cne $projectRoot -and -not $resolved.StartsWith($projectPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Visual Proof file resolves outside the project root: $Path"
  }
  return $resolved.Substring($projectRoot.Length).TrimStart([char]'/')
}

function Sort-VisualProofOrdinal {
  param([string[]]$Values)

  $copy = [string[]]@($Values)
  [array]::Sort($copy, [System.StringComparer]::Ordinal)
  return $copy
}

function Get-VisualProofReviewInputDigest {
  param(
    [string]$Project,
    $VisualProofPolicy
  )

  $parts = New-Object System.Collections.Generic.List[string]
  $textExtensions = @($VisualProofPolicy.freshness.normalized_text_extensions | ForEach-Object { ([string]$_).ToLowerInvariant() })

  foreach ($relative in (Sort-VisualProofOrdinal -Values ([string[]]@($VisualProofPolicy.freshness.review_input_files)))) {
    $path = Join-Path $Project $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      $parts.Add("$relative`n<absent>") | Out-Null
      continue
    }
    $extension = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
    $digest = if ($textExtensions -contains $extension) {
      Get-VisualProofNormalizedTextHash -Path $path
    } else {
      Get-VisualProofFileHash -Path $path
    }
    $parts.Add("$relative`n$digest") | Out-Null
  }

  foreach ($directory in (Sort-VisualProofOrdinal -Values ([string[]]@($VisualProofPolicy.freshness.review_input_directories)))) {
    $directoryPath = Join-Path $Project $directory
    if (-not (Test-Path -LiteralPath $directoryPath -PathType Container)) {
      $parts.Add("$directory/`n<absent>") | Out-Null
      continue
    }
    $files = @(Get-ChildItem -LiteralPath $directoryPath -Recurse -File -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) {
      $parts.Add("$directory/`n<empty>") | Out-Null
      continue
    }
    foreach ($file in ($files | Sort-Object { Get-VisualProofRelativePath -Project $Project -Path $_.FullName })) {
      $relative = Get-VisualProofRelativePath -Project $Project -Path $file.FullName
      $extension = [System.IO.Path]::GetExtension($file.Name).ToLowerInvariant()
      $digest = if ($textExtensions -contains $extension) {
        Get-VisualProofNormalizedTextHash -Path $file.FullName
      } else {
        Get-VisualProofFileHash -Path $file.FullName
      }
      $parts.Add("$relative`n$digest") | Out-Null
    }
  }

  return (Get-VisualProofTextSha256 -Text ($parts -join "`n--`n"))
}

function Get-VisualProofPngDimensions {
  param([string]$Path)

  $stream = [System.IO.File]::OpenRead($Path)
  try {
    $buffer = New-Object byte[] 24
    $read = $stream.Read($buffer, 0, $buffer.Length)
  } finally {
    $stream.Dispose()
  }
  if ($read -lt 24) { return $null }

  $signature = @(137, 80, 78, 71, 13, 10, 26, 10)
  for ($index = 0; $index -lt $signature.Count; $index++) {
    if ($buffer[$index] -ne $signature[$index]) { return $null }
  }
  if ($buffer[12] -ne 73 -or $buffer[13] -ne 72 -or $buffer[14] -ne 68 -or $buffer[15] -ne 82) {
    return $null
  }

  $width = ([uint64]$buffer[16] -shl 24) -bor ([uint64]$buffer[17] -shl 16) -bor ([uint64]$buffer[18] -shl 8) -bor [uint64]$buffer[19]
  $height = ([uint64]$buffer[20] -shl 24) -bor ([uint64]$buffer[21] -shl 16) -bor ([uint64]$buffer[22] -shl 8) -bor [uint64]$buffer[23]
  if ($width -eq 0 -or $height -eq 0) { return $null }
  return [pscustomobject]@{ Width = $width; Height = $height }
}

function Get-VisualProofStringProperty {
  param(
    $Object,
    [string]$Name
  )

  if ($null -eq $Object) { return "" }
  $property = $Object.PSObject.Properties[$Name]
  if (-not $property -or $null -eq $property.Value) { return "" }
  if ($property.Value -is [datetimeoffset]) {
    return ([datetimeoffset]$property.Value).ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)
  }
  if ($property.Value -is [datetime]) {
    $dateValue = [datetime]$property.Value
    if ($dateValue.Kind -eq [System.DateTimeKind]::Unspecified -and $dateValue.TimeOfDay.Ticks -eq 0) {
      return $dateValue.ToString("yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
    }
    return $dateValue.ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)
  }
  return ("$($property.Value)").Trim()
}

function Get-VisualProofObjectProperty {
  param(
    $Object,
    [string]$Name
  )

  if ($null -eq $Object) { return $null }
  $property = $Object.PSObject.Properties[$Name]
  if (-not $property) { return $null }
  return $property.Value
}

function Test-VisualProofMinimumInteger {
  param(
    $Object,
    [string]$Name,
    [int]$Minimum
  )

  $value = Get-VisualProofStringProperty -Object $Object -Name $Name
  $parsed = 0
  if (-not [int]::TryParse($value, [ref]$parsed)) { return $false }
  return ($parsed -ge $Minimum)
}

function Get-VisualProofDirectionField {
  param(
    [string]$Text,
    [string[]]$Names
  )

  foreach ($name in $Names) {
    $pattern = "(?im)^\s*(?:-\s*)?" + [regex]::Escape($name) + "\s*:\s*(.+?)\s*$"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim().Trim('`', ' ') }

    $tablePattern = "(?im)^\s*\|\s*" + [regex]::Escape($name) + "\s*\|\s*([^|]+?)\s*\|"
    $tableMatch = [regex]::Match($Text, $tablePattern)
    if ($tableMatch.Success) { return $tableMatch.Groups[1].Value.Trim().Trim('`', ' ') }
  }
  return ""
}

function Get-VisualProofDirectionDeclaration {
  param([string]$Path)

  $raw = Get-Content -LiteralPath $Path -Raw
  $text = if ($null -eq $raw) { "" } else { $raw }
  return [pscustomobject]@{
    Status = Get-VisualProofDirectionField -Text $text -Names @("direction_status", "Direction status")
    SelectedDirection = Get-VisualProofDirectionField -Text $text -Names @("selected_direction", "Selected direction", "Direction")
    DecisionRef = Get-VisualProofDirectionField -Text $text -Names @("direction_decision_ref", "decision_ref", "Direction decision ref", "Human decision ref")
  }
}

function Get-VisualProofProjectCode {
  param([string]$ProjectText)

  $match = [regex]::Match($ProjectText, '(?m)^#\s+PROJECT\s+-\s+(.+?)\s*$')
  if (-not $match.Success) { return "" }
  return $match.Groups[1].Value.Trim()
}

function Get-VisualProofDecisionDecider {
  param(
    [string]$Project,
    [string]$DecisionId
  )

  $path = Join-Path $Project "decision-log.md"
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
  $raw = Get-Content -LiteralPath $path -Raw
  $text = if ($null -eq $raw) { "" } else { $raw }
  $rows = @(Get-TableRowsAfterHeading $text '^#\s+Decision Log')
  if ($rows.Count -eq 0) { $rows = @(Get-TableRowsAfterHeading $text '^##?\s+') }

  foreach ($row in $rows) {
    $rowId = ""
    foreach ($idColumn in @("ID", "Decision ID")) {
      $property = $row.PSObject.Properties[$idColumn]
      if ($property -and -not [string]::IsNullOrWhiteSpace("$($property.Value)")) {
        $rowId = "$($property.Value)".Trim()
        break
      }
    }
    if ($rowId -cne $DecisionId) { continue }
    foreach ($deciderColumn in @("Decided By", "Owner", "Approved By", "Decider", "Approver")) {
      $property = $row.PSObject.Properties[$deciderColumn]
      if ($property -and -not [string]::IsNullOrWhiteSpace("$($property.Value)")) {
        return "$($property.Value)".Trim()
      }
    }
    return ""
  }
  return $null
}

function Test-VisualProofDate {
  param([string]$Value)

  if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
  $dateOnlyPattern = '^\d{4}-\d{2}-\d{2}$'
  $timestampPattern = '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|[+-]\d{2}:\d{2})$'
  if ($Value -notmatch $dateOnlyPattern -and $Value -notmatch $timestampPattern) {
    return $false
  }
  $parsed = [datetimeoffset]::MinValue
  return [datetimeoffset]::TryParse(
    $Value,
    [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Globalization.DateTimeStyles]::AssumeUniversal,
    [ref]$parsed
  )
}

function Test-VisualProofReview {
  param(
    [string]$Project,
    [string]$Mode,
    $HandoffPolicy,
    [string]$ProjectText,
    [string[]]$DecisionIds
  )

  $proof = $HandoffPolicy.visual_proof
  if (-not $proof) { throw "handoff-policy.json is missing visual_proof; refusing to guess M10 evidence policy." }
  if (-not (Test-VisualProofActivated -Project $Project -VisualProofPolicy $proof)) { return }

  $reviewRelative = [string]$proof.artifact
  $reviewPath = Join-Path $Project $reviewRelative
  $severity = Get-VisualProofSeverity -SeverityMap $proof.severity_by_mode -Mode $Mode
  if (-not (Test-Path -LiteralPath $reviewPath -PathType Leaf)) {
    Add-Result $severity "$reviewRelative is required when a project carries visual direction and both design-system artifacts" "VPROOF-001" $true -Artifact $reviewRelative
    return
  }

  $review = $null
  try {
    $raw = Get-Content -LiteralPath $reviewPath -Raw
    $review = $raw | ConvertFrom-Json
  } catch {
    Add-Result $severity "$reviewRelative is not valid JSON" "VPROOF-001" $true -Artifact $reviewRelative
    return
  }

  $problems = New-Object System.Collections.Generic.List[string]
  $projectCode = Get-VisualProofProjectCode -ProjectText $ProjectText
  if ((Get-VisualProofStringProperty -Object $review -Name "schema_version") -cne [string]$proof.schema_version) {
    $problems.Add("schema_version does not match the policy") | Out-Null
  }
  if (-not $projectCode) {
    $problems.Add("PROJECT.md does not declare a project code") | Out-Null
  } elseif ((Get-VisualProofStringProperty -Object $review -Name "project_code") -cne $projectCode) {
    $problems.Add("project_code does not match PROJECT.md") | Out-Null
  }
  if (-not (Test-VisualProofDate -Value (Get-VisualProofStringProperty -Object $review -Name "reviewed_at"))) {
    $problems.Add("reviewed_at is not an ISO date") | Out-Null
  }
  if (@($proof.reviewer_kinds) -notcontains (Get-VisualProofStringProperty -Object $review -Name "reviewer_kind")) {
    $problems.Add("reviewer_kind is not declared by policy") | Out-Null
  }
  if (Test-GenericOwner -Value (Get-VisualProofStringProperty -Object $review -Name "reviewer") -OwnerPolicy $HandoffPolicy.owner_policy) {
    $problems.Add("reviewer is not a named person or identifier") | Out-Null
  }

  $reviewDecision = Get-VisualProofStringProperty -Object $review -Name "decision_ref"
  if ($reviewDecision -notmatch '^DEC-\d{3}$' -or ($DecisionIds -notcontains $reviewDecision)) {
    $problems.Add("decision_ref is not a resolvable project decision") | Out-Null
  } else {
    $decider = Get-VisualProofDecisionDecider -Project $Project -DecisionId $reviewDecision
    if ($null -eq $decider -or (Test-GenericOwner -Value $decider -OwnerPolicy $HandoffPolicy.owner_policy)) {
      $problems.Add("decision_ref has no named decision owner") | Out-Null
    }
  }

  $directionPath = Join-Path $Project "DESIGN/VISUAL-DIRECTION.md"
  $direction = Get-VisualProofDirectionDeclaration -Path $directionPath
  if (@("selected", "conformance") -notcontains $direction.Status.ToLowerInvariant()) {
    $problems.Add("visual direction is not selected or conformance") | Out-Null
  }
  if ([string]::IsNullOrWhiteSpace($direction.SelectedDirection)) {
    $problems.Add("visual direction records no selected direction") | Out-Null
  }
  if ($direction.DecisionRef -notmatch '^DEC-\d{3}$' -or ($DecisionIds -notcontains $direction.DecisionRef)) {
    $problems.Add("visual direction has no resolvable selection decision") | Out-Null
  }
  $reviewDirection = Get-VisualProofObjectProperty -Object $review -Name "visual_direction"
  if ($null -eq $reviewDirection) {
    $problems.Add("visual_direction is not recorded") | Out-Null
  } else {
    if ((Get-VisualProofStringProperty -Object $reviewDirection -Name "selected_direction") -cne $direction.SelectedDirection) {
      $problems.Add("visual_direction.selected_direction does not match the selected direction") | Out-Null
    }
    if ((Get-VisualProofStringProperty -Object $reviewDirection -Name "decision_ref") -cne $direction.DecisionRef) {
      $problems.Add("visual_direction.decision_ref does not match the selection decision") | Out-Null
    }
  }

  $reviewedRubric = @($review.rubric)
  $policyRubricIds = @($proof.rubric | ForEach-Object { [string]$_.id })
  $seenRubricIds = @()
  foreach ($item in $reviewedRubric) {
    $id = Get-VisualProofStringProperty -Object $item -Name "id"
    $status = Get-VisualProofStringProperty -Object $item -Name "status"
    $seenRubricIds += $id
    if ($policyRubricIds -notcontains $id) { $problems.Add("rubric contains unknown id '$id'") | Out-Null; continue }
    if (@($proof.rubric_statuses) -notcontains $status) { $problems.Add("rubric '$id' has invalid status") | Out-Null; continue }
    if ($status -cne "reviewed") { $problems.Add("rubric '$id' is not reviewed") | Out-Null }
  }
  foreach ($id in $policyRubricIds) {
    if (@($seenRubricIds | Where-Object { $_ -ceq $id }).Count -ne 1) {
      $problems.Add("rubric '$id' is missing or duplicated") | Out-Null
    }
  }

  $captures = @($review.captures)
  $captureIds = @($captures | ForEach-Object { Get-VisualProofStringProperty -Object $_ -Name "id" })
  foreach ($expected in @($proof.captures)) {
    $id = [string]$expected.id
    $matching = @($captures | Where-Object { (Get-VisualProofStringProperty -Object $_ -Name "id") -ceq $id })
    if ($matching.Count -ne 1) {
      $problems.Add("capture '$id' is missing or duplicated") | Out-Null
      continue
    }
    $capture = $matching[0]
    $expectedPath = [string]$expected.path
    $capturePath = Get-VisualProofStringProperty -Object $capture -Name "path"
    if ($capturePath -cne $expectedPath) {
      $problems.Add("capture '$id' path is not the required local path") | Out-Null
      continue
    }
    $absoluteCapturePath = Join-Path $Project $expectedPath
    if (-not (Test-Path -LiteralPath $absoluteCapturePath -PathType Leaf)) {
      $problems.Add("capture '$id' file is missing") | Out-Null
      continue
    }
    $dimensions = Get-VisualProofPngDimensions -Path $absoluteCapturePath
    if ($null -eq $dimensions) {
      $problems.Add("capture '$id' does not have a PNG signature and IHDR dimensions") | Out-Null
    } else {
      if ($dimensions.Width -lt [uint64]$expected.min_width -or $dimensions.Height -lt [uint64]$expected.min_height) {
        $problems.Add("capture '$id' is below the configured minimum dimensions") | Out-Null
      }
    }
    $recordedHash = (Get-VisualProofStringProperty -Object $capture -Name "sha256").ToLowerInvariant()
    if ($recordedHash -notmatch '^[a-f0-9]{64}$' -or $recordedHash -cne (Get-VisualProofFileHash -Path $absoluteCapturePath)) {
      $problems.Add("capture '$id' sha256 does not match the committed file") | Out-Null
    }
    $viewport = Get-VisualProofObjectProperty -Object $capture -Name "viewport"
    if ($null -eq $viewport -or -not (Test-VisualProofMinimumInteger -Object $viewport -Name "width" -Minimum ([int]$expected.min_viewport_width)) -or -not (Test-VisualProofMinimumInteger -Object $viewport -Name "height" -Minimum ([int]$expected.min_viewport_height))) {
      $problems.Add("capture '$id' viewport is below the configured minimum") | Out-Null
    }
    if (@($proof.capture_methods) -notcontains (Get-VisualProofStringProperty -Object $capture -Name "capture_method")) {
      $problems.Add("capture '$id' has an unsupported capture_method") | Out-Null
    }
    if (-not (Test-VisualProofDate -Value (Get-VisualProofStringProperty -Object $capture -Name "captured_at"))) {
      $problems.Add("capture '$id' captured_at is not an ISO date") | Out-Null
    }
  }
  foreach ($id in $captureIds) {
    if (@($proof.captures | Where-Object { ([string]$_.id) -ceq $id }).Count -eq 0) {
      $problems.Add("capture '$id' is not declared by policy") | Out-Null
    }
  }

  $recommendation = Get-VisualProofObjectProperty -Object $review -Name "recommendation"
  if ($null -eq $recommendation -or (Get-VisualProofStringProperty -Object $recommendation -Name "status") -cne "accepted") {
    $problems.Add("recommendation.status is not accepted") | Out-Null
  }

  if ($problems.Count -gt 0) {
    foreach ($problem in $problems) {
      Add-Result $severity "Visual Proof is incomplete: $problem" "VPROOF-001" $true -Artifact $reviewRelative
    }
    return
  }

  $recordedDigest = Get-VisualProofStringProperty -Object $review.review_inputs -Name "digest"
  $currentDigest = Get-VisualProofReviewInputDigest -Project $Project -VisualProofPolicy $proof
  if ($recordedDigest -notmatch '^[a-f0-9]{64}$' -or $recordedDigest.ToLowerInvariant() -cne $currentDigest) {
    Add-Result $severity "Visual Proof is stale: a reviewed creative artifact, brand asset, or committed capture changed" "VPROOF-002" $true -Artifact $reviewRelative -Field "review_inputs.digest"
    return
  }

  Add-Result PASS "Visual Proof covers all $($policyRubricIds.Count) rubric items and is current against its committed captures" "VPROOF-001"
  Add-Result PASS "Visual Proof freshness digest matches the current creative artifacts and captures" "VPROOF-002"
}
