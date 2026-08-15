# Phase 0 helper — capture DOCTOR-002 and DOCTOR-004 goldens.
#
# These are framework self-audit rules: DOCTOR-002 fires when CLAUDE.md/AGENTS.md names
# an archived legacy skill; DOCTOR-004 fires when an active skill contains a legacy rule
# pattern. They cannot fire on a healthy checkout, so this script copies the repo to a
# temp dir (same pattern as tests/helpers/m2-m3-tests.ps1), injects the two regression
# signals, and captures one doctor run that exercises both.
param([string]$RepoPath = ".")

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "../../scripts/lib/golden-normalizer.ps1")
. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$goldenDir = Join-Path $repo "tests/golden"
New-Item -ItemType Directory -Force -Path $goldenDir | Out-Null
$pwshExe = Get-PowerShellHost
if (-not $pwshExe) { Write-Host (Get-PowerShellHostMissingMessage); exit 127 }

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-doctor-legacy-" + [System.Guid]::NewGuid().ToString("N"))
$tempRepo = Join-Path $work "repo"
try {
  New-Item -ItemType Directory -Force -Path $tempRepo | Out-Null
  foreach ($item in Get-ChildItem -LiteralPath $repo -Force) {
    if ($item.Name -eq ".git") { continue }
    Copy-Item -LiteralPath $item.FullName -Destination $tempRepo -Recurse -Force
  }

  # DOCTOR-002: name an archived legacy skill in CLAUDE.md.
  Add-Content -LiteralPath (Join-Path $tempRepo "CLAUDE.md") -Value "`nReference to archived pmo-gap-analysis skill.`n" -NoNewline

  # DOCTOR-004: an active skill contains a legacy rule pattern. skill-manifest.json
  # lists the active skill ids; inject "SystemFlow" into one active skill's markdown.
  $manifest = Get-Content -LiteralPath (Join-Path $tempRepo "pmo-config/skill-manifest.json") -Raw | ConvertFrom-Json
  $targetSkill = $manifest.active_skills[0].id
  $skillRoot = Join-Path $tempRepo ".claude/skills"
  $targetDir = Join-Path $skillRoot $targetSkill
  if (Test-Path -LiteralPath $targetDir -PathType Container) {
    $md = @(Get-ChildItem -LiteralPath $targetDir -Filter *.md -Recurse -File -ErrorAction SilentlyContinue)[0]
    if ($md) { Add-Content -LiteralPath $md.FullName -Value "`nSystemFlow legacy reference`n" -NoNewline }
  }

  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $output = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/pmo-doctor.ps1") -RepoPath $tempRepo 2>&1
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prev

  $raw = (($output | Out-String).TrimEnd()) + "`nEXIT_CODE=$code"
  $raw = $raw.Replace($tempRepo, '<REPO_ROOT>')
  Set-Content -LiteralPath (Join-Path $goldenDir "doctor-legacy.txt") -Value (Get-CanonicalGoldenText -Text $raw) -NoNewline -Encoding utf8
  Write-Host "Captured doctor-legacy.txt (EXIT_CODE=$code)"
} finally {
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
exit 0
