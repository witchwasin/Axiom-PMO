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

# The block body the framework generates, and the only content it will claim as
# its own.
#
# This lives here rather than in the setup script for a reason that a review
# found the hard way: ownership has to be decided against something the actor
# writing the file cannot choose. The first version compared the block's
# content to a digest recorded in the block's own BEGIN marker -- an unkeyed
# SHA-256 that anyone can compute. Arbitrary content plus a correctly computed
# digest read as "framework-generated", and uninstall then deleted content the
# framework had never written, with no -Force required. Demonstrated before
# this was changed.
#
# A digest proves a body has not changed since it was hashed. It proves nothing
# about who wrote it. That is the same thing Milestone 5 learned three times
# about execution evidence, arriving here in a different costume.
#
# So ownership is now: does this body match a body the framework itself
# generates? The digest is kept, but demoted to what it can actually support --
# telling "edited after we wrote it" apart from "never ours".
function Get-AxiomCanonicalBody {
  [CmdletBinding()]
  param([string]$Version = "1")
  if ($Version -ne "1") { return $null }
  return @"
## Axiom-PMO

This repository is governed by [Axiom-PMO](https://github.com/witchwasin/Axiom-PMO),
a governance and development-handoff framework. This block is generated -- edit
it by re-running the setup command, not by hand.

**Before implementing anything**, read the governed context for the work item
you were given: ``PROJECT.md`` for scope, ``DELIVERY.md`` for the work item and its
acceptance criteria, ``SCOPE.json`` for the approved implementation scope, and
``.execution/<work-item>/EXECUTION-CONTRACT.json`` if one was exported for you.

**Stay inside the approved scope.** Changing files outside ``SCOPE.json``'s
``implementation_scope`` is a scope deviation and will be reported.

**You may not approve your own work.** Report ``implementation-complete`` and
nothing more. Release, QA, security, scope-change, risk-downgrade and
test-evidence acceptance are human-only authority claims; each needs a decision
recorded in ``decision-log.md`` by a person. Writing ``"actor": "human"`` in a file
you authored does not make one.

**Evidence, not assertion.** A required test is satisfied by evidence from a
source you cannot impersonate -- a CI check -- or by a human accepting a
specific artifact on the record. Your own report that a test passed is not
evidence of it.

**Verification is after the fact.** Run
``axiom verify --project . --result .execution/<work-item>/EXECUTION-RESULT.json``
when you are done. This block gives you the approved scope and authority as
context; it does not enforce them, and nothing here prevents an out-of-scope
edit. Axiom-PMO checks afterwards whether the implementation stayed inside them.
"@
}

# Digests of every body version the framework has ever generated, frozen as
# literals.
#
# Frozen, not computed, and that is the point. If the canonical body is edited,
# the computed digest changes and every block already installed in a user's
# repository would stop being recognised as ours -- so uninstall would refuse
# and every user would need -Force. Keeping the old digests here is what makes
# an upgrade a normal operation instead of a support incident.
#
# Adding a version means appending its digest, never replacing one. A test
# asserts the current canonical body's digest is present, so editing the body
# without recording it fails the suite rather than silently orphaning installs.
$script:AxiomKnownBodyDigests = @(
  # v1 -- Milestone 6.3
  "b3af36639b1077269108f6719c53630ecdf6c3c517f410589a599686194c626b"
)

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

  # How much separator setup inserted before this block, if it said. Absent
  # means "unknown", which removal treats as zero -- never guessing that
  # whitespace it cannot account for belongs to it.
  $separatorLength = 0
  $sepMatch = [regex]::Match($attributes, '(?i)\bsep\s*=\s*(\d{1,3})')
  if ($sepMatch.Success) { $separatorLength = [int]$sepMatch.Groups[1].Value }
  $trailerLength = 0
  $tailMatch = [regex]::Match($attributes, '(?i)\btail\s*=\s*(\d{1,3})')
  if ($tailMatch.Success) { $trailerLength = [int]$tailMatch.Groups[1].Value }

  $contentStart = $begins[0].Index + $begins[0].Length
  $content = $Text.Substring($contentStart, $ends[0].Index - $contentStart)

  return [pscustomobject]@{
    Status = "present"
    Content = $content
    Digest = $digest
    SeparatorLength = $separatorLength
    TrailerLength = $trailerLength
    StartIndex = $begins[0].Index
    EndIndex = $ends[0].Index + $ends[0].Length
  }
}

