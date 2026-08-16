<#
.SYNOPSIS
  Add, preview, or remove the Axiom-PMO instruction block in a repository.

.DESCRIPTION
  Milestone 6.2 put the framework in a Claude Code plugin, which touches
  nothing in the user's repository. This command handles the part that cannot
  be avoided: the agent-facing instruction file.

  It has to be in the repository, as a file, because AGENTS.md is written for
  Claude, Codex, Cursor and Copilot alike. Shipping those rules only as a
  Claude Code plugin would quietly narrow a multi-agent framework into a
  single-vendor one.

  So the footprint is exactly one fenced block in one file, and this command's
  entire job is putting it there without damaging anything else:

    - previews before writing (-DryRun) by printing the exact block it would
      write plus a byte-count summary -- not a diff, and not a paraphrase;
    - backs up before modifying;
    - writes atomically, so an interrupted run leaves the old file or the new
      one and never a half-written one;
    - is idempotent -- running twice changes nothing the second time;
    - refuses, with a reason, when the existing block was edited by hand or the
      file's markers are malformed;
    - removes exactly what it added, and nothing adjacent.

  What the block does NOT do is worth stating as plainly as what it does. It
  hands Claude Code the approved scope and authority as governed context. It
  does not enforce them. Nothing here prevents an out-of-scope edit; SCOPE-DIFF
  and the EXEC-* rules detect one afterwards.

.PARAMETER ProjectPath
  The repository to modify. Defaults to the current directory.

.PARAMETER DryRun
  Print what would change and exit. Writes nothing.

.PARAMETER Uninstall
  Remove the Axiom-PMO block.

.PARAMETER Force
  Proceed even when the block cannot be proven framework-generated. Discards
  hand edits inside the block. Never implied by anything else.

.PARAMETER File
  Which instruction file to target. AGENTS.md by default -- it is the
  cross-agent surface; CLAUDE.md is Claude-specific and, in this repository's
  own convention, references AGENTS.md rather than duplicating it.
