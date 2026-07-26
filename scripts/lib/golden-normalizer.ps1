# Host-independent normalization for golden-master comparison.
#
# Why this exists: golden masters are captured by whichever PowerShell host runs
# the capture, but the JSON *pretty-printer* is not part of the diagnostic
# contract and is not stable across hosts:
#
#   Windows PowerShell 5.1        PowerShell 7 (pwsh)
#   ----------------------        -------------------
#   UTF-8 BOM at file start       no BOM
#   4-space indent, keys aligned  2-space indent
#   "project":  "value"           "project": "value"
#   <REPO_ROOT>\\examples\\X      <REPO_ROOT>/examples/X
#   escapes ' < & as \uXXXX      emits ' < & literally
#
# A byte-exact comparison therefore reports every case as a mismatch the moment
# the verifying host differs from the capturing host, which made `-VerifyGolden`
# unusable outside Windows and would make any future re-capture break the other
# platform's CI leg.
#
# What is still compared: the ordered sequence of results, every rule_id, level,
# blocking flag, message text, every summary counter, and the child exit code.
# What is deliberately ignored: indentation, BOM, line endings, and the path
# separator inside string values. Those are host artifacts, not behavior.

function Get-CanonicalGoldenText {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Text
  )

  if ($null -eq $Text) { return "" }

  # 1. Strip a UTF-8 BOM (Set-Content -Encoding utf8 emits one on 5.1).
  $normalized = $Text -replace "^\uFEFF", ""

  # 2. Normalize line endings; git's text normalization also rewrites these on
  #    checkout, so CRLF/LF must never be a mismatch source.
  $normalized = $normalized -replace "`r`n", "`n"

  # 3. Decode \uXXXX escapes to the characters they denote. Windows PowerShell
  #    5.1's ConvertTo-Json escapes the apostrophe, angle brackets, and
  #    ampersand into their numeric-escape form; pwsh 7 emits them literally.
  #    The negative lookbehind stops the second backslash of an escaped `\\`
  #    pair from being read as the start of an escape.
  $normalized = [regex]::Replace(
    $normalized,
    '(?<!\\)\\u([0-9a-fA-F]{4})',
    { param($m) [char][Convert]::ToInt32($m.Groups[1].Value, 16) })

  # 4. Windows path separators inside JSON string values arrive escaped as `\\`.
  #    Fold them to forward slashes so a Windows checkout and a POSIX checkout
  #    produce the same canonical text. Applied before whitespace handling so
  #    the replacement cannot interact with indentation.
  $normalized = $normalized.Replace('\\', '/')

  $lines = $normalized -split "`n"
  $canonicalLines = New-Object System.Collections.Generic.List[string]
  foreach ($line in $lines) {
    # 5. Drop indentation: 5.1 aligns nested values under the key column,
    #    7 uses a flat 2-space step. Neither is semantic.
    $trimmed = $line.Trim()
    # 6. Collapse the run of spaces 5.1 inserts after a key's colon.
    $trimmed = [regex]::Replace($trimmed, '^("(?:[^"\\]|\\.)*")\s*:\s+', '$1: ')
    $canonicalLines.Add($trimmed) | Out-Null
  }

  return (($canonicalLines -join "`n").TrimEnd())
}

# Compare a freshly produced output against a stored golden file.
# Returns $true when they are equivalent under canonical normalization.
function Test-GoldenMatch {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Expected,

    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Actual
  )

  return (Get-CanonicalGoldenText -Text $Expected) -eq (Get-CanonicalGoldenText -Text $Actual)
}
