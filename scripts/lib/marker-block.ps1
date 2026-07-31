# Fenced, namespaced block management for files Axiom-PMO does not own.
#
# The whole of Milestone 6's repository-side footprint is one block appended to
# a file the user already owns. That makes this file the most dangerous code in
# the milestone: everything else operates on the framework's own directories,
# and this operates on somebody's AGENTS.md.
#
# Three rules follow from that, and every function here is shaped by them.
#
# 1. Only ever touch what is between our own markers. Content before and after
#    is not ours to reformat, reorder, or normalise.
#
# 2. Know whether the block is still ours. The BEGIN marker carries a digest of
#    the content the framework wrote. If what is actually inside no longer
#    hashes to it, a human edited our block, and "remove the Axiom block" stops
#    being an unambiguous instruction. Fail closed and say so.
#
# 3. Malformed is not the same as absent. A BEGIN with no END, two BEGINs, or a
#    nested pair means the file is in a state nobody designed. Refusing is the
#    only safe answer -- guessing which BEGIN belongs to which END is how a
#    tool silently eats half a document.

$script:AxiomMarkerBegin = "AXIOM-PMO:BEGIN"
$script:AxiomMarkerEnd = "AXIOM-PMO:END"

function Get-AxiomBlockDigest {
  <#
    .SYNOPSIS
      The digest recorded in a BEGIN marker and recomputed to detect edits.
    .DESCRIPTION
      Line endings are normalised before hashing. A file that round-trips
      through a Windows editor gets CRLF throughout, and that must not read as
      "the user edited our block" -- a false ownership conflict on every
      Windows machine would make uninstall unusable.
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content)

  $normalised = ($Content -replace "`r`n", "`n").Trim()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalised)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
  } finally { $sha.Dispose() }
}

function Read-TextFileState {
  <#
    .SYNOPSIS
      Read a text file, remembering how it was encoded so it can be written
      back the same way.
    .DESCRIPTION
      A setup command that silently strips a BOM or flips CRLF to LF has
      modified every line of a file it was supposed to append one block to.
      That shows up as a catastrophic diff in the user's next commit and is
      indistinguishable, at review time, from the tool having gone wrong.
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return [pscustomobject]@{ Exists = $false; Text = ""; HasBom = $false; Newline = [System.Environment]::NewLine }
  }

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
  $text = [System.Text.Encoding]::UTF8.GetString($bytes)
  if ($hasBom) { $text = $text.Substring(1) }

  # Dominant, not first: a file with one stray CRLF in an otherwise LF document
  # should stay an LF document.
  $crlfCount = ([regex]::Matches($text, "`r`n")).Count
  $lfCount = ([regex]::Matches($text, "(?<!`r)`n")).Count
  $newline = if ($crlfCount -gt $lfCount) { "`r`n" } else { "`n" }

  return [pscustomobject]@{ Exists = $true; Text = $text; HasBom = $hasBom; Newline = $newline }
}

function Write-TextFileAtomic {
  <#
    .SYNOPSIS
      Replace a file's contents without ever leaving it half-written.
    .DESCRIPTION
      Written to a temporary file in the same directory, then moved over the
      target. An interrupted run leaves either the old file or the new one --
      never a truncated AGENTS.md. Same directory matters: a move across
      filesystems is a copy, and a copy is not atomic.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
    [bool]$HasBom = $false
  )

  $directory = Split-Path -Parent $Path
  if (-not $directory) { $directory = "." }
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }

  $temp = Join-Path $directory (".axiom-write-" + [guid]::NewGuid().ToString("N").Substring(0, 10) + ".tmp")
  $encoding = New-Object System.Text.UTF8Encoding($HasBom)
  try {
    [System.IO.File]::WriteAllText($temp, $Text, $encoding)
    # Move-Item -Force replaces on every supported host; Rename-Item does not.
    Move-Item -LiteralPath $temp -Destination $Path -Force
  } catch {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
    throw
  }
}

