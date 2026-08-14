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

function Set-ProjectDeclarations {
  param([string]$Project, [string]$Ui = "dev_guided")
  $path = Join-Path $Project "PROJECT.md"
  $text = Get-Content -LiteralPath $path -Raw
  $declarations = "> Research mode: off`n> Research depth: standard`n> Research provider: none`n> UI delivery: $Ui`n"
  $text = $text -replace '(?m)^(# PROJECT[^\r\n]*\r?\n)', "`$1`n$declarations"
  Set-Content -LiteralPath $path -Value $text -Encoding utf8
}

function Set-Change {
  param([string]$Project, $Change)
  $doc = [ordered]@{ schema_version = "1.0"; changes = @($Change) }
  $doc | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $Project "CHANGE-REQUESTS.json") -Encoding utf8
}

$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pmo m2-m3 " + [guid]::NewGuid().ToString("N"))
$tempRepo = Join-Path $workRoot "repo"
try {
  New-Item -ItemType Directory -Force -Path $tempRepo | Out-Null
  foreach ($item in Get-ChildItem -LiteralPath $RepoPath -Force) {
    if ($item.Name -eq ".git") { continue }
    Copy-Item -LiteralPath $item.FullName -Destination $tempRepo -Recurse -Force
  }

  # M2: harmless proposed patch is auditable but does not block Handoff.
  $changeProject = Join-Path $tempRepo "examples/HANDOFF-DEMO"
  $baseChange = [pscustomobject]@{
    id = "CR-001"; detected_at = "2026-08-14T00:00:00Z"; source = "implementation"; classification = "patch"
    summary = "Small implementation note"; reason = "Observed harmless detail"; affected_requirements = @("REQ-001")
    affected_artifacts = @("DESIGN/BUILD-SPEC.md"); scope_impact = $false; acceptance_impact = $false; mode_impact = "none"
    status = "proposed"; owner = "Demo Tech Lead"; decision_ref = ""
  }
  Set-Change $changeProject $baseChange
  $result = Invoke-ValidationJson $tempRepo $changeProject "Standard" "Handoff"
  Assert-NoRule $result "CHANGE-003" "proposed harmless patch"

  # Diagnostics identify only the registry entry, never a credential-like
  # string present in the candidate summary.
  $baseChange.summary = "Observed sk-THIS-MUST-NOT-LEAK-12345678901234567890 detail"
  $baseChange.classification = "scope"
  $baseChange.scope_impact = $true
  Set-Change $changeProject $baseChange
  $result = Invoke-ValidationJson $tempRepo $changeProject "Standard" "Handoff"
  Assert-Rule $result "CHANGE-003" "unresolved scope change"
  if ($result.Text -match "sk-THIS-MUST-NOT-LEAK") { throw "CHANGE diagnostics leaked sensitive candidate text" }

  # A disposed blocking change must cite a real named Human decision.
  $baseChange.status = "approved"; $baseChange.decision_ref = "DEC-999"
  Set-Change $changeProject $baseChange
  $result = Invoke-ValidationJson $tempRepo $changeProject "Standard" "Handoff"
  Assert-Rule $result "CHANGE-002" "approved change without decision"

  # Implemented Scope impact still blocks until downstream contracts are
  # revalidated; this is the non-silent re-export boundary.
  $baseChange.decision_ref = "DEC-002"; $baseChange.status = "implemented"
  Set-Change $changeProject $baseChange
  $result = Invoke-ValidationJson $tempRepo $changeProject "Standard" "Handoff"
  Assert-Rule $result "CHANGE-003" "implemented scope change without downstream evidence"

  $buildSpec = Join-Path $changeProject "DESIGN/BUILD-SPEC.md"
  $buildHash = (Get-FileHash -LiteralPath $buildSpec -Algorithm SHA256).Hash.ToLowerInvariant()
  $baseChange | Add-Member -NotePropertyName downstream_validation -NotePropertyValue ([pscustomobject]@{
    status = "current"; artifacts = @([pscustomobject]@{ path = "DESIGN/BUILD-SPEC.md"; sha256 = $buildHash }); execution_contracts = @()
  }) -Force
  Set-Change $changeProject $baseChange
  $result = Invoke-ValidationJson $tempRepo $changeProject "Standard" "Handoff"
  Assert-NoRule $result "CHANGE-003" "implemented scope change with current downstream evidence"

  # M3: explicit UI-path projects must carry early Test Strategy coverage.
  $designProject = Join-Path $tempRepo "examples/HANDOFF-DEMO"
  Remove-Item -LiteralPath (Join-Path $designProject "CHANGE-REQUESTS.json") -Force
  Set-ProjectDeclarations $designProject "dev_guided"
  $buildSpecPath = Join-Path $designProject "DESIGN/BUILD-SPEC.md"
  $originalBuildSpec = Get-Content -LiteralPath $buildSpecPath -Raw
  $withoutStrategy = $originalBuildSpec -replace '(?ms)\r?\n### Test Strategy\r?\n.*?(?=\r?\n### |\z)', ""
  Set-Content -LiteralPath $buildSpecPath -Value $withoutStrategy -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $designProject "Standard" "Design"
  Assert-Rule $result "TEST-DESIGN-001" "Standard Design without early Test Strategy"

  $strategy = @"

### Test Strategy

Status: specified

| Test Area | Requirement / Risk Ref | Level | Execution | Environment | Owner |
|---|---|---|---|---|---|
| Scan lookup | REQ-001 | system | automated | local | Demo Tech Lead |
| Consume stock | REQ-002 | system | automated | local | Demo Tech Lead |
| Receive stock | REQ-003 | system | automated | local | Demo Tech Lead |
| Attach photo | REQ-004 | system | manual | tablet | Demo Tech Lead |
"@
  Set-Content -LiteralPath $buildSpecPath -Value ($withoutStrategy.TrimEnd() + $strategy) -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $designProject "Standard" "Design"
  Assert-NoRule $result "TEST-DESIGN-001" "complete early Test Strategy"
  Assert-NoRule $result "TEST-DESIGN-002" "complete requirement coverage"

  $mutatedStrategy = (Get-Content -LiteralPath $buildSpecPath -Raw) -replace '\| Attach photo \| REQ-004 \|', '| Attach photo | R-UNKNOWN |'
  Set-Content -LiteralPath $buildSpecPath -Value $mutatedStrategy -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $designProject "Standard" "Design"
  Assert-Rule $result "TEST-DESIGN-002" "missing scoped requirement coverage"

  # Strict mode keeps the same canonical table but requires a concrete test
  # level for each detailed requirement/risk case.
  $strictProject = Join-Path $tempRepo "examples/HANDOFF-DEMO"
  $strictBuildSpec = Join-Path $strictProject "DESIGN/BUILD-SPEC.md"
  $strictText = Get-Content -LiteralPath $strictBuildSpec -Raw
  $strictText = $strictText -replace '(?m)^> UI delivery: dev_guided\s*$', '> UI delivery: not_applicable'
  $strictText = $strictText + $strategy
  Set-Content -LiteralPath $strictBuildSpec -Value $strictText -Encoding utf8
  $strictProjectText = Get-Content -LiteralPath (Join-Path $strictProject "PROJECT.md") -Raw
  $strictProjectText = $strictProjectText -replace '(?m)^> UI delivery: dev_guided\s*$', '> UI delivery: not_applicable'
  Set-Content -LiteralPath (Join-Path $strictProject "PROJECT.md") -Value $strictProjectText -Encoding utf8
  $strictMutated = (Get-Content -LiteralPath $strictBuildSpec -Raw) -replace '\| Scan lookup \| REQ-001 \| system \|', '| Scan lookup | REQ-001 | <level> |'
  Set-Content -LiteralPath $strictBuildSpec -Value $strictMutated -Encoding utf8
  $result = Invoke-ValidationJson $tempRepo $strictProject "Strict" "Design"
  Assert-Rule $result "TEST-DESIGN-001" "Strict strategy without concrete test level"

  # Legacy projects with no new declarations stay silent.
  $legacyProject = Join-Path $tempRepo "examples/STANDARD-FEATURE"
  $result = Invoke-ValidationJson $tempRepo $legacyProject "Standard" "Design"
  Assert-NoRule $result "TEST-DESIGN-001" "legacy project compatibility"
  Assert-NoRule $result "TEST-DESIGN-002" "legacy project compatibility"

  Write-Host "[PASS] M2/M3 contract tests completed"
} finally {
  if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }
}
