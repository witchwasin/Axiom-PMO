param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")
$pwshExe = Get-PowerShellHost
if (-not $pwshExe) { Write-Host (Get-PowerShellHostMissingMessage); exit 127 }

function Invoke-ValidationJson {
  param([string]$Repo, [string]$Project, [string]$Mode, [string]$Gate)
  $output = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Repo "scripts/validate-project.ps1") -ProjectPath $Project -Mode $Mode -Gate $Gate -Format Json
  $code = $LASTEXITCODE
  $json = $null
  try { $json = ($output | Out-String) | ConvertFrom-Json } catch { throw "Validation did not return JSON (exit $code): $($output | Out-String)" }
  return [pscustomobject]@{ ExitCode = $code; Json = $json; Text = ($output | Out-String) }
}

function Assert-Rule {
  param($Result, [string]$Rule, [string]$Name)
  $hit = @($Result.Json.results | Where-Object { $_.rule_id -eq $Rule -and $_.level -eq "FAIL" })
  if ($hit.Count -eq 0) { throw "$Name did not emit expected FAIL $Rule (exit $($Result.ExitCode)).`n$($Result.Text)" }
  Write-Host "[PASS] $Name -> $Rule"
}

function Assert-NoRule {
  param($Result, [string]$Rule, [string]$Name)
  $hit = @($Result.Json.results | Where-Object { $_.rule_id -eq $Rule -and $_.level -eq "FAIL" })
  if ($hit.Count -gt 0) { throw "$Name unexpectedly emitted FAIL $Rule.`n$($Result.Text)" }
  Write-Host "[PASS] $Name has no FAIL $Rule"
}

function Assert-Clean {
  param($Result, [string]$Name)
  $fails = @($Result.Json.results | Where-Object { $_.level -eq "FAIL" })
  if ($fails.Count -gt 0) { throw "$Name expected a clean run but got FAILs: $($fails.rule_id -join ', ')`n$($Result.Text)" }
  Write-Host "[PASS] $Name is clean"
}

