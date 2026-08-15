# Phase 0 helper — capture pmo-doctor output as a golden master.
#
# pmo-doctor emits DOCTOR-*, PERMISSION-*, and TABLE-001 rule ids as Text (not the
# JSON the validator emits), so it is captured here rather than through
# run-validation-tests.ps1's $cases loop. The same canonical normalizer and
# <REPO_ROOT> path replacement are applied so the golden is portable across machines.
param([string]$RepoPath = ".")

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../../scripts/lib/golden-normalizer.ps1")
. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$exe = Get-PowerShellHost
if (-not $exe) { Write-Host (Get-PowerShellHostMissingMessage); exit 127 }
$goldenDir = Join-Path $repo "tests/golden"
New-Item -ItemType Directory -Force -Path $goldenDir | Out-Null

$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$output = & $exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/pmo-doctor.ps1") -RepoPath $repo 2>&1
$exit = $LASTEXITCODE
$ErrorActionPreference = $prevEAP

$raw = (($output | Out-String).TrimEnd()) + "`nEXIT_CODE=$exit"
$raw = $raw.Replace($repo, '<REPO_ROOT>')
Set-Content -LiteralPath (Join-Path $goldenDir "doctor-baseline.txt") -Value (Get-CanonicalGoldenText -Text $raw) -NoNewline -Encoding utf8
Write-Host "Captured doctor-baseline.txt (EXIT_CODE=$exit)"
exit 0
