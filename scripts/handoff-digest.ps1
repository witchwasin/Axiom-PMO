param(
  [Parameter(Mandatory = $true)]
  [Alias("Project")]
  [string]$ProjectPath,

  [ValidateSet("Both", "Source", "ReviewInputs")]
  [string]$Which = "Both"
)

# Prints the freshness digests a semantic review must record.
#
# HANDOFF-REVIEW.json carries two, because a review goes stale two different
# ways:
#
#   source_snapshot   the material the requirements came from changed
#   review_inputs     a governed artifact the reviewer read changed
#
# Hashing only the first would let someone rewrite the build sequence or waive a
# build-spec section after review and keep a clean bill of health.
#
#   pwsh -File scripts/handoff-digest.ps1 -ProjectPath examples/HANDOFF-DEMO

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/config-loader.ps1")
. (Join-Path $PSScriptRoot "lib/markdown-table-parser.ps1")
. (Join-Path $PSScriptRoot "lib/reference-resolver.ps1")
. (Join-Path $PSScriptRoot "lib/handoff-validator.ps1")

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$projectFile = Join-Path $project "PROJECT.md"
if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
  Write-Error "No PROJECT.md found: $projectFile"
  exit 1
}

$cfg = Import-PmoConfig -RepoRoot $repoRoot
$handoffPolicy = $cfg.HandoffPolicy

# Explicit UTF-8 on the recording side too. This script prints the digest a
# review must record; if it decoded differently from the validator that later
# checks it, every review recorded on one host would read as stale on another.
# See powershell-portability.md section 7.
$sourceDigest = Get-SourceSnapshotDigest -ProjectText (Get-Content -LiteralPath $projectFile -Raw -Encoding UTF8)
if (-not $sourceDigest) {
  Write-Error "PROJECT.md has no Source Snapshot or Source Inventory table to digest."
  exit 1
}
$inputDigest = Get-ReviewInputDigest -Project $project -HandoffPolicy $handoffPolicy

switch ($Which) {
  "Source" { Write-Output $sourceDigest }
  "ReviewInputs" { Write-Output $inputDigest }
  default {
    Write-Output "source_snapshot.digest : $sourceDigest"
    Write-Output "review_inputs.digest   : $inputDigest"
  }
}
exit 0
