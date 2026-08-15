#requires -Version 5.1
<#
.SYNOPSIS
  Regression test for risk-based CI profile selection.

.DESCRIPTION
  Exercises scripts/ci-profile.ps1 -- the single source of truth for mapping
  changed paths to a fast/targeted/full CI profile -- so a future edit to the
  mapping cannot silently widen a check away from a required host, nor narrow a
  high-risk change down to a docs-only fast run. This is the guard the risk-based
  plan requires: profile selection must be covered by a regression test and must
  never swallow a failure by picking a cheaper profile.

  The classifier is dot-sourced and its Resolve-CiProfile / Resolve-DispatchProfile
  functions are called directly, so this runs without git and without spawning
  child PowerShell processes.
#>
param(
  [string]$RepoPath = "."
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path -LiteralPath $RepoPath).Path
$classifier = Join-Path $root "scripts/ci-profile.ps1"
if (-not (Test-Path -LiteralPath $classifier -PathType Leaf)) {
  Write-Host "[FAIL] missing classifier: $classifier"
  exit 1
}

. $classifier
. (Join-Path $root "scripts/lib/pwsh-host.ps1")

$pass = 0
$fail = 0
$failures = New-Object System.Collections.Generic.List[string]

function Assert-Equal {
  param([string]$Name, [object]$Expected, [object]$Actual)
  if ($Expected -eq $Actual) {
    $script:pass++
    Write-Host "[PASS] $Name"
  } else {
    $script:fail++
    $script:failures.Add("$Name -- expected '$Expected', got '$Actual'")
    Write-Host "[FAIL] $Name -- expected '$Expected', got '$Actual'"
  }
}

