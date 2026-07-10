param(
  [string]$RepoPath = (Resolve-Path ".").Path
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path -LiteralPath $RepoPath
$repo = $root.Path

$pass = 0
$warn = 0
$fail = 0
$messages = New-Object System.Collections.Generic.List[object]

function Add-Result {
  param(
    [ValidateSet("PASS", "WARN", "FAIL")]
    [string]$Level,
    [string]$Message,
    [string]$RuleId = "DOCTOR-000"
  )

  $script:messages.Add([pscustomobject]@{
    level = $Level
    rule_id = $RuleId
    message = $Message
  }) | Out-Null
  switch ($Level) {
    "PASS" { $script:pass++ }
    "WARN" { $script:warn++ }
    "FAIL" { $script:fail++ }
  }
}

function Require-File {
  param([string]$RelativePath)
  $path = Join-Path $repo $RelativePath
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    Add-Result PASS "Found $RelativePath" "DOCTOR-STRUCT"
  } else {
    Add-Result FAIL "Missing $RelativePath" "DOCTOR-STRUCT"
  }
}

Require-File "AGENTS.md"
Require-File "CLAUDE.md"
Require-File "VERSION"
Require-File "CHANGELOG.md"
Require-File "README.md"
Require-File "TESTING.md"
Require-File "SECURITY.md"
Require-File "MIGRATION.md"
Require-File "CONTEXT-ROUTER.md"
Require-File "pmo-config/context-map.yaml"
Require-File "pmo-config/policy.yaml"
Require-File "pmo-config/skill-manifest.yaml"
Require-File "pmo-config/validation-rules.yaml"
Require-File "scripts/validate-project.ps1"
Require-File "scripts/pmo-doctor.ps1"
Require-File "scripts/run-validation-tests.ps1"
Require-File "scripts/run-all-checks.ps1"
Require-File "scripts/new-project.ps1"
Require-File "scripts/update-source-snapshot.ps1"
Require-File "scripts/measure-context.ps1"

$templateNames = @("PROJECT.md", "DELIVERY.md", "RELEASE.md", "RAID-log.md", "decision-log.md", "RTM.yaml", "WIREFRAME.md")
foreach ($name in $templateNames) {
  Require-File (Join-Path "templates" $name)
}

$exampleNames = @("LITE-BUGFIX", "STANDARD-FEATURE", "STRICT-HIGH-RISK", "P01-DEMO")
foreach ($name in $exampleNames) {
  $examplePath = Join-Path "examples" $name
  $fullExamplePath = Join-Path $repo $examplePath
  if (Test-Path -LiteralPath $fullExamplePath -PathType Container) {
    Add-Result PASS "Found $examplePath" "DOCTOR-EXAMPLE"
  } else {
    Add-Result FAIL "Missing $examplePath" "DOCTOR-EXAMPLE"
  }
}

$activeSkills = @("pmo-intake", "pmo-design", "pmo-delivery", "pmo-build-review", "pmo-quality-release", "pmo-governance", "pmo-git-safety")
$skillsRoot = Join-Path $repo ".claude/skills"
$actualSkills = @()
if (Test-Path -LiteralPath $skillsRoot -PathType Container) {
  $actualSkills = @(Get-ChildItem -LiteralPath $skillsRoot -Directory | Select-Object -ExpandProperty Name)
}

$missingActive = $activeSkills | Where-Object { $actualSkills -notcontains $_ }
$extraActive = $actualSkills | Where-Object { $activeSkills -notcontains $_ }
if ($missingActive.Count -eq 0 -and $extraActive.Count -eq 0) {
  Add-Result PASS "Active skill runtime contains exactly 7 skills" "DOCTOR-001"
} else {
  if ($missingActive.Count -gt 0) { Add-Result FAIL ("Missing active skills: " + ($missingActive -join ", ")) "DOCTOR-001" }
  if ($extraActive.Count -gt 0) { Add-Result FAIL ("Unexpected active skills: " + ($extraActive -join ", ")) "DOCTOR-001" }
}

$manifestText = Get-Content -LiteralPath (Join-Path $repo "pmo-config/skill-manifest.yaml") -Raw
foreach ($skill in $activeSkills) {
  if ($manifestText -notmatch [regex]::Escape($skill)) {
    Add-Result FAIL "Skill manifest does not list $skill" "DOCTOR-001"
  }
}

$contextMap = Get-Content -LiteralPath (Join-Path $repo "pmo-config/context-map.yaml") -Raw
if ($contextMap -match "policy_ref:\s*pmo-config/policy.yaml" -and $contextMap -match "skill_manifest_ref:\s*pmo-config/skill-manifest.yaml") {
  Add-Result PASS "Context map references central policy and skill manifest" "DOCTOR-003"
} else {
  Add-Result FAIL "Context map must reference policy.yaml and skill-manifest.yaml" "DOCTOR-003"
}

