# Git ground truth for execution-contract verification (M5.3).
#
# This is the whole reason Milestone 5 is buildable at all. The reference
# execution workflow has no native result-emission surface to trust (see
# docs/architecture/execution-contract-verification.md), so what an agent
# claims it did is checked against what the repository can be observed to
# show: which commits exist, what they changed, and whether a claimed ref
# actually contains them.
#
# Every command here is read-only local plumbing (rev-parse, merge-base,
# diff, rev-list, branch --contains) against objects already in the checkout.
# Never a fetch, never a write, never a network call -- a governance check
# that mutates the repository it is judging would be its own worst finding.
#
# Privacy contract, identical to scope-diff-git-adapter.ps1's: raw git
# stdout/stderr never reaches a caller that might put it in a report,
# annotation, or uploaded artifact. Failures become a small set of known,
# actionable messages; the underlying git text goes to this process's own
# stderr (the workflow run log), which is not a persisted artifact.

function Test-ExecutionRefResolvable {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$Ref
  )

  $result = & git -C $RepoRoot rev-parse --verify --quiet "$Ref^{commit}" 2>$null
  return (($LASTEXITCODE -eq 0) -and (-not [string]::IsNullOrWhiteSpace($result)))
}

function Resolve-ExecutionCommitSha {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$Ref
  )

  $result = & git -C $RepoRoot rev-parse --verify --quiet "$Ref^{commit}" 2>$null
  if ($LASTEXITCODE -ne 0) { return $null }
  if ($result -is [array]) { $result = $result[0] }
  $text = [string]$result
  if ([string]::IsNullOrWhiteSpace($text)) { return $null }
  return $text.Trim()
}

# Is $Ancestor actually an ancestor of $Descendant?
#
# This is what catches a result claiming to have built on the approved base
# when it in fact branched from somewhere else entirely -- the contract named
# a base commit, and work that does not descend from it is not the work that
# was approved, whatever the result says.
function Test-ExecutionAncestry {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$Ancestor,
    [Parameter(Mandatory = $true)][string]$Descendant
  )

  & git -C $RepoRoot merge-base --is-ancestor $Ancestor $Descendant 2>$null | Out-Null
  return ($LASTEXITCODE -eq 0)
}

# Commit SHAs reachable from head but not from base -- the commits this
# execution actually produced, as opposed to the ones it says it produced.
function Get-ExecutionCommitRange {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$BaseRef,
    [Parameter(Mandatory = $true)][string]$HeadRef
  )

  $stderrFile = [System.IO.Path]::GetTempFileName()
  try {
    $raw = & git -C $RepoRoot --no-pager rev-list "$BaseRef..$HeadRef" 2>$stderrFile
    if ($LASTEXITCODE -ne 0) {
      $stderrText = Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue
      if ($stderrText) { [Console]::Error.WriteLine($stderrText) }
      return $null
    }
  } finally {
    Remove-Item -LiteralPath $stderrFile -ErrorAction SilentlyContinue
  }

  $commits = New-Object System.Collections.Generic.List[string]
  foreach ($line in @($raw)) {
    $text = [string]$line
    if (-not [string]::IsNullOrWhiteSpace($text)) { $commits.Add($text.Trim()) | Out-Null }
  }
  return $commits
}

# Changed paths between two commits, as git reports them.
#
# Deliberately delegates to the M4.5 adapter rather than re-implementing the
# parse: the -z NUL-separated form, the rename/copy two-path handling, and the
# pinned rename-detection configuration are all subtle, all already tested by
# tests/helpers/scope-diff-tests.ps1, and all exactly as correct here as they
# were there. A second parser would be a second thing to get wrong.
function Get-ExecutionChangedFiles {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$BaseRef,
    [Parameter(Mandatory = $true)][string]$HeadRef
  )

  return (Get-ScopeDiffChangedFiles -RepoRoot $RepoRoot -BaseRef $BaseRef -HeadRef $HeadRef)
}

