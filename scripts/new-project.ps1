param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectCode,

  [ValidateSet("Lite", "Standard", "Strict")]
  [string]$Mode = "Standard",

  [string]$OutputRoot = "projects"
)

$ErrorActionPreference = "Stop"

$repo = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
  $targetRoot = $OutputRoot
} else {
  $targetRoot = Join-Path $repo $OutputRoot
}
$target = Join-Path $targetRoot $ProjectCode
$today = Get-Date -Format "yyyy-MM-dd"

if (Test-Path -LiteralPath $target) {
  throw "Project already exists: $target"
}

New-Item -ItemType Directory -Force -Path $target | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $target "source/REQ") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $target "source/MOM") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $target "source/Transcript") | Out-Null

Copy-Item -LiteralPath (Join-Path $repo "templates/PROJECT.md") -Destination (Join-Path $target "PROJECT.md")
Copy-Item -LiteralPath (Join-Path $repo "templates/DELIVERY.md") -Destination (Join-Path $target "DELIVERY.md")

$projectFile = Join-Path $target "PROJECT.md"
$deliveryFile = Join-Path $target "DELIVERY.md"
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
  New-Item -ItemType Directory -Force -Path (Join-Path $target "DESIGN") | Out-Null
  Copy-TemplateWithProjectCode (Join-Path $repo "templates/RELEASE.md") (Join-Path $target "RELEASE.md")
  Copy-TemplateWithProjectCode (Join-Path $repo "templates/WIREFRAME.md") (Join-Path $target "DESIGN/WIREFRAME.md")
  @"
@startuml
start
:Define $ProjectCode flow;
stop
@enduml
"@ | Set-Content -LiteralPath (Join-Path $target "DESIGN/FLOW.puml") -Encoding utf8
}

if ($Mode -eq "Strict") {
  Copy-TemplateWithProjectCode (Join-Path $repo "templates/RAID-log.md") (Join-Path $target "RAID-log.md")
  Copy-TemplateWithProjectCode (Join-Path $repo "templates/decision-log.md") (Join-Path $target "decision-log.md")
  Copy-TemplateWithProjectCode (Join-Path $repo "templates/RTM.json") (Join-Path $target "RTM.json")
}

Write-Host "Created $Mode project: $target"
Write-Host ""
Write-Host "Draft validation:"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/validate-project.ps1") -ProjectPath $target -Mode $Mode -Gate Draft
$draftExitCode = $LASTEXITCODE
Write-Host ""
Write-Host "Next actions:"
Write-Host "1. Add source files under source/MOM, source/REQ, or source/Transcript."
Write-Host "2. Run scripts/update-source-snapshot.ps1 -ProjectPath $target after adding sources."
Write-Host "3. Replace remaining draft placeholders before Scope/Release gates."

if ($draftExitCode -ne 0) {
  exit $draftExitCode
}
exit 0
