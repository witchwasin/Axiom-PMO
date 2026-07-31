<#
.SYNOPSIS
  Generates (or checks) the Claude Code plugin's skills/ mirror.

.DESCRIPTION
  Claude Code discovers plugin skills from <plugin-root>/skills/ and nowhere
  else. This was established twice, independently, in Milestone 6.1: from the
  manifest reference (plugin.json has path overrides for commands, agents,
  hooks and mcpServers -- but not skills), and then empirically, by installing
  a probe plugin whose skills sat under .claude/skills/ and watching the
  component inventory report Skills (0).

  This repository keeps its own skills at .claude/skills/, because that is
  where Claude Code looks for a *project's* skills and this repository
  dogfoods its own framework. Those two facts are both true and neither can
  be given up, so skills/ is a generated mirror.

  A mirror invites drift, so it is not maintained by convention. -Check makes
  the comparison a CI gate: any difference in file set or bytes fails, and the
  message names the file.

  Nothing else is mirrored. The plugin root IS the repository root
  (marketplace source "./"), so scripts/, cli/, pmo-config/ and templates/ are
  already in place -- copying them would duplicate the validator, which the
  milestone explicitly forbids.

.PARAMETER Check
  Compare instead of write. Exit 1 on any drift. Intended for CI.
#>
[CmdletBinding()]
param(
  [switch]$Check
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$sourceRoot = Join-Path $repoRoot ".claude/skills"
$mirrorRoot = Join-Path $repoRoot "skills"

if (-not (Test-Path -LiteralPath $sourceRoot)) {
  Write-Host "[FAIL] PLUGIN-PKG-001 Source skills directory not found: .claude/skills"
  exit 1
}

function Get-SkillFileMap {
  param([string]$Root)
  $map = [ordered]@{}
  if (-not (Test-Path -LiteralPath $Root)) { return $map }
  $prefix = (Resolve-Path -LiteralPath $Root).Path
  foreach ($file in (Get-ChildItem -LiteralPath $Root -Recurse -File | Sort-Object FullName)) {
    $relative = $file.FullName.Substring($prefix.Length).TrimStart([char]92, [char]47)
    # Normalised so a mirror generated on Windows and checked on Linux compares
    # equal. Without this the gate would report drift on every cross-host run
    # and be switched off within a week.
    $relative = $relative -replace "\\", "/"
    $map[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  }
  return $map
}

$source = Get-SkillFileMap -Root $sourceRoot

if ($Check) {
  $mirror = Get-SkillFileMap -Root $mirrorRoot
  $problems = New-Object System.Collections.Generic.List[string]

  foreach ($key in $source.Keys) {
    if (-not $mirror.Contains($key)) {
      $problems.Add("missing from skills/: $key") | Out-Null
    } elseif ($mirror[$key] -ne $source[$key]) {
      $problems.Add("content differs: $key") | Out-Null
    }
  }
  foreach ($key in $mirror.Keys) {
    if (-not $source.Contains($key)) {
      $problems.Add("present in skills/ but not in .claude/skills/: $key") | Out-Null
    }
  }

  if ($problems.Count -gt 0) {
    Write-Host "[FAIL] PLUGIN-PKG-002 The packaged skills mirror has drifted from .claude/skills/"
    foreach ($p in $problems) { Write-Host "        - $p" }
    Write-Host ""
    Write-Host "  Fix: run scripts/build-plugin-package.ps1 and commit the result."
    Write-Host "  .claude/skills/ is the single source of truth; skills/ is generated."
    Write-Host ""
    Write-Host "Summary: PASS=0 FAIL=1"
    exit 1
  }

  Write-Host "[PASS] PLUGIN-PKG-002 Packaged skills mirror matches .claude/skills/ ($($source.Count) files)"
  Write-Host ""
  Write-Host "Summary: PASS=1 FAIL=0"
  exit 0
}

# Rebuild from scratch rather than merging into whatever is there: a stale
# skill left behind by a rename is exactly the kind of thing a mirror is
# supposed to make impossible.
if (Test-Path -LiteralPath $mirrorRoot) {
  Remove-Item -LiteralPath $mirrorRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $mirrorRoot -Force | Out-Null

foreach ($relative in $source.Keys) {
  $target = Join-Path $mirrorRoot $relative
  $targetDir = Split-Path -Parent $target
  if (-not (Test-Path -LiteralPath $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
  }
  Copy-Item -LiteralPath (Join-Path $sourceRoot $relative) -Destination $target -Force
}

Write-Host "Generated skills/ from .claude/skills/ ($($source.Count) files)."
Write-Host "This directory is generated. Edit .claude/skills/ and re-run this script."
exit 0
