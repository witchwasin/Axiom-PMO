# DESIGN-001: the design system's two canonical files must agree on token values.
#
# DESIGN/DESIGN-SYSTEM.md declares tokens in its "## Design Tokens - ..." tables.
# DESIGN/DESIGN-SYSTEM.html carries the same tokens as CSS custom properties in
# its :root block. Both files are read by developers -- the markdown is the
# contract, the sheet is what a stakeholder looks at -- so a value written twice
# and maintained once is a defect the moment it drifts, and nothing else in the
# framework would notice.
#
# This is deliberately a Layer 1 check in the sense of
# docs/concepts/handoff-readiness.md: it compares two strings that are both
# present in the repository. It makes no judgement about whether a colour is
# right, whether contrast is adequate, or whether a token should exist.
#
# Three deliberate limits:
#
#   1. One-directional. Every token DECLARED in the markdown must exist in the
#      sheet with the same value. Extra custom properties in the sheet are
#      implementation detail, not a contract breach -- a sheet always needs
#      working values the contract has no opinion about.
#   2. Only tables that carry a "Value" column participate. The typography
#      table spreads one token across Family/Size/Line Height/Weight, which is
#      not a single comparable value, so it is skipped rather than guessed at.
#   3. Silent when either file is absent. The design system is optional in every
#      mode and this rule never asks for it to exist.

function Get-DesignSystemDeclaredTokens {
  # Returns @( @{ Name; Value; Section } ) for every row of every
  # "## Design Tokens" table that has both a Token and a Value column.
  param([string]$MarkdownText)

  $tokens = @()
  if ([string]::IsNullOrWhiteSpace($MarkdownText)) { return $tokens }

  $lines = $MarkdownText -split "`r?`n"
  $inTokenSection = $false
  $section = ""
  $tokenIndex = -1
  $valueIndex = -1

  foreach ($line in $lines) {
    if ($line -match '^\s*##\s+(.*)$') {
      $heading = $Matches[1].Trim()
      $inTokenSection = $heading -match '^Design Tokens'
      $section = $heading
      $tokenIndex = -1
      $valueIndex = -1
      continue
    }
    if (-not $inTokenSection) { continue }
    if ($line -notmatch '^\s*\|') {
      # A blank line or prose between tables ends the current table, so the
      # next table in the same section re-reads its own header row.
      if ($line -notmatch '\S') { $tokenIndex = -1; $valueIndex = -1 }
      continue
    }

    $cells = @(($line -split '\|'))
    if ($cells.Count -lt 3) { continue }
    # Drop the empty strings produced by the leading and trailing pipe.
    $cells = @($cells[1..($cells.Count - 2)] | ForEach-Object { $_.Trim() })

    if ($tokenIndex -lt 0) {
      for ($i = 0; $i -lt $cells.Count; $i++) {
        if ($cells[$i] -eq "Token") { $tokenIndex = $i }
        if ($cells[$i] -eq "Value") { $valueIndex = $i }
      }
      continue
    }
    if ($valueIndex -lt 0) { continue }
    if ($cells[$tokenIndex] -match '^-{2,}:?$' -or $cells[$tokenIndex] -match '^:?-{2,}:?$') { continue }
    if ($cells.Count -le $tokenIndex -or $cells.Count -le $valueIndex) { continue }

    $name = $cells[$tokenIndex]
    $value = $cells[$valueIndex]
    if ([string]::IsNullOrWhiteSpace($name)) { continue }
    if ($name -notmatch '^[A-Za-z][A-Za-z0-9-]*$') { continue }

    $tokens += @{ Name = $name; Value = $value; Section = $section }
  }

  return $tokens
}

function Get-DesignSystemSheetTokens {
  # Returns @( @{ Name; Value } ) for every custom property declared in the
  # first :root block of the sheet.
  param([string]$HtmlText)

  $tokens = @()
  if ([string]::IsNullOrWhiteSpace($HtmlText)) { return $tokens }

  $rootMatch = [regex]::Match($HtmlText, '(?s):root\s*\{(.*?)\}')
  if (-not $rootMatch.Success) { return $tokens }

  $body = $rootMatch.Groups[1].Value
  # Strip CSS comments so a commented-out token is not read as a declaration.
  $body = [regex]::Replace($body, '(?s)/\*.*?\*/', ' ')

  foreach ($declaration in ($body -split ';')) {
    $m = [regex]::Match($declaration, '(?s)^\s*--([A-Za-z][A-Za-z0-9-]*)\s*:\s*(.+?)\s*$')
    if (-not $m.Success) { continue }
    $tokens += @{ Name = $m.Groups[1].Value; Value = $m.Groups[2].Value }
  }

  return $tokens
}

