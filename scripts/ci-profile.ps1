#requires -Version 5.1
<#
.SYNOPSIS
  Classifies a set of changed paths into a risk-based CI profile.

.DESCRIPTION
  Single source of truth for risk-based CI selection (see
  docs/architecture/ci-risk-based.md). Given a list of repo-relative changed
  paths, it resolves the least-expensive CI profile that still covers the risk:

    fast      docs/report-only, no code        -> one cheap Linux pwsh job
    targeted  code in a known area             -> relevant suite + host(s) only
    full      high-risk / merge / release gate -> every required host

  The mapping is intentionally conservative: an unknown path escalates one
  level to `targeted`, never silently down to `fast`, and the high-risk set
  (.github/workflows, action.yml, scripts/lib, the core validator/runtime)
  escalates straight to `full`. That is the guard against a path filter that
  lets a validator or configuration change slip past CI by accident.

  This script performs no I/O beyond reading an optional paths file and writing
  its answer, so it is host-agnostic and unit-testable offline. It never shells
  out to git; callers feed it the `git diff --name-only` output.

.PARAMETER ChangedPaths
  One or more repo-relative paths (forward or back slashes).

.PARAMETER ChangedPathsPath
  Alternative to -ChangedPaths: a file with one repo-relative path per line.

.PARAMETER Profile
  Explicit override for workflow_dispatch (fast, targeted, full). When set,
  the changed paths are ignored.

.PARAMETER TargetHost
  Optional host override for a targeted dispatch: windows-ps51, windows-ps7,
  linux, macos, or all. Named TargetHost, not Host, because $Host is a
  PowerShell automatic variable.

.PARAMETER Suite
  Optional suite override for a targeted dispatch (informational; the runner
  may narrow the check set).

.PARAMETER GithubOutput
  Also write profile/suite/hosts/matrix/reason to $env:GITHUB_OUTPUT for a
  downstream job to consume.

.OUTPUTS
  A single-line JSON object on stdout:
  {"profile":"targeted","suite":"doctor","hosts":"windows-ps51,windows-ps7",
   "reason":"...","matrix":{"include":[{...}]}}
#>
param(
  [string[]]$ChangedPaths = @(),
  [string]$ChangedPathsPath = "",
  [ValidateSet("", "fast", "targeted", "full")]
  [string]$Profile = "",
  [string]$TargetHost = "",
  [string]$Suite = "",
  [switch]$GithubOutput
)

$ErrorActionPreference = "Stop"

$hostCatalog = @{
  "windows-ps51" = @{ name = "windows-ps51"; runsOn = "windows-2025"; shell = "powershell"; exe = "powershell.exe" }
  "windows-ps7"  = @{ name = "windows-ps7";  runsOn = "windows-2025"; shell = "pwsh";       exe = "pwsh" }
  "linux"        = @{ name = "linux";        runsOn = "ubuntu-24.04";  shell = "pwsh";       exe = "pwsh" }
  "macos"        = @{ name = "macos";        runsOn = "macos-15";      shell = "pwsh";       exe = "pwsh" }
}
$allHosts = @("windows-ps51", "windows-ps7", "linux", "macos")

function Normalize-Path([string]$Path) {
  $p = $Path.Trim()
  if (-not $p) { return $null }
  $p = $p -replace '\\', '/'
  $p = $p -replace '^\./', ''
  return $p.TrimEnd('/')
}

function Add-Unique([System.Collections.Generic.List[string]]$List, [string]$Value) {
  if (-not $List.Contains($Value)) { $List.Add($Value) | Out-Null }
}

