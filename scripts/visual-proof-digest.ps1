param(
  [Parameter(Mandatory = $true)]
  [Alias("Project")]
  [string]$ProjectPath
)

# Prints the digest a current Visual Proof review must record.
#
# The digest binds the selected direction, design-system Markdown and HTML,
# brand assets, and the committed desktop/mobile captures. It intentionally
# excludes VISUAL-REVIEW.json itself, so writing the review does not make it
# stale. The digest proves that those local files are the same ones the review
# named; it cannot prove how a screenshot was produced or rate what it shows.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/config-loader.ps1")
. (Join-Path $PSScriptRoot "lib/visual-proof-validator.ps1")

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$cfg = Import-PmoConfig -RepoRoot $repoRoot
$proof = $cfg.HandoffPolicy.visual_proof
if (-not $proof) {
  Write-Error "handoff-policy.json has no visual_proof policy."
  exit 1
}
if (-not (Test-VisualProofActivated -Project $project -VisualProofPolicy $proof)) {
  Write-Error "Visual Proof is inactive: the project does not contain all configured creative artifacts."
  exit 1
}

Write-Output (Get-VisualProofReviewInputDigest -Project $project -VisualProofPolicy $proof)
exit 0
