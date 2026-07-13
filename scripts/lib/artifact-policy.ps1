# File/directory presence checks, and the Mode x Gate artifact matrix
# (pmo-config/artifact-policy.json) that decides which artifacts are required
# at each (effective mode, gate) combination -- a Standard project at Draft
# no longer needs RELEASE.md/DELIVERY.md to exist yet, for example.

function Get-RelativePath {
  param([string]$Path)
  return $Path.Substring($script:project.Length).TrimStart("\", "/")
}

function Test-File {
  param(
    [string]$RelativePath,
    [ValidateSet("required", "optional")]
    [string]$Requirement = "required"
  )

  $path = Join-Path $script:project $RelativePath
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    Add-Result PASS "Found $RelativePath" "STRUCT-001"
    return $true
  }

  if ($Requirement -eq "required") {
    Add-Result FAIL "Missing $RelativePath" "STRUCT-001"
  } else {
    Add-Result INFO "Missing optional file $RelativePath" "STRUCT-001"
  }
  return $false
}

function Test-Dir {
  param(
    [string]$RelativePath,
    [ValidateSet("required", "optional")]
    [string]$Requirement = "optional"
  )

  $path = Join-Path $script:project $RelativePath
  if (Test-Path -LiteralPath $path -PathType Container) {
    Add-Result PASS "Found $RelativePath/" "STRUCT-001"
    return $true
  }

  if ($Requirement -eq "required") {
    Add-Result FAIL "Missing $RelativePath/" "STRUCT-001"
  } else {
    Add-Result INFO "Missing optional directory $RelativePath/" "STRUCT-001"
  }
  return $false
}

function Get-ProjectText {
  $path = Join-Path $script:project "PROJECT.md"
  if (Test-Path -LiteralPath $path) {
    return Get-Content -LiteralPath $path -Raw
  }
  return ""
}

function Get-ProjectFileSets {
  param([string]$Project)
  $allProjectFiles = Get-ChildItem -LiteralPath $Project -Recurse -File -ErrorAction SilentlyContinue
  $allTextFiles = @($allProjectFiles | Where-Object { $_.Extension -in @(".md", ".yaml", ".yml", ".puml", ".html") })
  $governedFiles = @($allTextFiles | Where-Object { -not (Test-UserSourcePath (Get-RelativePath $_.FullName)) })
  $userSourceFiles = @($allTextFiles | Where-Object { Test-UserSourcePath (Get-RelativePath $_.FullName) })
  return [pscustomobject]@{
    AllProjectFiles = $allProjectFiles
    AllTextFiles = $allTextFiles
    GovernedFiles = $governedFiles
    UserSourceFiles = $userSourceFiles
  }
}

function Test-RequiredArtifacts {
  param(
    [string]$Project,
    [string]$Mode,
    [string]$Gate,
    $ArtifactPolicy,
    [bool]$TaskSourceIsGithub = $false
  )

  Test-File "PROJECT.md" | Out-Null

  $matrixRequired = @()
  $modeMatrix = $ArtifactPolicy.artifact_matrix.$Mode
  if ($modeMatrix -and $modeMatrix.$Gate) {
    $matrixRequired = @($modeMatrix.$Gate)
  }

  # H5: when the declared task source is GitHub Issues (with a named repo),
  # DELIVERY.md is no longer required -- the work-item board lives on GitHub,
  # which this offline validator cannot read. DELIVERY.md's absence becomes a
  # TASK-003 non-blocking warning instead of a STRUCT-001 failure. The board's
  # actual state must be checked on GitHub (and by the CI that runs there).
  $deliveryOptionalViaGithub = ($TaskSourceIsGithub -and ($matrixRequired -contains "DELIVERY.md"))

  # RTM.json used to be hardcoded as Strict-only/always-optional here instead
  # of going through the same Mode x Gate matrix as every other artifact --
  # caught by a config-mutation test that added RTM.json to a mode's Release
  # requirement and found the validator never actually enforced it.
  $allTrackedArtifacts = @("DELIVERY.md", "RELEASE.md", "RAID-log.md", "decision-log.md", "DESIGN", "RTM.json")
  foreach ($artifact in $allTrackedArtifacts) {
    $requirement = if ($matrixRequired -contains $artifact) { "required" } else { "optional" }
    if ($artifact -eq "DELIVERY.md" -and $deliveryOptionalViaGithub) { $requirement = "optional" }
    if ($artifact -eq "DESIGN") {
      Test-Dir "DESIGN" $requirement | Out-Null
    } else {
      Test-File $artifact $requirement | Out-Null
    }
  }
  Test-Dir "source" "optional" | Out-Null

  if ($deliveryOptionalViaGithub -and -not (Test-Path -LiteralPath (Join-Path $script:project "DELIVERY.md") -PathType Leaf)) {
    Add-Result WARN "Task source is GitHub Issues; DELIVERY.md is absent, so work-item completion cannot be verified offline (check the GitHub board / CI)" "TASK-003" -Blocking $false
  }
}

function Test-GithubTaskSource {
  # H5: true only when PROJECT.md both declares `Task source: github` AND names
  # a repository -- github with no repo is treated as file (DELIVERY.md still
  # required), so a half-filled template can't accidentally waive the board.
  param([string]$Project)
  $path = Join-Path $Project "PROJECT.md"
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
  $text = Get-Content -LiteralPath $path -Raw
  # [ \t] not \s: .NET \s matches newlines, so `github_repository:\s*\S+` would
  # skip a blank line and match the *next* line's value, making an empty repo
  # field look filled.
  # \r? before $ tolerates CRLF line endings ([ \t] does not consume \r the way
  # \s would, and .NET (?m)$ anchors before \n).
  $isGithub = $text -match '(?m)^[ \t]*>?[ \t]*Task source:[ \t]*github[ \t]*\r?$'
  $hasRepo = $text -match '(?m)^[ \t]*github_repository:[ \t]*\S+'
  return ([bool]$isGithub -and [bool]$hasRepo)
}
