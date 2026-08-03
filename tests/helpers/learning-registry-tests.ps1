param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

# Behaviour tests for Milestone 9 (scripts/aggregate-diagnostics.ps1). Each
# case runs in an isolated .axiom directory so cases cannot see each other's
# events, and so this file never touches the real repository's own
# .axiom/learning/ if a maintainer has one.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$aggregateScript = Join-Path $repo "scripts/aggregate-diagnostics.ps1"
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

# Each case gets its own isolated copy of the framework (learning-policy.json
# resolves events_dir/registry_path/salt_path relative to -RepoRoot), so
# concurrent test runs and the real repository's own .axiom/ never collide.
function New-IsolatedRepoRoot {
  $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-learning-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $repo "pmo-config") -Destination (Join-Path $dir "pmo-config") -Recurse -Force
  Copy-Item -LiteralPath (Join-Path $repo "scripts") -Destination (Join-Path $dir "scripts") -Recurse -Force
  Copy-Item -LiteralPath (Join-Path $repo "tests/fixtures") -Destination (Join-Path $dir "tests/fixtures") -Recurse -Force
  return $dir
}

function Remove-IsolatedRepoRoot {
  param([string]$Dir)
  Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue
}

function Invoke-Aggregate {
  param([string]$RepoRoot, [string]$ProjectPath, [string]$Mode = "Standard", [string]$Gate = "Release", [switch]$RebuildOnly)
  $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/aggregate-diagnostics.ps1"), "-RepoRoot", $RepoRoot, "-Format", "Json")
  if ($RebuildOnly) { $psArgs += "-RebuildOnly" } else { $psArgs += @("-ProjectPath", $ProjectPath, "-Mode", $Mode, "-Gate", $Gate) }
  $previous = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $output = & $pwshExe @psArgs 2>$null
  $ErrorActionPreference = $previous
  $json = $null
  try { $json = ($output | Out-String) | ConvertFrom-Json } catch { }
  return $json
}

Write-Host "Axiom-PMO Failure Pattern Registry Tests: $repo"
Write-Host ""

# ---- Case: no artifact content or free text reaches an event ---------------
{
  $isolated = New-IsolatedRepoRoot
  try {
    Invoke-Aggregate -RepoRoot $isolated -ProjectPath (Join-Path $isolated "tests/fixtures/invalid-mode-downgrade-workitem") -Mode Standard -Gate Release | Out-Null
    $eventFiles = Get-ChildItem -LiteralPath (Join-Path $isolated ".axiom/learning/events") -Filter "*.jsonl"
    Assert-True "at least one event file was written" ($eventFiles.Count -gt 0)
    $allText = ($eventFiles | Get-Content) -join "`n"
    Assert-True "no event carries a 'message' key" ($allText -notmatch '"message"')
    Assert-True "no event carries a 'suggestion' key" ($allText -notmatch '"suggestion"')
    Assert-True "no event carries a raw markdown/source path outside the governed allowlist" ($allText -notmatch '\.md"' -or $allText -match '"artifact":"(PROJECT|DELIVERY|HANDOFF|RELEASE|RAID-log|decision-log)\.md"')
  } finally { Remove-IsolatedRepoRoot $isolated }
}.Invoke()

# ---- Case: an unlisted artifact is bucketed to "other", not retained -------
{
  $isolated = New-IsolatedRepoRoot
  try {
    $projectPath = Join-Path $isolated "tests/fixtures/invalid-mode-downgrade-workitem"
    Invoke-Aggregate -RepoRoot $isolated -ProjectPath $projectPath -Mode Standard -Gate Release | Out-Null
    $eventFiles = Get-ChildItem -LiteralPath (Join-Path $isolated ".axiom/learning/events") -Filter "*.jsonl"
    $events = ($eventFiles | Get-Content) | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json }
    $unlistedArtifacts = @($events | Where-Object { $_.artifact -and $_.artifact -notin @("PROJECT.md", "DELIVERY.md", "HANDOFF.md", "RELEASE.md", "RAID-log.md", "decision-log.md", "SCOPE.json", "RTM.json", "HANDOFF-REVIEW.json", "EXECUTION-CONTRACT.json", "EXECUTION-RESULT.json", "EXECUTION-REVIEW.json", "DESIGN/BUILD-SPEC.md", "DESIGN/FLOW.puml", "DESIGN/WIREFRAME.md", "other") })
    Assert-True "every non-governed artifact field is 'other'" ($unlistedArtifacts.Count -eq 0) `
      ("saw: " + (($unlistedArtifacts | ForEach-Object { $_.artifact }) -join ", "))
  } finally { Remove-IsolatedRepoRoot $isolated }
}.Invoke()

# ---- Case: rebuild is byte-for-byte identical (generated_at excepted) ------
{
  $isolated = New-IsolatedRepoRoot
  try {
    $r1 = Invoke-Aggregate -RepoRoot $isolated -ProjectPath (Join-Path $isolated "tests/fixtures/invalid-mode-downgrade-workitem") -Mode Standard -Gate Release
    $registryPath = Join-Path $isolated ".axiom/learning/FAILURE-PATTERNS.json"
    Remove-Item -LiteralPath $registryPath -Force
    $r2 = Invoke-Aggregate -RepoRoot $isolated -RebuildOnly
    $r1.PSObject.Properties.Remove("generated_at")
    $r2.PSObject.Properties.Remove("generated_at")
    Assert-True "rebuilt registry matches the original (generated_at aside)" `
      (($r1 | ConvertTo-Json -Depth 8) -eq ($r2 | ConvertTo-Json -Depth 8))
  } finally { Remove-IsolatedRepoRoot $isolated }
}.Invoke()

# ---- Case: twenty reruns of one unfixed defect do not cross the candidate threshold ---
{
  $isolated = New-IsolatedRepoRoot
  try {
    for ($i = 0; $i -lt 20; $i++) {
      Invoke-Aggregate -RepoRoot $isolated -ProjectPath (Join-Path $isolated "tests/fixtures/invalid-mode-downgrade-workitem") -Mode Standard -Gate Release | Out-Null
    }
    $candidatesDir = Join-Path $isolated ".axiom/learning/candidates"
    $candidateCount = if (Test-Path -LiteralPath $candidatesDir) { @(Get-ChildItem -LiteralPath $candidatesDir -Filter "*.json").Count } else { 0 }
    Assert-True "20 reruns against ONE project/commit produce zero improvement candidates" ($candidateCount -eq 0)

    $registry = Get-Content -LiteralPath (Join-Path $isolated ".axiom/learning/FAILURE-PATTERNS.json") -Raw | ConvertFrom-Json
    $modeCluster = @($registry.clusters | Where-Object { $_.rule_id -eq "MODE-001" })[0]
    Assert-True "MODE-001 cluster recorded 20 events but only 1 distinct project" `
      ($modeCluster.count -eq 20 -and $modeCluster.distinct_projects -eq 1)
  } finally { Remove-IsolatedRepoRoot $isolated }
}.Invoke()

# ---- Case: events dir is git-ignored -----------------------------------------
{
  Assert-True ".gitignore excludes .axiom/learning/events/" `
    ((Get-Content -LiteralPath (Join-Path $repo ".gitignore") -Raw) -match [regex]::Escape(".axiom/learning/events/"))
}.Invoke()

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"
if ($fail -gt 0) { exit 1 }
exit 0