function Test-AxiomBlockOwnership {
  <#
    .SYNOPSIS
      Did the framework write this block?
    .DESCRIPTION
      'owned'   -- the body is one the framework generates. Safe to replace or
                   remove.
      'edited'  -- the body is not canonical, and does not match the digest
                   recorded when it was written: something changed it after we
                   wrote it.
      'foreign' -- the body is not canonical, but its recorded digest matches
                   it exactly. Self-consistent, and self-consistency is not
                   authorship. This is the case a correctly forged digest
                   produces, and it must fail closed.
      'unknown' -- not canonical, and there is nothing to compare against.

      Only 'owned' permits an unforced replace or remove. The other three all
      require -Force, and the distinction between them exists so the message
      can tell the user which situation they are actually in.
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)]$Block)

  if ($Block.Status -ne "present") { return "absent" }

  $actual = Get-AxiomBlockDigest -Content $Block.Content
  if ($script:AxiomKnownBodyDigests -contains $actual) { return "owned" }

  if (-not $Block.Digest) { return "unknown" }
  if ($Block.Digest -eq $actual) { return "foreign" }
  return "edited"
}

function Get-AxiomOwnershipReason {
  <#
    .SYNOPSIS
      Why a non-owned block will not be touched, in words a user can act on.
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$Ownership, [string]$Verb = "modify")

  switch ($Ownership) {
    "edited" { return "the block's content is not one Axiom-PMO generates, and it no longer matches the digest recorded when it was written -- it has been edited by hand since. ${Verb}ing it would discard those edits" }
    "foreign" { return "the block's content is not one Axiom-PMO generates. Its recorded digest matches its content, but that digest is unkeyed and anyone can compute one -- a matching digest shows the content is internally consistent, not that Axiom-PMO wrote it. ${Verb}ing it would discard content the framework never created" }
    "unknown" { return "the block's content is not one Axiom-PMO generates and carries no recorded digest, so it cannot be shown to be framework-generated" }
    default { return "the block cannot be shown to be framework-generated" }
  }
}

