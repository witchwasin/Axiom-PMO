<#
.SYNOPSIS
  Report-only scope advisory for a Claude Code PreToolUse event.

.DESCRIPTION
  Milestone 6.0 identified a preventive hook as the most interesting thing on
  the integration list and also the most dangerous, and carved it out as its
  own opt-in milestone for that reason. The danger is specific: a false
  positive here does not produce a report a human triages later, it blocks an
  edit right now, and the natural response is to switch the tool off and stop
  trusting it.

  So this ships the way SCOPE-DIFF and the GitHub Action shipped: it observes,
  it reports, and it decides nothing.

    - Disabled unless the project opts in. No opt-in file, no advisory.
    - It NEVER emits a permission decision. Claude Code is free to proceed
      whatever this says. Blocking is not a configuration option here; there is
      no code path that emits one.
    - It is not an authority. What it produces is a note, and a note is not
      evidence and certainly not an approval. The verdict that matters is still
      SCOPE-DIFF at the pull request and the EXEC-* rules at verification.
    - It reuses the real matcher (scripts/lib/scope-diff-matcher.ps1). A second
      glob implementation that disagreed with the validator would be worse than
      no hook at all -- it would teach users that the advisory and the gate
      mean different things.

  Reads the PreToolUse payload as JSON on stdin. Writes an advisory to stdout
  and exits 0. Always exits 0: a governance advisory that breaks somebody's
  editing session has done more harm than the deviation it was watching for.
#>
[CmdletBinding()]
param(
  [string]$ProjectPath = $null,
  [string]$PayloadPath = $null
)

# Deliberately NOT "Stop". Every failure here must degrade to silence rather
# than to a broken tool call.
$ErrorActionPreference = "Continue"

function Exit-Silently { exit 0 }

try {
  . (Join-Path $PSScriptRoot "lib/scope-diff-matcher.ps1")
  . (Join-Path $PSScriptRoot "lib/pwsh-host.ps1")
} catch {
  Exit-Silently
}

# ---- Read the event ------------------------------------------------------

$payloadText = ""
try {
  if ($PayloadPath) {
    if (-not (Test-Path -LiteralPath $PayloadPath)) { Exit-Silently }
    $payloadText = [System.IO.File]::ReadAllText($PayloadPath)
  } else {
    $payloadText = [Console]::In.ReadToEnd()
  }
} catch { Exit-Silently }

if ([string]::IsNullOrWhiteSpace($payloadText)) { Exit-Silently }

$payload = $null
try { $payload = $payloadText | ConvertFrom-Json } catch { Exit-Silently }
if (-not $payload) { Exit-Silently }

# The payload shape is Claude Code's, not ours, and it may grow fields. Only
# the ones actually needed are read, and a missing one means "nothing to say"
# rather than an error -- an advisory that starts complaining because an
# upstream schema gained a field is an advisory people turn off.
$toolInput = $payload.tool_input
if (-not $toolInput) { Exit-Silently }

$candidatePaths = New-Object System.Collections.Generic.List[string]
foreach ($field in @("file_path", "path", "notebook_path")) {
  $value = $toolInput.$field
  if ($value -and $value -is [string]) { $candidatePaths.Add($value) | Out-Null }
}
if ($candidatePaths.Count -eq 0) { Exit-Silently }

# ---- Locate the project and its opt-in -----------------------------------

if (-not $ProjectPath) {
  $ProjectPath = $payload.cwd
}
if (-not $ProjectPath) { $ProjectPath = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $ProjectPath)) { Exit-Silently }

$project = $null
try { $project = (Resolve-Path -LiteralPath $ProjectPath).Path } catch { Exit-Silently }

# Opt-in lives in the user's project, so one repository can enable it without
# enabling it everywhere the plugin is installed. Absent means off, and off is
# the default that ships.
$optInPath = Join-Path $project ".axiom/hooks.json"
if (-not (Test-Path -LiteralPath $optInPath)) { Exit-Silently }

$optIn = $null
try { $optIn = [System.IO.File]::ReadAllText($optInPath) | ConvertFrom-Json } catch { Exit-Silently }
if (-not $optIn) { Exit-Silently }
if ($optIn.scope_advisory -ne $true) { Exit-Silently }

# ---- Ask the real matcher ------------------------------------------------

$declaration = $null
try { $declaration = Read-ScopeDeclaration -ProjectPath $project } catch { Exit-Silently }
if (-not $declaration -or -not $declaration.Present -or -not $declaration.Valid) { Exit-Silently }

$includeRegexes = @()
$excludeRegexes = @()
try {
  foreach ($pattern in $declaration.Include) { $includeRegexes += (ConvertTo-ScopeGlobRegex $pattern) }
  foreach ($pattern in $declaration.Exclude) { $excludeRegexes += (ConvertTo-ScopeGlobRegex $pattern) }
} catch { Exit-Silently }

$findings = New-Object System.Collections.Generic.List[string]
foreach ($candidate in $candidatePaths) {
  $relative = $candidate
  try {
    $full = if ([System.IO.Path]::IsPathRooted($candidate)) { $candidate } else { Join-Path $project $candidate }
    # GetFullPath on both sides, and an ordinal-ignore-case comparison. Windows
    # paths are case-insensitive and can arrive with mixed separators, so a
    # case-sensitive raw StartsWith reports an in-project file as "outside the
    # project" and silently says nothing about it -- which CI caught on
    # windows-pwsh7 and nowhere else.
    $full = [System.IO.Path]::GetFullPath($full)
    $projectFull = [System.IO.Path]::GetFullPath($project)
    $normalisedProject = $projectFull.TrimEnd([char]92, [char]47) + [System.IO.Path]::DirectorySeparatorChar
    $comparison = if (Test-WindowsHost) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }
    if ($full.StartsWith($normalisedProject, $comparison)) {
      $relative = $full.Substring($normalisedProject.Length)
    } else {
      # Outside the project entirely. SCOPE.json says nothing about such a
      # path, so this hook says nothing about it either.
      continue
    }
  } catch { continue }

  $relative = $relative -replace "\\", "/"

  $verdict = $null
  try { $verdict = Resolve-ScopeVerdict -Path $relative -IncludeRegexes $includeRegexes -ExcludeRegexes $excludeRegexes -ExemptEntries @() } catch { continue }
  if ($verdict -and $verdict.Verdict -eq "out_of_scope") {
    $findings.Add($relative) | Out-Null
  }
}

if ($findings.Count -eq 0) { Exit-Silently }

# ---- Say something, decide nothing ---------------------------------------
#
# systemMessage only. There is deliberately no permissionDecision field here
# and no branch that could add one: this is the difference between an advisory
# and an enforcement, and it is enforced by there being no code to do it.

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("Axiom-PMO scope advisory (report-only -- nothing is blocked):") | Out-Null
foreach ($finding in $findings) {
  $lines.Add("  - $finding is outside this project's approved implementation_scope") | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("This is a note, not a decision and not evidence. If the change is correct, the") | Out-Null
$lines.Add("scope needs a recorded change; if it is not, it is worth reconsidering now rather") | Out-Null
$lines.Add("than at review. SCOPE-DIFF checks this for real at the pull request.") | Out-Null

$response = [ordered]@{
  systemMessage = ($lines -join "`n")
}
Write-Output ($response | ConvertTo-Json -Depth 4 -Compress)
exit 0
