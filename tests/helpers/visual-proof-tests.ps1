param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

# Behaviour tests for Milestone 10 conditional Visual Proof evidence.
#
# The permanent fixtures deliberately stay free of Visual Proof so they retain
# their compatibility value. Each case below copies the already-valid Strict
# handoff fixture into an exact temporary directory, then adds only the
# optional creative artifact trio. The PNG files are deterministic test-only
# headers: this validator verifies a committed PNG signature/IHDR size and
# identity hash, not rendering provenance or visual quality.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")
. (Join-Path $PSScriptRoot "../../scripts/lib/config-loader.ps1")

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$fixture = Join-Path $repo "tests/fixtures/valid-handoff-strict"
$validateScript = Join-Path $repo "scripts/validate-project.ps1"
$digestScript = Join-Path $repo "scripts/visual-proof-digest.ps1"
$handoffDigestScript = Join-Path $repo "scripts/handoff-digest.ps1"
$cfg = Import-PmoConfig -RepoRoot $repo
$proofPolicy = $cfg.HandoffPolicy.visual_proof
$pass = 0
$fail = 0
$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-visual-proof-" + [System.Guid]::NewGuid().ToString("N"))

function Assert-True {
  param([string]$Name, [bool]$Condition, [string]$Detail = "")
  if ($Condition) {
    $script:pass++
    Write-Host "[PASS] $Name"
  } else {
    $script:fail++
    Write-Host "[FAIL] $Name$(if ($Detail) { " -- $Detail" })"
  }
}

function Write-Utf8File {
  param(
    [string]$Path,
    [string]$Text
  )

  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-VisualValidation {
  param([string]$ProjectPath)

  $childArgs = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $validateScript,
    "-ProjectPath", $ProjectPath, "-Mode", "Strict", "-Gate", "Handoff", "-Format", "Json"
  )
  # Native stderr must not become a terminating error on Windows PowerShell
  # 5.1. See docs/architecture/powershell-portability.md section 1.
  $previousEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & $pwshExe @childArgs 2>$null
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousEap
  }

  $raw = ($output | Out-String).Trim()
  if ([string]::IsNullOrWhiteSpace($raw)) {
    throw "Visual Proof test validator emitted no JSON (exit $exitCode)."
  }
  try {
    $document = $raw | ConvertFrom-Json
  } catch {
    throw "Visual Proof test validator emitted invalid JSON (exit $exitCode): $raw"
  }
  return [pscustomobject]@{ ExitCode = $exitCode; Document = $document }
}

function Invoke-VisualProofDigest {
  param([string]$ProjectPath)

  $childArgs = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $digestScript,
    "-ProjectPath", $ProjectPath
  )
  $previousEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & $pwshExe @childArgs 2>$null
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousEap
  }
  if ($exitCode -ne 0) {
    throw "visual-proof-digest.ps1 failed with exit $exitCode."
  }
  $digest = ($output | Out-String).Trim()
  if ($digest -notmatch '^[a-f0-9]{64}$') {
    throw "visual-proof-digest.ps1 returned an invalid digest '$digest'."
  }
  return $digest
}

function Invoke-HandoffReviewInputDigest {
  param([string]$ProjectPath)

  $childArgs = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $handoffDigestScript,
    "-ProjectPath", $ProjectPath, "-Which", "ReviewInputs"
  )
  $previousEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & $pwshExe @childArgs 2>$null
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousEap
  }
  if ($exitCode -ne 0) {
    throw "handoff-digest.ps1 failed with exit $exitCode."
  }
  $digest = ($output | Out-String).Trim()
  if ($digest -notmatch '^[a-f0-9]{64}$') {
    throw "handoff-digest.ps1 returned an invalid digest '$digest'."
  }
  return $digest
}

function Get-RuleHits {
  param(
    $Validation,
    [string]$RuleId,
    [string]$Level = ""
  )

  return @($Validation.Document.results | Where-Object {
    $_.rule_id -eq $RuleId -and ([string]::IsNullOrWhiteSpace($Level) -or $_.level -eq $Level)
  })
}

function Get-ValidationFailureSummary {
  param($Validation)

  $hits = @($Validation.Document.results | Where-Object { $_.level -eq "FAIL" })
  if ($hits.Count -eq 0) { return "none" }
  return (($hits | Select-Object -First 4 | ForEach-Object { "$($_.rule_id): $($_.message)" }) -join " | ")
}

