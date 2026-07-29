# SCOPE-DIFF orchestration: combines scope-diff-matcher.ps1 (what is
# approved) and scope-diff-git-adapter.ps1 (what actually changed) into the
# structured diagnostics this framework's other checks already produce, via
# the same Add-Result accumulator every other validator module uses. This
# file adds no new validation engine -- it is one more caller of the
# existing one.
#
# Only runs when the caller supplies both -ScopeDiffBase and -ScopeDiffHead
# to validate-project.ps1. Every existing invocation of validate-project.ps1
# (M4's own tests, every example/demo project, every fixture) supplies
# neither, so this function is simply never called for them -- M4 behavior
# is unchanged.

# Severity ranking used to combine a rename's two verdicts (old path, new
# path) into one. Higher is worse. A rename is only as clean as its worse
# side: renaming an in-scope file to an out-of-scope location, or vice
# versa, is exactly the kind of scope drift this check exists to catch.
$script:ScopeDiffVerdictSeverity = @{
  "excluded" = 3
  "out_of_scope" = 2
  "exempt" = 1
  "in_scope" = 0
}

function Resolve-ScopeDiffCombinedVerdict {
  param($VerdictA, $VerdictB)
  if (-not $VerdictB) { return $VerdictA }
  $sevA = $script:ScopeDiffVerdictSeverity[$VerdictA.Verdict]
  $sevB = $script:ScopeDiffVerdictSeverity[$VerdictB.Verdict]
  if ($sevB -gt $sevA) { return $VerdictB }
  return $VerdictA
}

