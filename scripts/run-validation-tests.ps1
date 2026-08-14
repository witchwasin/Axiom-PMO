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

. (Join-Path $PSScriptRoot "lib/pwsh-host.ps1")
. (Join-Path $PSScriptRoot "lib/golden-normalizer.ps1")

$root = Resolve-Path -LiteralPath $RepoPath
$repo = $root.Path

# Maintainer-only: audits the framework's own checkout, so it fails with a
# diagnostic rather than a raw exception when run from a packaged install.
. (Join-Path $PSScriptRoot "lib/framework-checkout.ps1")
Assert-FrameworkCheckout -Root $repo -ToolName "run-validation-tests" -Alternative "scripts/validate-project.ps1 -ProjectPath <your project>"
$validator = Join-Path $repo "scripts/validate-project.ps1"

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

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
  @{ Name = "github-task-source-waives-delivery"; Path = "tests/fixtures/valid-github-task-source-no-delivery"; Mode = "Standard"; Gate = "Release"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; FailOnWarning = $true; Type = "positive" },
  @{ Name = "github-no-repo-still-needs-delivery"; Path = "tests/fixtures/invalid-github-no-repo-needs-delivery"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "STRUCT-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "strict-scope-no-rtm-required"; Path = "examples/STRICT-HIGH-RISK"; Mode = "Strict"; Gate = "Scope"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; FailOnWarning = $true; Type = "positive" },
  @{ Name = "example-design-system-demo-design"; Path = "examples/DESIGN-SYSTEM-DEMO"; Mode = "Standard"; Gate = "Design"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; FailOnWarning = $true; Type = "positive" },
  # Covers the three ways the token comparison could produce a false positive:
  # a lowercase hex, a token composed with var(), and a typography table that
  # has no Value column and must therefore be skipped rather than guessed at.
  @{ Name = "design-system-tokens-agree"; Path = "tests/fixtures/valid-design-system-tokens"; Mode = "Standard"; Gate = "Release"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; FailOnWarning = $true; Type = "positive" },

  # Empty AllowedSecondaryRules on purpose: this fixture must fire DESIGN-001
  # and nothing else, so a future change that makes token drift collateral
  # damage of some other rule shows up here.
  @{ Name = "invalid-design-token-drift"; Path = "tests/fixtures/invalid-design-token-drift"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "DESIGN-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
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
  @{ Name = "approval-external-evidence-blocks"; Path = "tests/fixtures/invalid-approval-external-evidence"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "APPROVAL-004"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "approval-generic-approver-blocks"; Path = "tests/fixtures/invalid-approval-generic-approver"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "APPROVAL-005"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "approval-file-ref-escape-blocks"; Path = "tests/fixtures/invalid-approval-file-ref-escape"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "REF-002"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "review-external-evidence-blocks"; Path = "tests/fixtures/invalid-review-external-evidence"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "APPROVAL-004"; ExpectedLevel = "FAIL"; Type = "negative" },
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
  @{ Name = "invalid-no-test-summary"; Path = "tests/fixtures/invalid-no-test-summary"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "TEST-SUMMARY-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "valid-test-summary-waived"; Path = "tests/fixtures/valid-test-summary-waived"; Mode = "Standard"; Gate = "Release"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; FailOnWarning = $true; Type = "positive" },
  @{ Name = "invalid-strict-all-tests-skipped"; Path = "tests/fixtures/invalid-strict-all-tests-skipped"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "TEST-SUMMARY-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "invalid-rtm-source-ref-not-in-snapshot"; Path = "tests/fixtures/invalid-rtm-source-ref-not-in-snapshot"; Mode = "Strict"; Gate = "Release"; ShouldPass = $false; Rule = "RTM-008"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "not-required-in-approval"; Path = "tests/fixtures/invalid-not-required-approval"; Mode = "Lite"; Gate = "Release"; ShouldPass = $false; Rule = "APPROVAL-002"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "not-required-in-workitem"; Path = "tests/fixtures/invalid-not-required-workitem"; Mode = "Lite"; Gate = "Release"; ShouldPass = $false; Rule = "WORKITEM-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "not-required-in-rollback"; Path = "tests/fixtures/invalid-not-required-rollback"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "RELEASE-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "mode-downgrade-project-default"; Path = "examples/STRICT-HIGH-RISK"; Mode = "Lite"; Gate = "Release"; ShouldPass = $false; Rule = "MODE-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "mode-downgrade-workitem-escalation"; Path = "tests/fixtures/invalid-mode-downgrade-workitem"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "MODE-001"; ExpectedLevel = "FAIL"; Type = "negative" },
  @{ Name = "path-unrecognized-execution-path"; Path = "tests/fixtures/invalid-path-unrecognized"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "PATH-001"; ExpectedLevel = "WARN"; Type = "negative"; FailOnWarning = $true },
  @{ Name = "path-active-execution-package-warns"; Path = "tests/fixtures/invalid-path-active-execution"; Mode = "Lite"; Gate = "Draft"; ShouldPass = $false; Rule = "PATH-002"; ExpectedLevel = "WARN"; Type = "negative"; FailOnWarning = $true },
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
  @{ Name = "missing-requirement-at-release"; Path = "tests/fixtures/invalid-missing-requirement-release"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "SOURCE-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("REF-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001", "TEST-SUMMARY-001") },
  @{ Name = "workitem-mode-not-in-enum"; Path = "tests/fixtures/invalid-part2-matrix"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "ENUM-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("REF-001", "APPROVAL-002", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001", "TEST-SUMMARY-001") },
  @{ Name = "status-not-in-enum"; Path = "tests/fixtures/invalid-part2-matrix"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "ENUM-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("REF-001", "APPROVAL-002", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001", "TEST-SUMMARY-001") },
  @{ Name = "review-stage-not-in-enum"; Path = "tests/fixtures/invalid-part2-matrix"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "ENUM-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("REF-001", "APPROVAL-002", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001", "TEST-SUMMARY-001") },
  @{ Name = "requirement-ref-not-exist"; Path = "tests/fixtures/invalid-part2-matrix"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "REF-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("ENUM-001", "APPROVAL-002", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001", "TEST-SUMMARY-001") },
  @{ Name = "design-ref-file-missing"; Path = "tests/fixtures/invalid-part2-matrix"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "REF-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("ENUM-001", "APPROVAL-002", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001", "TEST-SUMMARY-001") },
  @{ Name = "approval-evidence-id-not-exist"; Path = "tests/fixtures/invalid-part2-matrix"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "APPROVAL-002"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("ENUM-001", "REF-001", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001", "TEST-SUMMARY-001") },
  @{ Name = "rollback-rows-empty"; Path = "tests/fixtures/invalid-part2-matrix"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "RELEASE-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("ENUM-001", "REF-001", "APPROVAL-002", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001", "TEST-SUMMARY-001") },
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
  @{ Name = "malformed-external-evidence"; Path = "tests/fixtures/invalid-malformed-external-evidence"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false; Rule = "QA-REVIEW-001"; ExpectedLevel = "FAIL"; Type = "negative" },

  # -- Handoff gate (v1.1) -----------------------------------------------------
  # Positive cases first. The Design case is load-bearing: it proves that adding
  # the Handoff gate did not retro-apply handoff requirements to the gates that
  # existed in v1.0.
  @{ Name = "handoff-demo-standard"; Path = "examples/HANDOFF-DEMO"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; FailOnWarning = $true; Type = "positive" },
  @{ Name = "handoff-demo-design-gate-unaffected"; Path = "examples/HANDOFF-DEMO"; Mode = "Standard"; Gate = "Design"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; FailOnWarning = $true; Type = "positive" },
  @{ Name = "handoff-demo-scope-gate-unaffected"; Path = "examples/HANDOFF-DEMO"; Mode = "Standard"; Gate = "Scope"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; FailOnWarning = $true; Type = "positive" },
  # STANDARD-FEATURE carries a full Handoff artifact set, but every CI leg ran it
  # at -Gate Release, where the HANDOFF-### rules do not evaluate at all. That is
  # not a theoretical hole: adding one row to its decision-log.md changes the
  # review_inputs digest (the file is listed in handoff-policy.json
  # semantic_review.freshness.review_input_files), which makes HANDOFF-REVIEW.json
  # stale -- and the whole suite stayed green while the shipped example was, at
  # the gate it exists to demonstrate, not handoff-ready.
  #
  # FailOnWarning is load-bearing here, not decoration. A stale review is a
  # BLOCKING WARN, not a FAIL, so the validator exits 0 without it; measured on
  # the stale example, exit 2 with the switch and exit 0 without. Dropping it
  # would restore the exact gap this case closes.
  @{ Name = "example-standard-feature-handoff"; Path = "examples/STANDARD-FEATURE"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; FailOnWarning = $true; Type = "positive" },
  @{ Name = "valid-handoff-lite"; Path = "tests/fixtures/valid-handoff-lite"; Mode = "Lite"; Gate = "Handoff"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; FailOnWarning = $true; Type = "positive" },
  @{ Name = "valid-handoff-strict"; Path = "tests/fixtures/valid-handoff-strict"; Mode = "Strict"; Gate = "Handoff"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; FailOnWarning = $true; Type = "positive" },
  # Passes the gate with an open action still outstanding. The gate is right to
  # pass it -- the contract is complete -- and the assessment is what has to
  # report that the demo is still blocked. See handoff-assessment-tests.ps1.
  @{ Name = "valid-handoff-action-blocks-demo"; Path = "tests/fixtures/valid-handoff-action-blocks-demo"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $true; Rule = ""; ExpectedLevel = ""; FailOnWarning = $true; Type = "positive" },

  @{ Name = "handoff-missing"; Path = "tests/fixtures/invalid-handoff-missing"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("STRUCT-001", "LINK-001") },
  @{ Name = "handoff-missing-buildspec"; Path = "tests/fixtures/invalid-handoff-missing-buildspec"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("STRUCT-001", "LINK-001", "REF-001") },
  @{ Name = "handoff-metadata-incomplete"; Path = "tests/fixtures/invalid-handoff-metadata-incomplete"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-scope-incomplete"; Path = "tests/fixtures/invalid-handoff-scope-incomplete"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-002"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-scope-unresolved-ref"; Path = "tests/fixtures/invalid-handoff-scope-unresolved-ref"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-002"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("HANDOFF-004") },
  @{ Name = "handoff-generic-owner"; Path = "tests/fixtures/invalid-handoff-generic-owner"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-003"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-workitem-generic-owner"; Path = "tests/fixtures/invalid-handoff-workitem-generic-owner"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-003"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-lite-generic-owner-warns"; Path = "tests/fixtures/invalid-handoff-lite-generic-owner"; Mode = "Lite"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-003"; ExpectedLevel = "WARN"; Type = "negative"; FailOnWarning = $true; AllowedSecondaryRules = @() },
  @{ Name = "handoff-dependency-missing"; Path = "tests/fixtures/invalid-handoff-dependency-missing"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-004"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-sequence-inverted"; Path = "tests/fixtures/invalid-handoff-sequence-inverted"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-004"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-sequence-blank-depends"; Path = "tests/fixtures/invalid-handoff-sequence-blank-depends"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-004"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-buildspec-section-missing"; Path = "tests/fixtures/invalid-handoff-buildspec-section-missing"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-005"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-buildspec-waiver-no-rationale"; Path = "tests/fixtures/invalid-handoff-buildspec-waiver-no-rationale"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-005"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-buildspec-waiver-not-allowed"; Path = "tests/fixtures/invalid-handoff-buildspec-waiver-not-allowed"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-005"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-acceptance-no-execution"; Path = "tests/fixtures/invalid-handoff-acceptance-no-execution"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-006"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-acceptance-no-fixture"; Path = "tests/fixtures/invalid-handoff-acceptance-no-fixture"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-007"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-demo-no-integrator"; Path = "tests/fixtures/invalid-handoff-demo-no-integrator"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-008"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-demo-no-reset"; Path = "tests/fixtures/invalid-handoff-demo-no-reset"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-008"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-action-no-owner"; Path = "tests/fixtures/invalid-handoff-action-no-owner"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-009"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-action-no-blocking-point"; Path = "tests/fixtures/invalid-handoff-action-no-blocking-point"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-009"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-review-missing"; Path = "tests/fixtures/invalid-handoff-review-missing"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-010"; ExpectedLevel = "WARN"; Type = "negative"; FailOnWarning = $true; AllowedSecondaryRules = @("LINK-001") },
  @{ Name = "handoff-review-stale"; Path = "tests/fixtures/invalid-handoff-review-stale"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-010"; ExpectedLevel = "WARN"; Type = "negative"; FailOnWarning = $true; AllowedSecondaryRules = @() },
  @{ Name = "handoff-review-unknown-lens"; Path = "tests/fixtures/invalid-handoff-review-unknown-lens"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-010"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-review-finding-no-owner"; Path = "tests/fixtures/invalid-handoff-review-finding-no-owner"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-010"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-review-open-critical-warns"; Path = "tests/fixtures/invalid-handoff-review-open-critical"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-010"; ExpectedLevel = "WARN"; Type = "negative"; FailOnWarning = $true; AllowedSecondaryRules = @() },
  @{ Name = "handoff-sensitive-no-decision"; Path = "tests/fixtures/invalid-handoff-sensitive-no-decision"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-011"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-capability-unresolved"; Path = "tests/fixtures/invalid-handoff-capability-unresolved"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-012"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-environment-unresolved"; Path = "tests/fixtures/invalid-handoff-environment-unresolved"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-012"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },

  # -- Closure authority, freshness, and reference resolution -----------------
  # These are the checks that stop the gate reporting "ready" on evidence that
  # was never actually produced: a finding closed by whoever felt like closing
  # it, a review that no longer describes the artifacts, or a reference that
  # points at nothing.
  @{ Name = "handoff-ai-closed-human-lens"; Path = "tests/fixtures/invalid-handoff-ai-closed-human-lens"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-010"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-accepted-risk-no-decision"; Path = "tests/fixtures/invalid-handoff-accepted-risk-no-decision"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-010"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-closed-unresolvable-decision"; Path = "tests/fixtures/invalid-handoff-closed-unresolvable-decision"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-010"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-review-stale-inputs"; Path = "tests/fixtures/invalid-handoff-review-stale-inputs"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-010"; ExpectedLevel = "WARN"; Type = "negative"; FailOnWarning = $true; AllowedSecondaryRules = @() },
  @{ Name = "handoff-review-no-input-digest"; Path = "tests/fixtures/invalid-handoff-review-no-input-digest"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-010"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-acceptance-unresolved-requirement"; Path = "tests/fixtures/invalid-handoff-acceptance-unresolved-requirement"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-006"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-sensitive-freetext-decision"; Path = "tests/fixtures/invalid-handoff-sensitive-freetext-decision"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-011"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-environment-freetext-decision"; Path = "tests/fixtures/invalid-handoff-environment-freetext-decision"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-012"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-mode-mismatch"; Path = "tests/fixtures/invalid-handoff-mode-mismatch"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-horizon-not-a-date"; Path = "tests/fixtures/invalid-handoff-horizon-not-a-date"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-buildspec-ref-missing"; Path = "tests/fixtures/invalid-handoff-buildspec-ref-missing"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-001"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },

  # A vague classification is an undeclared one, and a human-only closure has to
  # be anchored to a decision somebody signed. Both were ways to pass the gate
  # without producing the evidence it claims to require.
  @{ Name = "handoff-sensitive-undeclared"; Path = "tests/fixtures/invalid-handoff-sensitive-undeclared"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-011"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-human-closure-generic-decider"; Path = "tests/fixtures/invalid-handoff-human-closure-generic-decider"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-010"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-human-closure-no-decision-log"; Path = "tests/fixtures/invalid-handoff-human-closure-no-decision-log"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-010"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },

  # -- Table headers and project identity (issues #6, #7) ----------------------
  # The two header cases deliberately allow one downstream rule. That secondary
  # finding IS the symptom HANDOFF-013 exists to explain: cells are read by
  # column name, so a renamed header makes a filled-in value read as empty and
  # some other rule complains about it. Asserting both proves the pair.
  @{ Name = "handoff-header-renamed"; Path = "tests/fixtures/invalid-handoff-header-renamed"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-013"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("HANDOFF-009") },
  @{ Name = "handoff-header-reordered"; Path = "tests/fixtures/invalid-handoff-header-reordered"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-013"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @("HANDOFF-004") },
  @{ Name = "handoff-header-buildspec"; Path = "tests/fixtures/invalid-handoff-header-buildspec"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-013"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-project-mismatch"; Path = "tests/fixtures/invalid-handoff-project-mismatch"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-014"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() },
  @{ Name = "handoff-review-project-mismatch"; Path = "tests/fixtures/invalid-handoff-review-project-mismatch"; Mode = "Standard"; Gate = "Handoff"; ShouldPass = $false; Rule = "HANDOFF-014"; ExpectedLevel = "FAIL"; Type = "negative"; AllowedSecondaryRules = @() }
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

Write-Host "Axiom-PMO Validation Fixture Tests: $repo"
Write-Host "Matrix: positive=$positive negative=$negative doctor-negative=$doctorNegative total=$($cases.Count + $doctorNegative)"
Write-Host ""

if ($CaptureGolden -or $VerifyGolden) {
  New-Item -ItemType Directory -Force -Path $GoldenMasterDir | Out-Null
}
$goldenMismatches = @()
# Parallel to $goldenMismatches: the differing lines behind each one, printed
# with the summary. See Get-GoldenDiffReport for why a bare "output differs"
# is not enough on a host the maintainer cannot run locally.
$goldenDiffReports = @()

foreach ($case in $cases) {
  $projectPath = Join-Path $repo $case.Path
  $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $validator, "-ProjectPath", $projectPath, "-Mode", $case.Mode, "-Gate", $case.Gate, "-Format", "Json")
  if ($case.FailOnWarning) {
    $psArgs += "-FailOnWarning"
  }

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  # Preserve child diagnostics. On Windows PowerShell 5.1, stderr from a
  # native child becomes ErrorRecord output even when the child only reports
  # a parser/runtime failure. Discarding it here previously reduced every
  # fixture to an unexplained EXIT_CODE=1 and made host-only failures
  # impossible to diagnose from CI.
  $output = & $pwshExe @psArgs 2>&1
  $nativeExitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorActionPreference

  $rawOutput = ($output | Out-String).TrimEnd() + "`nEXIT_CODE=$nativeExitCode"
  # The JSON output embeds the resolved absolute project path, which differs
  # by checkout location (local clone vs GitHub Actions' D:\a\... runner
  # path). Strip it to a fixed placeholder so golden masters are portable
  # across machines. Handle both the raw path and its JSON-escaped (doubled
  # backslash) form.
  $repoJsonEscaped = $repo -replace '\\', '\\'
  $rawOutput = $rawOutput.Replace($repoJsonEscaped, '<REPO_ROOT>').Replace($repo, '<REPO_ROOT>')
  $goldenFile = Join-Path $GoldenMasterDir "$($case.Name).txt"
  if ($CaptureGolden) {
    # Store the canonical form, not the capturing host's pretty-printer output.
    # A golden captured on Windows PowerShell 5.1 and one captured on pwsh 7
    # are then byte-identical, so re-capturing on either platform produces a
    # reviewable diff instead of rewriting all 90 files.
    Set-Content -LiteralPath $goldenFile -Value (Get-CanonicalGoldenText -Text $rawOutput) -NoNewline -Encoding utf8
  } elseif ($VerifyGolden) {
    if (-not (Test-Path -LiteralPath $goldenFile)) {
      $goldenMismatches += "$($case.Name): no golden file recorded"
    } else {
      # Compare canonically (see scripts/lib/golden-normalizer.ps1): git's text
      # normalization rewrites CRLF/LF on every checkout, and the JSON
      # pretty-printer differs between Windows PowerShell 5.1 and pwsh 7. Rule
      # ids, levels, blocking flags, messages, counters, and the exit code are
      # all still compared exactly.
      # A zero-byte golden makes Get-Content -Raw return $null, not "" (see
      # docs/architecture/powershell-portability.md section 3); an explicit
      # null check, never a [string] cast, is the fix that actually works.
      $expectedRaw = Get-Content -LiteralPath $goldenFile -Raw
      $expected = if ($null -eq $expectedRaw) { "" } else { $expectedRaw }
      if (-not (Test-GoldenMatch -Expected $expected -Actual $rawOutput)) {
        $goldenMismatches += "$($case.Name): output differs from golden master"
        $goldenDiffReports += ,@{
          Name = $case.Name
          Lines = @(Get-GoldenDiffReport -Expected $expected -Actual $rawOutput)
        }
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

    # ContainsKey, not truthiness: an explicitly-supplied empty
    # AllowedSecondaryRules means "this fixture must fire nothing else", and
    # @() is falsy in PowerShell, so testing the value would silently turn the
    # strictest possible assertion into no assertion at all.
    if ($case.ContainsKey('AllowedSecondaryRules') -or $case.ContainsKey('ForbiddenRules')) {
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
  $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $repo "scripts/pmo-doctor.ps1"), "-RepoPath", $repo)
  if ($case.SkillRoot) {
    $psArgs += @("-SkillRootOverride", (Join-Path $repo $case.SkillRoot))
  }
  if ($case.TemplateRoot) {
    $psArgs += @("-TemplateRootOverride", (Join-Path $repo $case.TemplateRoot))
  }

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & $pwshExe @psArgs 2>$null
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
    # The differing lines themselves. Without these the log says only that a
    # golden moved, which is undiagnosable when the mismatch reproduces on a
    # host the maintainer cannot run and the job uploads no artifact.
    if ($goldenDiffReports.Count -gt 0) {
      Write-Host ""
      Write-Host "Differing lines (canonical form, the same comparison Test-GoldenMatch makes):"
      foreach ($report in $goldenDiffReports) {
        Write-Host "    $($report.Name):"
        foreach ($line in $report.Lines) { Write-Host $line }
      }
    }
  } else {
    Write-Host "Golden master verification: all $($cases.Count) case(s) match (canonical comparison)"
  }
}

if ($fail -gt 0 -or ($VerifyGolden -and $goldenMismatches.Count -gt 0)) {
  exit 1
}

exit 0
