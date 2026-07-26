param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

# Line-ending regression tests.
#
# Why this file exists: `.gitattributes` marks `*.md`, `*.puml`, `*.csv`, and
# `*.json` as text, so a Windows checkout gets CRLF while a Linux or macOS
# checkout gets LF. Any regex in this repository that anchors with (?m)$ against
# raw file content therefore behaves differently by platform, because .NET's $
# matches immediately before \n and never before the \r of a \r\n pair.
#
# That is not hypothetical. It shipped: the E2E handoff filler used
# `(?m)^<[^>\r\n]+>$` to collapse template placeholders. On macOS it matched; on
# a Windows runner it matched nothing, the placeholders survived, and the
# generated project failed its own gate. Every check passed on the Linux CI leg
# and the Windows leg failed, which is the worst shape a bug can take -- it
# looks like a platform quirk rather than a defect.
#
# These tests assert the property directly, so the next one is caught before CI.

$ErrorActionPreference = "Stop"

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$pass = 0
$fail = 0

function Assert-True {
  param([string]$Name, [bool]$Condition, [string]$Detail = "")
  if ($Condition) {
    $script:pass++
    Write-Host "[PASS] $Name"
  } else {
    $script:fail++
    Write-Host "[FAIL] $Name$(if ($Detail) { " -- $Detail" })"
  }
}

Write-Host "Axiom-PMO Line Ending Tests: $repo"
Write-Host ""

# --- 1. No regex anchors (?m)$ in a way that CRLF would break ----------------
#
# A pattern is suspect when it uses the multiline end anchor with no tolerance
# for a carriage return immediately before it: no \r? , no \s* , and no
# character class that admits \r. Matching on `-split "\r?\n"` output is safe
# and common, so only patterns applied to raw text matter -- which in practice
# means the ones in the E2E filler and the generator.
$rawTextScripts = @(
  "tests/e2e/lib/fill-project.ps1",
  "scripts/new-project.ps1",
  "scripts/update-source-snapshot.ps1"
)

$suspect = @()
foreach ($relative in $rawTextScripts) {
  $path = Join-Path $repo $relative
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
  $lineNumber = 0
  foreach ($line in (Get-Content -LiteralPath $path)) {
    $lineNumber++
    if ($line -match '^\s*#') { continue }
    # Look for a multiline pattern that ends at $ with nothing that can absorb \r.
    foreach ($m in [regex]::Matches($line, "'(\(\?[a-z]*m[a-z]*\)[^']*)'")) {
      $pattern = $m.Groups[1].Value
      if ($pattern -notmatch '\$$') { continue }
      if ($pattern -match '\\r\?\$$' -or $pattern -match '\\s\*\$$' -or $pattern -match '\\s\+\$$') { continue }
      $suspect += "${relative}:${lineNumber}  $pattern"
    }
  }
}
Assert-True "no (?m)`$ anchor is applied to raw file text without CRLF tolerance" `
  ($suspect.Count -eq 0) (($suspect | Select-Object -First 3) -join ' ; ')

# --- 2. The specific pattern that broke, asserted behaviourally ---------------
#
# A structural scan can be fooled; this one runs the actual regex against both
# line endings and demands the same answer.
$placeholderPattern = '(?m)^<[^>\r\n]+>[ \t]*\r?$'
$lfSample = "### Section`n`nStatus: specified`n`n<Languages, frameworks, and versions.>`n"
$crlfSample = $lfSample -replace "`n", "`r`n"
$lfHits = [regex]::Matches($lfSample, $placeholderPattern).Count
$crlfHits = [regex]::Matches($crlfSample, $placeholderPattern).Count
Assert-True "the template placeholder pattern matches under LF" ($lfHits -eq 1) "hits=$lfHits"
Assert-True "the template placeholder pattern matches identically under CRLF" `
  ($crlfHits -eq $lfHits) "lf=$lfHits crlf=$crlfHits"

# --- 3. Digests must not depend on line endings ------------------------------
#
# The review-input digest hashes file content. If it did not normalize line
# endings, every review would read as stale the moment it crossed platforms.
. (Join-Path $repo "scripts/lib/config-loader.ps1")
. (Join-Path $repo "scripts/lib/markdown-table-parser.ps1")
. (Join-Path $repo "scripts/lib/reference-resolver.ps1")
. (Join-Path $repo "scripts/lib/handoff-validator.ps1")

$cfg = Import-PmoConfig -RepoRoot $repo
$sample = Join-Path ([System.IO.Path]::GetTempPath()) ("pmo line endings " + [guid]::NewGuid().ToString("N"))
try {
  $source = Join-Path $repo "examples/HANDOFF-DEMO"
  Copy-Item -LiteralPath $source -Destination $sample -Recurse -Force

  $lfDigest = Get-ReviewInputDigest -Project $sample -HandoffPolicy $cfg.HandoffPolicy
  $lfSnapshot = Get-SourceSnapshotDigest -ProjectText (Get-Content -LiteralPath (Join-Path $sample "PROJECT.md") -Raw)

  foreach ($file in (Get-ChildItem -LiteralPath $sample -Recurse -File -Include *.md, *.puml, *.json)) {
    $text = [System.IO.File]::ReadAllText($file.FullName)
    # Normalize first, then convert: the parenthesis placement matters, or the
    # second -replace binds as a third argument to WriteAllText.
    $crlf = (($text -replace "`r`n", "`n") -replace "`n", "`r`n")
    [System.IO.File]::WriteAllText($file.FullName, $crlf)
  }

  $crlfDigest = Get-ReviewInputDigest -Project $sample -HandoffPolicy $cfg.HandoffPolicy
  $crlfSnapshot = Get-SourceSnapshotDigest -ProjectText (Get-Content -LiteralPath (Join-Path $sample "PROJECT.md") -Raw)

  Assert-True "the review-input digest survives a CRLF checkout" ($lfDigest -eq $crlfDigest) `
    "lf=$($lfDigest.Substring(0,12)) crlf=$($crlfDigest.Substring(0,12))"
  Assert-True "the source-snapshot digest survives a CRLF checkout" ($lfSnapshot -eq $crlfSnapshot) `
    "lf=$($lfSnapshot.Substring(0,12)) crlf=$($crlfSnapshot.Substring(0,12))"
} finally {
  if (Test-Path -LiteralPath $sample) { Remove-Item -LiteralPath $sample -Recurse -Force }
}

# --- 4. Golden comparison must survive a CRLF checkout too -------------------
. (Join-Path $repo "scripts/lib/golden-normalizer.ps1")
$goldenSample = "{`n  `"level`": `"FAIL`",`n  `"rule_id`": `"HANDOFF-004`"`n}`nEXIT_CODE=1"
Assert-True "golden comparison ignores the line ending" `
  (Test-GoldenMatch -Expected $goldenSample -Actual ($goldenSample -replace "`n", "`r`n"))

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"
if ($fail -gt 0) { exit 1 }
exit 0