function New-TestProject {
  $project = Join-Path $workRoot ("project-" + [System.Guid]::NewGuid().ToString("N"))
  Copy-Item -LiteralPath $fixture -Destination $project -Recurse -Force
  return $project
}

function Write-TestPngHeader {
  param(
    [string]$Path,
    [int]$Width,
    [int]$Height
  )

  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  # The validator's deterministic PNG check reads the PNG signature and IHDR
  # width/height. These bytes intentionally are not offered as a rendered UI.
  $bytes = New-Object byte[] 24
  [byte[]]$signature = 137, 80, 78, 71, 13, 10, 26, 10
  for ($index = 0; $index -lt $signature.Length; $index++) {
    $bytes[$index] = $signature[$index]
  }
  $bytes[8] = 0
  $bytes[9] = 0
  $bytes[10] = 0
  $bytes[11] = 13
  $bytes[12] = 73
  $bytes[13] = 72
  $bytes[14] = 68
  $bytes[15] = 82
  $bytes[16] = [byte](($Width -shr 24) -band 0xff)
  $bytes[17] = [byte](($Width -shr 16) -band 0xff)
  $bytes[18] = [byte](($Width -shr 8) -band 0xff)
  $bytes[19] = [byte]($Width -band 0xff)
  $bytes[20] = [byte](($Height -shr 24) -band 0xff)
  $bytes[21] = [byte](($Height -shr 16) -band 0xff)
  $bytes[22] = [byte](($Height -shr 8) -band 0xff)
  $bytes[23] = [byte]($Height -band 0xff)
  [System.IO.File]::WriteAllBytes($Path, $bytes)
}

function Add-VisualProofArtifacts {
  param([string]$ProjectPath)

  $design = Join-Path $ProjectPath "DESIGN"
  $direction = @(
    "# VISUAL DIRECTION - HANDOFF-DEMO",
    "",
    "## Status",
    "",
    "- stage: selected",
    "- direction_status: selected",
    "- selected_direction: VD-01 Workshop Signal",
    "- direction_decision_ref: DEC-002",
    "",
    "## Selected Direction",
    "",
    "Workshop Signal uses clear scan lanes and high-contrast state markers for the floor tablet."
  ) -join "`n"
  Write-Utf8File -Path (Join-Path $design "VISUAL-DIRECTION.md") -Text ($direction + "`n")

  $system = @(
    "# DESIGN-SYSTEM - HANDOFF-DEMO",
    "",
    "## Status",
    "",
    "- direction_status: selected",
    "- direction_decision_ref: DEC-002",
    "",
    "## Design Tokens - Color",
    "",
    "| Token | Value | Role |",
    "|---|---|---|",
    "| color-ink-900 | #111827 | tablet headings and labels |",
    "| color-signal-500 | #0F766E | confirmed scan state |"
  ) -join "`n"
  Write-Utf8File -Path (Join-Path $design "DESIGN-SYSTEM.md") -Text ($system + "`n")

  $sheet = @(
    "<!doctype html>",
    '<html lang="en">',
    '<head><meta charset="utf-8"><style>',
    ":root { --color-ink-900: #111827; --color-signal-500: #0F766E; }",
    "body { color: var(--color-ink-900); }",
    "</style></head>",
    '<body><main id="screen-examples"><h1>Workshop Signal</h1><p>Illustrative tablet sheet.</p></main></body>',
    "</html>"
  ) -join "`n"
  Write-Utf8File -Path (Join-Path $design "DESIGN-SYSTEM.html") -Text ($sheet + "`n")

  $decisionPath = Join-Path $ProjectPath "decision-log.md"
  $existingRaw = Get-Content -LiteralPath $decisionPath -Raw
  $existing = if ($null -eq $existingRaw) { "" } else { $existingRaw.TrimEnd([char[]]@("`r", "`n")) }
  $decision = "| DEC-007 | Named human reviewed the committed Visual Proof evidence. | The review records local artifact identity only. | REQ-20260714 row 1 | 2026-08-11 | Morgan Chen |"
  Write-Utf8File -Path $decisionPath -Text ($existing + "`n" + $decision + "`n")

  foreach ($capture in @($proofPolicy.captures)) {
    $relative = [string]$capture.path
    Write-TestPngHeader -Path (Join-Path $ProjectPath $relative) -Width ([int]$capture.min_width) -Height ([int]$capture.min_height)
  }

  # This existing Strict fixture carries a semantic handoff review whose input
  # digest includes decision-log.md. Adding DEC-007 is intentional, so reseal
  # that separate review against its actual input set before testing Visual
  # Proof. VISUAL-REVIEW.json is deliberately not part of that digest.
  $handoffReviewPath = Join-Path $ProjectPath "HANDOFF-REVIEW.json"
  $handoffReview = Get-Content -LiteralPath $handoffReviewPath -Raw | ConvertFrom-Json
  $handoffReview.review_inputs.digest = Invoke-HandoffReviewInputDigest -ProjectPath $ProjectPath
  Write-Utf8File -Path $handoffReviewPath -Text (($handoffReview | ConvertTo-Json -Depth 16) + "`n")
}

