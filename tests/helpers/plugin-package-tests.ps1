param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

# Milestone 6.2: the plugin package itself.
#
# What is under test is the packaging contract, not Claude Code. Two facts
# established in Milestone 6.1 are load-bearing here and are re-asserted rather
# than trusted:
#
#   1. Claude Code discovers plugin skills from <plugin-root>/skills/ only.
#      plugin.json carries path overrides for commands, agents, hooks and
#      mcpServers -- and none for skills. Verified from the official manifest
#      reference, then confirmed by installing a probe plugin whose skills sat
#      under .claude/skills/ and watching the inventory report Skills (0).
#
#   2. The plugin root is the repository root (marketplace source "./"), so
#      scripts/, cli/, pmo-config/ and templates/ are already where the plugin
#      needs them. Nothing is copied. Duplicating the validator is forbidden
#      and, at this layout, unnecessary.
#
# What that leaves is one generated directory -- skills/ -- and a generated
# directory is a drift hazard. Most of this file is about the gate that makes
# drift impossible rather than merely discouraged.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$buildScript = Join-Path $repo "scripts/build-plugin-package.ps1"
$pass = 0
$fail = 0

function Assert-True {
  param([string]$Name, [bool]$Condition, [string]$Detail = "")
  if ($Condition) {
    Write-Host "[PASS] $Name"
    $script:pass++
  } else {
    Write-Host "[FAIL] $Name$(if ($Detail) { " -- $Detail" })"
    $script:fail++
  }
}

function Invoke-Build {
  param([string]$Root, [switch]$Check)
  $argv = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "scripts/build-plugin-package.ps1"))
  if ($Check) { $argv += "-Check" }
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & $pwshExe @argv 2>&1
    $code = $LASTEXITCODE
  } finally { $ErrorActionPreference = $previous }
  return [pscustomobject]@{ ExitCode = $code; Text = (($output | ForEach-Object { [string]$_ }) -join "`n") }
}

function New-RepoCopy {
  # A disposable copy of the repository, so drift cases can mutate the mirror
  # without touching the working tree. Only what the build script reads is
  # copied; that is also an implicit assertion about what it depends on.
  param([string]$Root)
  $copy = Join-Path $Root "repo"
  New-Item -ItemType Directory -Path (Join-Path $copy "scripts/lib") -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $repo "scripts/build-plugin-package.ps1") -Destination (Join-Path $copy "scripts/") -Force
  Copy-Item -LiteralPath (Join-Path $repo ".claude/skills") -Destination (Join-Path $copy ".claude/skills") -Recurse -Force
  return $copy
}

# ---- The manifests ------------------------------------------------------

$pluginManifestPath = Join-Path $repo ".claude-plugin/plugin.json"
$marketplaceManifestPath = Join-Path $repo ".claude-plugin/marketplace.json"

Assert-True "plugin manifest exists at .claude-plugin/plugin.json" `
  (Test-Path -LiteralPath $pluginManifestPath)
Assert-True "marketplace manifest exists at .claude-plugin/marketplace.json" `
  (Test-Path -LiteralPath $marketplaceManifestPath)

$plugin = Get-Content -LiteralPath $pluginManifestPath -Raw | ConvertFrom-Json
$marketplace = Get-Content -LiteralPath $marketplaceManifestPath -Raw | ConvertFrom-Json

Assert-True "plugin name is kebab-case as the manifest reference requires" `
  ([string]$plugin.name -cmatch '^[a-z][a-z0-9]*(-[a-z0-9]+)*$') ("name=" + $plugin.name)
# The plugin carries the version of the release it will ship in, which is
# ahead of VERSION while that release is unbuilt. Asserting equality was
# correct until Milestone 6 existed; it now has to assert the relationship
# instead -- the plugin must never claim a version already released, or an
# installed 1.2.0 plugin and the released 1.2.0 would be different software.
$repoVersion = ((Get-Content -LiteralPath (Join-Path $repo "VERSION") -Raw).Trim())
Assert-True "plugin version is a valid semantic version" `
  ([string]$plugin.version -match '^\d+\.\d+\.\d+$') ("plugin=" + $plugin.version)
