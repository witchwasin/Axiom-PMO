param(
  [string]$RepoPath = ".",
  # P4 golden-master control: -CaptureGolden writes each case's raw stdout to
  # $GoldenMasterDir/<case>.txt; -VerifyGolden compares current stdout against
  # those files byte-for-byte and fails the run on any diff. Used to prove the
  # Phase 4 modular refactor changes zero observable behavior.
  [switch]$CaptureGolden,
  [switch]$VerifyGolden,
  [string]$GoldenMasterDir = (Join-Path $RepoPath "tests/golden")
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path -LiteralPath $RepoPath
$repo = $root.Path
$validator = Join-Path $repo "scripts/validate-project.ps1"

$cases = @(
  @{ Name = "example-lite-bugfix-scope"; Path = "examples/LITE-BUGFIX"; Mode = "Lite"; Gate = "Scope"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; Type = "positive" },
  @{ Name = "example-lite-bugfix-draft"; Path = "examples/LITE-BUGFIX"; Mode = "Lite"; Gate = "Draft"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; Type = "positive" },
  @{ Name = "example-standard-feature-release"; Path = "examples/STANDARD-FEATURE"; Mode = "Standard"; Gate = "Release"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; Type = "positive" },
  @{ Name = "example-strict-high-risk-release"; Path = "examples/STRICT-HIGH-RISK"; Mode = "Strict"; Gate = "Release"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; Type = "positive" },
  @{ Name = "valid-standard-release"; Path = "tests/fixtures/valid-standard"; Mode = "Standard"; Gate = "Release"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; Type = "positive" },
  @{ Name = "valid-standard-scope"; Path = "tests/fixtures/valid-standard"; Mode = "Standard"; Gate = "Scope"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; Type = "positive" },
  @{ Name = "valid-standard-draft"; Path = "tests/fixtures/valid-standard"; Mode = "Standard"; Gate = "Draft"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; Type = "positive" },
  @{ Name = "generated-project-passes-draft"; Path = "tests/fixtures/generated-project-draft"; Mode = "Lite"; Gate = "Draft"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; Type = "positive" },
  @{ Name = "lite-release-light-approval-no-decision-log"; Path = "tests/fixtures/valid-lite-release-light-approval"; Mode = "Lite"; Gate = "Release"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; Type = "positive" },
  @{ Name = "html-wireframe-not-flagged"; Path = "tests/fixtures/valid-html-wireframe"; Mode = "Standard"; Gate = "Release"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; Type = "positive" },
  @{ Name = "source-ref-REQ-V1"; Path = "tests/fixtures/valid-source-ref-REQ-V1"; Mode = "Standard"; Gate = "Release"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; Type = "positive" },
  @{ Name = "user-source-placeholders-do-not-fail-release"; Path = "tests/fixtures/valid-user-source-placeholders"; Mode = "Standard"; Gate = "Release"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; Type = "positive" },
  @{ Name = "others-and-sensitive-source-do-not-fail-release"; Path = "tests/fixtures/valid-source-others-and-sensitive"; Mode = "Standard"; Gate = "Release"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; FailOnWarning = $true; Type = "positive" },
  @{ Name = "standard-draft-no-delivery-release-required"; Path = "tests/fixtures/valid-standard-draft-minimal"; Mode = "Standard"; Gate = "Draft"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; Type = "positive" },
  @{ Name = "strict-scope-no-rtm-required"; Path = "examples/STRICT-HIGH-RISK"; Mode = "Strict"; Gate = "Scope"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; FailOnWarning = $true; Type = "positive" },

  @{ Name = "invalid-no-project"; Path = "tests/fixtures/invalid-no-project"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "STRUCT-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-missing-delivery"; Path = "tests/fixtures/invalid-missing-delivery"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "STRUCT-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-missing-release"; Path = "tests/fixtures/invalid-missing-release"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "STRUCT-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-missing-design"; Path = "tests/fixtures/invalid-missing-design"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "STRUCT-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-no-source-ref"; Path = "tests/fixtures/invalid-no-source-ref"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "SOURCE-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-no-evidence-status"; Path = "tests/fixtures/invalid-no-evidence-status"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "EVIDENCE-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-duplicate-requirement-id"; Path = "tests/fixtures/invalid-duplicate-requirement-id"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "SOURCE-003"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-source-snapshot-no-sync"; Path = "tests/fixtures/invalid-source-snapshot-no-sync"; Mode = "Standard"; Gate = "Scope"; ShouldPass = $false; Rule = "SOURCE-002"; ExpectedLevel = "WARN"; Type = "negative"; FailOnWarning = $true },
  @{ Name = "invalid-fake-approval"; Path = "tests/fixtures/invalid-fake-approval"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "APPROVAL-002"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "approval-evidence-freetext-rejected"; Path = "tests/fixtures/invalid-approval-evidence-freetext"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "APPROVAL-002"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "approval-role-mismatch-standard-blocks-warning"; Path = "tests/fixtures/invalid-approval-role-standard"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "APPROVAL-003"; ExpectedLevel = "WARN"; Type = "negative"; FailOnWarning = $true },
  @{ Name = "approval-role-mismatch-strict-fails"; Path = "tests/fixtures/invalid-approval-role-strict"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "APPROVAL-003"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-missing-scope-approval"; Path = "tests/fixtures/invalid-missing-scope-approval"; Mode = "Standard"; Gate = "Scope"; ShouldPass = $false; Rule = "APPROVAL-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-missing-design-approval"; Path = "tests/fixtures/invalid-missing-design-approval"; Mode = "Standard"; Gate = "Design"; ShouldPass = $false; Rule = "APPROVAL-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-missing-release-approval"; Path = "tests/fixtures/invalid-missing-release-approval"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "APPROVAL-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "lite-release-missing-approval"; Path = "tests/fixtures/invalid-lite-release-no-approval"; Mode = "Lite"; Gate = "Release"; ShouldPass = $false; Rule = "APPROVAL-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "lite-release-no-delivery-workitem-prose"; Path = "tests/fixtures/invalid-lite-release-no-delivery"; Mode = "Lite"; Gate = "Release"; ShouldPass = $false; Rule = "STRUCT-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "lite-approval-freetext-evidence-blocks"; Path = "tests/fixtures/invalid-lite-freetext-evidence"; Mode = "Lite"; Gate = "Release"; ShouldPass = $false; Rule = "APPROVAL-002"; ExpectedLevel = "WARN"; Type = "negative"; FailOnWarning = $true },
  @{ Name = "lite-workitem-freetext-evidence-blocks"; Path = "tests/fixtures/invalid-lite-workitem-freetext-evidence"; Mode = "Lite"; Gate = "Release"; ShouldPass = $false; Rule = "TEST-EVIDENCE-001"; ExpectedLevel = "WARN"; Type = "negative"; FailOnWarning = $true },
  @{ Name = "test-summary-still-pending"; Path = "tests/fixtures/invalid-test-summary-pending"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "TEST-RESULT-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "test-summary-evidence-unresolved"; Path = "tests/fixtures/invalid-test-summary-evidence-unresolved"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "TEST-EVIDENCE-002"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "test-summary-skipped-with-reason"; Path = "tests/fixtures/valid-test-summary-skipped-with-reason"; Mode = "Standard"; Gate = "Release"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; Type = "positive" },
  @{ Name = "not-required-in-approval"; Path = "tests/fixtures/invalid-not-required-approval"; Mode = "Lite"; Gate = "Release"; ShouldPass = $false; Rule = "APPROVAL-002"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "not-required-in-workitem"; Path = "tests/fixtures/invalid-not-required-workitem"; Mode = "Lite"; Gate = "Release"; ShouldPass = $false; Rule = "WORKITEM-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "not-required-in-rollback"; Path = "tests/fixtures/invalid-not-required-rollback"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "RELEASE-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "mode-downgrade-project-default"; Path = "examples/STRICT-HIGH-RISK"; Mode = "Lite"; Gate = "Release"; ShouldPass = $false; Rule = "MODE-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "mode-downgrade-workitem-escalation"; Path = "tests/fixtures/invalid-mode-downgrade-workitem"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "MODE-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-task-source-conflict"; Path = "tests/fixtures/invalid-task-source-conflict"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "TASK-002"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-delivery-task-source-missing"; Path = "tests/fixtures/invalid-delivery-task-source-missing"; Mode = "Standard"; Gate = "Scope"; ShouldPass = $false; Rule = "TASK-001"; ExpectedLevel = "WARN"; Type = "negative"; FailOnWarning = $true },
  @{ Name = "invalid-workitem-header-missing"; Path = "tests/fixtures/invalid-workitem-header-missing"; Mode = "Standard"; Gate = "Scope"; ShouldPass = $false; Rule = "WORKITEM-001"; ExpectedLevel = "WARN"; Type = "negative"; FailOnWarning = $true },
  @{ Name = "invalid-workitem-owner-missing"; Path = "tests/fixtures/invalid-workitem-owner-missing"; Mode = "Standard"; Gate = "Scope"; ShouldPass = $false; Rule = "WORKITEM-001"; ExpectedLevel = "WARN"; Type = "negative"; FailOnWarning = $true },
  @{ Name = "invalid-strict-trigger-standard"; Path = "tests/fixtures/invalid-strict-trigger-standard"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "STRICT-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-strict-missing-rtm"; Path = "tests/fixtures/invalid-strict-missing-rtm"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "STRICT-002"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-strict-missing-review"; Path = "tests/fixtures/invalid-strict-missing-review"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "QA-REVIEW-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-open-blocker"; Path = "tests/fixtures/invalid-open-blocker"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "BLOCKER-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-missing-rollback"; Path = "tests/fixtures/invalid-missing-rollback"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "RELEASE-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-unstructured-rollback"; Path = "tests/fixtures/invalid-unstructured-rollback"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "RELEASE-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "missing-requirement-at-release"; Path = "tests/fixtures/invalid-missing-requirement-release"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "SOURCE-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("REF-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001") },
  @{ Name = "workitem-mode-not-in-enum"; Path = "tests/fixtures/invalid-part2-matrix"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "ENUM-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("REF-001", "APPROVAL-002", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001") },
  @{ Name = "status-not-in-enum"; Path = "tests/fixtures/invalid-part2-matrix"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "ENUM-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("REF-001", "APPROVAL-002", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001") },
  @{ Name = "review-stage-not-in-enum"; Path = "tests/fixtures/invalid-part2-matrix"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "ENUM-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("REF-001", "APPROVAL-002", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001") },
  @{ Name = "requirement-ref-not-exist"; Path = "tests/fixtures/invalid-part2-matrix"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "REF-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("ENUM-001", "APPROVAL-002", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001") },
  @{ Name = "design-ref-file-missing"; Path = "tests/fixtures/invalid-part2-matrix"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "REF-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("ENUM-001", "APPROVAL-002", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001") },
  @{ Name = "approval-evidence-id-not-exist"; Path = "tests/fixtures/invalid-part2-matrix"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "APPROVAL-002"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("ENUM-001", "REF-001", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001") },
  @{ Name = "rollback-rows-empty"; Path = "tests/fixtures/invalid-part2-matrix"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "RELEASE-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("ENUM-001", "REF-001", "APPROVAL-002", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001") },
  @{ Name = "empty-RTM"; Path = "tests/fixtures/invalid-empty-rtm"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "RTM-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "RTM-references-missing-requirement"; Path = "tests/fixtures/invalid-rtm-references-missing-requirement"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "RTM-002"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "rtm-broken-delivery-ref"; Path = "tests/fixtures/invalid-rtm-broken-delivery-ref"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "RTM-003"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "rtm-broken-test-ref"; Path = "tests/fixtures/invalid-rtm-broken-test-ref"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "RTM-004"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "rtm-broken-evidence-ref"; Path = "tests/fixtures/invalid-rtm-broken-evidence-ref"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "RTM-005"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "rtm-broken-release-ref"; Path = "tests/fixtures/invalid-rtm-broken-release-ref"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "RTM-006"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "rtm-orphan-row"; Path = "tests/fixtures/invalid-rtm-orphan-row"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "RTM-007"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "rtm-bad-source-ref"; Path = "tests/fixtures/invalid-rtm-bad-source-ref"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "RTM-008"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "rtm-missing-design-file"; Path = "tests/fixtures/invalid-rtm-missing-design-file"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "RTM-009"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "rtm-bad-status"; Path = "tests/fixtures/invalid-rtm-bad-status"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "RTM-010"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "rtm-freetext-evidence"; Path = "tests/fixtures/invalid-rtm-freetext-evidence"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "RTM-005"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-broken-link"; Path = "tests/fixtures/invalid-broken-link"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "LINK-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-sensitive-env"; Path = "tests/fixtures/invalid-sensitive-env"; Mode = "Standard"; Gate = "Scope"; ShouldPass = $false; Rule = "SENSITIVE-001"; ExpectedLevel = "WARN"; Type = "negative"; FailOnWarning = $true },
  @{ Name = "invalid-placeholder-release"; Path = "tests/fixtures/invalid-placeholder-release"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "PLACEHOLDER-001"; ExpectedLevel = "FAIL"; Type = "negative" },

  @{ Name = "release-status-not-done"; Path = "tests/fixtures/invalid-release-status-not-done"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "RELEASE-STATUS-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "release-scope-excluded-no-reason"; Path = "tests/fixtures/invalid-release-scope-excluded-no-reason"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "RELEASE-SCOPE-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "test-evidence-unresolvable"; Path = "tests/fixtures/invalid-test-evidence-unresolvable"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "TEST-EVIDENCE-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "review-stage-none-at-release"; Path = "tests/fixtures/invalid-review-stage-none-release"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "REVIEW-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "qa-review-missing"; Path = "tests/fixtures/invalid-qa-review-missing"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "QA-REVIEW-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "lite-rollback-waiver-valid"; Path = "tests/fixtures/valid-lite-rollback-waiver"; Mode = "Lite"; Gate = "Release"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; Type = "positive" },
  @{ Name = "source-broken-link-non-blocking"; Path = "tests/fixtures/valid-source-broken-link-non-blocking"; Mode = "Standard"; Gate = "Release"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; FailOnWarning = $true; Type = "positive" },

  @{ Name = "security-review-pending"; Path = "tests/fixtures/invalid-security-review-pending"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "SECURITY-REVIEW-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "evidence-file-missing"; Path = "tests/fixtures/invalid-evidence-file-missing"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "TEST-EVIDENCE-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "malformed-external-evidence"; Path = "tests/fixtures/invalid-malformed-external-evidence"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "QA-REVIEW-001"; ExpectedLevel = "FAIL"; Type = "negative" }
)

$doctorCases = @(
  @{ Name = "skill-without-frontmatter"; SkillRoot = "tests/doctor-fixtures/skill-without-frontmatter/skills"; TemplateRoot = ""; Rule = "DOCTOR-SKILL-001" },
  @{ Name = "skill-name-mismatch"; SkillRoot = "tests/doctor-fixtures/skill-name-mismatch/skills"; TemplateRoot = ""; Rule = "DOCTOR-SKILL-001" },
  @{ Name = "broken-table-missing-column"; SkillRoot = ""; TemplateRoot = "tests/doctor-fixtures/broken-table-missing-column/templates"; Rule = "TABLE-001" },
  @{ Name = "broken-table-extra-column"; SkillRoot = ""; TemplateRoot = "tests/doctor-fixtures/broken-table-extra-column/templates"; Rule = "TABLE-001" },
  @{ Name = "broken-table-wrong-order-column"; SkillRoot = ""; TemplateRoot = "tests/doctor-fixtures/broken-table-wrong-order-column/templates"; Rule = "TABLE-001" }
)

$pass = 0
$fail = 0
$positive = @($cases | Where-Object { $_.Type -eq "positive" }).Count
$negative = @($cases | Where-Object { $_.Type -eq "negative" }).Count
$doctorNegative = @($doctorCases).Count

Write-Host "PMO Validation Fixture Tests: $repo"
Write-Host "Matrix: positive=$positive negative=$negative doctor-negative=$doctorNegative total=$($cases.Count + $doctorNegative)"
Write-Host ""

if ($CaptureGolden -or $VerifyGolden) {
  New-Item -ItemType Directory -Force -Path $GoldenMasterDir | Out-Null
}
$goldenMismatches = @()

foreach ($case in $cases) {
  $projectPath = Join-Path $repo $case.Path
  $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $validator, "-ProjectPath", $projectPath, "-Mode", $case.Mode, "-Gate", $case.Gate, "-Format", "Json")
  if ($case.FailOnWarning) {
    $args += "-FailOnWarning"
  }

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & powershell @args 2>$null
  $nativeExitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorActionPreference

  $rawOutput = ($output | Out-String).TrimEnd() + "`nEXIT_CODE=$nativeExitCode"
  $goldenFile = Join-Path $GoldenMasterDir "$($case.Name).txt"
  if ($CaptureGolden) {
    Set-Content -LiteralPath $goldenFile -Value $rawOutput -NoNewline -Encoding utf8
  } elseif ($VerifyGolden) {
    if (-not (Test-Path -LiteralPath $goldenFile)) {
      $goldenMismatches += "$($case.Name): no golden file recorded"
    } else {
      # Compare with normalized line endings: git's text normalization
      # rewrites the golden files' CRLF/LF mix on every checkout (autocrlf),
      # so a byte-exact comparison flags every case after a git round-trip
      # even though the content is identical.
      $expected = ((Get-Content -LiteralPath $goldenFile -Raw) -replace "`r`n", "`n").TrimEnd()
      $actual = ($rawOutput -replace "`r`n", "`n").TrimEnd()
      if ($expected -ne $actual) {
        $goldenMismatches += "$($case.Name): output differs from golden master"
      }
    }
  }

  $actualPass = ($nativeExitCode -eq 0)
  $json = $null
  try {
    $json = ($output | Out-String) | ConvertFrom-Json
  } catch {
    $json = $null
  }

  $ruleOk = $true
  $unexpectedRuleOk = $true
  if (-not $case.ShouldPass -and $case.Rule) {
    $matchingRules = @($json.results | Where-Object { $_.rule_id -eq $case.Rule -and $_.level -eq $case.ExpectedLevel })
    $ruleOk = ($matchingRules.Count -gt 0)

    if ($case.AllowedSecondaryRules -or $case.ForbiddenRules) {
      $primaryAndAllowed = @($case.Rule)
      if ($case.AllowedSecondaryRules) {
        $primaryAndAllowed += @($case.AllowedSecondaryRules)
      }
      $observedBlockingRules = @($json.results | Where-Object {
        $_.level -eq "FAIL" -or ($case.FailOnWarning -and $_.level -eq "WARN")
      } | ForEach-Object { $_.rule_id } | Sort-Object -Unique)
      $unexpectedBlockingRules = @($observedBlockingRules | Where-Object { $primaryAndAllowed -notcontains $_ })
      $unexpectedRuleOk = ($unexpectedBlockingRules.Count -eq 0)
    }

    if ($case.ForbiddenRules) {
      $forbiddenHits = @($json.results | Where-Object { @($case.ForbiddenRules) -contains $_.rule_id })
      if ($forbiddenHits.Count -gt 0) {
        $unexpectedRuleOk = $false
      }
    }
  }

  if ($actualPass -eq $case.ShouldPass -and $ruleOk -and $unexpectedRuleOk) {
    $pass++
    Write-Host "[PASS] $($case.Name)"
  } else {
    $fail++
    $expected = if ($case.ShouldPass) { "pass" } else { "fail" }
    $actual = if ($actualPass) { "pass" } else { "fail" }
    $ruleMessage = if ($case.Rule) { " expected $($case.ExpectedLevel) $($case.Rule)" } else { "" }
    Write-Host "[FAIL] $($case.Name) expected $expected$ruleMessage but got $actual"
  }
}

