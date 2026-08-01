param(
  [string]$RepoPath = (Resolve-Path ".").Path,
  [string]$SkillRootOverride = "",
  [string]$TemplateRootOverride = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/ordinal-sort.ps1")
. (Join-Path $PSScriptRoot "lib/markdown-files.ps1")

$root = Resolve-Path -LiteralPath $RepoPath
$repo = $root.Path

# Maintainer-only: audits the framework's own checkout, so it fails with a
# diagnostic rather than a raw exception when run from a packaged install.
. (Join-Path $PSScriptRoot "lib/framework-checkout.ps1")
Assert-FrameworkCheckout -Root $repo -ToolName "pmo-doctor" -Alternative "scripts/validate-project.ps1 -ProjectPath <your project>"
$policyPath = Join-Path $repo "pmo-config/policy.json"
$skillManifestPath = Join-Path $repo "pmo-config/skill-manifest.json"
$validationRulesPath = Join-Path $repo "pmo-config/validation-rules.json"
$referenceTypesPath = Join-Path $repo "pmo-config/reference-types.json"
$artifactPolicyPath = Join-Path $repo "pmo-config/artifact-policy.json"
$handoffPolicyPath = Join-Path $repo "pmo-config/handoff-policy.json"
$diagnosticsSchemaPath = Join-Path $repo "pmo-config/diagnostics-schema.json"
$policy = $null
$skillManifest = $null
$validationRules = $null
$referenceTypesConfig = $null
$artifactPolicy = $null
$handoffPolicy = $null
$diagnosticsSchema = $null
if (Test-Path -LiteralPath $policyPath -PathType Leaf) {
  $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
}
if (Test-Path -LiteralPath $skillManifestPath -PathType Leaf) {
  $skillManifest = Get-Content -LiteralPath $skillManifestPath -Raw | ConvertFrom-Json
}
if (Test-Path -LiteralPath $validationRulesPath -PathType Leaf) {
  $validationRules = Get-Content -LiteralPath $validationRulesPath -Raw | ConvertFrom-Json
}
if (Test-Path -LiteralPath $referenceTypesPath -PathType Leaf) {
  $referenceTypesConfig = Get-Content -LiteralPath $referenceTypesPath -Raw | ConvertFrom-Json
}
if (Test-Path -LiteralPath $artifactPolicyPath -PathType Leaf) {
  $artifactPolicy = Get-Content -LiteralPath $artifactPolicyPath -Raw | ConvertFrom-Json
}
if (Test-Path -LiteralPath $handoffPolicyPath -PathType Leaf) {
  $handoffPolicy = Get-Content -LiteralPath $handoffPolicyPath -Raw | ConvertFrom-Json
}
if (Test-Path -LiteralPath $diagnosticsSchemaPath -PathType Leaf) {
  $diagnosticsSchema = Get-Content -LiteralPath $diagnosticsSchemaPath -Raw | ConvertFrom-Json
}

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

function Get-MarkdownTableDiagnostics {
  param([string]$Path)

  $diagnostics = @()
  $lines = Read-MarkdownText -Path $Path
  $tableStart = -1
  $tableLines = @()

  for ($i = 0; $i -le $lines.Count; $i++) {
    $line = if ($i -lt $lines.Count) { $lines[$i] } else { "" }
    if ($line -match '^\s*\|') {
      if ($tableStart -lt 0) { $tableStart = $i + 1 }
      $tableLines += $line
      continue
    }

    if ($tableLines.Count -gt 0) {
      if ($tableLines.Count -ge 2) {
        $headerCount = (($tableLines[0] -split '\|').Count - 2)
        for ($j = 1; $j -lt $tableLines.Count; $j++) {
          $cellCount = (($tableLines[$j] -split '\|').Count - 2)
          if ($cellCount -ne $headerCount) {
            $diagnostics += "$Path line $($tableStart + $j): expected $headerCount columns, got $cellCount"
          }
        }
      }
      $tableStart = -1
      $tableLines = @()
    }
  }

  return $diagnostics
}

function Test-SkillFrontmatter {
  param(
    [string]$SkillsRoot,
    [string[]]$ExpectedSkills
  )

  $problems = @()
  foreach ($skill in $ExpectedSkills) {
    $skillFile = Join-Path (Join-Path $SkillsRoot $skill) "SKILL.md"
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
      $problems += "$skill missing SKILL.md"
      continue
    }

    $text = Read-MarkdownText -Path $skillFile -Raw
    if ($text -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') {
      $problems += "$skill missing YAML frontmatter"
      continue
    }

    $frontmatter = $Matches[1]
    $nameMatch = [regex]::Match($frontmatter, '(?m)^\s*name:\s*(.+?)\s*$')
    $descriptionMatch = [regex]::Match($frontmatter, '(?m)^\s*description:\s*(.+?)\s*$')
    if (-not $nameMatch.Success) {
      $problems += "$skill missing frontmatter name"
    } elseif ($nameMatch.Groups[1].Value.Trim() -ne $skill) {
      $problems += "$skill frontmatter name does not match folder"
    }
    if (-not $descriptionMatch.Success -or $descriptionMatch.Groups[1].Value.Trim().Length -lt 12) {
      $problems += "$skill missing useful frontmatter description"
    }
  }

  if ($problems.Count -eq 0) {
    Add-Result PASS "Active skill frontmatter is valid" "DOCTOR-SKILL-001"
  } else {
    Add-Result FAIL ("Active skill frontmatter problems: " + (($problems | Select-Object -First 8) -join "; ")) "DOCTOR-SKILL-001"
  }
}