function New-VisualProofReview {
  param([string]$ProjectPath)

  $captures = @()
  foreach ($capture in @($proofPolicy.captures)) {
    $relative = [string]$capture.path
    $path = Join-Path $ProjectPath $relative
    $captures += [ordered]@{
      id = [string]$capture.id
      path = $relative
      sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
      viewport = [ordered]@{
        width = [int]$capture.min_viewport_width
        height = [int]$capture.min_viewport_height
      }
      captured_at = "2026-08-11T10:00:00Z"
      capture_method = "local_browser_screenshot"
    }
  }

  $rubric = @()
  foreach ($item in @($proofPolicy.rubric)) {
    $rubric += [ordered]@{
      id = [string]$item.id
      status = "reviewed"
      notes = "Named human reviewed this rubric item against the selected direction."
    }
  }

  $review = [ordered]@{
    schema_version = [string]$proofPolicy.schema_version
    project_code = "HANDOFF-DEMO"
    reviewed_at = "2026-08-11"
    reviewer_kind = "human"
    reviewer = "Morgan Chen, Product Design Lead"
    decision_ref = "DEC-007"
    visual_direction = [ordered]@{
      selected_direction = "VD-01 Workshop Signal"
      decision_ref = "DEC-002"
    }
    review_inputs = [ordered]@{
      digest = Invoke-VisualProofDigest -ProjectPath $ProjectPath
    }
    captures = $captures
    rubric = $rubric
    findings = @()
    recommendation = [ordered]@{
      status = "accepted"
      notes = "Named human reviewed the committed captures. This is candidate evidence, not approval."
    }
  }
  Write-Utf8File -Path (Join-Path $ProjectPath ([string]$proofPolicy.artifact)) -Text (($review | ConvertTo-Json -Depth 12) + "`n")
}

function New-VisualProofProject {
  $project = New-TestProject
  Add-VisualProofArtifacts -ProjectPath $project
  New-VisualProofReview -ProjectPath $project
  return $project
}

function Read-Review {
  param([string]$ProjectPath)
  return (Get-Content -LiteralPath (Join-Path $ProjectPath ([string]$proofPolicy.artifact)) -Raw | ConvertFrom-Json)
}

function Write-Review {
  param(
    [string]$ProjectPath,
    $Review
  )
  Write-Utf8File -Path (Join-Path $ProjectPath ([string]$proofPolicy.artifact)) -Text (($Review | ConvertTo-Json -Depth 12) + "`n")
}

Write-Host "Axiom-PMO Visual Proof Tests: $repo"
Write-Host ""