function Find-AxiomBlock {
  <#
    .SYNOPSIS
      Locate the Axiom block in a document.
    .OUTPUTS
      Status is one of: absent, present, malformed.
      On 'present': Content, Digest (as recorded), StartIndex, EndIndex.
      On 'malformed': Reason, suitable for showing a user verbatim.
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

  $beginPattern = "<!--\s*" + [regex]::Escape($script:AxiomMarkerBegin) + "([^>]*?)-->"
  $endPattern = "<!--\s*" + [regex]::Escape($script:AxiomMarkerEnd) + "\s*-->"

  $begins = [regex]::Matches($Text, $beginPattern)
  $ends = [regex]::Matches($Text, $endPattern)

  if ($begins.Count -eq 0 -and $ends.Count -eq 0) {
    return [pscustomobject]@{ Status = "absent" }
  }
  if ($begins.Count -gt 1) {
    return [pscustomobject]@{ Status = "malformed"; Reason = "the file contains $($begins.Count) Axiom-PMO BEGIN markers; exactly one is expected" }
  }
  if ($ends.Count -gt 1) {
    return [pscustomobject]@{ Status = "malformed"; Reason = "the file contains $($ends.Count) Axiom-PMO END markers; exactly one is expected" }
  }
  if ($begins.Count -eq 1 -and $ends.Count -eq 0) {
    return [pscustomobject]@{ Status = "malformed"; Reason = "an Axiom-PMO BEGIN marker has no matching END marker" }
  }
  if ($begins.Count -eq 0 -and $ends.Count -eq 1) {
    return [pscustomobject]@{ Status = "malformed"; Reason = "an Axiom-PMO END marker has no matching BEGIN marker" }
  }
  if ($ends[0].Index -lt $begins[0].Index) {
    return [pscustomobject]@{ Status = "malformed"; Reason = "the Axiom-PMO END marker appears before its BEGIN marker" }
  }

  $attributes = [string]$begins[0].Groups[1].Value
  $digest = $null
  $digestMatch = [regex]::Match($attributes, '(?i)sha256\s*=\s*([0-9a-f]{64})')
  if ($digestMatch.Success) { $digest = $digestMatch.Groups[1].Value.ToLowerInvariant() }

  $contentStart = $begins[0].Index + $begins[0].Length
  $content = $Text.Substring($contentStart, $ends[0].Index - $contentStart)

  return [pscustomobject]@{
    Status = "present"
    Content = $content
    Digest = $digest
    StartIndex = $begins[0].Index
    EndIndex = $ends[0].Index + $ends[0].Length
  }
}

function Test-AxiomBlockOwnership {
  <#
    .SYNOPSIS
      Is the block still byte-for-byte what the framework wrote?
    .DESCRIPTION
      'owned'   -- safe to replace or remove.
      'edited'  -- a human changed our block. Removing it would destroy their
                   work, so callers must stop and report rather than proceed.
      'unknown' -- written before digests were recorded, or the attribute was
                   stripped. Treated as 'edited': not provably ours is not ours.
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)]$Block)

  if ($Block.Status -ne "present") { return "absent" }
  if (-not $Block.Digest) { return "unknown" }
  $actual = Get-AxiomBlockDigest -Content $Block.Content
  if ($actual -eq $Block.Digest) { return "owned" }
  return "edited"
}

function New-AxiomBlockText {
  <#
    .SYNOPSIS
      Render the block, with its own digest embedded in the BEGIN marker.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Body,
    [string]$Newline = "`n"
  )

  $normalisedBody = ($Body -replace "`r`n", "`n").Trim()
  $digest = Get-AxiomBlockDigest -Content $normalisedBody
  $lines = @(
    "<!-- $($script:AxiomMarkerBegin) v1 sha256=$digest -->",
    "",
    $normalisedBody,
    "",
    "<!-- $($script:AxiomMarkerEnd) -->"
  )
  return (($lines -join "`n") -replace "`n", $Newline)
}

function Set-AxiomBlock {
  <#
    .SYNOPSIS
      Insert or replace the block in a document, returning the new text.
    .DESCRIPTION
      Never modifies anything outside the markers. Appending leaves the
      existing document untouched and adds a blank line separator; replacing
      swaps only the span between and including the markers.
    .OUTPUTS
      Action is one of: inserted, replaced, unchanged, blocked.
      On 'blocked': Reason.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
    [Parameter(Mandatory = $true)][string]$Body,
    [string]$Newline = "`n",
    [switch]$Force
  )

  $block = Find-AxiomBlock -Text $Text
  $rendered = New-AxiomBlockText -Body $Body -Newline $Newline

  if ($block.Status -eq "malformed") {
    return [pscustomobject]@{ Action = "blocked"; Reason = $block.Reason; Text = $Text }
  }

  if ($block.Status -eq "absent") {
    if ([string]::IsNullOrWhiteSpace($Text)) {
      return [pscustomobject]@{ Action = "inserted"; Text = ($rendered + $Newline) }
    }
    $separator = $Newline + $Newline
    $trimmed = $Text.TrimEnd("`r", "`n")
    return [pscustomobject]@{ Action = "inserted"; Text = ($trimmed + $separator + $rendered + $Newline) }
  }

  $ownership = Test-AxiomBlockOwnership -Block $block
  if ($ownership -ne "owned" -and -not $Force) {
    $reason = if ($ownership -eq "edited") {
      "the existing Axiom-PMO block has been edited by hand; replacing it would discard those edits"
    } else {
      "the existing Axiom-PMO block carries no ownership digest, so it cannot be proven to be framework-generated"
    }
    return [pscustomobject]@{ Action = "blocked"; Reason = $reason; Text = $Text }
  }

  $existing = $Text.Substring($block.StartIndex, $block.EndIndex - $block.StartIndex)
  if ($existing -eq $rendered) {
    return [pscustomobject]@{ Action = "unchanged"; Text = $Text }
  }

  $updated = $Text.Substring(0, $block.StartIndex) + $rendered + $Text.Substring($block.EndIndex)
  return [pscustomobject]@{ Action = "replaced"; Text = $updated }
}

