param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

# P8 Final Gate: config mutation must assert the *specific expected rule*
# fired, not just that the command exited non-zero -- a mutation that breaks
# something unrelated would otherwise pass this test vacuously.

function Invoke-ExpectJsonRuleFailure {
  param(
    [string]$Name,
    [string]$ExpectedRule,
    [scriptblock]$Command
  )

  $output = & $Command
  $code = $LASTEXITCODE
  $json = $null
  try { $json = ($output | Out-String) | ConvertFrom-Json } catch { $json = $null }

  if ($code -eq 0) {
    throw "$Name did not fail after config mutation"
  }
  $hit = @($json.results | Where-Object { $_.rule_id -eq $ExpectedRule -and $_.level -eq "FAIL" })
  if ($hit.Count -eq 0) {
    $output | Write-Host
    throw "$Name failed (exit $code) but did not FAIL on expected rule $ExpectedRule"
  }
  Write-Host "[PASS] $Name failed as expected on $ExpectedRule (exit $code)"
}

function Invoke-ExpectTextRuleFailure {
  param(
    [string]$Name,
    [string]$ExpectedRule,
    [scriptblock]$Command
  )

  $output = & $Command
  $code = $LASTEXITCODE
  $text = $output | Out-String

  if ($code -eq 0) {
    throw "$Name did not fail after config mutation"
  }
  if ($text -notmatch "\[FAIL\]\s+$([regex]::Escape($ExpectedRule))\b") {
    $output | Write-Host
    throw "$Name failed (exit $code) but did not FAIL on expected rule $ExpectedRule"
  }
  Write-Host "[PASS] $Name failed as expected on $ExpectedRule (exit $code)"
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

  Invoke-ExpectJsonRuleFailure "policy enum mutation" "ENUM-001" {
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/validate-project.ps1") -ProjectPath (Join-Path $tempRepo "tests/fixtures/valid-standard") -Mode Standard -Gate Release -Format Json
  }

  $skillManifestPath = Join-Path $tempRepo "pmo-config/skill-manifest.json"
  $manifest = Get-Content -LiteralPath $skillManifestPath -Raw | ConvertFrom-Json
  $manifest.active_skills = @($manifest.active_skills | Where-Object { $_.id -ne "pmo-intake" })
  $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $skillManifestPath -Encoding utf8

  Invoke-ExpectTextRuleFailure "skill manifest mutation" "DOCTOR-001" {
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/pmo-doctor.ps1") -RepoPath $tempRepo
  }

  # P5.1: artifact-policy.json mutation -- proves the Mode x Gate artifact
  # matrix is genuinely config-driven, not a hardcoded fallback list. Add
  # RTM.json to Standard/Release (a file valid-standard does not have) and
  # confirm the validator now requires it. Restore policy.json first: this
  # repo copy still carries the statuses-enum mutation from the test above,
  # which would make Standard/Release fail on ENUM-001 regardless of the
  # artifact-policy change, masking whether this mutation did anything.
  Copy-Item -LiteralPath (Join-Path $RepoPath "pmo-config/policy.json") -Destination $policyPath -Force
  $artifactPolicyPath = Join-Path $tempRepo "pmo-config/artifact-policy.json"
  $artifactPolicy = Get-Content -LiteralPath $artifactPolicyPath -Raw | ConvertFrom-Json
  $artifactPolicy.artifact_matrix.Standard.Release = @($artifactPolicy.artifact_matrix.Standard.Release) + "RTM.json"
  $artifactPolicy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $artifactPolicyPath -Encoding utf8

  Invoke-ExpectJsonRuleFailure "artifact-policy mutation" "STRUCT-001" {
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/validate-project.ps1") -ProjectPath (Join-Path $tempRepo "tests/fixtures/valid-standard") -Mode Standard -Gate Release -Format Json
  }

  # P7.3: schema_version mutation -- proves DOCTOR-006 actually reads the
  # field instead of only checking that it exists once at authoring time.
  # policy.json still carries the artifact-policy-test's mutation to $policyPath
  # from further up, but that only touched pmo-config/artifact-policy.json, so
  # policy.json itself is still the clean, restored copy here.
  $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
  $policy.schema_version = "2.0"
  $policy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $policyPath -Encoding utf8

  Invoke-ExpectTextRuleFailure "schema_version mutation" "DOCTOR-006" {
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/pmo-doctor.ps1") -RepoPath $tempRepo
  }

  # H6: rule catalog mutation -- proves DOCTOR-007 actually reconciles the
  # catalog against the real emitters instead of just checking the file parses.
  $rulesPath = Join-Path $tempRepo "pmo-config/validation-rules.json"
  $rules = Get-Content -LiteralPath $rulesPath -Raw | ConvertFrom-Json
  $rules.rules.PSObject.Properties.Remove("REF-001")
  $rules | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $rulesPath -Encoding utf8

  Invoke-ExpectTextRuleFailure "rule catalog mutation" "DOCTOR-007" {
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/pmo-doctor.ps1") -RepoPath $tempRepo
  }

  Write-Host "[PASS] Config mutation tests prove JSON runtime config is source of truth"
} finally {
  if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force
  }
}
