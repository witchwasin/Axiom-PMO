param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,

  # Emits the transcript without ANSI colour or timing, for recording an asciinema
  # cast or capturing expected output into docs.
  [switch]$Plain,

  # Skip the pauses. CI and the smoke test use this.
  [switch]$NoPause
)

# Three-minute proof.
#
# Runs the Handoff gate against two synthetic projects that differ only in the
# things this framework exists to catch, and shows the difference. No narration
# that the tool cannot back up: every line below is real validator output.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/pwsh-host.ps1")

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$broken = Join-Path $repo "demo/broken-project"
$fixed = Join-Path $repo "demo/fixed-project"

foreach ($path in @($broken, $fixed)) {
  if (-not (Test-Path -LiteralPath $path -PathType Container)) {
    Write-Host "Demo project not found: $path"
    exit 1
  }
}

function Write-Rule {
  param([string]$Text)
  Write-Host ""
  Write-Host ("=" * 74)
  Write-Host $Text
  Write-Host ("=" * 74)
  Write-Host ""
}

function Wait-Beat {
  param([int]$Seconds = 2)
  if ($NoPause -or $Plain) { return }
  Start-Sleep -Seconds $Seconds
}

# Child stdout is captured and re-emitted with Write-Host so the function's
# only pipeline output is the exit code. Letting the native command write
# straight to the pipeline would fold the whole report into the caller's
# "$code = Invoke-..." assignment.
function Invoke-Child {
  param([string]$Script, [string[]]$ScriptArgs)
  $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
    (Join-Path $repo $Script)) + $ScriptArgs
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & $pwshExe @psArgs 2>&1
  $code = $LASTEXITCODE
  $ErrorActionPreference = $previous
  foreach ($line in $output) { Write-Host $line }
  return $code
}

function Invoke-Gate {
  param([string]$ProjectPath, [string[]]$ExtraArgs = @())
  return (Invoke-Child -Script "scripts/validate-project.ps1" -ScriptArgs (
    @("-ProjectPath", $ProjectPath, "-Mode", "Standard", "-Gate", "Handoff") + $ExtraArgs))
}

function Invoke-Assess {
  param([string]$ProjectPath)
  return (Invoke-Child -Script "scripts/assess-handoff.ps1" -ScriptArgs @(
    "-ProjectPath", $ProjectPath, "-Mode", "Standard"))
}

Write-Rule "Axiom-PMO -- the Handoff gate in three minutes"

Write-Host "Two synthetic projects. Both have a PROJECT.md, a design, a work-item"
Write-Host "board, and an approved Design Ready gate. Both would pass every gate"
Write-Host "Axiom-PMO 1.0 could run."
Write-Host ""
Write-Host "One of them cannot actually be built on Monday morning."
Wait-Beat 3

Write-Rule "1/3  demo/broken-project  --  scripts/validate-project.ps1 -Gate Handoff"

$brokenExit = Invoke-Gate -ProjectPath $broken
Write-Host ""
Write-Host "Exit code: $brokenExit"
Wait-Beat 3

Write-Rule "What those failures mean"

Write-Host "  HANDOFF-004  The shared schema every other item reads from is"
Write-Host "               scheduled last. Two engineers would spend day one"
Write-Host "               building against a table that does not exist yet."
Write-Host ""
Write-Host "  HANDOFF-012  The scan flow needs the rear camera and nobody decided"
Write-Host "               how the page is served. A browser will not open a"
Write-Host "               camera over plain HTTP, so this build works on the"
Write-Host "               developer laptop and fails on the demo tablet."
Write-Host ""
Write-Host "  HANDOFF-011  A data element the author marked sensitive has no"
Write-Host "               classification decision attached."
Write-Host ""
Write-Host "  HANDOFF-007  An acceptance case has no seed data, so it cannot be"
Write-Host "               reached from the demo dataset."
Write-Host ""
Write-Host "  HANDOFF-003  A work item is owned by 'Dev Team'."
Write-Host ""
Write-Host "None of these are style violations. Each one costs days."
Wait-Beat 4

Write-Rule "2/3  demo/fixed-project  --  same command"

$fixedExit = Invoke-Gate -ProjectPath $fixed -ExtraArgs @("-FailOnWarning")
Write-Host ""
Write-Host "Exit code: $fixedExit"
Wait-Beat 3

Write-Rule "3/3  Readiness is not one boolean"

Write-Host "The fixed project passes every deterministic check. That is not the"
Write-Host "same as being ready to demonstrate:"
Write-Host ""
$null = Invoke-Assess -ProjectPath $fixed
Wait-Beat 2

Write-Rule "Try it on your own project"

Write-Host "  node cli/axiom.mjs handoff --project <path> --mode Standard"
Write-Host "  node cli/axiom.mjs check"
Write-Host ""
Write-Host "Docs: docs/concepts/handoff-readiness.md"
Write-Host "Rules: docs/rules/"
Write-Host ""

if ($brokenExit -eq 0) {
  Write-Host "DEMO SELF-CHECK FAILED: the broken project was expected to fail the gate."
  exit 1
}
if ($fixedExit -ne 0) {
  Write-Host "DEMO SELF-CHECK FAILED: the fixed project was expected to pass the gate."
  exit 1
}

exit 0