function Remove-AxiomBlock {
  <#
    .SYNOPSIS
      Remove the block, and nothing else, returning the new text.
    .OUTPUTS
      Action is one of: removed, absent, blocked.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
    [string]$Newline = "`n",
    [switch]$Force
  )

  $block = Find-AxiomBlock -Text $Text
  if ($block.Status -eq "absent") {
    return [pscustomobject]@{ Action = "absent"; Text = $Text }
  }
  if ($block.Status -eq "malformed") {
    return [pscustomobject]@{ Action = "blocked"; Reason = $block.Reason; Text = $Text }
  }

  $ownership = Test-AxiomBlockOwnership -Block $block
  if ($ownership -ne "owned" -and -not $Force) {
    $reason = if ($ownership -eq "edited") {
      "the Axiom-PMO block has been edited by hand; removing it would discard those edits"
    } else {
      "the Axiom-PMO block carries no ownership digest, so it cannot be proven safe to remove"
    }
    return [pscustomobject]@{ Action = "blocked"; Reason = $reason; Text = $Text }
  }

  $before = $Text.Substring(0, $block.StartIndex)
  $after = $Text.Substring($block.EndIndex)

  # The separator this tool inserted on the way in comes back out with it; any
  # blank lines the user put there themselves stay. Collapsing whitespace
  # further would be tidying somebody else's file.
  # Reassembled with the document's OWN newline, not a hardcoded LF. Getting
  # this wrong converted every CRLF file to LF on uninstall -- a one-line
  # change that rewrites every line of somebody's file, which is exactly the
  # damage this whole library exists to avoid.
  $result = ($before.TrimEnd("`r", "`n"))
  if (-not [string]::IsNullOrWhiteSpace($after)) {
    $result = $result + $Newline + $Newline + $after.Trim("`r", "`n")
  }
  if ($result.Length -gt 0) { $result = $result.TrimEnd("`r", "`n") + $Newline }

  return [pscustomobject]@{ Action = "removed"; Text = $result }
}

function New-AxiomBackup {
  <#
    .SYNOPSIS
      Copy a file aside before it is modified, never overwriting an earlier
      backup.
    .DESCRIPTION
      Timestamped to the second, which collides when setup and uninstall run
      back to back in a test or a script -- so a counter is appended rather
      than the earlier backup being silently replaced. A backup that can be
      destroyed by the next run is not a backup.
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$Path)

  # Invariant culture, deliberately. On this maintainer's own machine the
  # ambient culture is th-TH, where "yyyy" renders the Buddhist year 2569 --
  # so backups taken on two differently-configured machines in the same
  # repository would not sort against each other, and "newest backup" would
  # silently mean the wrong file.
  $stamp = [datetime]::Now.ToString("yyyyMMdd-HHmmss", [System.Globalization.CultureInfo]::InvariantCulture)
  $candidate = "$Path.axiom-backup-$stamp"
  $counter = 1
  while (Test-Path -LiteralPath $candidate) {
    $candidate = "$Path.axiom-backup-$stamp-$counter"
    $counter++
  }
  # The backup is the first write of the run, so it is the first thing a
  # read-only directory rejects. Reported as the same diagnostic as any other
  # write failure rather than as a raw Copy-Item exception -- the user's
  # problem is "this directory is not writable", not "Copy-Item threw".
  try {
    Copy-Item -LiteralPath $Path -Destination $candidate -Force
  } catch {
    throw ("could not write a backup next to " + (Split-Path -Leaf $Path) + ": " + $_.Exception.Message)
  }
  return $candidate
}

function Get-AxiomBackups {
  <#
    .SYNOPSIS
      Backups of a file, newest first.
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$Path)

  $directory = Split-Path -Parent $Path
  if (-not $directory) { $directory = "." }
  $leaf = Split-Path -Leaf $Path
  if (-not (Test-Path -LiteralPath $directory)) { return @() }
  return @(Get-ChildItem -LiteralPath $directory -File |
    Where-Object { $_.Name -like "$leaf.axiom-backup-*" } |
    Sort-Object Name -Descending)
}
