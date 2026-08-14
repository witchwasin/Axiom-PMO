param(
  [Parameter(Mandatory = $true)]
  [Alias("Project")]
  [string]$ProjectPath
)

# Prints the digests the Claude Design workflow must record, following the
# same conventions as scripts/handoff-digest.ps1:
#
#   per-input SHA-256   -- current hash of each canonical input, so the
#                         INPUT-MANIFEST.json input rows can be updated
#   combined_digest     -- SHA-256 of the sorted "path|sha256" lines over the
#                         manifest's declared inputs
#   outputs_digest      -- SHA-256 of the current DESIGN/CLAUDE-DESIGN/OUTPUT/
#                         file set, for REVIEW.json's preflight record
#
# Recompute whenever an input changes (manifest) or output changes (review).
#
#   pwsh -File scripts/design-provider-digest.ps1 -ProjectPath <project>

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/config-loader.ps1")
. (Join-Path $PSScriptRoot "lib/ordinal-sort.ps1")
. (Join-Path $PSScriptRoot "lib/handoff-validator.ps1")
. (Join-Path $PSScriptRoot "lib/artifact-hash.ps1")
. (Join-Path $PSScriptRoot "lib/design-provider-validator.ps1")

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$project = (Resolve-Path -LiteralPath $ProjectPath).Path

$cfg = Import-PmoConfig -RepoRoot $repoRoot
$orchestrationPolicy = $cfg.OrchestrationPolicy

$manifestPath = Get-DesignProviderManifestPath -Project $project -OrchestrationPolicy $orchestrationPolicy
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
  Write-Error "No input manifest found: $manifestPath"
  exit 1
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$inputs = @($manifest.inputs)

# Current per-input hashes, in declared order so the rows can be copied back.
foreach ($input in $inputs) {
  $relative = [string]$input.path
  $full = Join-Path $project $relative
  if (Test-Path -LiteralPath $full -PathType Leaf) {
    $hash = Get-ArtifactSha256 -Path $full
  } else {
    $hash = "MISSING"
  }
  Write-Output "input: $relative -> $hash"
}

# Combined digest from the CURRENT input set (sorted), so the manifest's
# combined_digest can be refreshed after any change.
$currentInputs = @()
foreach ($input in $inputs) {
  $relative = [string]$input.path
  $full = Join-Path $project $relative
  $hash = if (Test-Path -LiteralPath $full -PathType Leaf) { Get-ArtifactSha256 -Path $full } else { "MISSING" }
  $currentInputs += [pscustomobject]@{ path = $relative; sha256 = $hash }
}
Write-Output "combined_digest: $(Get-DesignInputCombinedDigest -Inputs $currentInputs)"

$outputRoot = Get-DesignProviderOutputRoot -Project $project -OrchestrationPolicy $orchestrationPolicy
Write-Output "outputs_digest: $(Get-DesignOutputSetDigest -OutputRoot $outputRoot)"

# Per-output hashes, for REVIEW.json's declared output inventory. Paths are
# relative to OUTPUT/ and sorted so the rows can be copied back in order.
if (Test-Path -LiteralPath $outputRoot) {
  $prefix = (Resolve-Path -LiteralPath $outputRoot).Path
  foreach ($file in (Get-ChildItem -LiteralPath $outputRoot -Recurse -File -ErrorAction SilentlyContinue | Sort-Object FullName)) {
    $relative = $file.FullName.Substring($prefix.Length).TrimStart([char]92, [char]47) -replace '\\', '/'
    $hash = Get-ArtifactSha256 -Path $file.FullName
    Write-Output "output: $relative -> $hash"
  }
}

exit 0
