# Phase 0 helper — capture SCOPE-DIFF goldens (SCOPE-DIFF-001..005).
#
# Replicates the disposable-git-fixture pattern from tests/helpers/scope-diff-tests.ps1,
# runs the real entrypoint (scripts/validate-project.ps1 with -ScopeDiffBase/-ScopeDiffHead),
# and stores the canonical JSON output as one golden per rule id. One rule per file so the
# differential harness can later compare each SCOPE-DIFF rule independently.
param([string]$RepoPath = ".")

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "../../scripts/lib/golden-normalizer.ps1")
. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$validator = Join-Path $repo "scripts/validate-project.ps1"
$goldenDir = Join-Path $repo "tests/golden"
New-Item -ItemType Directory -Force -Path $goldenDir | Out-Null
$pwshExe = Get-PowerShellHost
if (-not $pwshExe) { Write-Host (Get-PowerShellHostMissingMessage); exit 127 }

function New-Fixture {
  $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-scopediff-golden-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  & git -C $dir init -q --initial-branch=main 2>$null
  if ($LASTEXITCODE -ne 0) { & git -C $dir init -q 2>$null }
  & git -C $dir config user.email "test@axiom-pmo.local" | Out-Null
  & git -C $dir config user.name "Axiom ScopeDiff Golden" | Out-Null
  return $dir
}
function Write-F {
  param([string]$Dir, [string]$Rel, [string]$Content = "content")
  $full = Join-Path $Dir $Rel
  $parent = Split-Path -Parent $full
  if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  Set-Content -LiteralPath $full -Value $Content -NoNewline
}
function Commit {
  param([string]$Dir, [string]$Msg)
  & git -C $Dir add -A 2>$null | Out-Null
  & git -C $Dir commit -q -m $Msg 2>$null | Out-Null
  return (& git -C $Dir rev-parse HEAD 2>$null)
}
function Capture {
  param([string]$Dir, [string]$Name, [string]$Base, [string]$Head)
  $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $validator,
    "-ProjectPath", $Dir, "-Mode", "Standard", "-Gate", "Draft", "-Format", "Json",
    "-ScopeDiffBase", $Base, "-ScopeDiffHead", $Head, "-ScopeDiffRepoRoot", $Dir)
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $output = & $pwshExe @psArgs 2>$null
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prev
  $raw = (($output | Out-String).TrimEnd()) + "`nEXIT_CODE=$code"
  $raw = $raw.Replace($Dir, '<REPO_ROOT>')
  Set-Content -LiteralPath (Join-Path $goldenDir "$Name.txt") -Value (Get-CanonicalGoldenText -Text $raw) -NoNewline -Encoding utf8
  Write-Host "Captured $Name.txt"
}

# SCOPE-DIFF-001: file changed outside the approved include scope.
$d = New-Fixture
try {
  Write-F $d "src/payments/foo.ts" "a"
  Write-F $d "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/payments/**"],"exclude":[]}}'
  $base = Commit $d "base"
  Write-F $d "src/payments/foo.ts" "b"
  Write-F $d "src/auth/bar.ts" "new"
  $head = Commit $d "change"
  Capture $d "scope-diff-001" $base $head
} finally { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }

# SCOPE-DIFF-002: scope declaration missing entirely.
$d = New-Fixture
try {
  Write-F $d "src/a.ts" "a"
  $base = Commit $d "base"
  Write-F $d "src/a.ts" "b"
  $head = Commit $d "change"
  Capture $d "scope-diff-002" $base $head
} finally { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }

# SCOPE-DIFF-003: invalid glob syntax (leading slash).
$d = New-Fixture
try {
  Write-F $d "src/a.ts" "a"
  Write-F $d "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["/src/**"],"exclude":[]}}'
  $base = Commit $d "base"
  Write-F $d "src/a.ts" "b"
  $head = Commit $d "change"
  Capture $d "scope-diff-003" $base $head
} finally { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }

# SCOPE-DIFF-004: base SHA not found (fetch-depth guidance).
$d = New-Fixture
try {
  Write-F $d "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/**"],"exclude":[]}}'
  $head = Commit $d "base"
  Capture $d "scope-diff-004" "0000000000000000000000000000000000000000" $head
} finally { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }

# SCOPE-DIFF-005: excluded file changed (distinct from 001).
$d = New-Fixture
try {
  Write-F $d "src/payments/generated/client.ts" "a"
  Write-F $d "SCOPE.json" '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/payments/**"],"exclude":["src/payments/generated/**"]}}'
  $base = Commit $d "base"
  Write-F $d "src/payments/generated/client.ts" "b"
  $head = Commit $d "change"
  Capture $d "scope-diff-005" $base $head
} finally { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }

exit 0
