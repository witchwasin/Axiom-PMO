# Marker-block probe harness: runs one marker-block function with a JSON
# hashtable of named args (from a file), returns normalized JSON output with
# lowercase keys so TS can compare field-by-field.
param(
  [string]$Fn,
  [string]$ArgsPath
)

. (Join-Path $PSScriptRoot "../../scripts/lib/marker-block.ps1")

$named = (Get-Content -LiteralPath $ArgsPath -Raw | ConvertFrom-Json -AsHashtable)
$result = & $Fn @named

if ($null -eq $result) {
  Write-Output "null"
  exit 0
}

if ($result -is [string]) {
  Write-Output ($result | ConvertTo-Json -Compress)
  exit 0
}

# Normalize PSCustomObject keys to lowercase for field-level comparison.
$out = [ordered]@{}
foreach ($prop in $result.PSObject.Properties) {
  $out[$prop.Name.ToLowerInvariant()] = $prop.Value
}
Write-Output ($out | ConvertTo-Json -Compress -Depth 6)
