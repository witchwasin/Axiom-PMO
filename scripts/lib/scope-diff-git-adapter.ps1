# SCOPE-DIFF's only git-touching module. Everything here is read-only local
# git plumbing (rev-parse, diff --name-status) against commits already
# present in the checkout -- never a network operation, never a write.
#
# Privacy/safety contract (same standard as the M4 Action's own privacy fix):
# a git command's raw stdout/stderr is never returned to a caller that might
# put it in a report, an annotation, or an uploaded artifact. Failures are
# translated into a small set of known, actionable messages. The one place
# raw git stderr is allowed to go is this process's own stderr stream, which
# becomes the workflow run log -- exactly where a human debugging the
# underlying git state should look, and nowhere a persisted artifact reads
# from.

# Resolves one ref to a commit, without fetching. A ref that cannot be
# resolved on a shallow checkout is the single most common real-world
# SCOPE-DIFF-004 cause, so the message says so explicitly rather than
# forwarding whatever git printed.
function Test-ScopeDiffRefResolvable {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$Ref
  )

  $result = & git -C $RepoRoot rev-parse --verify --quiet "$Ref^{commit}" 2>$null
  $ok = ($LASTEXITCODE -eq 0) -and (-not [string]::IsNullOrWhiteSpace($result))
  return $ok
}

# Parses `git diff --name-status -z base head` output. -z is not a style
# choice: it NUL-separates every field, which is the only way to read a path
# containing a space, a newline, or any other character safely -- the
# non -z form quotes/escapes paths in a way that is lossy to parse back
# exactly, and this check exists specifically to compare paths byte-for-byte
# against declared patterns.
function ConvertFrom-ScopeDiffNameStatus {
  param([string]$RawOutput)

  $changes = New-Object System.Collections.Generic.List[object]
  if ([string]::IsNullOrEmpty($RawOutput)) { return $changes }

  $tokens = $RawOutput -split "`0"
  $i = 0
  while ($i -lt $tokens.Count) {
    $status = $tokens[$i]
    if ([string]::IsNullOrEmpty($status)) { $i++; continue }  # trailing NUL produces one empty token
    $i++
    if ($status.StartsWith('R') -or $status.StartsWith('C')) {
      # Rename/copy: two paths follow -- old, then new.
      if ($i + 1 -ge $tokens.Count) { break }
      $oldPath = $tokens[$i]; $i++
      $newPath = $tokens[$i]; $i++
      $changes.Add([pscustomobject]@{ Status = $status; Path = $newPath; OldPath = $oldPath }) | Out-Null
    } else {
      if ($i -ge $tokens.Count) { break }
      $path = $tokens[$i]; $i++
      $changes.Add([pscustomobject]@{ Status = $status; Path = $path; OldPath = $null }) | Out-Null
    }
  }
  return $changes
}

# Returns:
#   Ok = $true,  Changes = [...]
#   Ok = $false, ErrorCode = "base-unresolvable" | "head-unresolvable" | "diff-failed", ErrorDetail = <safe, non-raw message>
# ErrorDetail is written for a human to read in a diagnostic; it is built
# from known conditions, never from raw git stderr text.
function Get-ScopeDiffChangedFiles {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$BaseRef,
    [Parameter(Mandatory = $true)][string]$HeadRef
  )

  if (-not (Test-ScopeDiffRefResolvable -RepoRoot $RepoRoot -Ref $BaseRef)) {
    return [pscustomobject]@{
      Ok = $false
      ErrorCode = "base-unresolvable"
      ErrorDetail = "The base commit ($BaseRef) could not be resolved in this checkout. This is commonly a shallow checkout: actions/checkout defaults to fetch-depth 1, which does not include the base commit for a scope-diff comparison. Increase fetch-depth (or use fetch-depth: 0) in the checkout step."
      Changes = @()
    }
  }
  if (-not (Test-ScopeDiffRefResolvable -RepoRoot $RepoRoot -Ref $HeadRef)) {
    return [pscustomobject]@{
      Ok = $false
      ErrorCode = "head-unresolvable"
      ErrorDetail = "The head commit ($HeadRef) could not be resolved in this checkout."
      Changes = @()
    }
  }

  # --no-pager and explicit refs (never a bare "..." range) so behavior does
  # not depend on the current branch or on any pager/alias configuration in
  # the runner's environment.
  $stderrFile = [System.IO.Path]::GetTempFileName()
  try {
    $raw = & git -C $RepoRoot --no-pager diff --no-color --name-status -z "$BaseRef" "$HeadRef" 2>$stderrFile
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
      # The actual git stderr is intentionally not included below -- only
      # forwarded to this process's own stderr, i.e. the workflow run log.
      $stderrText = Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue
      if ($stderrText) { [Console]::Error.WriteLine($stderrText) }
      return [pscustomobject]@{
        Ok = $false
        ErrorCode = "diff-failed"
        ErrorDetail = "git diff exited $exitCode comparing $BaseRef to $HeadRef. See the workflow run log for the underlying git error."
        Changes = @()
      }
    }
  } finally {
    Remove-Item -LiteralPath $stderrFile -ErrorAction SilentlyContinue
  }

  $rawJoined = if ($raw -is [array]) { $raw -join "`0" } else { [string]$raw }
  $changes = ConvertFrom-ScopeDiffNameStatus -RawOutput $rawJoined
  return [pscustomobject]@{ Ok = $true; ErrorCode = $null; ErrorDetail = $null; Changes = $changes }
}
