param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectCode,

  [ValidateSet("Lite", "Standard", "Strict")]
  [string]$Mode = "Standard",

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
$defaultDesignRef = if ($Mode -eq "Lite") { "not_required" } else { "DESIGN/FLOW.puml" }
$deliveryText = $deliveryText -replace '\| D-001 \| Standard \| none \| normal feature \| PM \| <feature> \| REQ-001 \| DESIGN/FLOW\.puml \|', "| D-001 | $Mode | none | normal feature | PM | <feature> | REQ-001 | $defaultDesignRef |"
Set-Content -LiteralPath $deliveryFile -Value $deliveryText -Encoding utf8

function Copy-TemplateWithProjectCode {
  param([string]$SourcePath, [string]$DestPath)
  $text = (Get-Content -LiteralPath $SourcePath -Raw).Replace("<PROJECT-CODE>", $ProjectCode)
  Set-Content -LiteralPath $DestPath -Value $text -Encoding utf8
}

if ($Mode -ne "Lite") {
  New-Item -ItemType Directory -Force -Path (Join-Path $projectDir "DESIGN") | Out-Null
  Copy-TemplateWithProjectCode (Join-Path $repo "templates/RELEASE.md") (Join-Path $projectDir "RELEASE.md")
  Copy-TemplateWithProjectCode (Join-Path $repo "templates/WIREFRAME.md") (Join-Path $projectDir "DESIGN/WIREFRAME.md")
  @"
@startuml
start
:Define $ProjectCode flow;
stop
@enduml
"@ | Set-Content -LiteralPath (Join-Path $projectDir "DESIGN/FLOW.puml") -Encoding utf8
}

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

  if ($Mode -ne "Lite") {
    Copy-TemplateWithProjectCode (Join-Path $repo "templates/BUILD-SPEC.md") (Join-Path $projectDir "DESIGN/BUILD-SPEC.md")
  }

  $reviewText = (Get-Content -LiteralPath (Join-Path $repo "templates/HANDOFF-REVIEW.json") -Raw).
    Replace("<PROJECT-CODE>", $ProjectCode).
    Replace('"handoff_target": "<demo | pilot | production | internal>"', """handoff_target"": ""$Target""")
  Set-Content -LiteralPath (Join-Path $projectDir "HANDOFF-REVIEW.json") -Value $reviewText -Encoding utf8
}

Write-Host "Created $Mode project: $projectDir"
Write-Host ""
Write-Host "Draft validation:"
& $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/validate-project.ps1") -ProjectPath $projectDir -Mode $Mode -Gate Draft
$draftExitCode = $LASTEXITCODE
Write-Host ""
Write-Host "Next actions:"
Write-Host "1. Add source files under source/MOM, source/REQ, or source/Transcript."
Write-Host "2. Run scripts/update-source-snapshot.ps1 -ProjectPath $projectDir after adding sources."
Write-Host "3. Replace remaining draft placeholders before Scope/Release gates."
if ($IncludeHandoff) {
  Write-Host "4. Fill HANDOFF.md and DESIGN/BUILD-SPEC.md, then record the review:"
  Write-Host "   scripts/handoff-digest.ps1 -ProjectPath $projectDir   (paste into HANDOFF-REVIEW.json source_snapshot.digest)"
  Write-Host "   scripts/validate-project.ps1 -ProjectPath $projectDir -Mode $Mode -Gate Handoff"
  Write-Host "   scripts/assess-handoff.ps1 -ProjectPath $projectDir -Mode $Mode"
}

if ($draftExitCode -ne 0) {
  exit $draftExitCode
}
exit 0
