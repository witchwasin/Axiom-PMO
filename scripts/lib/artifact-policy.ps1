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
    $ArtifactPolicy
  )

  Test-File "PROJECT.md" | Out-Null

  $matrixRequired = @()
  $modeMatrix = $ArtifactPolicy.artifact_matrix.$Mode
  if ($modeMatrix -and $modeMatrix.$Gate) {
    $matrixRequired = @($modeMatrix.$Gate)
  }

  # RTM.json used to be hardcoded as Strict-only/always-optional here instead
  # of going through the same Mode x Gate matrix as every other artifact --
  # caught by a config-mutation test that added RTM.json to a mode's Release
  # requirement and found the validator never actually enforced it.
  $allTrackedArtifacts = @("DELIVERY.md", "RELEASE.md", "RAID-log.md", "decision-log.md", "DESIGN", "RTM.json")
  foreach ($artifact in $allTrackedArtifacts) {
    $requirement = if ($matrixRequired -contains $artifact) { "required" } else { "optional" }
    if ($artifact -eq "DESIGN") {
      Test-Dir "DESIGN" $requirement | Out-Null
    } else {
      Test-File $artifact $requirement | Out-Null
    }
  }
  Test-Dir "source" "optional" | Out-Null
}
