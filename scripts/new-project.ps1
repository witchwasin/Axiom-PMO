param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectCode,

  [ValidateSet("Lite", "Standard", "Strict")]
  [string]$Mode = "Standard",

  # M7: declared delivery strategy, not project identity -- a project may
  # switch it later with an ordinary PROJECT.md edit. Defaults to
  # development_handoff, the core product's own default, so every existing
  # caller of this script keeps producing byte-for-byte the same PROJECT.md
  # it always has (see the same rationale on -IncludeHandoff below).
  [ValidateSet("development_handoff", "governed_ai_execution")]
  [string]$ExecutionPath = "development_handoff",

  [ValidateSet("off", "guided", "auto")]
  [string]$ResearchMode = "off",

  [ValidateSet("quick", "standard", "deep")]
  [string]$ResearchDepth = "standard",

  [ValidateSet("none", "feyman", "web", "auto")]
  [string]$ResearchProvider = "none",

  [ValidateSet("not_applicable", "dev_guided", "claude_design")]
  [string]$UiDelivery = "not_applicable",

  # M7 onboarding: when the interactive wizard's "Help me decide" path finds a
  # strict trigger, it passes it through here so the generated D-001 row
  # already carries the declaration instead of a human having to fill it in
  # by hand. None of these three change validator behavior on their own --
  # Resolve-EffectiveMode (scripts/lib/mode-resolver.ps1) already reads
  # DELIVERY.md's Strict Trigger column and escalates from it; this only
  # writes what the wizard already asked into the row that column lives in.
  [string]$StrictTrigger = "none",
  [string]$ModeReason = "normal feature",
  [string]$ModeApprovedBy = "PM",

  [string]$OutputRoot = "projects",

  # Handoff scaffolding is opt-in so the default generator output is byte-for-byte
  # what v1.0 produced. Existing scripts, tests, and muscle memory keep working.
  [switch]$IncludeHandoff,

  [ValidateSet("demo", "pilot", "production", "internal")]
  [string]$Target = "internal",

  [int]$HorizonDays = 14
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/pwsh-host.ps1")

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

$repo = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
  $targetRoot = $OutputRoot
} else {
  $targetRoot = Join-Path $repo $OutputRoot
}
$projectDir = Join-Path $targetRoot $ProjectCode
# InvariantCulture, not Get-Date -Format: on a machine whose culture uses a
# non-Gregorian calendar (th-TH and en-TH both do) the default formatter
# writes the Buddhist year, so a project generated in Bangkok came out dated
# 2569-07-26. Governed artifacts are ISO-8601 Gregorian everywhere.
$today = (Get-Date).ToString("yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)

if (Test-Path -LiteralPath $projectDir) {
  throw "Project already exists: $projectDir"
}

New-Item -ItemType Directory -Force -Path $projectDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $projectDir "source/REQ") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $projectDir "source/MOM") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $projectDir "source/Transcript") | Out-Null

Copy-Item -LiteralPath (Join-Path $repo "templates/PROJECT.md") -Destination (Join-Path $projectDir "PROJECT.md")
Copy-Item -LiteralPath (Join-Path $repo "templates/DELIVERY.md") -Destination (Join-Path $projectDir "DELIVERY.md")

$projectFile = Join-Path $projectDir "PROJECT.md"
$deliveryFile = Join-Path $projectDir "DELIVERY.md"
$projectText = Get-Content -LiteralPath $projectFile -Raw
$projectText = $projectText.Replace("<PROJECT-CODE>", $ProjectCode)
$projectText = $projectText.Replace("Lite / Standard / Strict", $Mode)
$projectText = $projectText.Replace("development_handoff / governed_ai_execution", $ExecutionPath)
$projectText = $projectText.Replace("off / guided / auto", $ResearchMode)
$projectText = $projectText.Replace("quick / standard / deep", $ResearchDepth)
$projectText = $projectText.Replace("none / feyman / web / auto", $ResearchProvider)
$projectText = $projectText.Replace("not_applicable / dev_guided / claude_design", $UiDelivery)
$projectText = $projectText.Replace("<YYYY-MM-DD>", $today)
$projectText = $projectText.Replace("YYYY-MM-DD", $today)
Set-Content -LiteralPath $projectFile -Value $projectText -Encoding utf8

$deliveryText = Get-Content -LiteralPath $deliveryFile -Raw
$deliveryText = $deliveryText.Replace("<PROJECT-CODE>", $ProjectCode)
$deliveryText = $deliveryText.Replace("Lite / Standard / Strict", $Mode)
# The template's example work item defaults to Mode=Standard with a
# DESIGN/FLOW.puml design ref -- both wrong for a freshly generated Lite
# project (Lite never creates DESIGN/), which silently escalated every new
# Lite project's effective mode to Standard and failed REF-001 on a design
# file that was never created. Match the row to the requested mode instead.
$defaultDesignRef = if ($Mode -eq "Lite") { "not_required" } else { "DESIGN/BUILD-SPEC.md" }
$deliveryText = $deliveryText -replace '\| D-001 \| Standard \| none \| normal feature \| PM \| <feature> \| REQ-001 \| DESIGN/FLOW\.puml \|', "| D-001 | $Mode | $StrictTrigger | $ModeReason | $ModeApprovedBy | <feature> | REQ-001 | $defaultDesignRef |"
Set-Content -LiteralPath $deliveryFile -Value $deliveryText -Encoding utf8

function Copy-TemplateWithProjectCode {
  param([string]$SourcePath, [string]$DestPath)
  $text = (Get-Content -LiteralPath $SourcePath -Raw).Replace("<PROJECT-CODE>", $ProjectCode)
  Set-Content -LiteralPath $DestPath -Value $text -Encoding utf8
}

