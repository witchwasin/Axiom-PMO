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
