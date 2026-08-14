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

  # ---------------------------------------------------------------------------
  # FB-002 regression mutations (CR-001..CR-012, CR-015, CR-017). Reset the
  # canonical example to its pristine state first, then exercise each repaired
  # rule with its own negative mutation.
  # ---------------------------------------------------------------------------
  foreach ($rel in @("EXTERNALIZATION.json", "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json", "DESIGN/CLAUDE-DESIGN/REVIEW.json", "CHANGE-REQUESTS.json", "RESEARCH/RESEARCH.md", "RESEARCH/PROVENANCE.json", "PROJECT.md")) {
    Copy-Item -LiteralPath (Join-Path $RepoPath ("examples/OPTIONAL-TRACKS/" + $rel)) -Destination (Join-Path $active $rel) -Force
  }
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/OUTPUT/ui-direction.md") -Destination (Join-Path $outputDir "ui-direction.md") -Force

  # --- CR-002: network_transfer_occurred is a required JSON boolean -----------
  $extDoc = Get-Content -LiteralPath $extPath -Raw | ConvertFrom-Json
  $extDoc.entries[0].PSObject.Properties.Remove("network_transfer_occurred")
  $extDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $extPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "EXT-001" "missing network_transfer_occurred is a structural defect"

  # --- CR-005: Public proceeds under policy; Internal default forces review ---
  $extDoc = Get-Content -LiteralPath $extPath -Raw | ConvertFrom-Json
  $extDoc.entries[0] = [pscustomobject]@{
    id = "EXT-001"; purpose = $extDoc.entries[0].purpose; provider = $extDoc.entries[0].provider
    provider_type = "web"; outgoing_artifacts = $extDoc.entries[0].outgoing_artifacts
    classification = "Public"; minimization_redaction = $extDoc.entries[0].minimization_redaction
    scan_result = "clean"; human_review_required = $false; reviewer = ""; decision_ref = ""
    network_transfer_occurred = $true; status = "approved"; recorded_at = "2026-08-14T09:30:00Z"
  }
  $extDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $extPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-NoRule $result "EXT-002" "Public approved transfer proceeds under policy"
  $extDoc = Get-Content -LiteralPath $extPath -Raw | ConvertFrom-Json
  $extDoc.entries[0].classification = "Internal"
  $extDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $extPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "EXT-002" "Internal without provider policy forces Human review by default"

  # --- CR-015: nested sensitive path (.env at depth) is caught by the scan ----
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/EXTERNALIZATION.json") -Destination $extPath -Force
  $envDir = Join-Path $active "source"
  New-Item -ItemType Directory -Force -Path $envDir | Out-Null
  $envPath = Join-Path $envDir ".env"
  Set-Content -LiteralPath $envPath -Value "TOKEN=not-a-real-secret-abcdef123456" -Encoding utf8
  $envHash = (Get-FileHash -LiteralPath $envPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $extDoc = Get-Content -LiteralPath $extPath -Raw | ConvertFrom-Json
  $extDoc.entries[0].outgoing_artifacts = @([pscustomobject]@{ path = "source/.env"; sha256 = $envHash })
  $extDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $extPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "EXT-003" "nested sensitive path matches the policy patterns"
  Remove-Item -LiteralPath $envPath -Force
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/EXTERNALIZATION.json") -Destination $extPath -Force

  # --- CR-017: a repo-relative link that escapes the project is rejected ------
  $outsideDir = Join-Path ([System.IO.Path]::GetTempPath()) ("fb002-outside " + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $outsideDir | Out-Null
  $outsideFile = Join-Path $outsideDir "leaked.txt"
  Set-Content -LiteralPath $outsideFile -Value "outside content" -Encoding utf8
  $linkPath = Join-Path $active "escape-link"
  try {
    if ($IsWindows -or ($PSVersionTable.PSEdition -eq "Desktop")) {
      New-Item -ItemType Junction -Path $linkPath -Target $outsideDir -ErrorAction Stop | Out-Null
    } else {
      New-Item -ItemType SymbolicLink -Path $linkPath -Target $outsideDir -ErrorAction Stop | Out-Null
    }
    $linkCreated = $true
  } catch {
    $linkCreated = $false
  }
  if ($linkCreated) {
    $leakedHash = (Get-FileHash -LiteralPath (Join-Path $linkPath "leaked.txt") -Algorithm SHA256).Hash.ToLowerInvariant()
    $extDoc = Get-Content -LiteralPath $extPath -Raw | ConvertFrom-Json
    $extDoc.entries[0].outgoing_artifacts = @([pscustomobject]@{ path = "escape-link/leaked.txt"; sha256 = $leakedHash })
    $extDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $extPath -Encoding utf8
    $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
    Assert-Rule $result "EXT-001" "externalization artifact escaping the boundary is rejected"

    # Same boundary escape through the design provider manifest input set.
    $projectMdHash = (Get-FileHash -LiteralPath (Join-Path $active "PROJECT.md") -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifestDoc = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $manifestDoc.inputs = @(
      [pscustomobject]@{ kind = "project_summary"; path = "PROJECT.md"; sha256 = $projectMdHash },
      [pscustomobject]@{ kind = "raw_source"; path = "escape-link/leaked.txt"; sha256 = $leakedHash; governed_justification = "Containment test fixture." }
    )
    $manifestDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
    Assert-Rule $result "DPROV-003" "design provider input escaping the boundary is rejected"
    Remove-Item -LiteralPath $linkPath -Force
  }
  Remove-Item -LiteralPath $outsideDir -Recurse -Force -ErrorAction SilentlyContinue
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/EXTERNALIZATION.json") -Destination $extPath -Force
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json") -Destination $manifestPath -Force

  # --- CR-007: REVIEW.json is required at Handoff for a claude_design track ---
  Remove-Item -LiteralPath $reviewPath -Force
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Handoff"
  Assert-Rule $result "DPROV-005" "missing provider review blocks Handoff"

  # --- CR-008: declared output inventory must match the OUTPUT/ file set ------
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/REVIEW.json") -Destination $reviewPath -Force
  $reviewDoc = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json
  $reviewDoc.outputs = @([pscustomobject]@{ path = "missing-file.md"; sha256 = ("d" * 64) })
  $reviewDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reviewPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "DPROV-005" "declared output that does not exist is rejected"

  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/REVIEW.json") -Destination $reviewPath -Force
  Set-Content -LiteralPath (Join-Path $outputDir "extra.md") -Value "undeclared" -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "DPROV-005" "undeclared output file is rejected"
  Remove-Item -LiteralPath (Join-Path $outputDir "extra.md") -Force

  # --- CR-001: preflight must speak for the current manifest ------------------
  $reviewDoc = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json
  $reviewDoc.preflight.manifest_digest = "0" * 64
  $reviewDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reviewPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "DPROV-005" "stale preflight manifest digest is rejected"

  # --- CR-009: routing is derived; open technical finding blocks acceptance ---
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/REVIEW.json") -Destination $reviewPath -Force
  $reviewDoc = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json
  $reviewDoc.findings = @([pscustomobject]@{ id = "DP-002"; lens = "technical"; impact = "technical"; routes_to_change_control = $false; summary = "Test finding with derived routing"; status = "open"; owner = "Demo Tech Lead"; decision_ref = "" })
  $reviewDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reviewPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "DPROV-007" "self-asserted routing is ignored; open technical finding blocks acceptance"

  # --- CR-010: the externalization payload must cover the manifest inputs -----
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/REVIEW.json") -Destination $reviewPath -Force
  $extDoc = Get-Content -LiteralPath $extPath -Raw | ConvertFrom-Json
  $extDoc.entries[0].outgoing_artifacts = @([pscustomobject]@{ path = "PROJECT.md"; sha256 = "c8d3ccf7cae03bc612b4f1271f6cee130803bf9925f17e5cce192317e9d14b70" })
  $extDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $extPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "DPROV-004" "manifest payload not covered by the externalization entry"

  # --- CR-003: a forged MOM reference is not resolvable ------------------------
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/EXTERNALIZATION.json") -Destination $extPath -Force
  $provDoc = Get-Content -LiteralPath $provenancePath -Raw | ConvertFrom-Json
  $provDoc.claims[0].sources = @([pscustomobject]@{ reference = "MOM-99999999"; title = "forged"; issuer = "forged"; date = "2026-07-14"; primary = $true; verification = "verified" })
  $provDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $provenancePath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Scope"
  Assert-Rule $result "RESEARCH-003" "forged repo-local source reference is unresolvable"

  # --- CR-011: accepted Impact Assessment must resolve through a proposal -----
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/RESEARCH/PROVENANCE.json") -Destination $provenancePath -Force
  $researchReport = Join-Path $active "RESEARCH/RESEARCH.md"
  $researchText = (Get-Content -LiteralPath $researchReport -Raw) -replace '\| RC-001 \| Scope \(REQ-003 receive\) \| receive is a first-class operation \| accepted \| CP-001 \|', '| RC-001 | Scope (REQ-003 receive) | receive is a first-class operation | accepted | |'
  Set-Content -LiteralPath $researchReport -Value $researchText -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Scope"
  Assert-Rule $result "RESEARCH-004" "accepted impact without a governed proposal is rejected"

  # --- CR-012: a rejected proposal still needs a Human decision ---------------
  $researchText = (Get-Content -LiteralPath $researchReport -Raw) -replace '\| CP-001 \| Defer multi-warehouse stock; demo covers a single site \| scope \| yes \| accepted \| Demo PO \| DEC-004 \|', '| CP-001 | Defer multi-warehouse stock; demo covers a single site | scope | yes | rejected | Demo PO | |'
  Set-Content -LiteralPath $researchReport -Value $researchText -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Scope"
  Assert-Rule $result "RESEARCH-004" "rejected proposal without a Human decision is rejected"

  # ---------------------------------------------------------------------------
  # CR-018: canonical artifact hashing -- LF/CRLF and UTF-8 BOM stable for text,
  # byte-sensitive for binary, real content changes still invalidate digests.
  # ---------------------------------------------------------------------------
  foreach ($rel in @("EXTERNALIZATION.json", "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json", "DESIGN/CLAUDE-DESIGN/REVIEW.json", "CHANGE-REQUESTS.json", "RESEARCH/RESEARCH.md", "RESEARCH/PROVENANCE.json", "PROJECT.md", "DESIGN/BUILD-SPEC.md")) {
    Copy-Item -LiteralPath (Join-Path $RepoPath ("examples/OPTIONAL-TRACKS/" + $rel)) -Destination (Join-Path $active $rel) -Force
  }
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/OUTPUT/ui-direction.md") -Destination (Join-Path $outputDir "ui-direction.md") -Force

  # LF -> CRLF must not change a text artifact digest.
  $projectMd = Join-Path $active "PROJECT.md"
  $lfText = (Get-Content -LiteralPath $projectMd -Raw) -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($projectMd, ($lfText -replace "`n", "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Clean $result "LF to CRLF does not change provider digests"

  # A UTF-8 BOM must not change a text artifact digest either.
  $buildSpec = Join-Path $active "DESIGN/BUILD-SPEC.md"
  $bsBytes = [System.IO.File]::ReadAllBytes($buildSpec)
  $bomPrefix = [byte[]](0xEF, 0xBB, 0xBF)
  [System.IO.File]::WriteAllBytes($buildSpec, ($bomPrefix + $bsBytes))
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Clean $result "UTF-8 BOM does not change provider digests"

  # Binary artifacts hash by original bytes: one changed byte fails EXT-004.
  $assetDir = Join-Path $active "assets"
  New-Item -ItemType Directory -Force -Path $assetDir | Out-Null
  $pngPath = Join-Path $assetDir "logo.png"
  [System.IO.File]::WriteAllBytes($pngPath, [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x01, 0x02))
  $pngHash = (Get-FileHash -LiteralPath $pngPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $extDoc = Get-Content -LiteralPath $extPath -Raw | ConvertFrom-Json
  $extDoc.entries[0].outgoing_artifacts += [pscustomobject]@{ path = "assets/logo.png"; sha256 = $pngHash }
  $extDoc | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $extPath -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Clean $result "binary artifact hashes by bytes"
  $pngBytes = [System.IO.File]::ReadAllBytes($pngPath)
  $pngBytes[9] = 0x99
  [System.IO.File]::WriteAllBytes($pngPath, $pngBytes)
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Design"
  Assert-Rule $result "EXT-004" "binary byte change invalidates the digest"

  # --- CR-014/CR-021: generator E2E -- a real optional-track generation must
  # pass its own Draft gate (scaffolding placeholders are tolerated at Draft).
  $genOut = Join-Path $tempRepo "projects"
  New-Item -ItemType Directory -Force -Path $genOut | Out-Null
  & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/new-project.ps1") -ProjectCode "E2E-TRACKS" -Mode Standard -ResearchMode guided -ResearchProvider feyman -UiDelivery claude_design -OutputRoot $genOut 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "optional-track generator exited $LASTEXITCODE" }
  $genProject = Join-Path $genOut "E2E-TRACKS"
  $result = Invoke-ValidationJson $tempRepo $genProject "Standard" "Draft"
  Assert-Clean $result "generated optional-track project passes Draft"

  # --- CR-021: active-track Handoff and Release coverage ----------------------
  foreach ($rel in @("EXTERNALIZATION.json", "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json", "DESIGN/CLAUDE-DESIGN/REVIEW.json", "CHANGE-REQUESTS.json", "RESEARCH/RESEARCH.md", "RESEARCH/PROVENANCE.json", "PROJECT.md", "DESIGN/BUILD-SPEC.md")) {
    Copy-Item -LiteralPath (Join-Path $RepoPath ("examples/OPTIONAL-TRACKS/" + $rel)) -Destination (Join-Path $active $rel) -Force
  }
  Copy-Item -LiteralPath (Join-Path $RepoPath "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/OUTPUT/ui-direction.md") -Destination (Join-Path $outputDir "ui-direction.md") -Force
  Remove-Item -LiteralPath $pngPath -Force -ErrorAction SilentlyContinue

  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Handoff"
  Assert-Clean $result "active-track example passes Handoff"
  $result = Invoke-ValidationJson $tempRepo $active "Standard" "Release"
  $m46Fails = @($result.Json.results | Where-Object { $_.level -eq "FAIL" -and $_.rule_id -match '^(EXT|DPROV|RESEARCH)-' })
  if ($m46Fails.Count -gt 0) { throw "M4-M6 rules failed at Release: $($m46Fails.rule_id -join ', ')" }
  Write-Host "[PASS] active-track M4-M6 rules hold at Release"

  Write-Host "[PASS] M4/M5/M6 contract tests completed"
} finally {
  if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }
}
