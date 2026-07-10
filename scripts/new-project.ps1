param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectCode,

  [ValidateSet("Lite", "Standard", "Strict")]
  [string]$Mode = "Standard",

  [string]$OutputRoot = "projects"
)

$ErrorActionPreference = "Stop"

$repo = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
$targetRoot = Join-Path $repo $OutputRoot
$target = Join-Path $targetRoot $ProjectCode

if (Test-Path -LiteralPath $target) {
  throw "Project already exists: $target"
}

New-Item -ItemType Directory -Force -Path $target | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $target "source/REQ") | Out-Null

Copy-Item -LiteralPath (Join-Path $repo "templates/PROJECT.md") -Destination (Join-Path $target "PROJECT.md")
Copy-Item -LiteralPath (Join-Path $repo "templates/DELIVERY.md") -Destination (Join-Path $target "DELIVERY.md")

if ($Mode -ne "Lite") {
  New-Item -ItemType Directory -Force -Path (Join-Path $target "DESIGN") | Out-Null
  Copy-Item -LiteralPath (Join-Path $repo "templates/RELEASE.md") -Destination (Join-Path $target "RELEASE.md")
}

if ($Mode -eq "Strict") {
  Copy-Item -LiteralPath (Join-Path $repo "templates/RAID-log.md") -Destination (Join-Path $target "RAID-log.md")
  Copy-Item -LiteralPath (Join-Path $repo "templates/decision-log.md") -Destination (Join-Path $target "decision-log.md")
  Copy-Item -LiteralPath (Join-Path $repo "templates/RTM.yaml") -Destination (Join-Path $target "RTM.yaml")
}

Write-Host "Created $Mode project: $target"