#>
[CmdletBinding()]
param(
  [string]$ProjectPath = ".",
  [switch]$DryRun,
  [switch]$Uninstall,
  [switch]$Force,
  [ValidateSet("AGENTS.md", "CLAUDE.md")]
  [string]$File = "AGENTS.md"
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/marker-block.ps1")

$exitOk = 0
$exitConflict = 1
$exitUsage = 2

function Write-Section { param([string]$Text) Write-Host ""; Write-Host $Text }

# ---- Resolve and contain the target ------------------------------------
# The path is user-supplied and everything below writes to it, so it is
# resolved to a real absolute path before anything else happens. A relative
# path containing .. is legitimate; a target file that escapes the resolved
# project root is not, and that check happens after resolution rather than by
# pattern-matching the input.

if (-not (Test-Path -LiteralPath $ProjectPath)) {
  Write-Host "[FAIL] SETUP-001 Project path does not exist: $ProjectPath"
  exit $exitUsage
}
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
if (-not (Test-Path -LiteralPath $project -PathType Container)) {
  Write-Host "[FAIL] SETUP-001 Project path is not a directory: $project"
  exit $exitUsage
}

$targetPath = Join-Path $project $File
$resolvedParent = (Resolve-Path -LiteralPath (Split-Path -Parent $targetPath)).Path
if ($resolvedParent -ne $project) {
  Write-Host "[FAIL] SETUP-002 Refusing to write outside the project directory."
  Write-Host "  project: $project"
  Write-Host "  target:  $targetPath"
  exit $exitConflict
}

# A reparse-point PROJECT ROOT points elsewhere: AGENTS.md physically lives in
# the link target, so editing it touches a tree this command was not asked to
# change -- the same escape the file-level SETUP-003 below refuses. Check the
# raw input before Resolve-Path dereferences anything (a junction must be seen
# as itself, not as its target). NTFS junctions carry the ReparsePoint
# attribute exactly like symlinks, so one check covers both. Verified on a real
# Windows host by src/probe/junction-probe.ts (CR-017-review-material §5).
$projectInput = Get-Item -LiteralPath $ProjectPath -Force -ErrorAction SilentlyContinue
if ($projectInput -and ($projectInput.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
  Write-Host "[FAIL] SETUP-003 Project path is a symbolic link or reparse point."
  Write-Host "  Refusing to follow it: the real project lies outside what this command was asked to change."
  Write-Host "  Fix: point --project at the real directory, or replace the link with a regular directory."
  exit $exitConflict
}

# A symlinked instruction file points somewhere this command was not asked to
# modify. Following it would edit a file outside the project without saying so.
if (Test-Path -LiteralPath $targetPath) {
  $item = Get-Item -LiteralPath $targetPath -Force
  if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
    Write-Host "[FAIL] SETUP-003 $File is a symbolic link or reparse point."
    Write-Host "  Refusing to follow it: the real file lies outside what this command was asked to change."
    Write-Host "  Fix: edit the real file directly, or replace the link with a regular file."
    exit $exitConflict
  }
}

# ---- Inspect what is already here --------------------------------------

$state = Read-TextFileState -Path $targetPath

# Encoding gate, before a backup is taken or a byte is written. A file this
# tool cannot decode losslessly is a file it must not rewrite: the whole
# promise is "one appended block, nothing else touched", and a lenient decode
# breaks that promise for every byte in the file at once.
if (-not $state.Supported) {
  Write-Host "[FAIL] SETUP-008 $File is $($state.Encoding); Axiom-PMO only edits UTF-8."
  Write-Host ""
  Write-Host "  Nothing was read as text, nothing was written, and no backup was taken --"
  Write-Host "  there is nothing to protect the file from, because nothing is going to touch it."
  Write-Host ""
  Write-Host "  Why this refuses instead of converting: rewriting the file would re-encode"
  Write-Host "  every byte in it, not just the block. A command that promises to append one"
  Write-Host "  section must not silently rewrite the other 99% of the document."
  Write-Host ""
  Write-Host "  Fix: convert $File to UTF-8 yourself, then re-run. On PowerShell:"
  Write-Host "    `$t = Get-Content -LiteralPath '$File' -Raw"
  Write-Host "    Set-Content -LiteralPath '$File' -Value `$t -Encoding utf8"
  Write-Host ""
  Write-Host "Summary: PASS=0 FAIL=1"
  exit $exitConflict
}

$block = Find-AxiomBlock -Text $state.Text
$ownership = Test-AxiomBlockOwnership -Block $block

Write-Host "Axiom-PMO Claude Code integration"
Write-Host "  Project:      $project"
Write-Host "  Target file:  $File $(if (-not $state.Exists) { '(will be created)' })"
Write-Host "  Axiom block:  $($block.Status)$(if ($block.Status -eq 'present') { " ($ownership)" })"

# Neighbours are reported, never touched. The point is that the user can see
# this command noticed their setup and left it alone.
$neighbours = New-Object System.Collections.Generic.List[string]
foreach ($probe in @(
  @{ Path = ".claude/skills"; Label = "Claude skills" },
  @{ Path = ".claude/commands"; Label = "Claude commands" },
  @{ Path = ".claude/settings.json"; Label = "Claude settings" },
  @{ Path = ".claude/hooks"; Label = "Claude hooks" },
  @{ Path = ".claude-plugin"; Label = "a plugin manifest" },
  @{ Path = "CLAUDE.md"; Label = "CLAUDE.md" },
  @{ Path = "AGENTS.md"; Label = "AGENTS.md" },
  @{ Path = ".bmad-core"; Label = "BMAD" },
  @{ Path = "bmad-core"; Label = "BMAD" },
  @{ Path = ".superpowers"; Label = "Superpowers" },
  @{ Path = "skills"; Label = "a skills directory" }
)) {
  $probePath = Join-Path $project $probe.Path
  if (Test-Path -LiteralPath $probePath) { $neighbours.Add("$($probe.Label) ($($probe.Path))") | Out-Null }
}
if ($neighbours.Count -gt 0) {
  Write-Host "  Detected:     $($neighbours -join '; ')"
  Write-Host "                left untouched -- this command only manages its own fenced block"
}

if ($block.Status -eq "malformed") {
  Write-Section "[FAIL] SETUP-004 The Axiom-PMO markers in $File are malformed."
  Write-Host "  $($block.Reason)"
  Write-Host ""
  Write-Host "  Refusing to guess which marker belongs to which. Repair the file by hand --"
  Write-Host "  the markers look like:"
  Write-Host "    <!-- AXIOM-PMO:BEGIN v1 sha256=... -->  ...  <!-- AXIOM-PMO:END -->"
  exit $exitConflict
}

# ---- The block itself ---------------------------------------------------
# Deliberately short. Every line here is context an agent reads on every
# session, and it grants nothing: no approval authority, no ability to close a
# finding, no exemption from any gate.

# The canonical body lives in the library, not here. Ownership is decided by
# comparing a block's content against what the framework generates, so there
# can only be one definition of that -- a second copy in this script would let
# the two drift and make ownership mean different things depending on which
# file you read.
$body = Get-AxiomCanonicalBody -Version "1"

# ---- Uninstall ----------------------------------------------------------

if ($Uninstall) {
  if (-not $state.Exists) {
    Write-Section "Nothing to remove: $File does not exist."
    exit $exitOk
  }

  $removal = Remove-AxiomBlock -Text $state.Text -Newline $state.Newline -Force:$Force
  if ($removal.Action -eq "absent") {
    Write-Section "Nothing to remove: $File has no Axiom-PMO block."
    exit $exitOk
  }
  if ($removal.Action -eq "blocked") {
    Write-Section "[FAIL] SETUP-005 Refusing to remove the Axiom-PMO block."
    Write-Host "  $($removal.Reason)"
    Write-Host ""
    Write-Host "  Nothing was changed. Either move your edits out of the block and re-run,"
    Write-Host "  or re-run with -Force to remove the block and the edits inside it."
    exit $exitConflict
  }

  if ($DryRun) {
    Write-Section "Dry run -- nothing was written."
    Write-Host "  Would remove the Axiom-PMO block from $File."
    Write-Host "  $($state.Text.Length) bytes -> $($removal.Text.Length) bytes"
    exit $exitOk
  }

  # The file is never deleted, whatever is left in it.
  #
  # An earlier version removed it when the remainder was empty or whitespace,
  # reasoning that setup must have created it. That reasoning is not available
  # after the fact: a repository whose AGENTS.md contained only a couple of
  # blank lines before installing is indistinguishable from one setup created,
  # and review found it deleting exactly that. Inferring provenance from a
  # file's current contents is guessing, and the mutable alternative -- writing
  # created=true into a marker anyone can edit -- would be guessing with extra
  # steps.
  #
  # So a zero-byte file may be left behind. That is the smallest wrong answer
  # available, and it is one the user can act on.
  try {
    $backup = New-AxiomBackup -Path $targetPath
    Write-TextFileAtomic -Path $targetPath -Text $removal.Text -HasBom $state.HasBom
  } catch {
    Write-Section "[FAIL] SETUP-007 Could not write $File."
    Write-Host "  $($_.Exception.Message)"
    Write-Host ""
    Write-Host "  The file was not modified -- the write is atomic, so it is either fully"
    Write-Host "  updated or untouched."
    if ($backup) { Write-Host "  A backup was taken first: $(Split-Path -Leaf $backup)" }
    exit $exitConflict
  }
  Write-Section "Removed the Axiom-PMO block from $File."
  Write-Host "  Backup: $(Split-Path -Leaf $backup)"
  if ([string]::IsNullOrWhiteSpace($removal.Text)) {
    Write-Host "  $File is now empty. It is left in place rather than deleted -- this command"
    Write-Host "  cannot tell a file it created from one that was already empty."
  }
  exit $exitOk
}

# ---- Install / update ---------------------------------------------------

$result = Set-AxiomBlock -Text $state.Text -Body $body -Newline $state.Newline -Force:$Force

if ($result.Action -eq "blocked") {
  Write-Section "[FAIL] SETUP-006 Refusing to modify the Axiom-PMO block."
  Write-Host "  $($result.Reason)"
  Write-Host ""
  Write-Host "  Nothing was changed. Re-run with -Force to overwrite the block as it stands."
  exit $exitConflict
}

if ($result.Action -eq "unchanged") {
  Write-Section "Already up to date -- $File is unchanged."
  exit $exitOk
}

if ($DryRun) {
  Write-Section "Dry run -- nothing was written."
  Write-Host "  Would $(if ($result.Action -eq 'inserted') { 'add' } else { 'update' }) the Axiom-PMO block in $File."
  Write-Host "  $($state.Text.Length) bytes -> $($result.Text.Length) bytes"
  Write-Host ""
  Write-Host "  --- block that would be written ---"
  foreach ($line in (New-AxiomBlockText -Body $body -Newline "`n") -split "`n") {
    Write-Host "  | $line"
  }
  Write-Host "  --- end ---"
  Write-Host ""
  Write-Host "  Nothing outside those markers is written, and nothing outside them would be"
  Write-Host "  removed by -Uninstall -- the block is appended with no separator, so"
  Write-Host "  install followed by uninstall returns this file to its current bytes exactly."
  exit $exitOk
}

$backup = $null
try {
  if ($state.Exists) { $backup = New-AxiomBackup -Path $targetPath }
  Write-TextFileAtomic -Path $targetPath -Text $result.Text -HasBom $state.HasBom
} catch {
  Write-Section "[FAIL] SETUP-007 Could not write $File."
  Write-Host "  $($_.Exception.Message)"
  Write-Host ""
  Write-Host "  The file was not modified -- the write is atomic, so it is either fully"
  Write-Host "  updated or untouched."
  if ($backup) { Write-Host "  A backup was taken first: $(Split-Path -Leaf $backup)" }
  exit $exitConflict
}

Write-Section "$(if ($result.Action -eq 'inserted') { 'Added' } else { 'Updated' }) the Axiom-PMO block in $File."
if ($backup) { Write-Host "  Backup: $(Split-Path -Leaf $backup)" }
Write-Host "  Remove it again with: -Uninstall"
exit $exitOk
