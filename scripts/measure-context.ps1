param(
  [string[]]$Files = @("AGENTS.md", "CLAUDE.md", "CONTEXT-ROUTER.md", "pmo-config/context-map.json", "pmo-config/policy.json")
)

$ErrorActionPreference = "Stop"

$repo = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")

# Maintainer-only: audits the framework's own checkout, so it fails with a
# diagnostic rather than a raw exception when run from a packaged install.
. (Join-Path $PSScriptRoot "lib/framework-checkout.ps1")
Assert-FrameworkCheckout -Root ([string]$repo) -ToolName "measure-context" -Alternative "scripts/validate-project.ps1 -ProjectPath <your project>"
$rows = @()

foreach ($relative in $Files) {
  $path = Join-Path $repo $relative
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
  $text = Get-Content -LiteralPath $path -Raw
  $words = @($text -split "\s+" | Where-Object { $_.Length -gt 0 }).Count
  $rows += [pscustomobject]@{
    File = $relative
    Lines = @($text -split "`r?`n").Count
    Words = $words
    EstimatedContextSize = [Math]::Ceiling($words * 1.35)
  }
}

$rows | Format-Table -AutoSize
Write-Host ""
Write-Host "Estimated Context Size is an approximation, not a tokenizer measurement."
