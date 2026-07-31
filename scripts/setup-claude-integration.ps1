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

    - previews before writing (-DryRun), and the preview is a real diff of
      what would change, not a description of it;
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

$body = @"
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
  Write-Host "  Content outside these markers is not modified."
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