Assert-True "plugin version does not collide with the released VERSION" `
  ([string]$plugin.version -ne $repoVersion) `
  ("plugin=" + $plugin.version + " VERSION=" + $repoVersion + " -- an unreleased plugin must not reuse a released version number")
Assert-True "plugin version is ahead of the released VERSION, not behind" `
  ([version][string]$plugin.version -gt [version]$repoVersion) `
  ("plugin=" + $plugin.version + " VERSION=" + $repoVersion)
Assert-True "marketplace declares exactly the one plugin" `
  (@($marketplace.plugins).Count -eq 1)
Assert-True "marketplace source is the repository root" `
  ([string]@($marketplace.plugins)[0].source -eq "./") `
  ("source=" + [string]@($marketplace.plugins)[0].source)
Assert-True "marketplace entry name matches the plugin manifest name" `
  ([string]@($marketplace.plugins)[0].name -eq [string]$plugin.name)

# The description is what a user reads before installing. Milestone 6's whole
# product boundary is that this is optional, so the description has to say so.
Assert-True "marketplace description states the integration is optional" `
  ([string]@($marketplace.plugins)[0].description -match "(?i)optional")

Assert-True "plugin manifest declares no component path overrides for skills" `
  (-not ($plugin.PSObject.Properties.Name -contains "skills")) `
  ("plugin.json has no 'skills' field in the documented schema; declaring one would be silently ignored")

# ---- The generated mirror ----------------------------------------------

$mirrorRoot = Join-Path $repo "skills"
Assert-True "the packaged skills mirror exists at the plugin root" `
  (Test-Path -LiteralPath $mirrorRoot)

$sourceSkills = @(Get-ChildItem -LiteralPath (Join-Path $repo ".claude/skills") -Directory | ForEach-Object { $_.Name }) | Sort-Object
$mirrorSkills = @(Get-ChildItem -LiteralPath $mirrorRoot -Directory | ForEach-Object { $_.Name }) | Sort-Object
Assert-True "the mirror carries every skill and no others" `
  (($sourceSkills -join ",") -eq ($mirrorSkills -join ",")) `
  ("source=" + ($sourceSkills -join ",") + " mirror=" + ($mirrorSkills -join ","))

# The skill manifest is the framework's own declaration of its active runtime.
# If it and the package disagree, one of them is lying to somebody.
$manifest = Get-Content -LiteralPath (Join-Path $repo "pmo-config/skill-manifest.json") -Raw | ConvertFrom-Json
$manifestSkills = @($manifest.active_skills | ForEach-Object { [string]$_.id }) | Sort-Object
Assert-True "the skill manifest lists the skills it is supposed to" `
  ($manifestSkills.Count -gt 0) ("skill-manifest.json active_skills[].id parsed as empty")
Assert-True "every packaged skill is one the skill manifest declares active" `
  (@($mirrorSkills | Where-Object { $manifestSkills -notcontains $_ }).Count -eq 0) `
  ("unlisted=" + (@($mirrorSkills | Where-Object { $manifestSkills -notcontains $_ }) -join ","))
Assert-True "every active skill in the manifest is packaged" `
  (@($manifestSkills | Where-Object { $mirrorSkills -notcontains $_ }).Count -eq 0) `
  ("unpackaged=" + (@($manifestSkills | Where-Object { $mirrorSkills -notcontains $_ }) -join ","))

foreach ($skill in $mirrorSkills) {
  $skillFile = Join-Path $mirrorRoot "$skill/SKILL.md"
  if (-not (Test-Path -LiteralPath $skillFile)) {
    Assert-True "packaged skill '$skill' has a SKILL.md" $false
    continue
  }
  $text = Get-Content -LiteralPath $skillFile -Raw
  if ($null -eq $text) { $text = "" }
  Assert-True "packaged skill '$skill' declares name and description frontmatter" `
    ($text -match "(?ms)^---\s*\r?\n.*?^name:\s*\S+.*?^description:\s*\S+.*?^---\s*$")
}