# Compare host/suite lists as sets (order-insensitive), normalised from the
# comma-joined strings the classifier emits.
function Get-Set([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
  return @($Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object)
}

function Assert-Profile {
  param(
    [string]$Name,
    [string[]]$Paths,
    [string]$ExpectedProfile,
    [string]$ExpectedSuite,
    [string]$ExpectedHosts
  )
  $r = Resolve-CiProfile -Paths $Paths
  $actualSuite = (Get-Set $r.suite) -join ','
  $expectedSuite = (Get-Set $ExpectedSuite) -join ','
  $actualHosts = (Get-Set $r.hosts) -join ','
  $expectedHosts = (Get-Set $ExpectedHosts) -join ','
  $ok = $true
  if ($r.profile -ne $ExpectedProfile) { $ok = $false; $reason = "profile expected '$ExpectedProfile' got '$($r.profile)'" }
  elseif ($actualSuite -ne $expectedSuite) { $ok = $false; $reason = "suite expected '$ExpectedSuite' got '$($r.suite)'" }
  elseif ($actualHosts -ne $expectedHosts) { $ok = $false; $reason = "hosts expected '$ExpectedHosts' got '$($r.hosts)'" }
  else { $reason = "" }

  if ($ok) {
    $script:pass++
    Write-Host "[PASS] $Name -> $($r.profile) (suite=$($r.suite); hosts=$($r.hosts))"
  } else {
    $script:fail++
    $script:failures.Add("$Name -- $reason")
    Write-Host "[FAIL] $Name -- $reason"
  }
}

# --- fast (docs / report only) ---------------------------------------------
Assert-Profile "docs-only"         @("docs/architecture/foo.md") "fast" "" "linux"
Assert-Profile "fixed-plan-only"   @("Fixed_Plan/Risk-Based-CI-Execution-Plan.md") "fast" "" "linux"
Assert-Profile "top-level-markdown" @("README.md") "fast" "" "linux"
Assert-Profile "empty-paths"       @() "fast" "" "linux"

# --- targeted: code in a known area ----------------------------------------
Assert-Profile "cli"               @("cli/axiom.mjs") "targeted" "cli" "linux"
Assert-Profile "cli-tests"         @("tests/helpers/cli-tests.mjs") "targeted" "cli" "linux"
Assert-Profile "scripts"           @("scripts/pmo-doctor.ps1") "targeted" "doctor" "windows-ps51,windows-ps7"
Assert-Profile "pmo-config"        @("pmo-config/policy.json") "targeted" "config-mutation" "windows-ps51,windows-ps7"
Assert-Profile "templates"         @("templates/PROJECT.md") "targeted" "config-mutation" "windows-ps51,windows-ps7"
Assert-Profile "tests"             @("tests/helpers/line-ending-tests.ps1") "targeted" "validation-fixtures" "windows-ps51,windows-ps7"
Assert-Profile "examples"          @("examples/STANDARD-FEATURE/PROJECT.md") "targeted" "validation-fixtures" "linux"
Assert-Profile "skills"            @(".claude/skills/pmo-governance/SKILL.md") "targeted" "plugin-drift" "linux"
Assert-Profile "unknown-one-level-up" @("VERSION") "targeted" "" "linux"

# --- full: high-risk / runtime / interface surfaces ------------------------
Assert-Profile "workflow"          @(".github/workflows/pmo-checks.yml") "full" "" "windows-ps51,windows-ps7,linux,macos"
Assert-Profile "action-yml"        @("action.yml") "full" "" "windows-ps51,windows-ps7,linux,macos"
Assert-Profile "shared-lib"        @("scripts/lib/golden-normalizer.ps1") "full" "" "windows-ps51,windows-ps7,linux,macos"
Assert-Profile "runtime-aggregator" @("scripts/run-all-checks.ps1") "full" "" "windows-ps51,windows-ps7,linux,macos"
Assert-Profile "core-validator"    @("scripts/validate-project.ps1") "full" "" "windows-ps51,windows-ps7,linux,macos"

# The CI control plane must escalate to `full`, and this classifier especially:
# a pull_request classifies its own diff with the merge commit's copy of
# ci-profile.ps1, so a change that weakened the mapping could otherwise select a
# cheap profile for itself and skip the very test asserting these lines.
Assert-Profile "ci-profile-self"   @("scripts/ci-profile.ps1") "full" "" "windows-ps51,windows-ps7,linux,macos"
Assert-Profile "ci-suite-runner"   @("scripts/run-ci-suite.ps1") "full" "" "windows-ps51,windows-ps7,linux,macos"

# --- union: highest risk wins, hosts/suites accumulate ---------------------
Assert-Profile "mixed-docs-and-lib" @("docs/a.md", "scripts/lib/x.ps1") "full" "" "windows-ps51,windows-ps7,linux,macos"
Assert-Profile "mixed-cli-and-scripts" @("cli/axiom.mjs", "scripts/pmo-doctor.ps1") "targeted" "cli,doctor" "linux,windows-ps51,windows-ps7"

# --- dispatch overrides ----------------------------------------------------
$d = Resolve-DispatchProfile -Profile "targeted" -TargetHost "windows-ps51" -Suite "line-ending"
Assert-Equal "dispatch-targeted-profile" "targeted" $d.profile
Assert-Equal "dispatch-targeted-hosts" "windows-ps51" $d.hosts
Assert-Equal "dispatch-targeted-suite" "line-ending" $d.suite

$d2 = Resolve-DispatchProfile -Profile "full" -TargetHost "" -Suite ""
Assert-Equal "dispatch-full-profile" "full" $d2.profile
Assert-Equal "dispatch-full-hosts" "windows-ps51,windows-ps7,linux,macos" $d2.hosts

$threw = $false
try {
  Resolve-DispatchProfile -Profile "targeted" -TargetHost "bogus" -Suite "" | Out-Null
} catch {
  $threw = $true
}
Assert-Equal "dispatch-unknown-host-rejected" $true $threw

# --- run-ci-suite whitelist (the targeted suite runner) --------------------
# The whitelist must map a known token to a real script and must reject an
# unknown token with a non-zero exit, never run nothing silently.
$ps = Get-PowerShellHost
if (-not $ps) {
  $script:fail++
  $script:failures.Add("run-ci-suite checks -- PowerShell host not found")
  Write-Host "[FAIL] run-ci-suite checks -- PowerShell host not found"
} else {
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $resolved = & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts/run-ci-suite.ps1") -Suite line-ending -RepoPath $root -ResolveOnly 2>&1
  Assert-Equal "ci-suite-known-maps-to-script" $true (($resolved -join "`n") -match 'line-ending-tests\.ps1')

  $unknown = & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts/run-ci-suite.ps1") -Suite bogus -RepoPath $root -ResolveOnly 2>&1
  $unknownExit = $LASTEXITCODE
  $ErrorActionPreference = $prevEap
  Assert-Equal "ci-suite-unknown-rejected" $false ($unknownExit -eq 0)
}

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"
if ($fail -gt 0) {
  Write-Host "Failures:"
  foreach ($f in $failures) { Write-Host "  - $f" }
  exit 1
}
exit 0
