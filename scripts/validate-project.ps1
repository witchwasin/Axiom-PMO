param(
  [Parameter(Mandatory = $true)]
  [Alias("Project")]
  [string]$ProjectPath,

  [ValidateSet("Lite", "Standard", "Strict")]
  [string]$Mode = "Standard",

  [ValidateSet("Draft", "Scope", "Design", "Handoff", "Release")]
  [string]$Gate = "Draft",

  [switch]$Release,

  [ValidateSet("Text", "Json")]
  [string]$Format = "Text",

  [switch]$FailOnWarning,

  # SCOPE-DIFF (M4.5) is opt-in: it only runs when BOTH refs are supplied.
  # Every existing caller -- the CLI, the GitHub Action's non-scope-diff
  # path, every example/demo/fixture invocation, every golden-master
  # capture -- passes neither, so this feature changes nothing for them.
  # Refs are anything `git rev-parse` accepts: a SHA, a branch name, HEAD~1,
  # etc. A GitHub Actions PR run should pass the PR's actual base and head
  # SHAs (not branch names, which move), obtained from the event context.
  [string]$ScopeDiffBase = $null,
  [string]$ScopeDiffHead = $null,

  # M4 (L2 completion), same opt-in discipline as -ScopeDiffBase/-ScopeDiffHead:
  # when BOTH refs are supplied, the release-path Test Summary check reconciles
  # passed FILE: evidence against git ground truth -- tracked evidence that was
  # not changed within base..head cannot be the output of a test run of this
  # release's work (TEST-EVIDENCE-003). Every existing caller passes neither,
  # so behavior is byte-identical for them. The project's own repository is the
  # git ground truth (evidence files and commit range live there), so no
  # separate repo-root parameter is needed the way SCOPE-DIFF needs
  # -ScopeDiffRepoRoot.
  [string]$ReleaseDiffBase = $null,
  [string]$ReleaseDiffHead = $null,

  # Deliberately separate from the $repoRoot this script already computes
  # below (Join-Path $PSScriptRoot ".."), which is always the Axiom-PMO
  # framework's own checkout -- correct for loading pmo-config/*.json, but
  # WRONG for git diff when this script runs as the GitHub Action. As an
  # Action, this file is checked out to github.action_path while the
  # consumer's own repository (the one with the PR history to diff) is
  # checked out separately at $GITHUB_WORKSPACE. Defaults to the framework
  # root for local/CLI use, where "the project being validated" and "the
  # repo with the git history" are the same checkout.
  [string]$ScopeDiffRepoRoot = $null
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
. (Join-Path $PSScriptRoot "lib/execution-path-validator.ps1")
. (Join-Path $PSScriptRoot "lib/artifact-policy.ps1")
. (Join-Path $PSScriptRoot "lib/approval-validator.ps1")
. (Join-Path $PSScriptRoot "lib/source-validator.ps1")
. (Join-Path $PSScriptRoot "lib/workitem-validator.ps1")
. (Join-Path $PSScriptRoot "lib/rtm-validator.ps1")
. (Join-Path $PSScriptRoot "lib/release-validator.ps1")
. (Join-Path $PSScriptRoot "lib/handoff-validator.ps1")
. (Join-Path $PSScriptRoot "lib/design-system-validator.ps1")
. (Join-Path $PSScriptRoot "lib/visual-proof-validator.ps1")
. (Join-Path $PSScriptRoot "lib/scope-diff-matcher.ps1")
. (Join-Path $PSScriptRoot "lib/scope-diff-git-adapter.ps1")
. (Join-Path $PSScriptRoot "lib/scope-diff-validator.ps1")

$cfg = Import-PmoConfig -RepoRoot $repoRoot
$policy = $cfg.Policy
$policyEnums = $cfg.PolicyEnums
$sentinelRules = $cfg.SentinelRules
$artifactPolicy = $cfg.ArtifactPolicy
$referenceTypesConfig = $cfg.ReferenceTypesConfig
# Rule catalog is read by Add-Result to attach suggestion/documentation_url to
# every actionable diagnostic (see lib/result-writer.ps1).
$ruleCatalog = $cfg.ValidationRules
$handoffPolicy = $cfg.HandoffPolicy

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
Test-RequiredArtifacts -Mode $Mode -Gate $Gate -ArtifactPolicy $artifactPolicy -TaskSourceIsGithub $taskSourceIsGithub

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
$projectSourceIds = @()
if ($projectText) {
  $sourceResult = Test-ProjectSourceSection -ProjectText $projectText -Mode $Mode -Gate $Gate -SourceRefRegex $sourceRefRegex -PolicyEnums $policyEnums -DecisionIds $decisionIds
  $projectReqIds = $sourceResult.ProjectReqIds
  $projectBusinessIds = $sourceResult.ProjectBusinessIds
  $projectTaskSource = $sourceResult.ProjectTaskSource
  $projectSourceIds = $sourceResult.ProjectSourceIds
}

$deliveryPath = Join-Path $project "DELIVERY.md"
$workItemResult = Test-DeliveryWorkItems -Project $project -DeliveryPath $deliveryPath -Gate $Gate -PolicyEnums $policyEnums -ProjectReqIds $projectReqIds -ProjectBusinessIds $projectBusinessIds -ProjectTaskSource $projectTaskSource
$workItems = $workItemResult.WorkItems
$deliveryIds = $workItemResult.DeliveryIds

Test-ExecutionPath -Project $project -PolicyEnums $policyEnums -WorkItems $workItems

Test-RaidBlocker -Project $project -Gate $Gate

$releaseResult = Test-ReleaseArtifact -Project $project -Mode $Mode -Gate $Gate -DeliveryIds $deliveryIds -DecisionIds $decisionIds
$releaseText = $releaseResult.ReleaseText
$releaseRegistry = $releaseResult.ReleaseRegistry

# M4 second increment (opt-in): git ground truth for release-path test
# evidence. Runs only when the caller supplies both refs; with neither
# supplied it is never invoked and the output is byte-identical to v1.x.
if ($ReleaseDiffBase -and $ReleaseDiffHead) {
  Test-TestEvidenceGitGroundTruth -ReleaseRegistry $releaseRegistry -Project $project -Mode $Mode -BaseRef $ReleaseDiffBase -HeadRef $ReleaseDiffHead
}

Test-ReleaseScopeCompletion -WorkItems $workItems -ReleaseText $releaseText -Mode $Mode -Gate $Gate -DecisionIds $decisionIds -ReleaseRegistry $releaseRegistry

Test-StrictReleaseGuardrails -Project $project -Mode $Mode -Gate $Gate -ProjectReqIds $projectReqIds -DeliveryIds $deliveryIds -DecisionIds $decisionIds -ReleaseRegistry $releaseRegistry -ProjectSourceIds $projectSourceIds

# Handoff checks run only when the caller asks for -Gate Handoff. Every other
# gate behaves exactly as it did in v1.0; adding the gate does not retro-apply
# handoff requirements to Draft/Scope/Design/Release runs.
if ($Gate -eq "Handoff") {
  Test-HandoffReadiness -Project $project -Mode $Mode -Gate $Gate -HandoffPolicy $handoffPolicy -PolicyEnums $policyEnums -WorkItems $workItems -DeliveryIds $deliveryIds -ProjectReqIds $projectReqIds -DecisionIds $decisionIds -ProjectText $projectText
  Test-VisualProofReview -Project $project -Mode $Mode -HandoffPolicy $handoffPolicy -ProjectText $projectText -DecisionIds $decisionIds
}

# The design system is optional at every gate, so this stays silent unless a
# project has both canonical files. When it does, they must agree: the markdown
# is the contract a developer builds from and the sheet is what a stakeholder
# looked at, and nothing else would notice the two drifting apart.
Test-DesignSystemTokens -Project $project -Gate $Gate

Test-SensitiveFilenames -AllProjectFiles $allProjectFiles

Test-Links -GovernedFiles $governedFiles -UserSourceFiles $userSourceFiles -Gate $Gate

# SCOPE-DIFF (M4.5): opt-in, gate-independent. Runs at whatever gate the
# caller requested, alongside every other check that gate already runs --
# it is one more finding in the same results array, not a separate pass.
$scopeDiffResult = $null
if ($ScopeDiffBase -and $ScopeDiffHead) {
  $scopeDiffGitRoot = if ($ScopeDiffRepoRoot) { (Resolve-Path -LiteralPath $ScopeDiffRepoRoot).Path } else { $repoRoot }
  $scopeDiffResult = Invoke-ScopeDiffCheck -ProjectPath $project -GitRepoRoot $scopeDiffGitRoot -FrameworkRoot $repoRoot -BaseRef $ScopeDiffBase -HeadRef $ScopeDiffHead
}

$exitCode = Get-ExitCode -Fail $fail -WarnBlocking $warnBlocking -FailOnWarning:$FailOnWarning

Write-ValidationOutput -Format $Format -Project $project -RequestedMode $requestedMode -EffectiveMode $effectiveMode -Gate $Gate -Pass $pass -Warn $warn -WarnBlocking $warnBlocking -Fail $fail -Messages $messages -ExitCode $exitCode -ScopeDiff $scopeDiffResult

if ($exitCode -ne 0) {
  exit $exitCode
}

exit 0
