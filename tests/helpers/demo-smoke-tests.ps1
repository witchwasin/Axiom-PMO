param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

# Smoke test for the three-minute demo.
#
# The demo is the first thing a stranger runs. If it prints a failure that is no
# longer produced, or claims a pass that no longer happens, the framework has
# lost more credibility than a broken unit test ever costs it. This asserts the
# demo's own claims against its actual output.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
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

Write-Host "Axiom-PMO Demo Smoke Test: $repo"
Write-Host ""

$previous = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$started = Get-Date
$output = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/demo.ps1") -RepoPath $repo -NoPause -Plain 2>&1
$demoExit = $LASTEXITCODE
$elapsed = ((Get-Date) - $started).TotalSeconds
$ErrorActionPreference = $previous

$text = ($output | Out-String)

Assert-True "demo exits 0" ($demoExit -eq 0) "exit=$demoExit"
Assert-True "demo completes well inside three minutes" ($elapsed -lt 180) ("took {0:N1}s" -f $elapsed)

# The demo's own self-check covers pass/fail. These assert that the *specific*
# findings it narrates are the ones actually produced -- the narration and the
# output must not be able to drift apart.
foreach ($rule in @("HANDOFF-003", "HANDOFF-004", "HANDOFF-007", "HANDOFF-011", "HANDOFF-012")) {
  Assert-True "demo shows a real $rule failure" ($text -match ("\[FAIL\]\s+" + [regex]::Escape($rule)))
}

Assert-True "demo shows the fixed project passing" ($text -match "Summary: PASS=\d+ WARN=0 \(0 blocking\) FAIL=0")
Assert-True "demo shows stage verdicts, not one boolean" ($text -match "Ready to Start Development")
Assert-True "demo shows build-ready but demo-blocked" ($text -match "READY TO BUILD, NOT READY TO DEMO")
Assert-True "demo states the score is not an approval" ($text -match "not an approval")
Assert-True "demo does not claim a recording asset exists" (-not ($text -match "\.gif|\.cast\b"))

# Diagnostics must reach the reader with their remediation attached; that is the
# whole point of the v1.1 contract and the demo is where it is most visible.
Assert-True "demo output includes a fix line" ($text -match "(?m)^\s+fix:")
Assert-True "demo output includes a docs link" ($text -match "(?m)^\s+docs:\s+https://")
Assert-True "demo output locates findings by artifact" ($text -match "(?m)^\s+where:")

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"
if ($fail -gt 0) {
  Write-Host ""
  Write-Host "--- demo output ---"
  Write-Host $text
  exit 1
}
exit 0
