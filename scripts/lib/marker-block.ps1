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
      Read a text file, or report that its encoding is one this tool must not
      touch.
    .DESCRIPTION
      The first version decoded every file with the replacement-fallback UTF-8
      decoder. Feed it a UTF-16 file and the bytes come back as U+FFFD; write
      them out again and the file is destroyed -- every byte, not just the ones
      near the block. Demonstrated on a UTF-16LE AGENTS.md whose BOM (ff fe)
      came back as ef bf bd ef bf bd.

      A tool whose entire promise is "one appended block, nothing else touched"
      cannot lose that argument. So decoding is strict, and anything that is not
      UTF-8 is refused rather than mangled: refusing is a message, mangling is a
      restore-from-backup.
    .OUTPUTS
      Supported = $false with an Encoding label when the file must not be
      written. Callers must stop, and must not take a backup first -- there is
      nothing to protect a file from if nothing is going to be written to it.
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return [pscustomobject]@{
      Exists = $false; Supported = $true; Encoding = "utf-8"
      Text = ""; HasBom = $false; Newline = [System.Environment]::NewLine
    }
  }

  $bytes = [System.IO.File]::ReadAllBytes($Path)

  # BOM sniffing first: a UTF-16 BOM is unambiguous, and a UTF-16 file is very
  # likely to decode as *something* under a lenient UTF-8 decoder, which is
  # exactly how this went wrong.
  if ($bytes.Length -ge 2) {
    if ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
      return [pscustomobject]@{ Exists = $true; Supported = $false; Encoding = "UTF-16LE"; Text = ""; HasBom = $true; Newline = "`n" }
    }
    if ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
      return [pscustomobject]@{ Exists = $true; Supported = $false; Encoding = "UTF-16BE"; Text = ""; HasBom = $true; Newline = "`n" }
    }
  }
  if ($bytes.Length -ge 4) {
    if ($bytes[0] -eq 0 -and $bytes[1] -eq 0 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF) {
      return [pscustomobject]@{ Exists = $true; Supported = $false; Encoding = "UTF-32BE"; Text = ""; HasBom = $true; Newline = "`n" }
    }
    if ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0 -and $bytes[3] -eq 0) {
      return [pscustomobject]@{ Exists = $true; Supported = $false; Encoding = "UTF-32LE"; Text = ""; HasBom = $true; Newline = "`n" }
    }
  }

  $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)

  # Throw-on-invalid, not replace-on-invalid. UTF8Encoding($emitBom, $throwOnInvalid).
  $strict = New-Object System.Text.UTF8Encoding($false, $true)
  $text = $null
  try {
    $offset = if ($hasBom) { 3 } else { 0 }
    $text = $strict.GetString($bytes, $offset, $bytes.Length - $offset)
  } catch {
    return [pscustomobject]@{ Exists = $true; Supported = $false; Encoding = "not valid UTF-8"; Text = ""; HasBom = $hasBom; Newline = "`n" }
  }

  # Dominant, not first: a file with one stray CRLF in an otherwise LF document
  # should stay an LF document.
  $crlfCount = ([regex]::Matches($text, "`r`n")).Count
  $lfCount = ([regex]::Matches($text, "(?<!`r)`n")).Count
  $newline = if ($crlfCount -gt $lfCount) { "`r`n" } else { "`n" }

  return [pscustomobject]@{
    Exists = $true; Supported = $true; Encoding = if ($hasBom) { "utf-8 with BOM" } else { "utf-8" }
    Text = $text; HasBom = $hasBom; Newline = $newline
  }
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

  # sep= and tail= are deliberately NOT read. v1 recorded them so removal could
  # reclaim surrounding whitespace; they live in a marker anyone can edit, and
  # ownership is decided by the body, so an owned block could carry a tampered
  # sep and have uninstall delete the user's newlines. Nothing outside the span
  # is removed any more, so there is nothing for them to control.

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
      Render the block. Everything it returns lies inside the removable span.
    .DESCRIPTION
      The v1 format recorded sep= and tail= in the BEGIN marker, saying how many
      characters of surrounding whitespace setup had added, so removal could
      reclaim them. Review found the flaw: those attributes are inside a marker
      anyone can edit, and ownership is decided by the BODY. So a block could
      stay perfectly `owned` while its sep was changed from 2 to 6, and
      uninstall would then delete four newlines belonging to the user.

      The fix is not a bound or a sanity check on the number. It is to stop
      having a number: v2 writes nothing outside the markers that it expects to
      take back. What setup adds outside the span, it leaves there forever.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Body,
    [string]$Newline = "`n"
  )

  $normalisedBody = ($Body -replace "`r`n", "`n").Trim()
  $digest = Get-AxiomBlockDigest -Content $normalisedBody
  $lines = @(
    "<!-- $($script:AxiomMarkerBegin) v2 sha256=$digest -->",
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
      Insertion appends the block to the text exactly as found. The only byte
      it may add outside the markers is a single newline, and only when the
      file did not end with one -- without it the BEGIN marker would land on the
      same line as the user's last sentence.

      That newline is never taken back. Uninstall leaves it, so a file that had
      no trailing newline gains one permanently. An addition the user keeps is
      a far smaller thing than a deletion they did not ask for, and it is
      documented rather than silently reclaimed.

      Replacing splices only the span between and including the markers.
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
  $rendered = New-AxiomBlockText -Body $Body -Newline $Newline

  if ($block.Status -eq "malformed") {
    return [pscustomobject]@{ Action = "blocked"; Reason = $block.Reason; Text = $Text }
  }

  if ($block.Status -eq "absent") {
    if ($Text.Length -eq 0) {
      return [pscustomobject]@{ Action = "inserted"; Text = $rendered }
    }
    # At most one newline, and only if the file lacks one. Nothing else is
    # added outside the span, so there is nothing outside the span to reclaim.
    $bridge = ""
    if (-not ($Text.EndsWith("`n"))) { $bridge = $Newline }
    return [pscustomobject]@{ Action = "inserted"; Text = ($Text + $bridge + $rendered) }
  }

  $ownership = Test-AxiomBlockOwnership -Block $block
  if ($ownership -ne "owned" -and -not $Force) {
    return [pscustomobject]@{
      Action = "blocked"
      Reason = (Get-AxiomOwnershipReason -Ownership $ownership -Verb "replac")
      Text = $Text
    }
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
      Remove exactly the marker span. Never a byte more.
    .DESCRIPTION
      No whitespace reclaim, no separator accounting, no marker attribute
      consulted to decide how much to delete. The span is what the BEGIN and
      END markers bound, and that is the whole of what goes.

      A v1 block installed before this change recorded sep= and tail=; those
      are now ignored, so a blank line setup once added may be left behind.
      That residue is the deliberate choice: leaving a newline the user did not
      want is recoverable by them in a second, and deleting one they did want
      is not.
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

  return [pscustomobject]@{
    Action = "removed"
    Text = ($Text.Substring(0, $block.StartIndex) + $Text.Substring($block.EndIndex))
  }
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
