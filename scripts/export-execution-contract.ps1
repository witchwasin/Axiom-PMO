param(
  [Parameter(Mandatory = $true)]
  [Alias("Project")]
  [string]$ProjectPath,

  # The DELIVERY.md work item this contract is for, e.g. D-001.
  [Parameter(Mandatory = $true)]
  [string]$WorkItemId,

  # Where the git history lives. Defaults to the project path's own
  # repository; separate parameter for the same reason SCOPE-DIFF has one.
  [string]$GitRepoRoot = $null,

  # Defaults to <ProjectPath>/.execution/<WorkItemId>/.
  [string]$OutputPath = $null,

  # Git actions this contract grants, e.g. -Grant commit or -Grant commit,push.
  # Everything not named here stays denied.
  #
  # This exists so granting authority is an explicit, recorded act at export
  # time rather than a hand-edit afterward. Editing git_authority in an
  # exported contract would change its bytes and therefore its digest, which
  # EXEC-002 reports as tampering -- correctly, since a contract whose granted
  # authority can be quietly widened after approval verifies nothing. Passing
  # -Grant re-exports the whole contract and mints a new digest, so the grant
  # is visible in the artifact a human reviews and in the file's identity.
  [string]$Grant = "",

  # Reserved for future execution workflows. Accepted and recorded so a
  # consumer can tell which shape produced a contract, but it does not change
  # the output today: the schema is deliberately workflow-neutral (see
  # docs/architecture/execution-contract-verification.md's GO WITH REFRAME
  # decision -- there is no native runtime to emit a workflow-specific dialect
  # for, and inventing per-workflow variants before a second consumer exists
  # would be the "normalized IR" this milestone's scope explicitly rejects).
  [string]$Format = "generic",

  [switch]$Force
)

# Milestone 5.1: turn an approved DELIVERY.md work item into an execution
# contract an agent can be handed, and pin that contract's identity so the
# result can later be checked against the version that was actually approved.
#
# This script writes two files and reads many. It never edits DELIVERY.md,
# PROJECT.md, SCOPE.json, or anything under source/ -- the contract is derived
# from approved artifacts, it does not become a second place where scope is
# decided.

$ErrorActionPreference = "Stop"

$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (-not $GitRepoRoot) { $GitRepoRoot = $project }
$gitRoot = (Resolve-Path -LiteralPath $GitRepoRoot).Path

. (Join-Path $PSScriptRoot "lib/markdown-files.ps1")
. (Join-Path $PSScriptRoot "lib/markdown-table-parser.ps1")
. (Join-Path $PSScriptRoot "lib/scope-diff-matcher.ps1")
. (Join-Path $PSScriptRoot "lib/execution-contract-schema.ps1")

function Fail-Export {
  param([string]$Message)
  Write-Host "EXPORT FAILED: $Message"
  exit 1
}

# --- work item ---------------------------------------------------------------

$deliveryPath = Join-Path $project "DELIVERY.md"
if (-not (Test-Path -LiteralPath $deliveryPath -PathType Leaf)) {
  Fail-Export "No DELIVERY.md in $project. An execution contract is generated from an approved work item; there is no work item board to read."
}

$deliveryText = Read-MarkdownText -Path $deliveryPath -Raw
$workItems = Get-TableRowsAfterHeading $deliveryText '^##\s+Work Items'
if (@($workItems).Count -eq 0) {
  Fail-Export "DELIVERY.md has no Work Items table."
}

$item = $null
foreach ($row in $workItems) {
  if ([string]$row.ID -eq $WorkItemId) { $item = $row; break }
}
if (-not $item) {
  Fail-Export "Work item '$WorkItemId' is not in DELIVERY.md's Work Items table."
}

# --- project code ------------------------------------------------------------

$projectMdPath = Join-Path $project "PROJECT.md"
$projectCode = Split-Path -Leaf $project
if (Test-Path -LiteralPath $projectMdPath -PathType Leaf) {
  $projectText = Read-MarkdownText -Path $projectMdPath -Raw
  if ($projectText -match '(?m)^#\s+(?:PROJECT\s*-\s*)?(.+?)\s*$') {
    $heading = $Matches[1].Trim()
    if ($heading) { $projectCode = $heading }
  }
}

# --- approved scope becomes allowed paths ------------------------------------

# Deliberately sourced from SCOPE.json rather than invented here or passed on
# the command line. SCOPE.json is the project's already-approved
# implementation scope (M4.5); deriving allowed_paths from it means an
# execution contract can never grant an agent more path freedom than the
# reviewed scope declaration does. A project without SCOPE.json has no
# approved scope to hand over, which is a real blocker, not a default of
# "anywhere".
$scope = Read-ScopeDeclaration -ProjectPath $project
if (-not $scope.Present) {
  Fail-Export "No SCOPE.json in $project. An execution contract's allowed_paths are derived from the project's approved implementation scope -- declare it first (see templates/SCOPE.json). A contract must never grant broader path access than the approved scope."
}
if (-not $scope.Valid) {
  Fail-Export "SCOPE.json is invalid: $($scope.Error)"
}

