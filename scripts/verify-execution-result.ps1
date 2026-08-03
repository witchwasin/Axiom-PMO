param(
  [Parameter(Mandatory = $true)]
  [Alias("Project")]
  [string]$ProjectPath,

  # Path to the agent-authored EXECUTION-RESULT.json under verification.
  [Parameter(Mandatory = $true)]
  [string]$ResultPath,

  # Defaults to the EXECUTION-CONTRACT.json sitting beside the result.
  [string]$ContractPath = $null,

  [string]$GitRepoRoot = $null,

  [ValidateSet("Text", "Json")]
  [string]$Format = "Text",

  [switch]$FailOnWarning,

  # M8.1: run only the mechanical EXEC-* checks (contract integrity, identity,
  # scope, git-state reconciliation) and skip AREV-*, which can make a live
  # GitHub API call. Never a new verb or gate -- a flag on this one.
  [switch]$Preflight
)

# Milestone 5.2/5.3 entry point: check an execution result against the
# contract it claims to satisfy and against what the repository can be
# observed to show actually happened.
#
# Deliberately a separate script from validate-project.ps1 rather than another
# gate inside it. The gates (Draft -> Scope -> Design -> Handoff -> Release)
# answer "is this project's documentation sound"; this answers "did this one
# agent run stay inside its contract". Bolting it onto a gate would mean every
# existing gate invocation grew an opinion about execution results it was
# never asked for -- the same reasoning that made SCOPE-DIFF opt-in rather
# than a new gate.
#
# Output uses the identical diagnostic contract as every other check
# (docs/reference/diagnostics-contract.md), so an existing consumer parses it
# with no new code.

$ErrorActionPreference = "Stop"

$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (-not $GitRepoRoot) { $GitRepoRoot = $project }
$gitRoot = (Resolve-Path -LiteralPath $GitRepoRoot).Path

. (Join-Path $PSScriptRoot "lib/config-loader.ps1")
. (Join-Path $PSScriptRoot "lib/result-writer.ps1")
. (Join-Path $PSScriptRoot "lib/markdown-files.ps1")
. (Join-Path $PSScriptRoot "lib/markdown-table-parser.ps1")
. (Join-Path $PSScriptRoot "lib/scope-diff-matcher.ps1")
. (Join-Path $PSScriptRoot "lib/scope-diff-git-adapter.ps1")
. (Join-Path $PSScriptRoot "lib/execution-contract-schema.ps1")
. (Join-Path $PSScriptRoot "lib/execution-contract-git.ps1")
. (Join-Path $PSScriptRoot "lib/execution-contract-evidence.ps1")
. (Join-Path $PSScriptRoot "lib/execution-contract-validator.ps1")
. (Join-Path $PSScriptRoot "lib/mode-resolver.ps1")
. (Join-Path $PSScriptRoot "lib/adversarial-review-validator.ps1")

$script:messages = New-Object System.Collections.Generic.List[object]
$script:pass = 0
$script:warn = 0
$script:warnBlocking = 0
$script:fail = 0
$script:ruleCatalog = (Import-PmoConfig -RepoRoot $repoRoot).ValidationRules

$resolvedResult = $ResultPath
if (-not [System.IO.Path]::IsPathRooted($resolvedResult)) {
  $resolvedResult = Join-Path (Get-Location).Path $ResultPath
}

$verification = Invoke-ExecutionContractVerification `
  -ProjectPath $project `
  -ResultPath $resolvedResult `
  -GitRepoRoot $gitRoot `
  -FrameworkRoot $repoRoot `
  -ContractPath $ContractPath `
  -Preflight:$Preflight

$exitCode = 0
if ($script:fail -gt 0) { $exitCode = 1 }
elseif ($FailOnWarning -and $script:warnBlocking -gt 0) { $exitCode = 2 }

if ($Format -eq "Json") {
  $envelope = [ordered]@{
    schema_version = (Get-DiagnosticsSchemaVersion)
    project = $project
    requested_mode = "Standard"
    effective_mode = "Standard"
    gate = "Draft"
    summary = [ordered]@{
      pass = $script:pass
      warn = $script:warn
      warn_blocking = $script:warnBlocking
      fail = $script:fail
      exit_code = $exitCode
    }
    results = $script:messages.ToArray()
    execution_verification = $verification
  }
  Write-Output ($envelope | ConvertTo-Json -Depth 12)
} else {
  Write-Host "Axiom-PMO Execution Contract Verification"
  Write-Host "  project  : $project"
  Write-Host "  result   : $resolvedResult"
  Write-Host "  contract : $($verification.contract_path)"
  Write-Host ""
  foreach ($row in $script:messages) {
    Write-Host "[$($row.level)] $($row.rule_id) $($row.message)"
    if ($row.suggestion) { Write-Host "    Fix: $($row.suggestion)" }
  }
  Write-Host ""
  Write-Host "Verdict: $($verification.verdict)"
  Write-Host "Summary: PASS=$($script:pass) WARN=$($script:warn) FAIL=$($script:fail)"
}

exit $exitCode
