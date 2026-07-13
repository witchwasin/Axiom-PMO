param(
  [Parameter(Mandatory = $true)]
  [Alias("Project")]
  [string]$ProjectPath,

  [ValidateSet("Lite", "Standard", "Strict")]
  [string]$Mode = "Standard",

  [ValidateSet("Draft", "Scope", "Design", "Release")]
  [string]$Gate = "Draft",

  [switch]$Release,

  [ValidateSet("Text", "Json")]
  [string]$Format = "Text",

  [switch]$FailOnWarning
)

$ErrorActionPreference = "Stop"

if ($Release) {
  $Gate = "Release"
}

$root = Resolve-Path -LiteralPath $ProjectPath
$project = $root.Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

# P4: modular validator. Every check now lives in scripts/lib/*.ps1; this
# file is the thin orchestrator described in the upgrade plan: parse params
# -> load config -> resolve mode -> invoke modules -> aggregate -> write
# Text/JSON -> exit code. Dot-sourcing (not Import-Module) is deliberate: it
# runs each lib file in this script's own scope, so $script: state (Add-Result
# accumulators, $project/$policy/etc. closures) is shared across modules
# without needing to thread every constant through every function call.
. (Join-Path $PSScriptRoot "lib/config-loader.ps1")
. (Join-Path $PSScriptRoot "lib/markdown-table-parser.ps1")
. (Join-Path $PSScriptRoot "lib/reference-resolver.ps1")
. (Join-Path $PSScriptRoot "lib/result-writer.ps1")
. (Join-Path $PSScriptRoot "lib/mode-resolver.ps1")
. (Join-Path $PSScriptRoot "lib/artifact-policy.ps1")
. (Join-Path $PSScriptRoot "lib/approval-validator.ps1")
. (Join-Path $PSScriptRoot "lib/source-validator.ps1")
. (Join-Path $PSScriptRoot "lib/workitem-validator.ps1")
. (Join-Path $PSScriptRoot "lib/rtm-validator.ps1")
. (Join-Path $PSScriptRoot "lib/release-validator.ps1")

$cfg = Import-PmoConfig -RepoRoot $repoRoot
$policy = $cfg.Policy
$policyEnums = $cfg.PolicyEnums
$sentinelRules = $cfg.SentinelRules
$artifactPolicy = $cfg.ArtifactPolicy
$referenceTypesConfig = $cfg.ReferenceTypesConfig

$pass = 0
$warn = 0
$warnBlocking = 0
$fail = 0
$messages = New-Object System.Collections.Generic.List[object]

# Effective mode: CLI -Mode may upgrade but never silently downgrade a project.
$requestedMode = $Mode
$modeResult = Resolve-EffectiveMode -Project $project -RequestedMode $Mode -Gate $Gate
$effectiveMode = $modeResult.EffectiveMode
$Mode = $effectiveMode

# Mode x Gate artifact matrix drives which artifacts must exist yet. A GitHub
# task source (declared repo) waives the DELIVERY.md requirement -- the board
# lives on GitHub and is verified there, not by this offline validator.
$taskSourceIsGithub = Test-GithubTaskSource -Project $project
Test-RequiredArtifacts -Project $project -Mode $Mode -Gate $Gate -ArtifactPolicy $artifactPolicy -TaskSourceIsGithub $taskSourceIsGithub

$fileSets = Get-ProjectFileSets -Project $project
$allProjectFiles = $fileSets.AllProjectFiles
$governedFiles = $fileSets.GovernedFiles
$userSourceFiles = $fileSets.UserSourceFiles
$sourceRefRegex = Get-PolicySourceRefRegex
$decisionIds = Get-DecisionIds

Test-GovernedPlaceholders -GovernedFiles $governedFiles -Gate $Gate

$projectText = Get-ProjectText
$projectReqIds = @()
$projectBusinessIds = @()
$projectTaskSource = $null
if ($projectText) {
  $sourceResult = Test-ProjectSourceSection -ProjectText $projectText -Mode $Mode -Gate $Gate -SourceRefRegex $sourceRefRegex -PolicyEnums $policyEnums -DecisionIds $decisionIds
  $projectReqIds = $sourceResult.ProjectReqIds
  $projectBusinessIds = $sourceResult.ProjectBusinessIds
  $projectTaskSource = $sourceResult.ProjectTaskSource
}

$deliveryPath = Join-Path $project "DELIVERY.md"
$workItemResult = Test-DeliveryWorkItems -Project $project -DeliveryPath $deliveryPath -Mode $Mode -Gate $Gate -PolicyEnums $policyEnums -ProjectReqIds $projectReqIds -ProjectBusinessIds $projectBusinessIds -ProjectTaskSource $projectTaskSource -ProjectText $projectText
$workItems = $workItemResult.WorkItems
$deliveryIds = $workItemResult.DeliveryIds

Test-RaidBlocker -Project $project -Gate $Gate

$releaseResult = Test-ReleaseArtifact -Project $project -Mode $Mode -Gate $Gate -DeliveryIds $deliveryIds -DecisionIds $decisionIds
$releaseText = $releaseResult.ReleaseText
$releaseRegistry = $releaseResult.ReleaseRegistry

Test-ReleaseScopeCompletion -WorkItems $workItems -ReleaseText $releaseText -Mode $Mode -Gate $Gate -DecisionIds $decisionIds -ReleaseRegistry $releaseRegistry

Test-StrictReleaseGuardrails -Project $project -Mode $Mode -Gate $Gate -ProjectReqIds $projectReqIds -DeliveryIds $deliveryIds -DecisionIds $decisionIds -ReleaseRegistry $releaseRegistry

Test-SensitiveFilenames -AllProjectFiles $allProjectFiles

Test-Links -GovernedFiles $governedFiles -UserSourceFiles $userSourceFiles -Gate $Gate

$exitCode = Get-ExitCode -Fail $fail -WarnBlocking $warnBlocking -FailOnWarning:$FailOnWarning

Write-ValidationOutput -Format $Format -Project $project -RequestedMode $requestedMode -EffectiveMode $effectiveMode -Gate $Gate -Pass $pass -Warn $warn -WarnBlocking $warnBlocking -Fail $fail -Messages $messages -ExitCode $exitCode

if ($exitCode -ne 0) {
  exit $exitCode
}

exit 0