function Resolve-CiProfile {
  param([string[]]$Paths)

  # 0 = fast, 1 = targeted, 2 = full
  $level = 0
  $suites = New-Object System.Collections.Generic.List[string]
  $hosts = New-Object System.Collections.Generic.List[string]
  $reasons = New-Object System.Collections.Generic.List[string]

  foreach ($raw in $Paths) {
    $p = Normalize-Path $raw
    if (-not $p) { continue }

    # --- full: high-risk runtime/interface surfaces -------------------------
    # This file is in its own high-risk set on purpose. A pull_request event
    # classifies its own diff using the merge commit's copy of this script, so
    # an edit here classifies itself. If a future change ever weakened the
    # mapping -- sending scripts/** to `fast`, say -- that change would select
    # `fast` for itself, skip run-all-checks.ps1, and therefore skip
    # tests/helpers/ci-profile-tests.ps1: the one test that guards the mapping.
    # Escalating to `full` closes that loop. run-ci-suite.ps1 joins it because
    # the two together are the CI control plane -- they decide what actually
    # executes -- and the plan's rule is to escalate when in doubt.
    if ($p.StartsWith('.github/workflows/') -or $p -eq 'action.yml' -or
        $p.StartsWith('scripts/lib/') -or
        $p -eq 'scripts/run-all-checks.ps1' -or $p -eq 'scripts/validate-project.ps1' -or
        $p -eq 'scripts/ci-profile.ps1' -or $p -eq 'scripts/run-ci-suite.ps1') {
      if ($level -lt 2) { $level = 2 }
      Add-Unique $reasons "$p -> high-risk (workflow / shared-lib / runtime / CI control plane)"
      continue
    }

    # --- targeted: code in a known area -------------------------------------
    # A path belongs to exactly one area, so the first matching branch must win
    # and `continue`. Otherwise tests/helpers/cli-tests.mjs would be classified
    # as both cli@linux and tests@windows and the union would over-select hosts.
    if ($p.StartsWith('cli/') -or $p -eq 'tests/helpers/cli-tests.mjs' -or $p -eq 'tests/helpers/github-action-tests.mjs') {
      if ($level -lt 1) { $level = 1 }
      Add-Unique $suites 'cli'
      Add-Unique $hosts 'linux'
      Add-Unique $reasons "$p -> cli@linux"
      continue
    }
    if ($p.StartsWith('pmo-config/') -or $p.StartsWith('templates/')) {
      if ($level -lt 1) { $level = 1 }
      Add-Unique $suites 'config-mutation'
      Add-Unique $hosts 'windows-ps51'
      Add-Unique $hosts 'windows-ps7'
      Add-Unique $reasons "$p -> config/template@windows"
      continue
    }
    if ($p.StartsWith('scripts/')) {
      if ($level -lt 1) { $level = 1 }
      Add-Unique $suites 'doctor'
      Add-Unique $hosts 'windows-ps51'
      Add-Unique $hosts 'windows-ps7'
      Add-Unique $reasons "$p -> scripts@windows"
      continue
    }
    if ($p.StartsWith('tests/')) {
      if ($level -lt 1) { $level = 1 }
      Add-Unique $suites 'validation-fixtures'
      Add-Unique $hosts 'windows-ps51'
      Add-Unique $hosts 'windows-ps7'
      Add-Unique $reasons "$p -> tests@windows"
      continue
    }
    if ($p.StartsWith('examples/') -or $p.StartsWith('demo/')) {
      if ($level -lt 1) { $level = 1 }
      Add-Unique $suites 'validation-fixtures'
      Add-Unique $hosts 'linux'
      Add-Unique $reasons "$p -> examples/demo@linux"
      continue
    }
    if ($p.StartsWith('.claude/') -or $p.StartsWith('skills/') -or $p.StartsWith('hooks/')) {
      if ($level -lt 1) { $level = 1 }
      Add-Unique $suites 'plugin-drift'
      Add-Unique $hosts 'linux'
      Add-Unique $reasons "$p -> skills/hooks@linux"
      continue
    }

    # --- fast: docs / report only ------------------------------------------
    if ($p.StartsWith('docs/') -or $p.StartsWith('Fixed_Plan/') -or ($p -notmatch '/' -and $p -match '(?i)\.md$')) {
      Add-Unique $reasons "$p -> docs/report only (fast)"
      continue
    }

    # --- unknown: one level up, never silently down ------------------------
    if ($level -lt 1) { $level = 1 }
    Add-Unique $hosts 'linux'
    Add-Unique $reasons "$p -> unclassified, targeted@linux (one level up)"
  }

  $profile = switch ($level) { 2 { 'full' } 1 { 'targeted' } default { 'fast' } }
  if ($profile -eq 'full') {
    $hostList = $allHosts
    $suiteList = @()
  } elseif ($profile -eq 'targeted') {
    $hostList = @($hosts | Select-Object -Unique)
    $suiteList = @($suites | Select-Object -Unique)
  } else {
    $hostList = @('linux')
    $suiteList = @()
  }

  $reason = if ($reasons.Count -eq 0) { 'no changed paths (default fast)' } else { (@($reasons | Select-Object -Unique) -join '; ') }

  return @{
    profile = $profile
    suite = ($suiteList -join ',')
    hosts = ($hostList -join ',')
    reason = $reason
  }
}