# Does any remote-tracking ref in this checkout contain the given commit?
#
# Returns $true / $false / $null, and the $null matters: it means "cannot be
# determined from here" (no remote-tracking refs are present at all), which is
# different from "no remote contains it." Collapsing the two would let a
# shallow or remote-less checkout silently report a push as not-having-happened
# -- exactly the false negative docs/architecture/execution-contract-verification.md
# says this MVP must never produce.
function Test-ExecutionCommitOnRemote {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$CommitSha
  )

  # "Continue" around both calls: this file's callers set
  # $ErrorActionPreference = "Stop", and Windows PowerShell 5.1 turns a native
  # command's stderr into a terminating error under "Stop" regardless of
  # `2>$null`. `branch --remotes --contains` writes to stderr on a malformed
  # object name, so an unguarded call could kill the whole verification run
  # instead of returning a tri-state answer. Same failure mode that broke the
  # ci-check adapter on the 5.1 CI leg.
  $previousEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $remoteRefs = & git -C $RepoRoot for-each-ref --format='%(refname)' refs/remotes 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    $refList = @($remoteRefs | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($refList.Count -eq 0) { return $null }

    $containing = & git -C $RepoRoot branch --remotes --contains $CommitSha 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
  } finally {
    $ErrorActionPreference = $previousEap
  }
  foreach ($line in @($containing)) {
    if (-not [string]::IsNullOrWhiteSpace([string]$line)) { return $true }
  }
  return $false
}

# The full observed picture, assembled once so the validator reads a single
# structure instead of interleaving git calls with diagnostics.
#
# Ok = $false means the comparison itself could not run (an unresolvable ref),
# which is an infrastructure failure and must be reported as one -- never as
# "the agent did nothing wrong."
function Get-ExecutionGitObservation {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$BaseRef,
    [Parameter(Mandatory = $true)][string]$HeadRef
  )

  if (-not (Test-ExecutionRefResolvable -RepoRoot $RepoRoot -Ref $BaseRef)) {
    return [pscustomobject]@{
      Ok = $false
      ErrorCode = "base-unresolvable"
      ErrorDetail = "The contract's base commit ($BaseRef) could not be resolved in this checkout. On a shallow clone the base commit is commonly absent; increase fetch-depth (or use fetch-depth: 0). A base that cannot be resolved cannot be verified against, so this run reports an infrastructure failure rather than a verdict."
    }
  }
  if (-not (Test-ExecutionRefResolvable -RepoRoot $RepoRoot -Ref $HeadRef)) {
    return [pscustomobject]@{
      Ok = $false
      ErrorCode = "head-unresolvable"
      ErrorDetail = "The result's head commit ($HeadRef) could not be resolved in this checkout. The result claims work at a commit this repository does not contain."
    }
  }

  $baseSha = Resolve-ExecutionCommitSha -RepoRoot $RepoRoot -Ref $BaseRef
  $headSha = Resolve-ExecutionCommitSha -RepoRoot $RepoRoot -Ref $HeadRef
  $isDescendant = Test-ExecutionAncestry -RepoRoot $RepoRoot -Ancestor $baseSha -Descendant $headSha
  $commits = Get-ExecutionCommitRange -RepoRoot $RepoRoot -BaseRef $baseSha -HeadRef $headSha
  $diff = Get-ExecutionChangedFiles -RepoRoot $RepoRoot -BaseRef $baseSha -HeadRef $headSha

  if (-not $diff.Ok) {
    return [pscustomobject]@{
      Ok = $false
      ErrorCode = "diff-failed"
      ErrorDetail = "Could not compute the changed-file diff between the contract base and the result head. See the workflow run log for the underlying git error."
    }
  }

  $onRemote = $null
  if ($headSha) { $onRemote = Test-ExecutionCommitOnRemote -RepoRoot $RepoRoot -CommitSha $headSha }

  return [pscustomobject]@{
    Ok = $true
    ErrorCode = $null
    ErrorDetail = $null
    BaseSha = $baseSha
    HeadSha = $headSha
    HeadDescendsFromBase = $isDescendant
    Commits = $commits
    CommitCount = @($commits).Count
    Changes = $diff.Changes
    HeadOnRemote = $onRemote
  }
}
