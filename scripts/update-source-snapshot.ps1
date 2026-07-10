param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path -LiteralPath $ProjectPath
$project = $root.Path
$sourceRoot = Join-Path $project "source"

if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
  throw "No source directory found: $sourceRoot"
}

$rows = @()
foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File) {
  $relative = $file.FullName.Substring($project.Length).TrimStart("\", "/")
  $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  $rows += [pscustomobject]@{
    Source = $relative
    LastWriteTime = $file.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssK")
    SHA256 = $hash
  }
}

$rows | Format-Table -AutoSize
Write-Host ""
Write-Host "Copy these values into PROJECT.md Source Snapshot. Source files were not modified."

