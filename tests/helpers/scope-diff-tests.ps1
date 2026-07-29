param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

# Behaviour tests for M4.5 SCOPE-DIFF (scripts/lib/scope-diff-*.ps1), exercised
# through scripts/validate-project.ps1 exactly the way a real caller would --
# subprocess, JSON output -- not by dot-sourcing internals. SCOPE-DIFF's
# entire job is comparing real git history against a real scope declaration,
# so these tests build a small, disposable git repository per case rather
# than reusing this repository's own history (which changes) or copying a
# large fixture project (unnecessary: the whole surface under test is a
# handful of files and a few commits).

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")
. (Join-Path $PSScriptRoot "../../scripts/lib/scope-diff-matcher.ps1")

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$validator = Join-Path $repo "scripts/validate-project.ps1"
$pass = 0
$fail = 0

function Assert-True {
  param([string]$Name, [bool]$Condition, [string]$Detail = "")
  if ($Condition) {
    $script:pass++
    Write-Host "[PASS] $Name"
  } else {
    $script:fail++
    Write-Host "[FAIL] $Name$(if ($Detail) { " -- $Detail" })"
  }
}

# --- disposable git fixture -------------------------------------------------

function New-ScopeDiffGitFixture {
  $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-scope-diff-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  & git -C $dir init -q --initial-branch=main 2>$null
  if ($LASTEXITCODE -ne 0) { & git -C $dir init -q 2>$null }  # older git: no --initial-branch
  & git -C $dir config user.email "test@axiom-pmo.local" | Out-Null
  & git -C $dir config user.name "Axiom Scope Diff Tests" | Out-Null
  return $dir
}

function Write-FixtureFile {
  param([string]$Dir, [string]$RelativePath, [string]$Content = "content")
  $full = Join-Path $Dir $RelativePath
  $parent = Split-Path -Parent $full
  if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  Set-Content -LiteralPath $full -Value $Content -NoNewline
}

function New-FixtureCommit {
  param([string]$Dir, [string]$Message)
  & git -C $Dir add -A 2>$null | Out-Null
  & git -C $Dir commit -q -m $Message 2>$null | Out-Null
  return (& git -C $Dir rev-parse HEAD 2>$null)
}

function Remove-ScopeDiffGitFixture {
  param([string]$Dir)
  Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue
}

function Invoke-ScopeDiffValidate {
  param(
    [string]$RepoRoot,
    [string]$ProjectPath,
    [string]$Base,
    [string]$Head,
    [string]$Gate = "Draft"
  )
  $psArgs = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $validator,
    "-ProjectPath", $ProjectPath, "-Mode", "Standard", "-Gate", $Gate, "-Format", "Json",
    "-ScopeDiffBase", $Base, "-ScopeDiffHead", $Head, "-ScopeDiffRepoRoot", $RepoRoot
  )
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & $pwshExe @psArgs 2>$null
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $previous
  $json = $null
  try { $json = (($output | Out-String) | ConvertFrom-Json) } catch { }
  return [pscustomobject]@{ Json = $json; ExitCode = $exitCode }
}

Write-Host "Axiom-PMO SCOPE-DIFF Tests: $repo"
Write-Host ""