$settingsPath = Join-Path $repo ".claude/settings.json"
if (Test-Path -LiteralPath $settingsPath) {
  $settings = Get-Content -LiteralPath $settingsPath -Raw
  try {
    $settingsJson = $settings | ConvertFrom-Json
    Add-Result PASS ".claude/settings.json parses as JSON" "PERMISSION-000"
  } catch {
    Add-Result FAIL ".claude/settings.json is not valid JSON" "PERMISSION-000"
    $settingsJson = $null
  }

  $allowEntries = @()
  $askEntries = @()
  $denyEntries = @()
  if ($settingsJson) {
    $allowEntries = @($settingsJson.permissions.allow)
    $askEntries = @($settingsJson.permissions.ask)
    $denyEntries = @($settingsJson.permissions.deny)
  }

  if (($allowEntries -join "`n") -match "git push|git commit|git tag") {
    Add-Result FAIL ".claude/settings.json still allows git push/commit/tag" "PERMISSION-001"
  } else {
    Add-Result PASS ".claude/settings.json does not allow git push/commit/tag by default" "PERMISSION-001"
  }
  if (($askEntries -join "`n") -match "git push" -and ($askEntries -join "`n") -match "git commit" -and ($askEntries -join "`n") -match "git tag") {
    Add-Result PASS ".claude/settings.json asks before git commit/push/tag" "PERMISSION-003"
  } else {
    Add-Result FAIL ".claude/settings.json should ask before git commit/push/tag" "PERMISSION-003"
  }
  if (($denyEntries -join "`n") -match "\.env" -and ($denyEntries -join "`n") -match "\.pem" -and ($denyEntries -join "`n") -match "credential") {
    Add-Result PASS ".claude/settings.json denies common secret and private key paths" "PERMISSION-004"
  } else {
    Add-Result FAIL ".claude/settings.json should deny common secret and private key paths" "PERMISSION-004"
  }
  if ($settingsJson -and $settingsJson.disableBypassPermissionsMode -eq "disable") {
    Add-Result PASS ".claude/settings.json disables bypass permissions mode" "PERMISSION-005"
  } else {
    Add-Result FAIL ".claude/settings.json should disable bypass permissions mode" "PERMISSION-005"
  }

  if (($allowEntries -join "`n") -match "scripts/pmo-doctor\.ps1") {
    Add-Result PASS ".claude/settings.json allows the framework doctor command" "PERMISSION-002"
  } else {
    Add-Result FAIL ".claude/settings.json does not allow scripts/pmo-doctor.ps1" "PERMISSION-002"
  }
  if (($allowEntries -join "`n") -match "scripts/run-validation-tests\.ps1") {
    Add-Result PASS ".claude/settings.json allows the validation fixture test command" "PERMISSION-002"
  } else {
    Add-Result FAIL ".claude/settings.json does not allow scripts/run-validation-tests.ps1" "PERMISSION-002"
  }

  if ($settings -match "echo 'PMO-") {
    Add-Result FAIL "Fake PMO echo hooks still exist" "DOCTOR-HOOK"
  } else {
    Add-Result PASS "No fake PMO echo hooks found in settings" "DOCTOR-HOOK"
  }
} else {
  Add-Result WARN ".claude/settings.json not found" "PERMISSION-002"
}

$claude = Get-Content -LiteralPath (Join-Path $repo "CLAUDE.md") -Raw
$agent = Get-Content -LiteralPath (Join-Path $repo "AGENTS.md") -Raw

$legacySkillNames = @(
  "pmo-analyze-new-mom", "pmo-gap-analysis", "pmo-activity-diagram", "pmo-dev-handoff",
  "pmo-qa-report", "pmo-git-push", "pmo-task-breakdown", "pmo-wireframe-design",
  "pmo-workflow-architect", "pmo-use-case-diagram"
)
foreach ($skill in $legacySkillNames) {
  if ($claude -match [regex]::Escape($skill) -or $agent -match [regex]::Escape($skill)) {
    Add-Result FAIL "Router or core rules reference archived legacy skill: $skill" "DOCTOR-002"
  }
}

$legacyPatterns = @("SystemFlow", "UserFlow", "TaskBreakdown", "Logging every", "log every")
foreach ($skill in $actualSkills) {
  $skillPath = Join-Path $skillsRoot $skill
  $hits = @()
  foreach ($file in Get-ChildItem -LiteralPath $skillPath -Recurse -File -Include *.md -ErrorAction SilentlyContinue) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    foreach ($pattern in $legacyPatterns) {
      if ($content -match [regex]::Escape($pattern)) {
        $hits += "$skill/$($file.Name):$pattern"
      }
    }
  }
  if ($hits.Count -gt 0) {
    Add-Result FAIL ("Active skill has legacy rule references: " + (($hits | Select-Object -First 5) -join ", ")) "DOCTOR-004"
  }
}

$links = @()
foreach ($file in Get-ChildItem -LiteralPath $repo -Recurse -File -Include *.md -ErrorAction SilentlyContinue) {
  if ($file.FullName -match "\\.git\\") { continue }
  $relativeFile = $file.FullName.Substring($repo.Length).TrimStart('\', '/')
  if ($relativeFile -match "^tests[\\/]fixtures[\\/]invalid-") { continue }

  $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
  $matches = [regex]::Matches($content, "\[[^\]]+\]\((?!https?://)([^)#]+)(?:#[^)]+)?\)")
  foreach ($match in $matches) {
    $target = $match.Groups[1].Value
    if ($target -match "^\s*$|^mailto:|^<") { continue }
    $base = Split-Path -Parent $file.FullName
    $resolved = Join-Path $base $target
    if (-not (Test-Path -LiteralPath $resolved)) {
      $links += "$relativeFile -> $target"
    }
  }
}

if ($links.Count -eq 0) {
  Add-Result PASS "No broken local markdown links found"
} else {
  Add-Result WARN ("Broken local links: " + (($links | Select-Object -First 8) -join ", "))
}

Write-Host "PMO Framework Doctor: $repo"
Write-Host ""
$messages | ForEach-Object { Write-Host "[$($_.level)] $($_.rule_id) $($_.message)" }
Write-Host ""
Write-Host "Summary: PASS=$pass WARN=$warn FAIL=$fail"

if ($fail -gt 0) {
  exit 1
}

exit 0