function Invoke-ScopeDiffCheck {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    # Where the git history to diff lives -- the consumer's own checkout when
    # running as the GitHub Action, which is NOT the same directory as
    # $FrameworkRoot below. See validate-project.ps1's -ScopeDiffRepoRoot
    # comment.
    [Parameter(Mandatory = $true)][string]$GitRepoRoot,
    # Where the Axiom-PMO framework's own pmo-config/*.json lives. Always the
    # framework's checkout, exactly like every other Import-PmoConfig caller
    # in this codebase -- never the project/consumer repo. Reusing $RepoRoot
    # for both this and $GitRepoRoot was a real bug caught by
    # tests/helpers/scope-diff-tests.ps1's disposable-fixture-repo cases: on
    # this developer's own machine, testing only against the Axiom-PMO
    # checkout itself, framework root and git root happen to be the same
    # directory, which hid the bug completely until a fixture used a
    # different one for each.
    [Parameter(Mandatory = $true)][string]$FrameworkRoot,
    [Parameter(Mandatory = $true)][string]$BaseRef,
    [Parameter(Mandatory = $true)][string]$HeadRef
  )

  $scope = Read-ScopeDeclaration -ProjectPath $ProjectPath
  if (-not $scope.Present) {
    Add-Result FAIL "No approved implementation scope declared for this project. SCOPE-DIFF was requested (base/head were supplied) but no SCOPE.json exists, so this run cannot prove any changed file is approved. A missing scope declaration is never treated as 'everything is approved.'" "SCOPE-DIFF-002" -Artifact "SCOPE.json"
    return [pscustomobject]@{
      base_sha = $BaseRef; head_sha = $HeadRef
      approved_include = @(); approved_exclude = @()
      changed_in_scope = @(); changed_out_of_scope = @(); changed_excluded = @(); exempt = @()
      verdict = "scope_missing"
    }
  }
  if (-not $scope.Valid) {
    Add-Result FAIL "Scope declaration is invalid: $($scope.Error)" "SCOPE-DIFF-003" -Artifact "SCOPE.json"
    return [pscustomobject]@{
      base_sha = $BaseRef; head_sha = $HeadRef
      approved_include = @(); approved_exclude = @()
      changed_in_scope = @(); changed_out_of_scope = @(); changed_excluded = @(); exempt = @()
      verdict = "invalid_scope"
    }
  }

  $diffResult = Get-ScopeDiffChangedFiles -RepoRoot $GitRepoRoot -BaseRef $BaseRef -HeadRef $HeadRef
  if (-not $diffResult.Ok) {
    Add-Result FAIL "Could not compute the changed-file diff between $BaseRef and $HeadRef`: $($diffResult.ErrorDetail)" "SCOPE-DIFF-004"
    return [pscustomobject]@{
      base_sha = $BaseRef; head_sha = $HeadRef
      approved_include = $scope.Include; approved_exclude = $scope.Exclude
      changed_in_scope = @(); changed_out_of_scope = @(); changed_excluded = @(); exempt = @()
      verdict = "git_error"
    }
  }

  $includeRegexes = @($scope.Include | ForEach-Object { ConvertTo-ScopeGlobRegex -Pattern $_ })
  $excludeRegexes = @($scope.Exclude | ForEach-Object { ConvertTo-ScopeGlobRegex -Pattern $_ })
  $exemptEntries = @(Read-ScopeDiffPolicy -RepoRoot $FrameworkRoot | ForEach-Object {
    [pscustomobject]@{ Pattern = $_.Pattern; Reason = $_.Reason; Regex = (ConvertTo-ScopeGlobRegex -Pattern $_.Pattern) }
  })

  $inScope = New-Object System.Collections.Generic.List[string]
  $outOfScope = New-Object System.Collections.Generic.List[string]
  $excluded = New-Object System.Collections.Generic.List[string]
  $exempt = New-Object System.Collections.Generic.List[object]

  foreach ($change in $diffResult.Changes) {
    $newVerdict = Resolve-ScopeVerdict -Path $change.Path -IncludeRegexes $includeRegexes -ExcludeRegexes $excludeRegexes -ExemptEntries $exemptEntries
    $combined = $newVerdict
    if ($change.OldPath) {
      $oldVerdict = Resolve-ScopeVerdict -Path $change.OldPath -IncludeRegexes $includeRegexes -ExcludeRegexes $excludeRegexes -ExemptEntries $exemptEntries
      $combined = Resolve-ScopeDiffCombinedVerdict -VerdictA $newVerdict -VerdictB $oldVerdict
    }

    switch ($combined.Verdict) {
      "excluded" {
        $excluded.Add($change.Path) | Out-Null
        $renameNote = if ($change.OldPath) { " (renamed from $($change.OldPath))" } else { "" }
        Add-Result FAIL "Changed file matches an excluded path in the approved implementation scope: $($change.Path)$renameNote" "SCOPE-DIFF-005" -Artifact $change.Path
      }
      "out_of_scope" {
        $outOfScope.Add($change.Path) | Out-Null
        $renameNote = if ($change.OldPath) { " (renamed from $($change.OldPath))" } else { "" }
        Add-Result FAIL "Changed file is outside the approved implementation scope: $($change.Path)$renameNote" "SCOPE-DIFF-001" -Artifact $change.Path
      }
      "exempt" {
        $exempt.Add([pscustomobject]@{ path = $change.Path; reason = $combined.Reason }) | Out-Null
        $inScope.Add($change.Path) | Out-Null
      }
      "in_scope" {
        $inScope.Add($change.Path) | Out-Null
      }
    }
  }

  $verdict = if ($outOfScope.Count -gt 0 -or $excluded.Count -gt 0) { "fail" } else { "pass" }
  if ($verdict -eq "pass") {
    if ($diffResult.Changes.Count -eq 0) {
      Add-Result PASS "No changed files between $BaseRef and $HeadRef" "SCOPE-DIFF-001"
    } else {
      $exemptNote = if ($exempt.Count -gt 0) { " ($($exempt.Count) repo-wide exempt)" } else { "" }
      Add-Result PASS "All $($diffResult.Changes.Count) changed file(s) are within the approved implementation scope$exemptNote" "SCOPE-DIFF-001"
    }
  }

  # .ToArray(), not @(...): wrapping a System.Collections.Generic.List[object]
  # containing [pscustomobject] entries in @() and assigning the result as a
  # [pscustomobject]@{} literal's value throws "Argument types do not match"
  # on this PowerShell build -- confirmed by isolated repro, not a guess. A
  # real .NET array from .ToArray() does not hit whatever internal path that
  # triggers. Applied to all four collections here for consistency, even
  # though only the pscustomobject-typed $exempt was proven to trigger it.
  return [pscustomobject]@{
    base_sha = $BaseRef
    head_sha = $HeadRef
    approved_include = $scope.Include
    approved_exclude = $scope.Exclude
    changed_in_scope = $inScope.ToArray()
    changed_out_of_scope = $outOfScope.ToArray()
    changed_excluded = $excluded.ToArray()
    exempt = $exempt.ToArray()
    verdict = $verdict
  }
}