function Resolve-DispatchProfile {
  param([string]$Profile, [string]$TargetHost, [string]$Suite)

  $hostList = @('linux')
  if ($Profile -eq 'full') {
    $hostList = $allHosts
  } elseif ($Profile -eq 'targeted') {
    if ($TargetHost -and $TargetHost -ne 'all') {
      if (-not $hostCatalog.ContainsKey($TargetHost)) {
        throw "Unknown host '$TargetHost'. Expected one of: $($allHosts -join ', '), or 'all'."
      }
      $hostList = @($TargetHost)
    } else {
      $hostList = $allHosts
    }
  }

  $reason = "workflow_dispatch profile=$Profile"
  if ($Profile -eq 'targeted') {
    $h = if ($TargetHost) { $TargetHost } else { 'all' }
    $s = if ($Suite) { $Suite } else { '(default)' }
    $reason += " host=$h suite=$s"
  }

  return @{
    profile = $Profile
    suite = $Suite
    hosts = ($hostList -join ',')
    reason = $reason
  }
}

# Builds the GitHub Actions matrix include as a JSON array string. Built by
# hand rather than ConvertTo-Json so a single-host selection stays a real array
# -- ConvertTo-Json collapses a one-element array to an object, which would
# make `matrix.include` on the consuming job fail on the common single-host
# targeted case.
function Get-CiMatrixJson {
  param([string[]]$HostList)
  $parts = @()
  foreach ($h in $HostList) {
    $c = $hostCatalog[$h]
    $parts += ('{"name":"' + $c.name + '","runsOn":"' + $c.runsOn + '","shell":"' + $c.shell + '","exe":"' + $c.exe + '"}')
  }
  return "[" + ($parts -join ",") + "]"
}

if ($MyInvocation.InvocationName -ne '.') {
  if ($Profile) {
    $result = Resolve-DispatchProfile -Profile $Profile -TargetHost $TargetHost -Suite $Suite
  } else {
    $paths = @($ChangedPaths)
    if ($ChangedPathsPath -and (Test-Path -LiteralPath $ChangedPathsPath -PathType Leaf)) {
      $paths = @(Get-Content -LiteralPath $ChangedPathsPath | Where-Object { $_.Trim() })
    }
    $result = Resolve-CiProfile -Paths $paths
  }

  $json = $result | ConvertTo-Json -Compress -Depth 5
  Write-Output $json

  if ($GithubOutput -and $env:GITHUB_OUTPUT) {
    $hostList = @($result.hosts.Split(',') | Where-Object { $_ })
    $lines = @(
      "profile=$($result.profile)",
      "suite=$($result.suite)",
      "hosts=$($result.hosts)",
      "reason=$($result.reason)",
      "matrix=$(Get-CiMatrixJson -HostList $hostList)"
    )
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value $lines -Encoding utf8
  }
}