# ---- Case: all changed files in approved include -> PASS ------------------
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "src/payments/foo.ts" "a"
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/payments/**"],"exclude":[]}}'
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "src/payments/foo.ts" "b"
    $head = New-FixtureCommit $dir "change"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base $base -Head $head
    $sd = $r.Json.scope_diff
    Assert-True "in-scope-only: verdict is pass" ($sd.verdict -eq "pass") "got $($sd.verdict)"
    Assert-True "in-scope-only: SCOPE-DIFF-001 row is PASS level" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "SCOPE-DIFF-001" })[0]).level -eq "PASS")
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: one file outside scope -> FAIL ----------------------------------
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "src/payments/foo.ts" "a"
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/payments/**"],"exclude":[]}}'
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "src/payments/foo.ts" "b"
    Write-FixtureFile $dir "src/auth/bar.ts" "new"
    $head = New-FixtureCommit $dir "change"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base $base -Head $head
    Assert-True "one-outside: verdict is fail" ($r.Json.scope_diff.verdict -eq "fail")
    Assert-True "one-outside: out_of_scope lists the offending file" `
      ($r.Json.scope_diff.changed_out_of_scope -contains "src/auth/bar.ts")
    Assert-True "one-outside: SCOPE-DIFF-001 FAIL row names the file as artifact" `
      (@($r.Json.results | Where-Object { $_.rule_id -eq "SCOPE-DIFF-001" -and $_.level -eq "FAIL" -and $_.artifact -eq "src/auth/bar.ts" }).Count -eq 1)
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: path matching is case-sensitive (MAJOR fix -- was a scope bypass) --
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "src/payments/foo.ts" "a"
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/payments/**"],"exclude":[]}}'
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "src/payments/foo.ts" "b"
    & git -C $dir add -A 2>$null | Out-Null
    # Added via git plumbing (hash-object + update-index --cacheinfo), not a
    # working-tree write: on a case-insensitive-but-case-preserving
    # filesystem (macOS APFS's default, and Windows/NTFS), writing to
    # "SRC/PAYMENTS/bar.ts" when "src/payments/" already exists on disk
    # silently resolves into the existing directory, and git then reports
    # the on-disk case -- which would hide the very case-sensitivity bug
    # this test exists to catch. Injecting the blob directly into the index
    # bypasses the filesystem's own case-folding entirely, so this test is
    # meaningful on every host this suite runs on, not only a
    # case-sensitive one (see also docs/reference/scope-declaration.md).
    $blobHash = (($(printf 'new' | & git -C $dir hash-object -w --stdin)) | Select-Object -Last 1).Trim()
    & git -C $dir update-index --add --cacheinfo "100644,$blobHash,SRC/PAYMENTS/bar.ts" 2>$null | Out-Null
    & git -C $dir commit -q -m "change" 2>$null | Out-Null
    $head = (& git -C $dir rev-parse HEAD 2>$null)

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base $base -Head $head
    Assert-True "case-sensitive: verdict is fail" ($r.Json.scope_diff.verdict -eq "fail")
    Assert-True "case-sensitive: wrong-case path reported out of scope" `
      ($r.Json.scope_diff.changed_out_of_scope -contains "SRC/PAYMENTS/bar.ts")
    Assert-True "case-sensitive: wrong-case path not counted as in scope" `
      (-not ($r.Json.scope_diff.changed_in_scope -contains "SRC/PAYMENTS/bar.ts"))
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: excluded file changed -> FAIL (SCOPE-DIFF-005, distinct from 001) --
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "src/payments/generated/client.ts" "a"
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/payments/**"],"exclude":["src/payments/generated/**"]}}'
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "src/payments/generated/client.ts" "b"
    $head = New-FixtureCommit $dir "change"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base $base -Head $head
    Assert-True "excluded: verdict is fail" ($r.Json.scope_diff.verdict -eq "fail")
    Assert-True "excluded: reported under changed_excluded, not out_of_scope" `
      (($r.Json.scope_diff.changed_excluded -contains "src/payments/generated/client.ts") -and `
       (-not ($r.Json.scope_diff.changed_out_of_scope -contains "src/payments/generated/client.ts")))
    Assert-True "excluded: rule id is SCOPE-DIFF-005, not SCOPE-DIFF-001" `
      (@($r.Json.results | Where-Object { $_.rule_id -eq "SCOPE-DIFF-005" -and $_.level -eq "FAIL" }).Count -eq 1)
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: include + exclude precedence (exclude wins) ---------------------
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "src/a.ts" "a"
    # Same path matches both include and exclude -- exclude must win.
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/**"],"exclude":["src/a.ts"]}}'
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "src/a.ts" "b"
    $head = New-FixtureCommit $dir "change"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base $base -Head $head
    Assert-True "precedence: exclude wins over include" `
      (@($r.Json.results | Where-Object { $_.rule_id -eq "SCOPE-DIFF-005" }).Count -eq 1)
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: missing scope declaration ---------------------------------------
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "src/a.ts" "a"
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "src/a.ts" "b"
    $head = New-FixtureCommit $dir "change"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base $base -Head $head
    Assert-True "missing scope: SCOPE-DIFF-002 FAIL" `
      (@($r.Json.results | Where-Object { $_.rule_id -eq "SCOPE-DIFF-002" -and $_.level -eq "FAIL" }).Count -eq 1)
    Assert-True "missing scope: overall exit code is 1 (not silently passing)" ($r.Json.summary.exit_code -eq 1)
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: invalid glob/syntax ----------------------------------------------
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "src/a.ts" "a"
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["/src/**"],"exclude":[]}}'
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "src/a.ts" "b"
    $head = New-FixtureCommit $dir "change"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base $base -Head $head
    Assert-True "invalid syntax: SCOPE-DIFF-003 FAIL" `
      (@($r.Json.results | Where-Object { $_.rule_id -eq "SCOPE-DIFF-003" -and $_.level -eq "FAIL" }).Count -eq 1)
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: empty include list is also invalid syntax -----------------------
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "src/a.ts" "a"
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":[],"exclude":[]}}'
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "src/a.ts" "b"
    $head = New-FixtureCommit $dir "change"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base $base -Head $head
    Assert-True "empty include: SCOPE-DIFF-003 FAIL" `
      (@($r.Json.results | Where-Object { $_.rule_id -eq "SCOPE-DIFF-003" -and $_.level -eq "FAIL" }).Count -eq 1)
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: added / modified / deleted files ---------------------------------
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "src/keep.ts" "a"
    Write-FixtureFile $dir "src/remove.ts" "a"
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/**"],"exclude":[]}}'
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "src/keep.ts" "b"          # modified
    Write-FixtureFile $dir "src/added.ts" "new"        # added
    Remove-Item -LiteralPath (Join-Path $dir "src/remove.ts")  # deleted
    $head = New-FixtureCommit $dir "change"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base $base -Head $head
    Assert-True "add/modify/delete: verdict is pass (all three still in scope)" ($r.Json.scope_diff.verdict -eq "pass")
    Assert-True "add/modify/delete: added file counted" ($r.Json.scope_diff.changed_in_scope -contains "src/added.ts")
    Assert-True "add/modify/delete: modified file counted" ($r.Json.scope_diff.changed_in_scope -contains "src/keep.ts")
    Assert-True "add/modify/delete: deleted file counted" ($r.Json.scope_diff.changed_in_scope -contains "src/remove.ts")
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: renamed file -- both old and new path considered ----------------
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "src/payments/old name.ts" "some reasonably long content so git's similarity heuristic detects a rename instead of a delete+add"
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/payments/**"],"exclude":[]}}'
    $base = New-FixtureCommit $dir "base"
    & git -C $dir mv "src/payments/old name.ts" "src/payments/new name.ts" 2>$null | Out-Null
    $head = New-FixtureCommit $dir "rename"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base $base -Head $head
    Assert-True "rename in-scope-to-in-scope: verdict pass" ($r.Json.scope_diff.verdict -eq "pass")
    $renameRow = @($r.Json.scope_diff.renames | Where-Object { $_.new_path -eq "src/payments/new name.ts" })
    Assert-True "rename in-scope-to-in-scope: renames array has one structured entry" ($renameRow.Count -eq 1)
    Assert-True "rename in-scope-to-in-scope: structured entry has both verdicts" `
      ($renameRow[0].old_path -eq "src/payments/old name.ts" -and `
       $renameRow[0].old_verdict -eq "in_scope" -and $renameRow[0].new_verdict -eq "in_scope")
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "src/payments/old name.ts" "some reasonably long content so git's similarity heuristic detects a rename instead of a delete+add"
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/payments/**"],"exclude":[]}}'
    $base = New-FixtureCommit $dir "base"
    # `git mv` does not create the destination directory -- without this, the
    # move fails silently (stderr suppressed below) and base==head, which is
    # exactly the bug this comment is here to stop from recurring: the first
    # version of this test passed a "fail" assertion for the wrong reason
    # (no diff at all, not a real rename) until this was added.
    New-Item -ItemType Directory -Path (Join-Path $dir "src/auth") -Force | Out-Null
    & git -C $dir mv "src/payments/old name.ts" "src/auth/new name.ts" 2>$null | Out-Null
    $head = New-FixtureCommit $dir "rename-out"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base $base -Head $head
    Assert-True "rename in-scope-to-out-of-scope: verdict fail (worse side wins)" ($r.Json.scope_diff.verdict -eq "fail")
    Assert-True "rename: violation message mentions the rename" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "SCOPE-DIFF-001" -and $_.level -eq "FAIL" })[0]).message -match "renamed from")
    $renameRow = @($r.Json.scope_diff.renames | Where-Object { $_.new_path -eq "src/auth/new name.ts" })
    Assert-True "rename in-scope-to-out-of-scope: structured entry present" ($renameRow.Count -eq 1)
    Assert-True "rename in-scope-to-out-of-scope: old side recorded in_scope, new side out_of_scope" `
      ($renameRow[0].old_path -eq "src/payments/old name.ts" -and `
       $renameRow[0].old_verdict -eq "in_scope" -and $renameRow[0].new_verdict -eq "out_of_scope")
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: path with space and special characters ---------------------------
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/**"],"exclude":[]}}'
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "src/with space (and parens) [brackets].ts" "content"
    $head = New-FixtureCommit $dir "change"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base $base -Head $head
    Assert-True "special characters: path parsed and matched correctly" `
      ($r.Json.scope_diff.changed_in_scope -contains "src/with space (and parens) [brackets].ts") `
      ("got: " + ($r.Json.scope_diff.changed_in_scope -join ", "))
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: base SHA not found ------------------------------------------------
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/**"],"exclude":[]}}'
    $head = New-FixtureCommit $dir "base"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base "0000000000000000000000000000000000000000" -Head $head
    Assert-True "bad base SHA: SCOPE-DIFF-004 FAIL" `
      (@($r.Json.results | Where-Object { $_.rule_id -eq "SCOPE-DIFF-004" -and $_.level -eq "FAIL" }).Count -eq 1)
    Assert-True "bad base SHA: message mentions fetch-depth guidance" `
      ((@($r.Json.results | Where-Object { $_.rule_id -eq "SCOPE-DIFF-004" })[0]).message -match "fetch-depth")
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: head ref invalid --------------------------------------------------
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/**"],"exclude":[]}}'
    $base = New-FixtureCommit $dir "base"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base $base -Head "not-a-real-ref-at-all"
    Assert-True "bad head ref: SCOPE-DIFF-004 FAIL" `
      (@($r.Json.results | Where-Object { $_.rule_id -eq "SCOPE-DIFF-004" -and $_.level -eq "FAIL" }).Count -eq 1)
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: empty diff (base == head) -----------------------------------------
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/**"],"exclude":[]}}'
    $head = New-FixtureCommit $dir "base"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base $head -Head $head
    Assert-True "empty diff: verdict pass" ($r.Json.scope_diff.verdict -eq "pass")
    Assert-True "empty diff: zero changed files in every bucket" `
      ($r.Json.scope_diff.changed_in_scope.Count -eq 0 -and $r.Json.scope_diff.changed_out_of_scope.Count -eq 0)
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: git error output is not persisted into the JSON result ----------
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/**"],"exclude":[]}}'
    $head = New-FixtureCommit $dir "base"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base "totally-bogus-ref-xyz" -Head $head
    $row = @($r.Json.results | Where-Object { $_.rule_id -eq "SCOPE-DIFF-004" })[0]
    Assert-True "git error privacy: message does not contain raw git stderr markers" `
      ($row.message -notmatch "fatal:|unknown revision")
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: repo-wide exempt path passes without being in include -----------
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "src/a.ts" "a"
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/**"],"exclude":[]}}'
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "package-lock.json" "{}"  # matches pmo-config/scope-diff-policy.json's repo_wide_exempt
    $head = New-FixtureCommit $dir "change"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base $base -Head $head
    Assert-True "repo-wide exempt: verdict pass" ($r.Json.scope_diff.verdict -eq "pass")
    Assert-True "repo-wide exempt: file listed with a reason" `
      (@($r.Json.scope_diff.exempt | Where-Object { $_.path -eq "package-lock.json" -and $_.reason }).Count -eq 1)
    Assert-True "repo-wide exempt: not double-counted into changed_in_scope" `
      (-not ($r.Json.scope_diff.changed_in_scope -contains "package-lock.json"))
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: repo-wide exemption policy rejects an overly broad pattern ------
{
  $policyDir = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-scope-diff-policy-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path (Join-Path $policyDir "pmo-config") -Force | Out-Null
  try {
    Set-Content -LiteralPath (Join-Path $policyDir "pmo-config/scope-diff-policy.json") -Value (
      '{"repo_wide_exempt":[{"pattern":"**","reason":"shared files"}]}'
    ) -NoNewline
    $threw = $false
    try { Read-ScopeDiffPolicy -RepoRoot $policyDir | Out-Null } catch { $threw = $true }
    Assert-True "repo-wide policy: '**' pattern is rejected, not silently accepted" $threw
  } finally { Remove-Item -LiteralPath $policyDir -Recurse -Force -ErrorAction SilentlyContinue }
}.Invoke()

# ---- Case: repo-wide exemption policy rejects an entry with no reason ------
{
  $policyDir = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-scope-diff-policy-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path (Join-Path $policyDir "pmo-config") -Force | Out-Null
  try {
    Set-Content -LiteralPath (Join-Path $policyDir "pmo-config/scope-diff-policy.json") -Value (
      '{"repo_wide_exempt":[{"pattern":"foo.lock","reason":""}]}'
    ) -NoNewline
    $threw = $false
    try { Read-ScopeDiffPolicy -RepoRoot $policyDir | Out-Null } catch { $threw = $true }
    Assert-True "repo-wide policy: empty reason is rejected" $threw
  } finally { Remove-Item -LiteralPath $policyDir -Recurse -Force -ErrorAction SilentlyContinue }
}.Invoke()

# ---- Case: repo-wide exemption policy rejects a duplicate pattern ----------
{
  $policyDir = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-scope-diff-policy-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path (Join-Path $policyDir "pmo-config") -Force | Out-Null
  try {
    Set-Content -LiteralPath (Join-Path $policyDir "pmo-config/scope-diff-policy.json") -Value (
      '{"repo_wide_exempt":[{"pattern":"foo.lock","reason":"a"},{"pattern":"foo.lock","reason":"b"}]}'
    ) -NoNewline
    $threw = $false
    try { Read-ScopeDiffPolicy -RepoRoot $policyDir | Out-Null } catch { $threw = $true }
    Assert-True "repo-wide policy: duplicate pattern is rejected" $threw
  } finally { Remove-Item -LiteralPath $policyDir -Recurse -Force -ErrorAction SilentlyContinue }
}.Invoke()

# ---- Case: the framework's own scope-diff-policy.json is itself valid ------
{
  $threw = $false
  $entries = $null
  try { $entries = Read-ScopeDiffPolicy -RepoRoot $repo } catch { $threw = $true }
  Assert-True "repo-wide policy: framework's own policy.json passes validation" `
    ((-not $threw) -and $entries.Count -gt 0)
}.Invoke()

# ---- Case: an unrelated, non-exempt file still fails ------------------------
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "src/a.ts" "a"
    Write-FixtureFile $dir "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/**"],"exclude":[]}}'
    $base = New-FixtureCommit $dir "base"
    Write-FixtureFile $dir "some-other-lockfile.lock" "{}"  # NOT in the repo-wide exempt list
    $head = New-FixtureCommit $dir "change"

    $r = Invoke-ScopeDiffValidate -RepoRoot $dir -ProjectPath $dir -Base $base -Head $head
    Assert-True "non-exempt unrelated file: verdict fail" ($r.Json.scope_diff.verdict -eq "fail")
    Assert-True "non-exempt unrelated file: not silently allowed" `
      ($r.Json.scope_diff.changed_out_of_scope -contains "some-other-lockfile.lock")
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

# ---- Case: SCOPE-DIFF is opt-in -- omitting -ScopeDiffBase/-Head changes nothing --
{
  $dir = New-ScopeDiffGitFixture
  try {
    Write-FixtureFile $dir "PROJECT.md" "# T"
    New-FixtureCommit $dir "base" | Out-Null
    $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $validator,
      "-ProjectPath", $dir, "-Mode", "Lite", "-Gate", "Draft", "-Format", "Json")
    $previous = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $output = & $pwshExe @psArgs 2>$null
    $ErrorActionPreference = $previous
    $json = ($output | Out-String) | ConvertFrom-Json
    Assert-True "opt-in: scope_diff key is absent when not requested" `
      (-not ($json.PSObject.Properties.Name -contains "scope_diff"))
    Assert-True "opt-in: no SCOPE-DIFF rows appear when not requested" `
      (@($json.results | Where-Object { $_.rule_id -like "SCOPE-DIFF-*" }).Count -eq 0)
  } finally { Remove-ScopeDiffGitFixture $dir }
}.Invoke()

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"
if ($fail -gt 0) { exit 1 }
exit 0