function Resolve-DesignSystemVarReferences {
  # Substitutes var(--other-token) with that token's own value so a sheet may
  # compose tokens without being reported as drift. Three passes is more than
  # any realistic chain; a cycle simply stops resolving rather than hanging.
  param($SheetTokens)

  $resolved = @{}
  foreach ($token in $SheetTokens) { $resolved[$token.Name] = $token.Value }

  for ($pass = 0; $pass -lt 3; $pass++) {
    $changed = $false
    foreach ($name in @($resolved.Keys)) {
      $value = $resolved[$name]
      $expanded = [regex]::Replace($value, 'var\(\s*--([A-Za-z][A-Za-z0-9-]*)\s*\)', {
        param($match)
        $referenced = $match.Groups[1].Value
        if ($resolved.ContainsKey($referenced)) { return $resolved[$referenced] }
        return $match.Value
      })
      if ($expanded -ne $value) { $resolved[$name] = $expanded; $changed = $true }
    }
    if (-not $changed) { break }
  }

  return $resolved
}

function Get-NormalizedTokenValue {
  # Whitespace-insensitive, and hex colours compare by value not by case.
  param([string]$Value)
  if ($null -eq $Value) { return "" }
  $normalized = ($Value -replace '\s+', ' ').Trim()
  $normalized = [regex]::Replace($normalized, '#([0-9A-Fa-f]{3,8})\b', { param($m) "#" + $m.Groups[1].Value.ToUpperInvariant() })
  return $normalized
}

function Test-DesignSystemTokens {
  param(
    [string]$Project,
    [string]$Gate
  )

  $markdownRelative = "DESIGN/DESIGN-SYSTEM.md"
  $htmlRelative = "DESIGN/DESIGN-SYSTEM.html"
  $markdownPath = Join-Path $Project "DESIGN/DESIGN-SYSTEM.md"
  $htmlPath = Join-Path $Project "DESIGN/DESIGN-SYSTEM.html"

  if (-not (Test-Path -LiteralPath $markdownPath -PathType Leaf)) { return }
  if (-not (Test-Path -LiteralPath $htmlPath -PathType Leaf)) { return }

  # Get-Content -Raw returns $null, not "", on a zero-byte file. See
  # docs/architecture/powershell-portability.md section 3.
  $rawMarkdown = Get-Content -LiteralPath $markdownPath -Raw
  $markdownText = if ($null -eq $rawMarkdown) { "" } else { $rawMarkdown }
  $rawHtml = Get-Content -LiteralPath $htmlPath -Raw
  $htmlText = if ($null -eq $rawHtml) { "" } else { $rawHtml }

  $declared = @(Get-DesignSystemDeclaredTokens -MarkdownText $markdownText)
  if ($declared.Count -eq 0) { return }

  $sheetTokens = @(Get-DesignSystemSheetTokens -HtmlText $htmlText)
  $resolved = Resolve-DesignSystemVarReferences -SheetTokens $sheetTokens

  # CSS custom property names are case-sensitive, so --Brand and --brand are
  # different tokens and a case difference is real drift, not a typo to absorb.
  $sheetNames = @($resolved.Keys)
  $problems = @()

  foreach ($token in $declared) {
    $match = @($sheetNames | Where-Object { $_ -ceq $token.Name })
    if ($match.Count -eq 0) {
      $problems += "$($token.Name) is declared in $markdownRelative but no --$($token.Name) exists in the sheet"
      continue
    }
    $sheetValue = Get-NormalizedTokenValue -Value $resolved[$match[0]]
    $declaredValue = Get-NormalizedTokenValue -Value $token.Value
    if ($sheetValue -ne $declaredValue) {
      $problems += "$($token.Name) is '$declaredValue' in $markdownRelative but '$sheetValue' in the sheet"
    }
  }

  if ($problems.Count -eq 0) {
    Add-Result PASS "Design system tokens agree between $markdownRelative and the sheet ($($declared.Count) checked)" "DESIGN-001"
    return
  }

  $level = switch ($Gate) {
    "Draft" { "INFO" }
    "Scope" { "WARN" }
    default { "FAIL" }
  }
  $message = "Design system token drift: " + (($problems | Select-Object -First 6) -join "; ")
  Add-Result $level $message "DESIGN-001" $true -Artifact $htmlRelative
}