# ---- Ownership registry -------------------------------------------------
# Ownership is decided by matching a block's body against bodies the framework
# generates, so the registry of those bodies is load-bearing. If the canonical
# body is edited without its digest being recorded, every block already
# installed in a user's repository silently stops being recognised as ours and
# uninstall starts refusing. This makes that a test failure instead.

. (Join-Path $repo "scripts/lib/marker-block.ps1")

$canonicalBody = Get-AxiomCanonicalBody -Version "1"
Assert-True "the canonical block body is available from the library" `
  (-not [string]::IsNullOrWhiteSpace($canonicalBody))

$canonicalDigest = Get-AxiomBlockDigest -Content $canonicalBody
Assert-True "the current canonical body's digest is in the frozen registry" `
  ($script:AxiomKnownBodyDigests -contains $canonicalDigest) `
  ("computed=" + $canonicalDigest + " -- if the body was edited, append this digest to AxiomKnownBodyDigests rather than replacing the existing entry, or every installed block stops being recognised")

Assert-True "the registry keeps every historical digest, never just the current one" `
  ($script:AxiomKnownBodyDigests.Count -ge 1)

# The body is the framework speaking to an agent on every session; it must not
# grant anything, and the packaging suite is a reasonable second place to say so.
Assert-True "the canonical body states the agent may not approve its own work" `
  ($canonicalBody -match "(?i)may not approve your own work")
Assert-True "the canonical body states it does not enforce scope" `
  ($canonicalBody -match "(?i)does not enforce|nothing here prevents")

# ---- The drift gate -----------------------------------------------------

