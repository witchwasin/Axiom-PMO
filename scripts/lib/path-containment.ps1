# Physical path containment shared by the M4-M6 validators (CR-017).
#
# Why this exists: every artifact-reference check that only compares lexical
# prefixes (GetFullPath().StartsWith(root)) can be escaped by a repository
# symlink or a Windows junction that points outside the project. Lexical
# containment is not physical containment: a repo-relative symlink to
# /etc/hosts passed the old EXT checks.
#
# These helpers resolve the FINAL physical target of a path by walking every
# component (so a symlinked DIRECTORY is followed too, not only a symlink as
# the final component) and answer one question: does the real file live inside
# the project root? Callers must never echo file content; a failed containment
# check only reports that the path escapes the boundary.

function Get-PhysicalTargetPath {
  param([string]$Path)

  $full = [System.IO.Path]::GetFullPath($Path)
  $root = [System.IO.Path]::GetPathRoot($full)
  $relative = $full.Substring($root.Length).TrimStart([char]92, [char]47)
  $components = @($relative -split '[\\/]')
  $current = $root.TrimEnd([char]92, [char]47)
  if ([string]::IsNullOrWhiteSpace($current)) { $current = [System.IO.Path]::GetPathRoot($full) }
  $steps = 0
  foreach ($component in $components) {
    if ([string]::IsNullOrWhiteSpace($component)) { continue }
    $steps++
    if ($steps -gt 64) { return $null } # link-chain runaway guard

    $candidate = Join-Path $current $component
    $item = Get-Item -LiteralPath $candidate -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { return $candidate }
    $linkType = $null
    try { $linkType = $item.LinkType } catch { }
    if (-not $linkType) { $current = $candidate; continue }

    $target = $null
    $resolver = $item.PSObject.Methods["ResolveLinkTarget"]
    if ($null -ne $resolver) {
      try {
        $resolved = $item.ResolveLinkTarget($false)
        if ($null -ne $resolved) { $target = $resolved.FullName }
      } catch { }
    } else {
      # Windows PowerShell 5.1 has LinkType/Target but no ResolveLinkTarget.
      try { $target = [string]$item.Target } catch { }
    }
    if ([string]::IsNullOrWhiteSpace($target)) { return $null } # broken link
    if (-not [System.IO.Path]::IsPathRooted($target)) {
      $target = Join-Path $current $target
    }
    $current = [System.IO.Path]::GetFullPath($target)
  }
  return $current
}

function Test-PhysicalContainment {
  param([string]$Path, [string]$Root)

  # The project root itself may sit under a symlinked prefix (for example
  # /var -> /private/var on macOS or a mounted volume alias). Resolve BOTH
  # sides to their physical targets before comparing, or every file in a
  # temp-dir copy would falsely escape its own boundary.
  $physicalRoot = Get-PhysicalTargetPath -Path $Root
  if ($null -eq $physicalRoot) { $physicalRoot = [System.IO.Path]::GetFullPath($Root) }
  $root = $physicalRoot.TrimEnd([char]92, [char]47)
  $target = Get-PhysicalTargetPath -Path $Path
  if ($null -eq $target) { return $false }
  if ([string]::Equals($target, $root, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
  return $target.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

# Finds a reparse point ANYWHERE in $Path's own ancestry -- not just whether
# $Path itself is a symlink/junction, but whether a directory somewhere above
# it is, which redirects the whole subtree it contains. A naive physical-vs-
# lexical comparison false-positives on ordinary OS-level prefix aliases (for
# example /tmp -> /private/tmp on macOS) that every temp-dir test fixture
# sits under; those only ever rewrite a LEADING prefix identically for every
# path beneath them, while a planted symlink/junction diverts one INTERIOR
# component instead. Compare path components from the tail (leaf) backward:
# matching all the way until one side runs out means the only difference is a
# prefix alias (safe); the first component that actually differs is a real
# redirect. Ported to src/core/path-containment.ts's findAncestorReparsePoint
# -- keep both in lockstep.
function Find-AncestorReparsePoint {
  param([string]$Path)

  $lexical = [System.IO.Path]::GetFullPath($Path)
  $physical = Get-PhysicalTargetPath -Path $Path
  if ($null -eq $physical) { return $null } # doesn't exist yet -- nothing to walk

  $lexParts = @($lexical.TrimEnd([char]92, [char]47) -split '[\\/]' | Where-Object { $_ -ne '' })
  $physParts = @($physical.TrimEnd([char]92, [char]47) -split '[\\/]' | Where-Object { $_ -ne '' })

  $i = $lexParts.Count - 1
  $j = $physParts.Count - 1
  $matched = 0
  while ($i -ge 0 -and $j -ge 0) {
    if ($lexParts[$i].ToLowerInvariant() -ne $physParts[$j].ToLowerInvariant()) { break }
    $matched++
    $i--
    $j--
  }
  if ($i -lt 0 -or $j -lt 0) { return $null } # one side exhausted first: prefix alias only, safe

  $ancestor = $lexical
  for ($k = 0; $k -lt $matched; $k++) {
    $ancestor = Split-Path -Path $ancestor -Parent
  }
  return $ancestor
}
