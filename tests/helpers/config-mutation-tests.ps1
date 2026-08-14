param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

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
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/validate-project.ps1") -ProjectPath (Join-Path $tempRepo "tests/fixtures/valid-standard") -Mode Standard -Gate Release -Format Json
  }

  $skillManifestPath = Join-Path $tempRepo "pmo-config/skill-manifest.json"
  $manifest = Get-Content -LiteralPath $skillManifestPath -Raw | ConvertFrom-Json
  $manifest.active_skills = @($manifest.active_skills | Where-Object { $_.id -ne "pmo-intake" })
  $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $skillManifestPath -Encoding utf8

  Invoke-ExpectTextRuleFailure "skill manifest mutation" "DOCTOR-001" {
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/pmo-doctor.ps1") -RepoPath $tempRepo
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
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/validate-project.ps1") -ProjectPath (Join-Path $tempRepo "tests/fixtures/valid-standard") -Mode Standard -Gate Release -Format Json
  }

  # M1: orchestration-policy.json must drive project declarations. A legacy
  # project remains compatible when the defaults are explicit; removing the
  # declared default from policy must then fire the declaration rule itself.
  Copy-Item -LiteralPath (Join-Path $RepoPath "pmo-config/artifact-policy.json") -Destination $artifactPolicyPath -Force
  $orchestrationPolicyPath = Join-Path $tempRepo "pmo-config/orchestration-policy.json"
  $orchestrationPolicy = Get-Content -LiteralPath $orchestrationPolicyPath -Raw | ConvertFrom-Json
  $orchestrationPolicy.research.modes = @($orchestrationPolicy.research.modes | Where-Object { $_ -ne "off" })
  $orchestrationPolicy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $orchestrationPolicyPath -Encoding utf8

  $declaredLegacyProject = Join-Path $tempRepo "examples/LITE-BUGFIX"
  $declaredProjectPath = Join-Path $declaredLegacyProject "PROJECT.md"
  $declaredProjectText = Get-Content -LiteralPath $declaredProjectPath -Raw
  $declarations = "> Research mode: off`n> Research depth: standard`n> Research provider: none`n> UI delivery: not_applicable`n"
  $declaredProjectText = $declaredProjectText -replace '(?m)^(# PROJECT[^\r\n]*\r?\n)', "`$1`n$declarations"
  Set-Content -LiteralPath $declaredProjectPath -Value $declaredProjectText -Encoding utf8

  Invoke-ExpectJsonRuleFailure "orchestration-policy enum mutation" "RESEARCH-001" {
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/validate-project.ps1") -ProjectPath $declaredLegacyProject -Mode Lite -Gate Scope -Format Json
  }

  Copy-Item -LiteralPath (Join-Path $RepoPath "pmo-config/orchestration-policy.json") -Destination $orchestrationPolicyPath -Force

  # CR-005/CR-021: externalization.internal_default_human_review is
  # load-bearing. The Human Owner selected false, so Internal proceeds under
  # policy by default; flipping the key to true must require Human evidence.
  $extPath = Join-Path $tempRepo "examples/OPTIONAL-TRACKS/EXTERNALIZATION.json"
  $extDoc = Get-Content -LiteralPath $extPath -Raw | ConvertFrom-Json
  $extDoc.entries[0].classification = "Internal"
  $extDoc.entries[0].human_review_required = $false
  $extDoc.entries[0].reviewer = ""
  $extDoc.entries[0].decision_ref = ""
  $extDoc | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $extPath -Encoding utf8

  $expectedExt002 = {
    $output = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/validate-project.ps1") -ProjectPath (Join-Path $tempRepo "examples/OPTIONAL-TRACKS") -Mode Standard -Gate Scope -Format Json
    $json = ($output | Out-String) | ConvertFrom-Json
    @($json.results | Where-Object { $_.rule_id -eq "EXT-002" -and $_.level -eq "FAIL" }).Count
  }
  $failsWithDefault = & $expectedExt002
  if ($failsWithDefault -ne 0) { throw "Internal transfer should proceed under the Human-selected false default (got $failsWithDefault EXT-002 FAILs)" }
  Write-Host "[PASS] internal_default_human_review=false allows Internal under policy"

  $orchestrationPolicy = Get-Content -LiteralPath $orchestrationPolicyPath -Raw | ConvertFrom-Json
  $orchestrationPolicy.externalization.internal_default_human_review = $true
  $orchestrationPolicy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $orchestrationPolicyPath -Encoding utf8
  $failsFlipped = & $expectedExt002
  if ($failsFlipped -lt 1) { throw "Flipping internal_default_human_review to true must require Human evidence" }
  Write-Host "[PASS] internal_default_human_review=true requires Human evidence"

  # CR-006/CR-021: research.research_statuses is load-bearing -- a stopped
  # project must fail when the policy no longer admits the stopped state.
  $provPath = Join-Path $tempRepo "examples/OPTIONAL-TRACKS/RESEARCH/PROVENANCE.json"
  $provDoc = Get-Content -LiteralPath $provPath -Raw | ConvertFrom-Json
  $provDoc.research_status = "stopped"
  $provDoc | Add-Member -NotePropertyName stop_reason -NotePropertyValue "Provider unavailable and no fallback configured" -Force
  $provDoc | Add-Member -NotePropertyName next_action -NotePropertyValue "Human decides whether to defer research or proceed without it" -Force
  $provDoc | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $provPath -Encoding utf8
  $orchestrationPolicy = Get-Content -LiteralPath $orchestrationPolicyPath -Raw | ConvertFrom-Json
  $orchestrationPolicy.research.research_statuses = @($orchestrationPolicy.research.research_statuses | Where-Object { $_ -ne "stopped" })
  $orchestrationPolicy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $orchestrationPolicyPath -Encoding utf8

  Invoke-ExpectJsonRuleFailure "research_statuses mutation" "RESEARCH-006" {
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/validate-project.ps1") -ProjectPath (Join-Path $tempRepo "examples/OPTIONAL-TRACKS") -Mode Standard -Gate Scope -Format Json
  }

  Copy-Item -LiteralPath (Join-Path $RepoPath "pmo-config/orchestration-policy.json") -Destination $orchestrationPolicyPath -Force

  # P7.3: schema_version mutation -- proves DOCTOR-006 actually reads the
  # field instead of only checking that it exists once at authoring time.
  # policy.json still carries the artifact-policy-test's mutation to $policyPath
  # from further up, but that only touched pmo-config/artifact-policy.json, so
  # policy.json itself is still the clean, restored copy here.
  $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
  $policy.schema_version = "2.0"
  $policy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $policyPath -Encoding utf8

  Invoke-ExpectTextRuleFailure "schema_version mutation" "DOCTOR-006" {
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/pmo-doctor.ps1") -RepoPath $tempRepo
  }

  # H6: rule catalog mutation -- proves DOCTOR-007 actually reconciles the
  # catalog against the real emitters instead of just checking the file parses.
  $rulesPath = Join-Path $tempRepo "pmo-config/validation-rules.json"
  $rules = Get-Content -LiteralPath $rulesPath -Raw | ConvertFrom-Json
  $rules.rules.PSObject.Properties.Remove("REF-001")
  $rules | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $rulesPath -Encoding utf8

  Invoke-ExpectTextRuleFailure "rule catalog mutation" "DOCTOR-007" {
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/pmo-doctor.ps1") -RepoPath $tempRepo
  }

  # v1.1: the rule catalog's suggestion and documentation fields are runtime
  # inputs, not decoration -- Add-Result reads them for every WARN/FAIL. These
  # two mutations prove DOCTOR-008 and DOCTOR-009 actually inspect the catalog.
  Copy-Item -LiteralPath (Join-Path $RepoPath "pmo-config/policy.json") -Destination $policyPath -Force
  $rules = Get-Content -LiteralPath (Join-Path $RepoPath "pmo-config/validation-rules.json") -Raw | ConvertFrom-Json
  $rules.rules.'HANDOFF-004'.PSObject.Properties.Remove("suggestion")
  $rules | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $rulesPath -Encoding utf8

  Invoke-ExpectTextRuleFailure "rule suggestion mutation" "DOCTOR-008" {
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/pmo-doctor.ps1") -RepoPath $tempRepo
  }

  $rules = Get-Content -LiteralPath (Join-Path $RepoPath "pmo-config/validation-rules.json") -Raw | ConvertFrom-Json
  $rules.rules.'HANDOFF-004'.documentation = "docs/rules/DOES-NOT-EXIST.md"
  $rules | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $rulesPath -Encoding utf8

  Invoke-ExpectTextRuleFailure "rule documentation mutation" "DOCTOR-009" {
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/pmo-doctor.ps1") -RepoPath $tempRepo
  }

  # v1.1: handoff-policy.json drives the Handoff gate's severities, tokens, and
  # required sections. Each mutation below changes exactly one knob and asserts
  # the gate's behaviour changed with it -- otherwise the config is decorative
  # and the real rule is hardcoded somewhere in the validator.
  Copy-Item -LiteralPath (Join-Path $RepoPath "pmo-config/validation-rules.json") -Destination $rulesPath -Force
  $handoffPolicyPath = Join-Path $tempRepo "pmo-config/handoff-policy.json"

  # A token added to generic_tokens must start failing an owner that passed before.
  $handoffPolicy = Get-Content -LiteralPath $handoffPolicyPath -Raw | ConvertFrom-Json
  $handoffPolicy.owner_policy.generic_tokens = @($handoffPolicy.owner_policy.generic_tokens) + "R. Silva"
  $handoffPolicy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $handoffPolicyPath -Encoding utf8

  Invoke-ExpectJsonRuleFailure "handoff owner-token mutation" "HANDOFF-003" {
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/validate-project.ps1") -ProjectPath (Join-Path $tempRepo "examples/HANDOFF-DEMO") -Mode Standard -Gate Handoff -Format Json
  }

  # A section flipped to not-waivable must reject the example's existing waiver.
  Copy-Item -LiteralPath (Join-Path $RepoPath "pmo-config/handoff-policy.json") -Destination $handoffPolicyPath -Force
  $handoffPolicy = Get-Content -LiteralPath $handoffPolicyPath -Raw | ConvertFrom-Json
  foreach ($section in $handoffPolicy.build_spec.sections) {
    if ($section.id -eq "state_machine") { $section.allow_not_required = $false }
  }
  $handoffPolicy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $handoffPolicyPath -Encoding utf8

  Invoke-ExpectJsonRuleFailure "handoff build-spec waiver mutation" "HANDOFF-005" {
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/validate-project.ps1") -ProjectPath (Join-Path $tempRepo "examples/HANDOFF-DEMO") -Mode Standard -Gate Handoff -Format Json
  }

  # An extra lens in the policy must make an existing review incomplete.
  Copy-Item -LiteralPath (Join-Path $RepoPath "pmo-config/handoff-policy.json") -Destination $handoffPolicyPath -Force
  $handoffPolicy = Get-Content -LiteralPath $handoffPolicyPath -Raw | ConvertFrom-Json
  $handoffPolicy.semantic_review.lenses = @($handoffPolicy.semantic_review.lenses) +
    ([pscustomobject]@{ id = "mutation_test_lens"; title = "Added by the config mutation test" })
  $handoffPolicy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $handoffPolicyPath -Encoding utf8

  Invoke-ExpectJsonRuleFailure "handoff review-lens mutation" "HANDOFF-010" {
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/validate-project.ps1") -ProjectPath (Join-Path $tempRepo "examples/HANDOFF-DEMO") -Mode Standard -Gate Handoff -Format Json
  }

  # A required Handoff artifact added to the matrix must be enforced.
  Copy-Item -LiteralPath (Join-Path $RepoPath "pmo-config/handoff-policy.json") -Destination $handoffPolicyPath -Force
  Copy-Item -LiteralPath (Join-Path $RepoPath "pmo-config/artifact-policy.json") -Destination $artifactPolicyPath -Force
  $artifactPolicy = Get-Content -LiteralPath $artifactPolicyPath -Raw | ConvertFrom-Json
  $artifactPolicy.artifact_matrix.Standard.Handoff = @($artifactPolicy.artifact_matrix.Standard.Handoff) + "RTM.json"
  $artifactPolicy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $artifactPolicyPath -Encoding utf8

  Invoke-ExpectJsonRuleFailure "handoff artifact-matrix mutation" "STRUCT-001" {
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/validate-project.ps1") -ProjectPath (Join-Path $tempRepo "examples/HANDOFF-DEMO") -Mode Standard -Gate Handoff -Format Json
  }

  # Turning the explicit-declaration requirement off must let a vague
  # classification through again -- proving the knob, not the code, decides.
  Copy-Item -LiteralPath (Join-Path $RepoPath "pmo-config/handoff-policy.json") -Destination $handoffPolicyPath -Force
  $handoffPolicy = Get-Content -LiteralPath $handoffPolicyPath -Raw | ConvertFrom-Json
  $handoffPolicy.sensitive_data.declared_no_values = @($handoffPolicy.sensitive_data.declared_no_values) + "yes"
  $handoffPolicy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $handoffPolicyPath -Encoding utf8

  Invoke-ExpectJsonRuleFailure "handoff sensitive-declaration mutation" "HANDOFF-011" {
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/validate-project.ps1") -ProjectPath (Join-Path $tempRepo "tests/fixtures/invalid-handoff-sensitive-undeclared") -Mode Standard -Gate Handoff -Format Json
  }

  # Adding a lens to human_only_close_lenses must start requiring a signed
  # decision behind closures under it.
  Copy-Item -LiteralPath (Join-Path $RepoPath "pmo-config/handoff-policy.json") -Destination $handoffPolicyPath -Force
  $handoffPolicy = Get-Content -LiteralPath $handoffPolicyPath -Raw | ConvertFrom-Json
  $handoffPolicy.semantic_review.closure_policy.human_only_close_lenses =
    @($handoffPolicy.semantic_review.closure_policy.human_only_close_lenses) + "capability_lifecycle"
  $handoffPolicy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $handoffPolicyPath -Encoding utf8

  Invoke-ExpectJsonRuleFailure "handoff human-only-lens mutation" "HANDOFF-010" {
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/validate-project.ps1") -ProjectPath (Join-Path $tempRepo "tests/fixtures/invalid-handoff-human-closure-generic-decider") -Mode Standard -Gate Handoff -Format Json
  }

  # Renaming a declared column must make the previously-valid example fail:
  # proves the header assertion reads the policy rather than a hardcoded list.
  Copy-Item -LiteralPath (Join-Path $RepoPath "pmo-config/handoff-policy.json") -Destination $handoffPolicyPath -Force
  $handoffPolicy = Get-Content -LiteralPath $handoffPolicyPath -Raw | ConvertFrom-Json
  foreach ($section in $handoffPolicy.handoff_document.sections) {
    if ($section.heading -eq "Open Actions") { $section.columns = @("Action ID", "Description", "Owner", "Blocks", "Status") }
  }
  $handoffPolicy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $handoffPolicyPath -Encoding utf8

  Invoke-ExpectJsonRuleFailure "handoff table-header mutation" "HANDOFF-013" {
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/validate-project.ps1") -ProjectPath (Join-Path $tempRepo "examples/HANDOFF-DEMO") -Mode Standard -Gate Handoff -Format Json
  }

  # Pointing project identity at a field the artifacts do not agree on must fail:
  # proves the cross-check list is config, not code.
  Copy-Item -LiteralPath (Join-Path $RepoPath "pmo-config/handoff-policy.json") -Destination $handoffPolicyPath -Force
  $handoffPolicy = Get-Content -LiteralPath $handoffPolicyPath -Raw | ConvertFrom-Json
  $handoffPolicy.project_identity.cross_checked =
    @($handoffPolicy.project_identity.cross_checked) +
    ([pscustomobject]@{ artifact = "HANDOFF.md"; field = "Handoff Target"; kind = "metadata" })
  $handoffPolicy | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $handoffPolicyPath -Encoding utf8

  Invoke-ExpectJsonRuleFailure "handoff project-identity mutation" "HANDOFF-014" {
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/validate-project.ps1") -ProjectPath (Join-Path $tempRepo "examples/HANDOFF-DEMO") -Mode Standard -Gate Handoff -Format Json
  }

  # M9: marking an existing rule experimental with a blocking severity must
  # make pmo-doctor itself fail on DOCTOR-014 -- proves the ceiling ("an
  # experimental rule may never block") is a real, enforced invariant and not
  # only documentation in pmo-config/learning-policy.json.
  $validationRulesPath = Join-Path $tempRepo "pmo-config/validation-rules.json"
  $validationRules = Get-Content -LiteralPath $validationRulesPath -Raw | ConvertFrom-Json
  $validationRules.rules.'STRUCT-001' | Add-Member -NotePropertyName lifecycle -NotePropertyValue "experimental" -Force
  $validationRules | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $validationRulesPath -Encoding utf8

  Invoke-ExpectTextRuleFailure "experimental rule with blocking severity mutation" "DOCTOR-014" {
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRepo "scripts/pmo-doctor.ps1") -RepoPath $tempRepo
  }

  Write-Host "[PASS] Config mutation tests prove JSON runtime config is source of truth"
} finally {
  if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force
  }
}