# M8.1: the pinned adversarial-review workflow path (if one is configured) is
# always added to prohibited_paths, on top of whatever SCOPE.json's own
# Exclude list already names. This is what lets AREV-003's externally-observed
# binding rely on EXEC-004 to catch an executor editing the review workflow
# within the very commit range under verification -- reusing scope protection
# that already exists, rather than adding a second mechanism for one path.
$reviewWorkflowPaths = @()
$adversarialReviewPolicyPath = Join-Path $repoRoot "pmo-config/adversarial-review-policy.json"
if (Test-Path -LiteralPath $adversarialReviewPolicyPath -PathType Leaf) {
  $adversarialReviewPolicy = Get-Content -LiteralPath $adversarialReviewPolicyPath -Raw | ConvertFrom-Json
  $pinnedWorkflowPath = [string]$adversarialReviewPolicy.externally_observed_binding.pinned_workflow_path
  if (-not [string]::IsNullOrWhiteSpace($pinnedWorkflowPath)) {
    $reviewWorkflowPaths = @($pinnedWorkflowPath)
  }
}

# --- base commit -------------------------------------------------------------

$baseSha = & git -C $gitRoot rev-parse --verify --quiet "HEAD^{commit}" 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$baseSha)) {
  Fail-Export "Could not resolve HEAD in $gitRoot. The contract pins an exact base commit (never a branch name, which moves); a repository with no resolvable HEAD cannot be exported from."
}
$baseSha = ([string]$baseSha).Trim()

# --- assemble ----------------------------------------------------------------

function Split-CellList {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
  $parts = @()
  foreach ($piece in ($Value -split ',')) {
    $trimmed = $piece.Trim()
    if ($trimmed -and $trimmed -ne "none" -and $trimmed -ne "-") { $parts += $trimmed }
  }
  return $parts
}

$grantableActions = @("create_branch", "commit", "push", "merge", "deploy")
$gitAuthority = [ordered]@{
  create_branch = $true
  commit = $false
  push = $false
  merge = $false
  deploy = $false
}
foreach ($piece in ($Grant -split ',')) {
  $action = $piece.Trim()
  if (-not $action) { continue }
  if ($grantableActions -notcontains $action) {
    Fail-Export "Unknown git action in -Grant: '$action'. Grantable actions are: $($grantableActions -join ', ')."
  }
  $gitAuthority[$action] = $true
}

$contract = [ordered]@{
  contract_version = "1.0"
  generated_by = "axiom export"
  project_id = $projectCode
  work_item_id = [string]$item.ID
  mode = [string]$item.Mode
  objective = [string]$item.'Feature / Deliverable'
  requirement_refs = @(Split-CellList ([string]$item.'Requirement Ref'))
  design_refs = @(Split-CellList ([string]$item.'Design Ref'))
  acceptance_criteria = @(Split-CellList ([string]$item.'Acceptance Criteria'))
  required_tests = @(Split-CellList ([string]$item.'Test Checklist'))
  base_sha = $baseSha
  allowed_paths = @($scope.Include)
  prohibited_paths = @(@($scope.Exclude) + $reviewWorkflowPaths | Select-Object -Unique)
  # Defaults from pmo-config/execution-contract-policy.json's stated posture:
  # an agent may work on a branch, and nothing else, unless -Grant names more.
  # Written explicitly rather than left to be defaulted at verification time --
  # the granted authority should be visible in the artifact a human reviews,
  # not inferred from config the reader has to go and look up.
  git_authority = $gitAuthority
  verification_note = "This contract is candidate input, not an approval. The execution result produced against it is a claim until Axiom-PMO verifies it against observable git state -- see docs/reference/execution-contract.md."
}

if (-not $OutputPath) {
  $OutputPath = Join-Path (Join-Path $project ".execution") $WorkItemId
}
$contractPath = Join-Path $OutputPath "EXECUTION-CONTRACT.json"
if ((Test-Path -LiteralPath $contractPath -PathType Leaf) -and (-not $Force)) {
  Fail-Export "$contractPath already exists. Re-exporting would change the digest an existing result may already reference; pass -Force to overwrite deliberately."
}

New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

# UTF-8 without BOM, LF line endings, trailing newline: the digest is over
# these exact bytes, so the encoding has to be pinned rather than left to the
# host's defaults (Windows PowerShell 5.1 would otherwise write UTF-16 or add
# a BOM, and the same contract would digest differently on two machines).
$json = ($contract | ConvertTo-Json -Depth 12)
$json = ($json -replace "`r`n", "`n")
if (-not $json.EndsWith("`n")) { $json += "`n" }
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($contractPath, $json, $utf8NoBom)

$digest = Get-ExecutionFileDigest -Path $contractPath
[System.IO.File]::WriteAllText("$contractPath.sha256", ($digest + "`n"), $utf8NoBom)

Write-Host "Execution contract exported"
Write-Host "  work item : $WorkItemId"
Write-Host "  base      : $baseSha"
Write-Host "  contract  : $contractPath"
Write-Host "  digest    : $digest"
Write-Host ""
Write-Host "The result produced against this contract must carry contract_sha256 = $digest"
Write-Host "Verify it with: axiom verify --project <path> --result $((Join-Path $OutputPath 'EXECUTION-RESULT.json'))"
exit 0