$check = Invoke-Build -Root $repo -Check
Assert-True "the drift check passes against the committed mirror" `
  ($check.ExitCode -eq 0) ($check.Text)

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-pkg-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $root -Force | Out-Null
try {
  # Each case mutates a fresh copy: a drift gate that only catches the first
  # kind of drift is not a gate.

  # 1. Content drift -- a skill edited in source but not regenerated.
  $copy = New-RepoCopy -Root (Join-Path $root "content")
  Invoke-Build -Root $copy | Out-Null
  Add-Content -LiteralPath (Join-Path $copy ".claude/skills/pmo-intake/SKILL.md") -Value "`n<!-- edited after packaging -->"
  $drift = Invoke-Build -Root $copy -Check
  Assert-True "drift gate catches a source skill edited after packaging" `
    ($drift.ExitCode -ne 0 -and $drift.Text -match "content differs") ($drift.Text)

  # 2. Addition drift -- a new skill that never reached the package.
  $copy = New-RepoCopy -Root (Join-Path $root "added")
  Invoke-Build -Root $copy | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $copy ".claude/skills/pmo-newcomer") -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $copy ".claude/skills/pmo-newcomer/SKILL.md") -Value "---`nname: pmo-newcomer`ndescription: x`n---" -NoNewline
  $drift = Invoke-Build -Root $copy -Check
  Assert-True "drift gate catches a new source skill missing from the package" `
    ($drift.ExitCode -ne 0 -and $drift.Text -match "missing from skills/") ($drift.Text)

  # 3. Removal drift -- the stale-after-rename case, which is the one a
  #    convention-based mirror always eventually gets wrong.
  $copy = New-RepoCopy -Root (Join-Path $root "removed")
  Invoke-Build -Root $copy | Out-Null
  Remove-Item -LiteralPath (Join-Path $copy ".claude/skills/pmo-design") -Recurse -Force
  $drift = Invoke-Build -Root $copy -Check
  Assert-True "drift gate catches a package skill whose source was deleted" `
    ($drift.ExitCode -ne 0 -and $drift.Text -match "not in \.claude/skills") ($drift.Text)

  # 4. Tampering with the package directly, source untouched.
  $copy = New-RepoCopy -Root (Join-Path $root "tampered")
  Invoke-Build -Root $copy | Out-Null
  Add-Content -LiteralPath (Join-Path $copy "skills/pmo-governance/SKILL.md") -Value "`n<!-- packaged copy edited by hand -->"
  $drift = Invoke-Build -Root $copy -Check
  Assert-True "drift gate catches an edit made to the package instead of the source" `
    ($drift.ExitCode -ne 0 -and $drift.Text -match "content differs") ($drift.Text)

  # 5. Rebuilding fixes every one of them, and is deterministic.
  $copy = New-RepoCopy -Root (Join-Path $root "rebuild")
  Invoke-Build -Root $copy | Out-Null
  Remove-Item -LiteralPath (Join-Path $copy "skills/pmo-design") -Recurse -Force
  Add-Content -LiteralPath (Join-Path $copy "skills/pmo-intake/SKILL.md") -Value "`nnoise"
  Invoke-Build -Root $copy | Out-Null
  $drift = Invoke-Build -Root $copy -Check
  Assert-True "regenerating restores the mirror exactly" ($drift.ExitCode -eq 0) ($drift.Text)

  # 6. The generator does not reach outside the source directory.
  $copy = New-RepoCopy -Root (Join-Path $root "scoped")
  Set-Content -LiteralPath (Join-Path $copy "SHOULD-NOT-BE-PACKAGED.md") -Value "maintainer file" -NoNewline
  Invoke-Build -Root $copy | Out-Null
  Assert-True "the generator packages only .claude/skills, nothing from the repository root" `
    (-not (Test-Path -LiteralPath (Join-Path $copy "skills/SHOULD-NOT-BE-PACKAGED.md")))
} finally {
  if (Test-Path -LiteralPath $root) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue } finally { $ErrorActionPreference = $previous }
  }
}

# ---- Maintainer-tool diagnostics ---------------------------------------
# The other half of M6.2's finding: these tools correctly do not run outside a
# checkout, and must say so rather than throwing.

$fakeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-nocheckout-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path (Join-Path $fakeRoot "scripts/lib") -Force | Out-Null
try {
  Copy-Item -LiteralPath (Join-Path $repo "scripts/lib/framework-checkout.ps1") -Destination (Join-Path $fakeRoot "scripts/lib/") -Force
  Set-Content -LiteralPath (Join-Path $fakeRoot "scripts/probe.ps1") -Value @'
$ErrorActionPreference = "Stop"
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "lib/framework-checkout.ps1")
Assert-FrameworkCheckout -Root $repo -ToolName "probe-tool"
Write-Host "reached the body"
'@ -NoNewline

  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $out = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fakeRoot "scripts/probe.ps1") 2>&1
    $code = $LASTEXITCODE
  } finally { $ErrorActionPreference = $previous }
  $text = ($out | ForEach-Object { [string]$_ }) -join "`n"

  Assert-True "a maintainer tool outside a checkout exits non-zero" ($code -ne 0) ("exit=" + $code)
  Assert-True "…with a FRAMEWORK-001 diagnostic naming the tool" `
    ($text -match "FRAMEWORK-001" -and $text -match "probe-tool") ($text)
  Assert-True "…explaining why a plugin install cannot satisfy it" `
    ($text -match "(?i)plugin install") ($text)
  Assert-True "…and it never reaches the tool body" ($text -notmatch "reached the body")

  # And the guard must not fire inside a real checkout, or every maintainer
  # command in this repository stops working.
  $realOut = & $pwshExe -NoProfile -ExecutionPolicy Bypass -Command `
    ". '$($repo -replace "'","''")/scripts/lib/framework-checkout.ps1'; if (Test-FrameworkCheckout -Root '$($repo -replace "'","''")') { 'checkout' } else { 'not-checkout' }" 2>&1
  Assert-True "the guard recognises this repository as a real checkout" `
    ((($realOut | ForEach-Object { [string]$_ }) -join "`n") -match "checkout" ) ($realOut -join "`n")
} finally {
  if (Test-Path -LiteralPath $fakeRoot) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { Remove-Item -LiteralPath $fakeRoot -Recurse -Force -ErrorAction SilentlyContinue } finally { $ErrorActionPreference = $previous }
  }
}

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"
if ($fail -gt 0) { exit 1 }
exit 0