foreach ($case in $doctorCases) {
  $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $repo "scripts/pmo-doctor.ps1"), "-RepoPath", $repo)
  if ($case.SkillRoot) {
    $args += @("-SkillRootOverride", (Join-Path $repo $case.SkillRoot))
  }
  if ($case.TemplateRoot) {
    $args += @("-TemplateRootOverride", (Join-Path $repo $case.TemplateRoot))
  }

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & powershell @args 2>$null
  $nativeExitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorActionPreference
  $textOutput = $output | Out-String

  if ($nativeExitCode -ne 0 -and $textOutput -match "\[FAIL\]\s+$($case.Rule)\b") {
    $pass++
    Write-Host "[PASS] doctor-$($case.Name)"
  } else {
    $fail++
    Write-Host "[FAIL] doctor-$($case.Name) expected FAIL $($case.Rule) but got exit $nativeExitCode"
  }
}

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"

if ($CaptureGolden) {
  Write-Host "Golden master captured: $($cases.Count) case(s) written to $GoldenMasterDir"
}
if ($VerifyGolden) {
  if ($goldenMismatches.Count -gt 0) {
    Write-Host ""
    Write-Host "Golden master verification FAILED ($($goldenMismatches.Count) mismatch(es)):"
    foreach ($m in $goldenMismatches) { Write-Host "  - $m" }
  } else {
    Write-Host "Golden master verification: all $($cases.Count) case(s) match byte-for-byte"
  }
}

if ($fail -gt 0 -or ($VerifyGolden -and $goldenMismatches.Count -gt 0)) {
  exit 1
}

exit 0
