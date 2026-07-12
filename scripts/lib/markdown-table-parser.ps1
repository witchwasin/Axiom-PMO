# Generic markdown table parsing shared by every validator module: finds the
# first pipe-table after a given heading and turns it into row objects (or
# raw lines, for callers that need to hand-parse cells themselves).

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

function Get-IdsFromRows {
  param($Rows)
  return @($Rows | Where-Object { $_.ID } | ForEach-Object { $_.ID.Trim() })
}

function Split-ReferenceValues {
  param([string]$Value)
  if (-not $Value) { return @() }
  return @($Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}