if ($Mode -ne "Lite") {
  New-Item -ItemType Directory -Force -Path (Join-Path $projectDir "DESIGN") | Out-Null
  Copy-TemplateWithProjectCode (Join-Path $repo "templates/RELEASE.md") (Join-Path $projectDir "RELEASE.md")
  Copy-TemplateWithProjectCode (Join-Path $repo "templates/BUILD-SPEC.md") (Join-Path $projectDir "DESIGN/BUILD-SPEC.md")
}

if ($Mode -ne "Lite" -and $UiDelivery -ne "not_applicable") {
  Copy-TemplateWithProjectCode (Join-Path $repo "templates/WIREFRAME.md") (Join-Path $projectDir "DESIGN/WIREFRAME.md")
  @"
@startuml
start
:Define $ProjectCode flow;
stop
@enduml
"@ | Set-Content -LiteralPath (Join-Path $projectDir "DESIGN/FLOW.puml") -Encoding utf8
}

# M5: a Claude Design project materializes the two provider contracts under
# their generated names only -- templates/DESIGN-PROVIDER-INPUT.json becomes
# DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json and
# templates/DESIGN-PROVIDER-REVIEW.json becomes DESIGN/CLAUDE-DESIGN/REVIEW.json.
# The repository source names never coexist with the generated names. Both are
# scaffolds with visible placeholders; the provider workflow fills them.
if ($UiDelivery -eq "claude_design") {
  New-Item -ItemType Directory -Force -Path (Join-Path $projectDir "DESIGN/CLAUDE-DESIGN") | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $projectDir "DESIGN/CLAUDE-DESIGN/OUTPUT") | Out-Null
  Copy-TemplateWithProjectCode (Join-Path $repo "templates/DESIGN-PROVIDER-INPUT.json") (Join-Path $projectDir "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json")
  Copy-TemplateWithProjectCode (Join-Path $repo "templates/DESIGN-PROVIDER-REVIEW.json") (Join-Path $projectDir "DESIGN/CLAUDE-DESIGN/REVIEW.json")
}

# Research, Externalization, and Claude Design artifacts are materialized by
# their owning milestones (M4-M6). M1-M3 record declarations and establish
# the early System Design/testability contract without creating provider files
# that are not yet governed.

if ($Mode -eq "Strict") {
  Copy-TemplateWithProjectCode (Join-Path $repo "templates/RAID-log.md") (Join-Path $projectDir "RAID-log.md")
  Copy-TemplateWithProjectCode (Join-Path $repo "templates/decision-log.md") (Join-Path $projectDir "decision-log.md")
  Copy-TemplateWithProjectCode (Join-Path $repo "templates/RTM.json") (Join-Path $projectDir "RTM.json")
}

if ($IncludeHandoff) {
  # Scaffolding only. Every owner, date, and decision stays a visible
  # placeholder: the generator must never produce a document that looks
  # filled-in, because a placeholder that reads like real evidence is worse
  # than an empty file. The Draft gate below tolerates placeholders; the
  # Handoff gate does not, and that is the intended sequence.
  $horizon = (Get-Date).AddDays($HorizonDays).ToString("yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)

  $handoffText = (Get-Content -LiteralPath (Join-Path $repo "templates/HANDOFF.md") -Raw).
    Replace("<PROJECT-CODE>", $ProjectCode).
    Replace("- Mode: <Lite | Standard | Strict>", "- Mode: $Mode").
    Replace("- Handoff Target: <demo | pilot | production | internal>", "- Handoff Target: $Target").
    Replace("- Horizon: <YYYY-MM-DD>", "- Horizon: $horizon")
  Set-Content -LiteralPath (Join-Path $projectDir "HANDOFF.md") -Value $handoffText -Encoding utf8

  $reviewText = (Get-Content -LiteralPath (Join-Path $repo "templates/HANDOFF-REVIEW.json") -Raw).
    Replace("<PROJECT-CODE>", $ProjectCode).
    Replace('"handoff_target": "<demo | pilot | production | internal>"', """handoff_target"": ""$Target""")
  Set-Content -LiteralPath (Join-Path $projectDir "HANDOFF-REVIEW.json") -Value $reviewText -Encoding utf8
}

Write-Host "Created $Mode project ($ExecutionPath): $projectDir"
Write-Host ""
Write-Host "Draft validation:"
# "Continue" around the child process: this script sets ErrorActionPreference
# to Stop, and Windows PowerShell 5.1 turns a child's stderr into a
# terminating error under Stop (docs/architecture/powershell-portability.md
# section 1). A draft project is *expected* to fail validation, so anything the
# validator writes to stderr here would abort project creation at the last
# step -- after the files were already written.
$previousEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/validate-project.ps1") -ProjectPath $projectDir -Mode $Mode -Gate Draft
  $draftExitCode = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $previousEap
}
Write-Host ""
Write-Host "Next actions:"
Write-Host "1. Add source files under source/MOM, source/REQ, or source/Transcript."
Write-Host "2. Run scripts/update-source-snapshot.ps1 -ProjectPath $projectDir after adding sources."
Write-Host "3. Replace remaining draft placeholders before Scope/Release gates."
if ($IncludeHandoff) {
  Write-Host "4. Fill HANDOFF.md and DESIGN/BUILD-SPEC.md, then record the review:"
  Write-Host "   scripts/handoff-digest.ps1 -ProjectPath $projectDir   (records BOTH digests in HANDOFF-REVIEW.json)"
  Write-Host "   scripts/validate-project.ps1 -ProjectPath $projectDir -Mode $Mode -Gate Handoff"
  Write-Host "   scripts/assess-handoff.ps1 -ProjectPath $projectDir -Mode $Mode"
}

if ($draftExitCode -ne 0) {
  exit $draftExitCode
}
exit 0
