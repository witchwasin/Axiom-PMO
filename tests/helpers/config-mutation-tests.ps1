param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

function Invoke-ExpectFailure {
  param(
    [string]$Name,
    [scriptblock]$Command
  )

  & $Command | Out-Host
  $code = $LASTEXITCODE
  if ($code -eq 0) {
    throw "$Name did not fail after config mutation"
  }
  Write-Host "[PASS] $Name failed as expected with exit $code"
}

$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pmo config mutation " + [guid]::NewGuid().ToString("N"))
$tempRepo = Join-Path $workRoot "repo"

try {
  New-Item -ItemType Directory -Force -Path $tempRepo | Out-Null
  foreach ($item in Get-ChildItem -LiteralPath $RepoPath -Force) {
    if ($item.Name -eq ".git") { continue }
    Copy-Item -LiteralPath $item.FullName -Destination $tempRepo -Recurse -Force
  }

  $policyPath = Join-Path $tempRepo "pmo-config/policy.json"
  $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
  $policy.enums.statuses = @($policy.enums.statuses | Where-Object { $_ -ne "Done" })
  $policy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $policyPath -Encoding utf8

  Invoke-ExpectFailure "policy enum mutation" {
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/validate-project.ps1") -ProjectPath (Join-Path $tempRepo "tests/fixtures/valid-standard") -Mode Standard -Gate Release
  }

  $skillManifestPath = Join-Path $tempRepo "pmo-config/skill-manifest.json"
  $manifest = Get-Content -LiteralPath $skillManifestPath -Raw | ConvertFrom-Json
  $manifest.active_skills = @($manifest.active_skills | Where-Object { $_.id -ne "pmo-intake" })
  $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $skillManifestPath -Encoding utf8

  Invoke-ExpectFailure "skill manifest mutation" {
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/pmo-doctor.ps1") -RepoPath $tempRepo
  }

  Write-Host "[PASS] Config mutation tests prove JSON runtime config is source of truth"
} finally {
  if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force
  }
}