function New-AxiomBlockText {
  <#
    .SYNOPSIS
      Render the block.
    .PARAMETER SeparatorLength
      How many characters of separator setup is inserting immediately before
      this block. Recorded in the marker as sep=N so that uninstall can remove
      exactly those characters and no others.
    .PARAMETER TrailerLength
      The same, for the newline setup appends immediately after the block.
      Recorded as tail=N. Symmetry matters here: an earlier version reclaimed
      the trailer only when the block happened to sit at end-of-file, so a
      block with content added below it left a stray newline behind on
      uninstall.

      This is written down rather than inferred because inferring it is
      guessing about the user's whitespace. If a file already ended with two
      blank lines and setup added none, an uninstall that "tidily" removed two
      newlines would be deleting the user's formatting.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Body,
    [string]$Newline = "`n",
    [int]$SeparatorLength = 0,
    [int]$TrailerLength = 0
  )

  $normalisedBody = ($Body -replace "`r`n", "`n").Trim()
  $digest = Get-AxiomBlockDigest -Content $normalisedBody
  $lines = @(
    "<!-- $($script:AxiomMarkerBegin) v1 sha256=$digest sep=$SeparatorLength tail=$TrailerLength -->",
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
      Insert or replace the block, returning the new text.
    .DESCRIPTION
      Never modifies a byte outside the markers -- not even whitespace.

      Inserting appends a fixed separator and the block to the text exactly as
      found. The original is NOT trimmed: an earlier version trimmed trailing
      newlines before appending, which silently rewrote the end of a file whose
      author had deliberately left blank lines there.

      Replacing splices only the span between and including the markers, and
      carries the existing block's recorded separator length forward -- the
      separator belongs to the install that created it, not to this rewrite.
    .OUTPUTS
      Action is one of: inserted, replaced, unchanged, blocked.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
    [Parameter(Mandatory = $true)][string]$Body,
    [string]$Newline = "`n",
    [switch]$Force
  )

  $block = Find-AxiomBlock -Text $Text

  if ($block.Status -eq "malformed") {
    return [pscustomobject]@{ Action = "blocked"; Reason = $block.Reason; Text = $Text }
  }

  if ($block.Status -eq "absent") {
    if ($Text.Length -eq 0) {
      $rendered = New-AxiomBlockText -Body $Body -Newline $Newline -SeparatorLength 0 -TrailerLength $Newline.Length
      return [pscustomobject]@{ Action = "inserted"; Text = ($rendered + $Newline) }
    }
    # A fixed separator, appended to the text verbatim. Whatever the file
    # already ended with stays exactly as it was.
    $separator = $Newline + $Newline
    $rendered = New-AxiomBlockText -Body $Body -Newline $Newline -SeparatorLength $separator.Length -TrailerLength $Newline.Length
    return [pscustomobject]@{ Action = "inserted"; Text = ($Text + $separator + $rendered + $Newline) }
  }

  $ownership = Test-AxiomBlockOwnership -Block $block
  if ($ownership -ne "owned" -and -not $Force) {
    return [pscustomobject]@{
      Action = "blocked"
      Reason = (Get-AxiomOwnershipReason -Ownership $ownership -Verb "replac")
      Text = $Text
    }
  }

  $rendered = New-AxiomBlockText -Body $Body -Newline $Newline -SeparatorLength $block.SeparatorLength -TrailerLength $block.TrailerLength
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
      Remove the block, and provably nothing else.
    .DESCRIPTION
      Removes the exact marker span, plus the separator setup recorded as its
      own (sep=N in the BEGIN marker) and only when those exact characters are
      actually there, plus the single trailing newline setup appends and only
      when it is the last character in the file.

      Everything else is left byte-for-byte. An earlier version reassembled the
      surrounding text with TrimEnd and Trim and a freshly chosen newline,
      which collapsed the user's blank lines around the block -- content the
      framework never owned. Whitespace is content.
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
    return [pscustomobject]@{
      Action = "blocked"
      Reason = (Get-AxiomOwnershipReason -Ownership $ownership -Verb "remov")
      Text = $Text
    }
  }

  $start = $block.StartIndex
  $end = $block.EndIndex

  # Reclaim the separator only if the marker says how much there was AND those
  # exact characters are sitting there. A recorded length that does not match
  # what is actually in the file means somebody edited around the block, and
  # their edit wins.
  if ($block.SeparatorLength -gt 0 -and $start -ge $block.SeparatorLength) {
    $candidate = $Text.Substring($start - $block.SeparatorLength, $block.SeparatorLength)
    if ($candidate -match '^[\r\n]+$') {
      $start = $start - $block.SeparatorLength
    }
  }

  # The trailer setup appended, reclaimed on the same terms as the separator:
  # only what the marker says is ours, and only when those exact characters are
  # actually there.
  if ($block.TrailerLength -gt 0 -and ($end + $block.TrailerLength) -le $Text.Length) {
    $candidate = $Text.Substring($end, $block.TrailerLength)
    if ($candidate -match '^[\r\n]+$') {
      $end = $end + $block.TrailerLength
    }
  }

  return [pscustomobject]@{ Action = "removed"; Text = ($Text.Substring(0, $start) + $Text.Substring($end)) }
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
