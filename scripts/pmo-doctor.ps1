param(
  [string]$RepoPath = (Resolve-Path ".").Path
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path -LiteralPath $RepoPath
$repo = $root.Path

$pass = 0
$warn = 0
$fail = 0
$messages = New-Object System.Collections.Generic.List[string]

function Add-Result {
  param(
    [ValidateSet("PASS", "WARN", "FAIL")]
    [string]$Level,
    [string]$Message
  )

  $script:messages.Add("[$Level] $Message") | Out-Null
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
    Add-Result PASS "Found $RelativePath"
  } else {
    Add-Result FAIL "Missing $RelativePath"
  }
}

Require-File "AGENTS.md"
Require-File "CLAUDE.md"
Require-File "CONTEXT-ROUTER.md"
Require-File "pmo-config/context-map.yaml"
Require-File "scripts/validate-project.ps1"
Require-File "scripts/pmo-doctor.ps1"
Require-File "scripts/run-validation-tests.ps1"

$templateNames = @("PROJECT.md", "DELIVERY.md", "RELEASE.md", "RAID-log.md", "decision-log.md", "RTM.yaml", "WIREFRAME.md")
foreach ($name in $templateNames) {
  Require-File (Join-Path "templates" $name)
}

$settingsPath = Join-Path $repo ".claude/settings.json"
if (Test-Path -LiteralPath $settingsPath) {
  $settings = Get-Content -LiteralPath $settingsPath -Raw
  if ($settings -match "git push|git commit|git tag") {
    Add-Result FAIL ".claude/settings.json still allows git push/commit/tag"
  } else {
    Add-Result PASS ".claude/settings.json does not allow git push/commit/tag by default"
  }
  if ($settings -match "scripts/pmo-doctor\.ps1") {
    Add-Result PASS ".claude/settings.json allows the framework doctor command"
  } else {
    Add-Result FAIL ".claude/settings.json does not allow scripts/pmo-doctor.ps1"
  }
  if ($settings -match "scripts/run-validation-tests\.ps1") {
    Add-Result PASS ".claude/settings.json allows the validation fixture test command"
  } else {
    Add-Result FAIL ".claude/settings.json does not allow scripts/run-validation-tests.ps1"
  }

  if ($settings -match "echo 'PMO-") {
    Add-Result FAIL "Fake PMO echo hooks still exist"
  } else {
    Add-Result PASS "No fake PMO echo hooks found in settings"
  }
} else {
  Add-Result WARN ".claude/settings.json not found"
}

$claude = Get-Content -LiteralPath (Join-Path $repo "CLAUDE.md") -Raw
$agent = Get-Content -LiteralPath (Join-Path $repo "AGENTS.md") -Raw

foreach ($skill in @("pmo-analyze-new-mom", "pmo-gap-analysis", "pmo-activity-diagram", "pmo-dev-handoff", "pmo-qa-report", "pmo-git-push")) {
  $skillPath = Join-Path $repo ".claude/skills/$skill"
  if (($claude -match [regex]::Escape($skill) -or $agent -match [regex]::Escape($skill)) -and -not (Test-Path -LiteralPath $skillPath -PathType Container)) {
    Add-Result WARN "Referenced skill folder missing: $skill"
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
$messages | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "Summary: PASS=$pass WARN=$warn FAIL=$fail"

if ($fail -gt 0) {
  exit 1
}

exit 0