$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pmo m4-m6 " + [guid]::NewGuid().ToString("N"))
$tempRepo = Join-Path $workRoot "repo"
try {
  New-Item -ItemType Directory -Force -Path $tempRepo | Out-Null
  foreach ($item in Get-ChildItem -LiteralPath $RepoPath -Force) {
    if ($item.Name -eq ".git") { continue }
    Copy-Item -LiteralPath $item.FullName -Destination $tempRepo -Recurse -Force
  }

  $active = Join-Path $tempRepo "examples/OPTIONAL-TRACKS"
  $legacy = Join-Path $tempRepo "examples/HANDOFF-DEMO"

  # Positive control: the canonical example is clean at Design and Scope.
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Clean $result "OPTIONAL-TRACKS Design gate"
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Scope"
  Assert-Clean $result "OPTIONAL-TRACKS Scope gate"

  # Inactive tracks are silent: HANDOFF-DEMO has no declarations and no
  # optional artifacts, so none of the M4-M6 rules may fire.
  $result = Invoke-ValidationJson $tempRepo $legacy "Standard" "Design"
  Assert-NoRule $result "EXT-001" "legacy externalization silent"
  Assert-NoRule $result "RESEARCH-002" "legacy research silent"
  Assert-NoRule $result "DPROV-002" "legacy design provider silent"

  # Research off stays silent even when other artifacts exist.
  $offProject = Join-Path $tempRepo "examples/OPTIONAL-TRACKS"
  $offText = Get-Content -LiteralPath (Join-Path $offProject "PROJECT.md") -Raw
  $offText = $offText -replace '(?m)^> Research mode: guided\s*$', '> Research mode: off'
  $offText = $offText -replace '(?m)^> Research provider: feyman\s*$', '> Research provider: none'
  Set-Content -LiteralPath (Join-Path $offProject "PROJECT.md") -Value $offText -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $offProject "Standard" "Design"
  Assert-NoRule $result "RESEARCH-002" "research off is silent"
  # Restore the guided/feyman declarations for the research contract tests below.
  $offText = (Get-Content -LiteralPath (Join-Path $offProject "PROJECT.md") -Raw) -replace '(?m)^> Research mode: off\s*$', '> Research mode: guided'
  $offText = $offText -replace '(?m)^> Research provider: none\s*$', '> Research provider: feyman'
  Set-Content -LiteralPath (Join-Path $offProject "PROJECT.md") -Value $offText -Encoding utf8

  # M4 -- Externalization structure, authority, scan honesty, freshness.
  $extPath = Join-Path $active "EXTERNALIZATION.json"
  $extDoc = Get-Content -LiteralPath $extPath -Raw | ConvertFrom-Json

  $extDoc.entries[0].classification = "Confidential"
  $extDoc.entries[0].decision_ref = ""
  $extDoc.entries[0].reviewer = "Dev Team"
  $extDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $extPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "EXT-002" "Confidential transfer without Human evidence"

  $extDoc.entries[0].classification = "Public"
  $extDoc.entries[0].status = "pending"
  $extDoc.entries[0].decision_ref = ""
  $extDoc.entries[0].reviewer = ""
  $extDoc.entries[0].human_review_required = $false
  $extDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $extPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "EXT-001" "entry with unrecognized status"

  # Scan honesty: declare clean while a secret pattern is present in an
  # outgoing artifact. The secret must never appear in diagnostics. The token
  # is assembled at runtime so the literal pattern never appears in this file
  # (the public-hygiene check scans source text).
  $secret = "ghp_" + "MUSTNOTECHO" + "12345678901234567890"
  $projectMd = Join-Path $active "PROJECT.md"
  Add-Content -LiteralPath $projectMd -Value "`nDiagnostic fixture: $secret" -Encoding utf8
  $newHash = (Get-FileHash -LiteralPath $projectMd -Algorithm SHA256).Hash.ToLowerInvariant()
  $extDoc = Get-Content -LiteralPath $extPath -Raw | ConvertFrom-Json
  $extDoc.entries[0].classification = "Internal"
  $extDoc.entries[0].status = "approved"
  $extDoc.entries[0].human_review_required = $true
  $extDoc.entries[0].reviewer = "Demo Tech Lead"
  $extDoc.entries[0].decision_ref = "DEC-003"
  $extDoc.entries[0].outgoing_artifacts = @([pscustomobject]@{ path = "PROJECT.md"; sha256 = $newHash })
  $extDoc.entries[0].scan_result = "clean"
  $extDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $extPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "EXT-003" "declared clean scan contradicts re-scan"
  if ($result.Text -match [regex]::Escape($secret)) { throw "EXT diagnostics echoed a detected secret value" }

  # Freshness: stale outgoing digest.
  $extDoc.entries[0].scan_result = "finding"
  $extDoc.entries[0].human_review_required = $true
  $extDoc.entries[0].outgoing_artifacts = @([pscustomobject]@{ path = "PROJECT.md"; sha256 = ("a" * 64) })
  $extDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $extPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "EXT-004" "stale externalization digest"

  # M5 -- Claude Design provider contract.
  $manifestPath = Join-Path $active "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json"
  $reviewPath = Join-Path $active "DESIGN/CLAUDE-DESIGN/REVIEW.json"
  $outputDir = Join-Path $active "DESIGN/CLAUDE-DESIGN/OUTPUT"

  # Stale manifest input digest.
  $manifestDoc = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  $manifestDoc.inputs[0].sha256 = ("b" * 64)
  $manifestDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "DPROV-003" "stale manifest input digest"

  # Missing externalization citation.
  $manifestDoc = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  $manifestDoc.externalization = "EXT-999"
  $manifestDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "DPROV-004" "manifest without approved externalization"

  # Review before preflight is rejected.
  $reviewDoc = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json
  $reviewDoc.preflight = $null
  $reviewDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reviewPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "DPROV-005" "review before preflight"

  # AI reviewer cannot mark Human acceptance.
  $reviewDoc = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json
  $reviewDoc.preflight = [pscustomobject]@{ status = "passed"; checked_at = "2026-08-14T10:15:00Z"; manifest_digest = "477a5cb59d8ad382b46a96404f8297ff18fcdc8a1ac3cdb459f2ddfc78c1f84c"; outputs_digest = "68710242a1030a108434d8472fc50fbe8b0aec0fd3d4de17d50343a14c8f2f83" }
  $reviewDoc.acceptance.reviewer_kind = "ai"
  $reviewDoc.acceptance.decision = "accepted"
  $reviewDoc.acceptance.decision_ref = "DEC-002"
  $reviewDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reviewPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "DPROV-006" "AI reviewer cannot mark acceptance"

  # Revision invalidates prior review: changing output makes acceptance stale.
  $reviewDoc = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json
  $reviewDoc.acceptance.reviewer_kind = "human"
  $reviewDoc.acceptance.decision = "accepted"
  $reviewDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reviewPath -Encoding utf8
  Add-Content -LiteralPath (Join-Path $outputDir "ui-direction.md") -Value "`nRevision note." -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "DPROV-005" "changed output invalidates recorded acceptance"

  # Technical finding routes to Change Control.
  Remove-Item -LiteralPath (Join-Path $active "CHANGE-REQUESTS.json") -Force
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "DPROV-007" "routed finding without change request"

  # Manifest missing at Handoff on a claude_design project.
  Remove-Item -LiteralPath $manifestPath -Force
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Handoff"
  Assert-Rule $result "DPROV-002" "claude_design project without input manifest at Handoff"

  # M6 -- Guided research contract.
  $researchReport = Join-Path $active "RESEARCH/RESEARCH.md"
  $provenancePath = Join-Path $active "RESEARCH/PROVENANCE.json"

  Remove-Item -LiteralPath $researchReport -Force
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Scope"
  Assert-Rule $result "RESEARCH-002" "guided research without report"

  $researchText = @"
# RESEARCH - OPTIONAL-TRACKS

## Research Status and Scope

Status: complete

## Problem and Research Questions

Question.

## Existing Solutions

Nothing.

## Feature Parity

None.

## Relevant Standards and Regulations

None.

## Differentiation and Value Implications

None.

## Risks and Unknowns

None.

## Impact Assessment

None.

## Change Proposals

| Proposal ID | Proposal | Impact | Accepted Impact | Status | Human Owner | Decision Ref |
|---|---|---|---|---|---|---|
| CP-001 | Defer multi-warehouse stock | scope | yes | accepted | Demo PO | DEC-004 |

## Explicit Limits and Unanswered Questions

None.
"@
  Set-Content -LiteralPath $researchReport -Value $researchText -Encoding utf8
  $provDoc = Get-Content -LiteralPath $provenancePath -Raw | ConvertFrom-Json
  $provDoc.claims[0].sources = @()
  $provDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $provenancePath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Scope"
  Assert-Rule $result "RESEARCH-003" "claim without a source"

  $provDoc = Get-Content -LiteralPath $provenancePath -Raw | ConvertFrom-Json
  $provDoc.claims[0].sources = @([pscustomobject]@{ reference = "MOM-20260714"; title = "t"; issuer = "i"; date = "2026-07-14"; primary = $true; verification = "verified" })
  $provDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $provenancePath -Encoding utf8
  $researchText = (Get-Content -LiteralPath $researchReport -Raw) -replace 'DEC-004', 'DEC-999'
  Set-Content -LiteralPath $researchReport -Value $researchText -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Scope"
  Assert-Rule $result "RESEARCH-004" "accepted proposal without resolvable decision"

  # Unresolved accepted-impact proposal blocks Scope.
  $researchText = (Get-Content -LiteralPath $researchReport -Raw) -replace '\| CP-001 \| Defer multi-warehouse stock \| scope \| yes \| accepted \| Demo PO \| DEC-999 \|', '| CP-001 | Defer multi-warehouse stock | scope | yes | proposed | Demo PO | |'
  Set-Content -LiteralPath $researchReport -Value $researchText -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Scope"
  Assert-Rule $result "RESEARCH-005" "unresolved accepted-impact proposal blocks Scope"

  # Truthful provider availability.
  $researchText = (Get-Content -LiteralPath $researchReport -Raw) -replace '\| CP-001 \| Defer multi-warehouse stock \| scope \| yes \| proposed \| Demo PO \| \|', '| CP-001 | Defer multi-warehouse stock | scope | yes | accepted | Demo PO | DEC-004 |'
  Set-Content -LiteralPath $researchReport -Value $researchText -Encoding utf8
  $provDoc = Get-Content -LiteralPath $provenancePath -Raw | ConvertFrom-Json
  $provDoc.fallback_used = $true
  $provDoc.provider_available = $true
  $provDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $provenancePath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Scope"
  Assert-Rule $result "RESEARCH-006" "fallback claimed while provider available"

  # External provider must cite an approved externalization entry.
  $provDoc = Get-Content -LiteralPath $provenancePath -Raw | ConvertFrom-Json
  $provDoc.fallback_used = $false
  $provDoc.provider_available = $true
  $provDoc.externalization = "EXT-999"
  $provDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $provenancePath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Scope"
  Assert-Rule $result "RESEARCH-007" "external provider without approved externalization"

  Write-Host "[PASS] M4/M5/M6 contract tests completed"
} finally {
  if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }
}