try {
  New-Item -ItemType Directory -Path $workRoot -Force | Out-Null

  $reviewerKinds = @($proofPolicy.reviewer_kinds | ForEach-Object { [string]$_ })
  Assert-True "Visual Proof policy requires human reviewer attestation only" `
    ($reviewerKinds.Count -eq 1 -and $reviewerKinds[0] -ceq "human") `
    ("reviewer_kinds=" + ($reviewerKinds -join ", "))

  # The unchanged valid handoff fixture proves the check is genuinely
  # conditional and does not retroactively require new artifacts.
  $legacy = New-TestProject
  $legacyRun = Invoke-VisualValidation -ProjectPath $legacy
  Assert-True "legacy handoff without the visual trio still passes" ($legacyRun.ExitCode -eq 0) "exit=$($legacyRun.ExitCode)"
  Assert-True "legacy handoff does not activate Visual Proof" ((Get-RuleHits -Validation $legacyRun -RuleId "VPROOF-001").Count -eq 0)

  $valid = New-VisualProofProject
  $validRun = Invoke-VisualValidation -ProjectPath $valid
  Assert-True "complete active Visual Proof passes the Handoff gate" ($validRun.ExitCode -eq 0) `
    "exit=$($validRun.ExitCode); $(Get-ValidationFailureSummary -Validation $validRun)"
  Assert-True "complete active Visual Proof reports evidence completeness" `
    (@(Get-RuleHits -Validation $validRun -RuleId "VPROOF-001" -Level "PASS").Count -eq 1)
  Assert-True "complete active Visual Proof reports current digest" `
    (@(Get-RuleHits -Validation $validRun -RuleId "VPROOF-002" -Level "PASS").Count -eq 1)

  $missingReview = New-VisualProofProject
  Remove-Item -LiteralPath (Join-Path $missingReview ([string]$proofPolicy.artifact)) -Force
  $missingReviewRun = Invoke-VisualValidation -ProjectPath $missingReview
  Assert-True "active Visual Proof without a manifest fails VPROOF-001" `
    (@(Get-RuleHits -Validation $missingReviewRun -RuleId "VPROOF-001" -Level "FAIL").Count -gt 0)

  $stale = New-VisualProofProject
  Add-Content -LiteralPath (Join-Path $stale "DESIGN/DESIGN-SYSTEM.html") -Value "<!-- reviewed sheet changed after capture -->"
  $staleRun = Invoke-VisualValidation -ProjectPath $stale
  Assert-True "changing a reviewed visual input fails VPROOF-002" `
    (@(Get-RuleHits -Validation $staleRun -RuleId "VPROOF-002" -Level "FAIL").Count -eq 1)

  $badHash = New-VisualProofProject
  $desktop = @($proofPolicy.captures | Where-Object { ([string]$_.id) -ceq "desktop" })[0]
  Add-Content -LiteralPath (Join-Path $badHash ([string]$desktop.path)) -Value "tampered" -NoNewline
  $badHashRun = Invoke-VisualValidation -ProjectPath $badHash
  $hashHits = @(Get-RuleHits -Validation $badHashRun -RuleId "VPROOF-001" -Level "FAIL" | Where-Object { $_.message -match "sha256" })
  Assert-True "changing a committed capture without resealing its hash fails VPROOF-001" ($hashHits.Count -eq 1)

  $wrongPath = New-VisualProofProject
  $wrongPathReview = Read-Review -ProjectPath $wrongPath
  $wrongPathDesktop = @($wrongPathReview.captures | Where-Object { ([string]$_.id) -ceq "desktop" })[0]
  $wrongPathDesktop.path = "DESIGN/VISUAL-PROOF/another-desktop.png"
  Write-Review -ProjectPath $wrongPath -Review $wrongPathReview
  $wrongPathRun = Invoke-VisualValidation -ProjectPath $wrongPath
  $pathHits = @(Get-RuleHits -Validation $wrongPathRun -RuleId "VPROOF-001" -Level "FAIL" | Where-Object { $_.message -match "path is not the required local path" })
  Assert-True "capture manifest path must bind to the policy's committed local path" ($pathHits.Count -eq 1)

  $aiReviewer = New-VisualProofProject
  $aiReview = Read-Review -ProjectPath $aiReviewer
  $aiReview.reviewer_kind = "ai"
  Write-Review -ProjectPath $aiReviewer -Review $aiReview
  $aiReviewerRun = Invoke-VisualValidation -ProjectPath $aiReviewer
  $aiHits = @(Get-RuleHits -Validation $aiReviewerRun -RuleId "VPROOF-001" -Level "FAIL" | Where-Object { $_.message -match "reviewer_kind" })
  Assert-True "AI reviewer attestation cannot satisfy named-human Visual Proof" ($aiHits.Count -eq 1)

  $unnamedDecisionOwner = New-VisualProofProject
  $decisionPath = Join-Path $unnamedDecisionOwner "decision-log.md"
  $logRaw = Get-Content -LiteralPath $decisionPath -Raw
  $log = if ($null -eq $logRaw) { "" } else { $logRaw }
  Write-Utf8File -Path $decisionPath -Text ($log.Replace("| Morgan Chen |", "| Team |"))
  $unnamedDecisionRun = Invoke-VisualValidation -ProjectPath $unnamedDecisionOwner
  $authorityHits = @(Get-RuleHits -Validation $unnamedDecisionRun -RuleId "VPROOF-001" -Level "FAIL" | Where-Object { $_.message -match "decision owner" })
  Assert-True "Visual Proof decision declaration requires a named human owner" ($authorityHits.Count -eq 1)
} finally {
  if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"
if ($fail -gt 0) { exit 1 }
exit 0
