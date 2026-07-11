param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path -LiteralPath $ProjectPath
$project = $root.Path
$projectFile = Join-Path $project "PROJECT.md"
$sourceRoot = Join-Path $project "source"

if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
  throw "No PROJECT.md found: $projectFile"
}
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
  throw "No source directory found: $sourceRoot"
}

$syncedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$rows = @()
foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File) {
  $relative = $file.FullName.Substring($project.Length).TrimStart("\", "/") -replace "\\", "/"
  $name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
  $sourceId = $name
  if ($name -match '(MOM|REQ|TR)[-_]?(\d{8}|V\d+)') {
    $prefix = $Matches[1]
    $suffix = $Matches[2]
    $sourceId = "$prefix-$suffix"
  } elseif ($name -match '(\d{8}).*(MOM|REQ|TR)') {
    $prefix = $Matches[2]
    $suffix = $Matches[1]
    $sourceId = "$prefix-$suffix"
  }
  $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  $rows += [pscustomobject]@{
    SourceId = $sourceId
    Version = "v1"
    SHA256 = $hash
    SyncedAt = $syncedAt
    Relative = $relative
  }
}

$table = New-Object System.Collections.Generic.List[string]
$table.Add("| Source ID | Version / Date | SHA256 | Last Synced At |") | Out-Null
$table.Add("|---|---|---|---|") | Out-Null
foreach ($row in ($rows | Sort-Object SourceId, Relative)) {
  $table.Add("| $($row.SourceId) | $($row.Version) | $($row.SHA256) | $($row.SyncedAt) |") | Out-Null
}
$replacement = "## Source Snapshot`r`n`r`n" + (($table.ToArray()) -join "`r`n") + "`r`n"

$text = Get-Content -LiteralPath $projectFile -Raw
if ($text -notmatch '(?s)## Source Snapshot.*?(?=\r?\n## )') {
  throw "PROJECT.md has no Source Snapshot section to update."
}
$updated = [regex]::Replace($text, '(?s)## Source Snapshot.*?(?=\r?\n## )', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement }, 1)

if ($DryRun) {
  Write-Host $replacement
  exit 0
}

$backup = "$projectFile.bak"
Copy-Item -LiteralPath $projectFile -Destination $backup -Force
Set-Content -LiteralPath $projectFile -Value $updated -Encoding utf8
Write-Host "Updated Source Snapshot in $projectFile"
Write-Host "Backup written to $backup"