function Test-MarkdownTables {
  param([string]$RootPath)

  $problems = @()
  if (Test-Path -LiteralPath $RootPath) {
    foreach ($file in Get-MarkdownFiles -RootPath $RootPath) {
      $problems += Get-MarkdownTableDiagnostics $file.FullName
    }
  }

  if ($problems.Count -eq 0) {
    Add-Result PASS "Markdown table column counts are consistent" "TABLE-001"
  } else {
    Add-Result FAIL ("Markdown table column mismatch: " + (($problems | Select-Object -First 8) -join "; ")) "TABLE-001"
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
Require-File "pmo-config/context-map.json"
Require-File "pmo-config/policy.json"
Require-File "pmo-config/skill-manifest.json"
Require-File "pmo-config/validation-rules.json"
Require-File "pmo-config/artifact-policy.json"
Require-File "pmo-config/reference-types.json"
Require-File "scripts/validate-project.ps1"
Require-File "scripts/pmo-doctor.ps1"
Require-File "scripts/run-validation-tests.ps1"
Require-File "scripts/run-all-checks.ps1"
Require-File "scripts/new-project.ps1"
Require-File "scripts/update-source-snapshot.ps1"
Require-File "scripts/measure-context.ps1"

$templateNames = @("PROJECT.md", "DELIVERY.md", "RELEASE.md", "RAID-log.md", "decision-log.md", "RTM.json", "WIREFRAME.md")
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

$activeSkills = @($skillManifest.active_skills | ForEach-Object { $_.id })
if ($activeSkills.Count -eq 0) {
  Add-Result FAIL "No active skills declared in pmo-config/skill-manifest.json" "DOCTOR-001"
}
$skillsRoot = if ($SkillRootOverride) { (Resolve-Path -LiteralPath $SkillRootOverride).Path } else { Join-Path $repo ".claude/skills" }
$actualSkills = @()
if (Test-Path -LiteralPath $skillsRoot -PathType Container) {
  $actualSkills = @(Get-ChildItem -LiteralPath $skillsRoot -Directory | Select-Object -ExpandProperty Name)
}

$missingActive = @($activeSkills | Where-Object { $actualSkills -notcontains $_ })
$extraActive = @($actualSkills | Where-Object { $activeSkills -notcontains $_ })
if ($missingActive.Count -eq 0 -and $extraActive.Count -eq 0) {
  Add-Result PASS "Active skill runtime contains exactly 7 skills" "DOCTOR-001"
} else {
  if ($missingActive.Count -gt 0) { Add-Result FAIL ("Missing active skills: " + ($missingActive -join ", ")) "DOCTOR-001" }
  if ($extraActive.Count -gt 0) { Add-Result FAIL ("Unexpected active skills: " + ($extraActive -join ", ")) "DOCTOR-001" }
}

Test-SkillFrontmatter $skillsRoot $activeSkills

$templateRoot = if ($TemplateRootOverride) { (Resolve-Path -LiteralPath $TemplateRootOverride).Path } else { Join-Path $repo "templates" }
Test-MarkdownTables $templateRoot

$contextMapPath = Join-Path $repo "pmo-config/context-map.json"
$contextMapConfig = $null
if (Test-Path -LiteralPath $contextMapPath -PathType Leaf) {
  $contextMapConfig = Get-Content -LiteralPath $contextMapPath -Raw | ConvertFrom-Json
}
if ($contextMapConfig -and
    $contextMapConfig.config_refs.policy -eq "pmo-config/policy.json" -and
    $contextMapConfig.config_refs.skill_manifest -eq "pmo-config/skill-manifest.json" -and
    $contextMapConfig.config_refs.validation_rules -eq "pmo-config/validation-rules.json") {
  Add-Result PASS "Context map references central policy and skill manifest" "DOCTOR-003"
} else {
  Add-Result FAIL "Context map must reference JSON runtime config files" "DOCTOR-003"
}
if ($validationRules -and $validationRules.rules.'STRUCT-001' -and $validationRules.rules.'ENUM-001' -and $validationRules.rules.'DOCTOR-001') {
  Add-Result PASS "Validation rule catalog parses from JSON runtime config" "DOCTOR-003"
} else {
  Add-Result FAIL "Validation rule catalog is missing required runtime rules" "DOCTOR-003"
}

$versionText = (Get-Content -LiteralPath (Join-Path $repo "VERSION") -Raw).Trim()
$changelogFirstVersion = ""
$changelogText = Read-MarkdownText -Path (Join-Path $repo "CHANGELOG.md") -Raw
if ($changelogText -match '(?m)^##\s+([^\s]+)\s+-') {
  $changelogFirstVersion = $Matches[1]
}
$configVersions = @($policy.version, $skillManifest.version, $validationRules.version, $contextMapConfig.version, $handoffPolicy.version, $diagnosticsSchema.version) | Where-Object { $_ }
if ($versionText -eq $changelogFirstVersion -and ($configVersions | Where-Object { $_ -ne $versionText }).Count -eq 0) {
  Add-Result PASS "VERSION, CHANGELOG, and JSON config versions match" "DOCTOR-005"
} else {
  Add-Result FAIL "Version drift: VERSION=$versionText CHANGELOG=$changelogFirstVersion CONFIG=$($configVersions -join ',')" "DOCTOR-005"
}

# P7.3: every machine-readable config carries schema_version, distinct from
# the app-release `version` above -- lets the validator warn/fail on a config
# shape it does not understand instead of silently misreading old fields.
$supportedSchemaVersion = "1.0"
$schemaVersionConfigs = [ordered]@{
  "policy.json" = $policy
  "artifact-policy.json" = $artifactPolicy
  "reference-types.json" = $referenceTypesConfig
  "skill-manifest.json" = $skillManifest
  "validation-rules.json" = $validationRules
  "context-map.json" = $contextMapConfig
  "handoff-policy.json" = $handoffPolicy
  "diagnostics-schema.json" = $diagnosticsSchema
}
$schemaVersionProblems = @()
foreach ($name in $schemaVersionConfigs.Keys) {
  $cfg = $schemaVersionConfigs[$name]
  if (-not $cfg) { continue }
  if (-not $cfg.schema_version) {
    $schemaVersionProblems += "$name is missing schema_version"
  } elseif ($cfg.schema_version -ne $supportedSchemaVersion) {
    $schemaVersionProblems += "$name has unsupported schema_version $($cfg.schema_version) (expected $supportedSchemaVersion)"
  }
}
if ($schemaVersionProblems.Count -eq 0) {
  Add-Result PASS "All pmo-config/*.json carry a supported schema_version ($supportedSchemaVersion)" "DOCTOR-006"
} else {
  Add-Result FAIL ("Config schema_version problems: " + ($schemaVersionProblems -join "; ")) "DOCTOR-006"
}

# DOCTOR-007 (H6): the rule catalog (validation-rules.json) must be complete
# and have no dead entries. Scan the actual emitters -- validate-project.ps1,
# scripts/lib/*.ps1, pmo-doctor.ps1 -- for every rule id passed to Add-Result
# (directly, via Test-ReviewRow's rule-id argument, or as an Add-Result/$RuleId
# default) and reconcile that set against the catalog both ways. Example
# project codes (STRICT-HIGH-RISK, etc.) live on skill/registry lines, not
# emitter lines, so they are not mistaken for rule ids.
$emitterFiles = @()
$emitterFiles += Join-Path $repo "scripts/validate-project.ps1"
$emitterFiles += Join-Path $repo "scripts/pmo-doctor.ps1"
$libDir = Join-Path $repo "scripts/lib"
if (Test-Path -LiteralPath $libDir -PathType Container) {
  $emitterFiles += @(Get-ChildItem -LiteralPath $libDir -Filter *.ps1 -File | ForEach-Object { $_.FullName })
}
$emittedRuleIds = New-Object System.Collections.Generic.HashSet[string]
foreach ($file in $emitterFiles) {
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
  foreach ($line in (Get-Content -LiteralPath $file)) {
    if ($line -notmatch 'Add-Result|Test-ReviewRow|\$RuleId\s*=') { continue }
    foreach ($m in [regex]::Matches($line, '"([A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+)"')) {
      [void]$emittedRuleIds.Add($m.Groups[1].Value)
    }
  }
}
$catalogRuleIds = @()
if ($validationRules -and $validationRules.rules) {
  $catalogRuleIds = @($validationRules.rules.PSObject.Properties.Name)
}
$missingFromCatalog = @($emittedRuleIds | Where-Object { $catalogRuleIds -notcontains $_ } | Sort-Object)
$deadCatalogEntries = @($catalogRuleIds | Where-Object { -not $emittedRuleIds.Contains($_) } | Sort-Object)
if ($missingFromCatalog.Count -eq 0 -and $deadCatalogEntries.Count -eq 0) {
  Add-Result PASS "Validation rule catalog matches the rule ids emitted by the scripts" "DOCTOR-007"
} else {
  if ($missingFromCatalog.Count -gt 0) {
    Add-Result FAIL ("Rule ids emitted but missing from validation-rules.json: " + ($missingFromCatalog -join ", ")) "DOCTOR-007"
  }
  if ($deadCatalogEntries.Count -gt 0) {
    Add-Result FAIL ("Dead catalog entries (in validation-rules.json but never emitted): " + ($deadCatalogEntries -join ", ")) "DOCTOR-007"
  }
}

# DOCTOR-008: every rule that can produce an actionable diagnostic must carry
# remediation text. A FAIL that says only what broke, with no "here is what to
# do", is the failure mode this whole diagnostics contract exists to prevent.
# INFO-only rules are exempt: they never render a suggestion.
$actionableSeverities = @("fail", "fail_release", "warn")
$rulesWithoutSuggestion = @()
if ($validationRules -and $validationRules.rules) {
  foreach ($prop in $validationRules.rules.PSObject.Properties) {
    $entry = $prop.Value
    if ($actionableSeverities -notcontains [string]$entry.severity) { continue }
    if ([string]::IsNullOrWhiteSpace([string]$entry.suggestion)) {
      $rulesWithoutSuggestion += $prop.Name
    }
  }
}
if ($rulesWithoutSuggestion.Count -eq 0) {
  Add-Result PASS "Every fail/warn rule in the catalog carries a suggestion" "DOCTOR-008"
} else {
  Add-Result FAIL ("Rules missing a suggestion: " + ((Sort-Ordinal -Values ([string[]]$rulesWithoutSuggestion)) -join ", ")) "DOCTOR-008"
}

# DOCTOR-009: a documentation_url must never 404. The catalog stores a
# repo-relative path; the emitted URL is that path joined to
# documentation_base_url, so if the file is absent every diagnostic for that
# rule advertises a dead link.
$rulesWithBrokenDocs = @()
if ($validationRules -and $validationRules.rules) {
  foreach ($prop in $validationRules.rules.PSObject.Properties) {
    $docPath = [string]$prop.Value.documentation
    if ([string]::IsNullOrWhiteSpace($docPath)) { continue }
    if (-not (Test-Path -LiteralPath (Join-Path $repo $docPath) -PathType Leaf)) {
      $rulesWithBrokenDocs += "$($prop.Name) -> $docPath"
    }
  }
}
if ($rulesWithBrokenDocs.Count -eq 0) {
  Add-Result PASS "Every rule documentation path resolves to a file" "DOCTOR-009"
} else {
  Add-Result FAIL ("Rules with unresolvable documentation: " + ((Sort-Ordinal -Values ([string[]]$rulesWithBrokenDocs)) -join ", ")) "DOCTOR-009"
}

# DOCTOR-010: native command invocations must be guarded against Windows
# PowerShell 5.1's stderr-as-terminating-error behaviour.
#
# This check exists because the same defect shipped three times. Under
# $ErrorActionPreference = "Stop", 5.1 converts ANY native command's stderr
# into a terminating error -- including purely informational output, and
# despite `2>$null`. PowerShell 7 does not, so it is invisible on the host
# most of this repo is written on, and it kills a script outright rather than
# producing a wrong answer. It has cost: a whole test file (git's CRLF
# notice), the ci-check adapter (`git remote get-url` on a repo with no
# remote), and the execution runner (any test command that writes to stderr
# while passing -- npm, pytest, and jest all do).
#
# The rule this encodes: in a script that sets "Stop", every native
# invocation either drops to "Continue" around the call, or matches one of
# the two safe patterns below. Documented in
# docs/architecture/powershell-portability.md §1.
#
# Deliberately a lexical check, not a parse: it looks at the ~15 lines before
# each invocation for a "Continue" assignment or a wrapper call. That is
# crude, but a false positive is a comment away from resolved while a false
# negative is a crash on a host the author cannot run -- and a full AST
# dataflow analysis to decide "is EAP Continue here" is far more machinery
# than this earns.
#
# Scoped to scripts/ (product code) rather than tests/ as well, and the
# reason is about consequence, not convenience: an unguarded call in a test
# harness crashes loudly in CI, which is annoying but self-revealing; the
# same call in product code crashes on a *user's* machine, on a host the
# maintainer cannot reproduce, and looks like the tool being broken. The
# ~50 equivalent sites under tests/ are real instances of the same class and
# are recorded as known debt in
# docs/architecture/powershell-portability.md rather than quietly excluded
# -- narrowing the scan is a scoping decision, not permission to write
# unguarded calls in tests.
$nativeGuardProblems = @()
$psFilesToScan = @(Get-ChildItem -LiteralPath (Join-Path $repo "scripts") -Filter *.ps1 -File -Recurse -ErrorAction SilentlyContinue)

foreach ($psFile in $psFilesToScan) {
  $psText = Get-Content -LiteralPath $psFile.FullName -Raw
  if ($null -eq $psText) { continue }
  # Only files that actually set "Stop" can exhibit the failure.
  if ($psText -notmatch '\$ErrorActionPreference\s*=\s*[''"]Stop[''"]') { continue }

  $psLines = $psText -split "`r?`n"
  for ($i = 0; $i -lt $psLines.Count; $i++) {
    $line = $psLines[$i]
    if ($line -match '^\s*#') { continue }
    # A native invocation: `& git ...`, `& gh ...`, or `& $someExe ...`.
    if ($line -notmatch '&\s*(git|gh|\$\w*([Ee]xe|[Ss]hell)\w*)\b') { continue }

    # Safe pattern 1: --quiet suppresses git's stderr by design.
    if ($line -match '--quiet') { continue }
    # Safe pattern 2: redirecting to a real file is a different mechanism and
    # does not raise; it is also how a caller keeps stderr text for a log.
    if ($line -match '2>\$\w*[Ss]tderr\w*') { continue }
    # Safe pattern 3: the call is already inside a named wrapper that guards.
    if ($line -match 'Invoke-NativeCapture|Invoke-FixtureGit|Get-FixtureGit') { continue }

    $windowStart = [Math]::Max(0, $i - 15)
    $window = ($psLines[$windowStart..$i]) -join "`n"
    if ($window -match '\$ErrorActionPreference\s*=\s*[''"]Continue[''"]') { continue }

    $relative = $psFile.FullName.Substring($repo.Length).TrimStart('\', '/') -replace '\\', '/'
    $nativeGuardProblems += "$relative line $($i + 1)"
  }
}
if ($nativeGuardProblems.Count -eq 0) {
  Add-Result PASS "Native command invocations are guarded against PowerShell 5.1 stderr-as-error" "DOCTOR-010"
} else {
  Add-Result FAIL ("Unguarded native invocations under ErrorActionPreference=Stop (see docs/architecture/powershell-portability.md): " + ((Sort-Ordinal -Values ([string[]]$nativeGuardProblems)) -join ", ")) "DOCTOR-010"
}

# DOCTOR-012: decision ids in the framework's own decision-log.md must be unique.
#
# A decision id is a reference target -- ROADMAP, CHANGELOG and the EXEC rules
# all cite them, and Milestone 5's authority model resolves them at runtime and
# treats "more than one match" as ambiguous. Two rows sharing an id makes every
# citation of it unresolvable.
#
# This is not hypothetical: DEC-003 was used for both the Milestone 6.0
# integration-shape decision and the product-scope-boundary decision, and a
# review found it. Nothing in the framework noticed, because nothing was
# looking.
$decisionLogPath = Join-Path $repo "decision-log.md"
if (Test-Path -LiteralPath $decisionLogPath) {
  $decisionText = Get-Content -LiteralPath $decisionLogPath -Raw
  if ($null -eq $decisionText) { $decisionText = "" }
  $decisionIds = @()
  foreach ($line in ($decisionText -split "`r?`n")) {
    # Table rows only: the id must sit in its own cell, so prose mentioning a
    # DEC-### does not count as a second declaration of it.
    $m = [regex]::Match($line, '^\s*\|[^|]*\|\s*(DEC-\d{3,})\s*\|')
    if ($m.Success) { $decisionIds += $m.Groups[1].Value }
  }
  $duplicateDecisions = @($decisionIds | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { "$($_.Name) x$($_.Count)" })
  if ($duplicateDecisions.Count -eq 0) {
    Add-Result PASS "Decision ids in decision-log.md are unique ($($decisionIds.Count) decisions)" "DOCTOR-012"
  } else {
    Add-Result FAIL ("Duplicate decision ids in decision-log.md -- every citation of these is ambiguous: " + ((Sort-Ordinal -Values ([string[]]$duplicateDecisions)) -join ", ")) "DOCTOR-012"
  }
} else {
  Add-Result FAIL "decision-log.md not found" "DOCTOR-012"
}

# DOCTOR-011: $IsWindows must not be used as a bare host test.
#
# It does not exist in Windows PowerShell 5.1 -- it is $null there, and 5.1
# only ever runs on Windows. So `if ($IsWindows -ne $true)` is TRUE on 5.1,
# and every branch written as "Unix only" runs on Windows anyway. So does
# `if ($null -eq $IsWindows)` written to mean "Unix".
#
# Same shape as DOCTOR-010 and encoded for the same reason: it is invisible on
# the host this repository is written on. It shipped in the Milestone 6.3 and
# 6.5 test suites -- a symlink case and a `chmod` case both ran on Windows
# PowerShell 5.1, where neither could work -- and only CI caught it.
#
# The safe form is Test-WindowsHost in scripts/lib/pwsh-host.ps1, which checks
# $PSVersionTable.PSEdition first. A file may still name $IsWindows as part of
# that check, so the definition itself and any line that also mentions
# PSEdition are allowed.
#
# Scanned across scripts/ AND tests/, unlike DOCTOR-010: here a wrong branch in
# a test is the whole defect, since the test silently exercises the wrong
# platform and reports a pass it did not earn.
$hostTestProblems = @()
$hostScanRoots = @("scripts", "tests") | ForEach-Object { Join-Path $repo $_ } | Where-Object { Test-Path -LiteralPath $_ }
# Two files legitimately name the variable: the helper that wraps it, and this
# check itself. Excluded by name rather than by a cleverer pattern, so the
# exclusion is visible.
$hostScanExempt = @("scripts/lib/pwsh-host.ps1", "scripts/pmo-doctor.ps1")
foreach ($scanRoot in $hostScanRoots) {
  foreach ($psFile in @(Get-ChildItem -LiteralPath $scanRoot -Filter *.ps1 -File -Recurse -ErrorAction SilentlyContinue)) {
    $relativeScan = $psFile.FullName.Substring($repo.Length).TrimStart('\', '/') -replace '\\', '/'
    if ($hostScanExempt -contains $relativeScan) { continue }
    $psText = Get-Content -LiteralPath $psFile.FullName -Raw
    if ($null -eq $psText) { continue }
    $psLines = $psText -split "`r?`n"
    for ($i = 0; $i -lt $psLines.Count; $i++) {
      $line = $psLines[$i]
      if ($line -notmatch '\$IsWindows') { continue }
      # The guarded form is fine, and so are comments explaining the pitfall.
      if ($line -match 'PSEdition') { continue }
      if ($line -match '^\s*#') { continue }
      $relative = $psFile.FullName.Substring($repo.Length).TrimStart('\', '/') -replace '\\', '/'
      $hostTestProblems += "$relative line $($i + 1)"
    }
  }
}
if ($hostTestProblems.Count -eq 0) {
  Add-Result PASS 'No bare $IsWindows host tests (it is $null on Windows PowerShell 5.1)' "DOCTOR-011"
} else {
  Add-Result FAIL ('Bare $IsWindows host tests -- use Test-WindowsHost from scripts/lib/pwsh-host.ps1: ' + ((Sort-Ordinal -Values ([string[]]$hostTestProblems)) -join ", ")) "DOCTOR-011"
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
  $denyText = $denyEntries -join "`n"
  if ($denyText -match "\.env" -and $denyText -match "\.pem" -and $denyText -match "\.pfx" -and $denyText -match "id_rsa" -and $denyText -match "id_ed25519") {
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
  if (($allowEntries -join "`n") -match "\bWebSearch\b") {
    Add-Result FAIL ".claude/settings.json allows WebSearch without approval" "PERMISSION-006"
  } elseif (($askEntries -join "`n") -match "\bWebSearch\b") {
    Add-Result PASS ".claude/settings.json asks before WebSearch" "PERMISSION-006"
  } else {
    Add-Result WARN ".claude/settings.json does not mention WebSearch" "PERMISSION-006"
  }

  if ($settings -match "echo 'PMO-") {
    Add-Result FAIL "Fake PMO echo hooks still exist" "DOCTOR-HOOK"
  } else {
    Add-Result PASS "No fake PMO echo hooks found in settings" "DOCTOR-HOOK"
  }
} else {
  Add-Result WARN ".claude/settings.json not found" "PERMISSION-002"
}

$gitignorePath = Join-Path $repo ".gitignore"
if (Test-Path -LiteralPath $gitignorePath -PathType Leaf) {
  $gitignore = Get-Content -LiteralPath $gitignorePath -Raw
  $requiredIgnorePatterns = @(".env", ".env.*", "*.pem", "*.key", "*.pfx", "*.p12", "id_rsa", "id_ed25519")
  $missingIgnores = @($requiredIgnorePatterns | Where-Object { $gitignore -notmatch ("(?m)^" + [regex]::Escape($_) + "\r?$") })
  $staleIgnores = @("P13-RR-EWALLET/Others/Figma Flow/", "P*/SystemFlow/PDF_*/") | Where-Object { $gitignore -match [regex]::Escape($_) }
  if ($missingIgnores.Count -eq 0 -and $staleIgnores.Count -eq 0 -and $gitignore -notmatch '\*\*/\*secret\*|\*\*/\*credential\*') {
    Add-Result PASS ".gitignore uses precise sensitive-file patterns" "PERMISSION-007"
  } else {
    Add-Result FAIL ".gitignore sensitive patterns need cleanup: missing=$($missingIgnores -join ',') stale=$($staleIgnores -join ',')" "PERMISSION-007"
  }
}

$claude = Read-MarkdownText -Path (Join-Path $repo "CLAUDE.md") -Raw
$agent = Read-MarkdownText -Path (Join-Path $repo "AGENTS.md") -Raw

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

$legacyPatterns = @("SystemFlow", "UserFlow", "TaskBreakdown")
# "log every"/"Logging every" needs its own line-level check: a skill saying
# "Do not ... log every minor AI action ..." is stating the desired
# prohibition, not committing the legacy over-logging anti-pattern the rule
# was written to catch, so only flag lines that lack a negation cue.
$loggingEveryPattern = "Logging every|log every"
foreach ($skill in $actualSkills) {
  $skillPath = Join-Path $skillsRoot $skill
  $hits = @()
  foreach ($file in Get-MarkdownFiles -RootPath $skillPath) {
    $content = Read-MarkdownText -Path $file.FullName -Raw
    foreach ($pattern in $legacyPatterns) {
      if ($content -match [regex]::Escape($pattern)) {
        $hits += "$skill/$($file.Name):$pattern"
      }
    }
    $loggingLines = @(($content -split "`r?`n") | Where-Object { $_ -match $loggingEveryPattern })
    $unprohibitedLoggingLines = @($loggingLines | Where-Object { $_ -notmatch "(?i)\b(do not|never|avoid|without)\b" })
    if ($unprohibitedLoggingLines.Count -gt 0) {
      $hits += "$skill/$($file.Name):log every"
    }
  }
  if ($hits.Count -gt 0) {
    Add-Result FAIL ("Active skill has legacy rule references: " + (($hits | Select-Object -First 5) -join ", ")) "DOCTOR-004"
  }
}

$links = @()
foreach ($file in Get-MarkdownFiles -RootPath $repo) {
  if ($file.FullName -match "\\.git\\") { continue }
  $relativeFile = $file.FullName.Substring($repo.Length).TrimStart('\', '/')
  if ($relativeFile -match "^tests[\\/]fixtures[\\/]invalid-") { continue }
  if ($relativeFile -match "(^|[\\/])(source|MOM|REQ|Transcript)[\\/]") { continue }

  $content = Read-MarkdownText -Path $file.FullName -Raw
  $linkMatches = [regex]::Matches($content, "\[[^\]]+\]\((?!https?://)([^)#]+)(?:#[^)]+)?\)")
  foreach ($match in $linkMatches) {
    $target = $match.Groups[1].Value
    if ($target -match "^\s*$|^mailto:|^<") { continue }
    $base = Split-Path -Parent $file.FullName
    $pathResult = Test-MarkdownLocalLinkPath -BasePath $base -Target $target
    if (-not $pathResult.valid_path) {
      $lineNumber = 1 + [regex]::Matches($content.Substring(0, $match.Index), "\r\n|\n|\r").Count
      $links += "$relativeFile line $lineNumber -> invalid local link target"
    } elseif (-not $pathResult.exists) {
      $links += "$relativeFile -> $target"
    }
  }
}

if ($links.Count -eq 0) {
  Add-Result PASS "No broken local markdown links found"
} else {
  Add-Result WARN ("Broken local links: " + (($links | Select-Object -First 8) -join ", "))
}

Write-Host "Axiom-PMO Framework Doctor: $repo"
Write-Host ""
$messages | ForEach-Object { Write-Host "[$($_.level)] $($_.rule_id) $($_.message)" }
Write-Host ""
Write-Host "Summary: PASS=$pass WARN=$warn FAIL=$fail"

if ($fail -gt 0) {
  exit 1
}

exit 0
