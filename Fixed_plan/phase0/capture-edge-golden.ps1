# Phase 0 helper — capture the remaining validator edge-case goldens:
#   MODE-002 (unrecognized default mode), RESEARCH-001 (unrecognized research mode),
#   DPROV-001 (unrecognized UI delivery), CHANGE-003 (blocking unresolved change),
#   VPROOF-001/002 (visual proof, via DESIGN-SYSTEM-DEMO at Handoff gate).
param([string]$RepoPath = ".")

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "../../scripts/lib/golden-normalizer.ps1")
. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$validator = Join-Path $repo "scripts/validate-project.ps1"
$goldenDir = Join-Path $repo "tests/golden"
New-Item -ItemType Directory -Force -Path $goldenDir | Out-Null
$pwshExe = Get-PowerShellHost
if (-not $pwshExe) { Write-Host (Get-PowerShellHostMissingMessage); exit 127 }

function Capture {
  param([string]$Name, [string[]]$ScriptArgs, [string]$StripPath = "")
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $output = & $pwshExe @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $validator) @ScriptArgs 2>$null
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prev
  $raw = (($output | Out-String).TrimEnd()) + "`nEXIT_CODE=$code"
  if ($StripPath) { $raw = $raw.Replace($StripPath, '<REPO_ROOT>') }
  Set-Content -LiteralPath (Join-Path $goldenDir "$Name.txt") -Value (Get-CanonicalGoldenText -Text $raw) -NoNewline -Encoding utf8
  Write-Host "Captured $Name.txt"
}

# --- MODE-002 + RESEARCH-001 + DPROV-001: one fixture with bogus declarations ---
$dir = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-edge-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $dir -Force | Out-Null
try {
  $projectMd = @(
    "# P99-EDGE", "",
    "> Default mode: SuperStrict", "",
    "> Research mode: turbo", "",
    "> UI delivery: hologram", ""
  ) -join "`n"
  Set-Content -LiteralPath (Join-Path $dir "PROJECT.md") -Value $projectMd -NoNewline
  Set-Content -LiteralPath (Join-Path $dir "DELIVERY.md") -Value "# DELIVERY - P99-EDGE" -NoNewline
  Set-Content -LiteralPath (Join-Path $dir "decision-log.md") -Value "# Decision Log" -NoNewline
  Capture "mode-002-research-001-dprov-001" @("-ProjectPath", $dir, "-Mode", "Standard", "-Gate", "Draft", "-Format", "Json") $dir
} finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }

# --- CHANGE-003: blocking "scope" classification, unresolved, at Handoff gate ---
# HANDOFF-DEMO already carries the In Scope table (REQ-001), DELIVERY.md, and
# DESIGN/BUILD-SPEC.md the change-control validator needs; copy it out of the repo
# so the shipped example is not mutated, then add a blocking unresolved change.
$dir = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-change-" + [System.Guid]::NewGuid().ToString("N"))
try {
  Copy-Item -LiteralPath (Join-Path $repo "examples/HANDOFF-DEMO") -Destination $dir -Recurse -Force
  $change = @{
    schema_version = "1.0"
    changes = @(
      @{ id = "CR-001"; detected_at = "2026-08-14T10:00:00Z"; source = "implementation"
         classification = "scope"; summary = "Unresolved scope change"
         reason = "fixture"; affected_requirements = @("REQ-001"); affected_artifacts = @("DESIGN/BUILD-SPEC.md")
         scope_impact = $true; acceptance_impact = $false; mode_impact = "none"
         status = "proposed"; owner = "Demo Tech Lead"; decision_ref = "" }
    )
  }
  Set-Content -LiteralPath (Join-Path $dir "CHANGE-REQUESTS.json") -Value ($change | ConvertTo-Json -Depth 12) -NoNewline
  Capture "change-003" @("-ProjectPath", $dir, "-Mode", "Standard", "-Gate", "Handoff", "-Format", "Json") $dir
} finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }

# --- VPROOF-001/002: DESIGN-SYSTEM-DEMO at Handoff (valid review -> both PASS) ---
Capture "vproof-001-002" @("-ProjectPath", (Join-Path $repo "examples/DESIGN-SYSTEM-DEMO"), "-Mode", "Standard", "-Gate", "Handoff", "-Format", "Json", "-FailOnWarning") $repo

exit 0
