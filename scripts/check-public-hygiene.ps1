#requires -Version 5.1
<#
.SYNOPSIS
  Scans tracked files for public-hygiene issues.

.DESCRIPTION
  Checks for old private project names, local machine paths, stale branch
  topology, concrete historical commit ids, and common secret token patterns.
  Intentional historical references must be listed in
  pmo-config/public-hygiene-allowlist.json.
#>
param(
  [string]$RepoPath = ""
)

$ErrorActionPreference = "Stop"
if (-not $RepoPath) { $RepoPath = Join-Path $PSScriptRoot ".." }
$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$allowlistPath = Join-Path $repo "pmo-config/public-hygiene-allowlist.json"

function ConvertTo-RepoPath([string]$Path) {
  return ($Path -replace '\\', '/')
}

function Test-AllowedMatch([string]$RelativePath, [string]$Pattern) {
  foreach ($entry in $script:allowlist.allowed_matches) {
    if ($entry.pattern -ne $Pattern) { continue }
    foreach ($allowedPath in $entry.paths) {
      if ((ConvertTo-RepoPath $RelativePath) -eq (ConvertTo-RepoPath $allowedPath)) {
        return $true
      }
    }
  }
  return $false
}

function Test-TextFile([string]$FullPath) {
  $bytes = [System.IO.File]::ReadAllBytes($FullPath)
  if ($bytes.Length -eq 0) { return $true }
  $limit = [Math]::Min($bytes.Length, 4096)
  for ($i = 0; $i -lt $limit; $i++) {
    if ($bytes[$i] -eq 0) { return $false }
  }
  return $true
}

if (-not (Test-Path -LiteralPath $allowlistPath -PathType Leaf)) {
  Write-Host "FAIL: missing public hygiene allowlist: pmo-config/public-hygiene-allowlist.json"
  exit 1
}

$script:allowlist = Get-Content -LiteralPath $allowlistPath -Raw | ConvertFrom-Json
$trackedFiles = @()
$trackedFiles += & git -C $repo ls-files --cached
$trackedFiles += & git -C $repo ls-files --others --exclude-from=.gitignore
if ($LASTEXITCODE -ne 0) {
  Write-Host "FAIL: unable to list tracked files"
  exit 1
}
$trackedFiles = $trackedFiles | Sort-Object -Unique
$selfExcludedPaths = @(
  "pmo-config/public-hygiene-allowlist.json",
  "scripts/check-public-hygiene.ps1"
)

$checks = @(
  @{ Id = "OLD-NAME-001"; Pattern = "PMO-Template-Personal"; Regex = $false; Description = "old private product name" },
  @{ Id = "PRIVATE-PROJECT-001"; Pattern = "AxiomGuard"; Regex = $false; Description = "private project name" },
  @{ Id = "PRIVATE-PROJECT-002"; Pattern = "Praxis"; Regex = $false; Description = "private project name" },
  @{ Id = "PRIVATE-PROJECT-003"; Pattern = "EarthhEvansHq"; Regex = $false; Description = "private project name" },
  @{ Id = "PRIVATE-PROJECT-004"; Pattern = "EarthhEvans"; Regex = $false; Description = "private project name" },
  @{ Id = "PRIVATE-PROJECT-005"; Pattern = "Super-Claude"; Regex = $false; Description = "private project name" },
  @{ Id = "PRIVATE-PROJECT-006"; Pattern = "Infinity Platform"; Regex = $false; Description = "private project name" },
  @{ Id = "PRIVATE-PROJECT-007"; Pattern = "Elegance"; Regex = $false; Description = "private project name" },
  @{ Id = "LOCAL-PATH-001"; Pattern = '[A-Z]:\\Users\\'; Regex = $true; Description = "Windows local user path" },
  @{ Id = "LOCAL-PATH-002"; Pattern = '/Users/[^/\s]+'; Regex = $true; Description = "macOS local user path" },
  @{ Id = "LOCAL-PATH-003"; Pattern = '~/Documents/'; Regex = $true; Description = "home Documents path" },
  @{ Id = "OLD-URL-001"; Pattern = 'github\.com/witchwasin/PMO-Template-Personal'; Regex = $true; Description = "old repository URL" },
  @{ Id = "BRANCH-001"; Pattern = "remediation/9plus"; Regex = $false; Description = "old remediation branch topology" },
  @{ Id = "BRANCH-002"; Pattern = "hardening/0.5"; Regex = $false; Description = "old hardening branch topology" },
  @{ Id = "COMMIT-001"; Pattern = "37c919b"; Regex = $false; Description = "old concrete commit id" },
  @{ Id = "COMMIT-002"; Pattern = "8650f0f"; Regex = $false; Description = "old concrete commit id" },
  @{ Id = "SECRET-001"; Pattern = 'ghp_[A-Za-z0-9_]{20,}'; Regex = $true; Description = "GitHub token-like string" },
  @{ Id = "SECRET-002"; Pattern = 'github_pat_[A-Za-z0-9_]{20,}'; Regex = $true; Description = "GitHub fine-grained token-like string" },
  @{ Id = "SECRET-003"; Pattern = 'sk-[A-Za-z0-9]{20,}'; Regex = $true; Description = "API key-like string" },
  @{ Id = "SECRET-004"; Pattern = 'AKIA[0-9A-Z]{16}'; Regex = $true; Description = "AWS access key-like string" },
  @{ Id = "SECRET-005"; Pattern = 'BEGIN PRIVATE KEY'; Regex = $true; Description = "private key marker" },
  @{ Id = "SECRET-006"; Pattern = 'Bearer\s+[A-Za-z0-9._~+/-]+=*'; Regex = $true; Description = "Bearer token-like string" }
)

$problems = @()

foreach ($file in $trackedFiles) {
  $relativePath = ConvertTo-RepoPath $file
  if ($selfExcludedPaths -contains $relativePath) { continue }
  $fullPath = Join-Path $repo $file
  if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { continue }
  if (-not (Test-TextFile $fullPath)) { continue }

  $text = Get-Content -LiteralPath $fullPath -Raw -ErrorAction SilentlyContinue
  foreach ($check in $checks) {
    $matched = if ($check.Regex) {
      $text -match $check.Pattern
    } else {
      $text.Contains($check.Pattern)
    }
    if (-not $matched) { continue }
    if (Test-AllowedMatch $relativePath $check.Pattern) { continue }
    $problems += ("{0}: {1} in {2} (pattern: {3})" -f $check.Id, $check.Description, $relativePath, $check.Pattern)
  }
}

Write-Host "Axiom-PMO Public Hygiene Check: $repo"
if ($problems.Count -eq 0) {
  Write-Host "Summary: PASS=1 FAIL=0"
  exit 0
}

foreach ($problem in $problems) {
  Write-Host "[FAIL] $problem"
}
Write-Host "Summary: PASS=0 FAIL=$($problems.Count)"
exit 1
