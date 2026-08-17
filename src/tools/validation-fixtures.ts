// Ported from scripts/run-validation-tests.ps1. Runs the full positive/negative
// fixture matrix against the ported validator chain: each case asserts overall
// pass/fail, plus (for negative cases) that a specific rule/level fired and
// that no unexpected blocking rule fired alongside it. In verify-golden mode
// (always on when this runs as part of `axiom check`), each case's canonical
// JSON output is also compared byte-for-byte against its committed golden
// master under tests/golden/ -- this is the "implementation-neutral corpus
// runner" master-plan.md's Phase 9 exit criteria says to retain permanently,
// proving the ported engine's full output shape, not just the rule-filtered
// subset differential-probe.ts compares.
//
// CaptureGolden mode (the PS original's one-time golden-writing switch) is
// intentionally not ported: it was a Phase 0/4 capture tool, not part of the
// ongoing check suite this file replaces.

import { readFileSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { runValidateEnvelope } from "../probe/validate-chain.js";
import { runPmoDoctor } from "../doctor/pmo-doctor.js";
import { testGoldenMatch, getGoldenDiffReport } from "../output/canonical-normalizer.js";
import type { Mode, Gate } from "../core/types.js";

interface FixtureCase {
  Name: string;
  Path: string;
  Mode: Mode;
  Gate: Gate;
  ShouldPass: boolean;
  Rule: string;
  ExpectedLevel: string;
  Type: "positive" | "negative";
  FailOnWarning?: boolean;
  AllowedSecondaryRules?: string[];
  ForbiddenRules?: string[];
}

const CASES: FixtureCase[] = [
  { Name: "example-lite-bugfix-scope", Path: "examples/LITE-BUGFIX", Mode: "Lite", Gate: "Scope", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive" },
  { Name: "example-lite-bugfix-draft", Path: "examples/LITE-BUGFIX", Mode: "Lite", Gate: "Draft", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive" },
  { Name: "example-standard-feature-release", Path: "examples/STANDARD-FEATURE", Mode: "Standard", Gate: "Release", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive" },
  { Name: "example-strict-high-risk-release", Path: "examples/STRICT-HIGH-RISK", Mode: "Strict", Gate: "Release", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive" },
  { Name: "valid-standard-release", Path: "tests/fixtures/valid-standard", Mode: "Standard", Gate: "Release", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive" },
  { Name: "valid-standard-scope", Path: "tests/fixtures/valid-standard", Mode: "Standard", Gate: "Scope", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive" },
  { Name: "valid-standard-draft", Path: "tests/fixtures/valid-standard", Mode: "Standard", Gate: "Draft", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive" },
  { Name: "generated-project-passes-draft", Path: "tests/fixtures/generated-project-draft", Mode: "Lite", Gate: "Draft", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive" },
  { Name: "lite-release-light-approval-no-decision-log", Path: "tests/fixtures/valid-lite-release-light-approval", Mode: "Lite", Gate: "Release", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive" },
  { Name: "html-wireframe-not-flagged", Path: "tests/fixtures/valid-html-wireframe", Mode: "Standard", Gate: "Release", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive" },
  { Name: "source-ref-REQ-V1", Path: "tests/fixtures/valid-source-ref-REQ-V1", Mode: "Standard", Gate: "Release", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive" },
  { Name: "user-source-placeholders-do-not-fail-release", Path: "tests/fixtures/valid-user-source-placeholders", Mode: "Standard", Gate: "Release", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive" },
  { Name: "others-and-sensitive-source-do-not-fail-release", Path: "tests/fixtures/valid-source-others-and-sensitive", Mode: "Standard", Gate: "Release", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive", FailOnWarning: true },
  { Name: "standard-draft-no-delivery-release-required", Path: "tests/fixtures/valid-standard-draft-minimal", Mode: "Standard", Gate: "Draft", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive" },
  { Name: "github-task-source-waives-delivery", Path: "tests/fixtures/valid-github-task-source-no-delivery", Mode: "Standard", Gate: "Release", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive", FailOnWarning: true },
  { Name: "github-no-repo-still-needs-delivery", Path: "tests/fixtures/invalid-github-no-repo-needs-delivery", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "STRUCT-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "strict-scope-no-rtm-required", Path: "examples/STRICT-HIGH-RISK", Mode: "Strict", Gate: "Scope", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive", FailOnWarning: true },
  { Name: "example-design-system-demo-design", Path: "examples/DESIGN-SYSTEM-DEMO", Mode: "Standard", Gate: "Design", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive", FailOnWarning: true },
  { Name: "design-system-tokens-agree", Path: "tests/fixtures/valid-design-system-tokens", Mode: "Standard", Gate: "Release", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive", FailOnWarning: true },
  { Name: "invalid-design-token-drift", Path: "tests/fixtures/invalid-design-token-drift", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "DESIGN-001", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "invalid-no-project", Path: "tests/fixtures/invalid-no-project", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "STRUCT-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-missing-delivery", Path: "tests/fixtures/invalid-missing-delivery", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "STRUCT-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-missing-release", Path: "tests/fixtures/invalid-missing-release", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "STRUCT-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-missing-design", Path: "tests/fixtures/invalid-missing-design", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "STRUCT-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-no-source-ref", Path: "tests/fixtures/invalid-no-source-ref", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "SOURCE-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-no-evidence-status", Path: "tests/fixtures/invalid-no-evidence-status", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "EVIDENCE-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-duplicate-requirement-id", Path: "tests/fixtures/invalid-duplicate-requirement-id", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "SOURCE-003", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-source-snapshot-no-sync", Path: "tests/fixtures/invalid-source-snapshot-no-sync", Mode: "Standard", Gate: "Scope", ShouldPass: false, Rule: "SOURCE-002", ExpectedLevel: "WARN", Type: "negative", FailOnWarning: true },
  { Name: "invalid-fake-approval", Path: "tests/fixtures/invalid-fake-approval", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "APPROVAL-002", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "approval-evidence-freetext-rejected", Path: "tests/fixtures/invalid-approval-evidence-freetext", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "APPROVAL-002", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "approval-role-mismatch-standard-blocks-warning", Path: "tests/fixtures/invalid-approval-role-standard", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "APPROVAL-003", ExpectedLevel: "WARN", Type: "negative", FailOnWarning: true },
  { Name: "approval-role-mismatch-strict-fails", Path: "tests/fixtures/invalid-approval-role-strict", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "APPROVAL-003", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "approval-external-evidence-blocks", Path: "tests/fixtures/invalid-approval-external-evidence", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "APPROVAL-004", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "approval-generic-approver-blocks", Path: "tests/fixtures/invalid-approval-generic-approver", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "APPROVAL-005", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "approval-file-ref-escape-blocks", Path: "tests/fixtures/invalid-approval-file-ref-escape", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "REF-002", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "review-external-evidence-blocks", Path: "tests/fixtures/invalid-review-external-evidence", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "APPROVAL-004", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-missing-scope-approval", Path: "tests/fixtures/invalid-missing-scope-approval", Mode: "Standard", Gate: "Scope", ShouldPass: false, Rule: "APPROVAL-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-missing-design-approval", Path: "tests/fixtures/invalid-missing-design-approval", Mode: "Standard", Gate: "Design", ShouldPass: false, Rule: "APPROVAL-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-missing-release-approval", Path: "tests/fixtures/invalid-missing-release-approval", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "APPROVAL-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "lite-release-missing-approval", Path: "tests/fixtures/invalid-lite-release-no-approval", Mode: "Lite", Gate: "Release", ShouldPass: false, Rule: "APPROVAL-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "lite-release-no-delivery-workitem-prose", Path: "tests/fixtures/invalid-lite-release-no-delivery", Mode: "Lite", Gate: "Release", ShouldPass: false, Rule: "STRUCT-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "lite-approval-freetext-evidence-blocks", Path: "tests/fixtures/invalid-lite-freetext-evidence", Mode: "Lite", Gate: "Release", ShouldPass: false, Rule: "APPROVAL-002", ExpectedLevel: "WARN", Type: "negative", FailOnWarning: true },
  { Name: "lite-workitem-freetext-evidence-blocks", Path: "tests/fixtures/invalid-lite-workitem-freetext-evidence", Mode: "Lite", Gate: "Release", ShouldPass: false, Rule: "TEST-EVIDENCE-001", ExpectedLevel: "WARN", Type: "negative", FailOnWarning: true },
  { Name: "test-summary-still-pending", Path: "tests/fixtures/invalid-test-summary-pending", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "TEST-RESULT-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "test-summary-evidence-unresolved", Path: "tests/fixtures/invalid-test-summary-evidence-unresolved", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "TEST-EVIDENCE-002", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "test-summary-skipped-with-reason", Path: "tests/fixtures/valid-test-summary-skipped-with-reason", Mode: "Standard", Gate: "Release", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive" },
  { Name: "invalid-no-test-summary", Path: "tests/fixtures/invalid-no-test-summary", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "TEST-SUMMARY-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "valid-test-summary-waived", Path: "tests/fixtures/valid-test-summary-waived", Mode: "Standard", Gate: "Release", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive", FailOnWarning: true },
  { Name: "invalid-strict-all-tests-skipped", Path: "tests/fixtures/invalid-strict-all-tests-skipped", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "TEST-SUMMARY-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-rtm-source-ref-not-in-snapshot", Path: "tests/fixtures/invalid-rtm-source-ref-not-in-snapshot", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "RTM-008", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "not-required-in-approval", Path: "tests/fixtures/invalid-not-required-approval", Mode: "Lite", Gate: "Release", ShouldPass: false, Rule: "APPROVAL-002", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "not-required-in-workitem", Path: "tests/fixtures/invalid-not-required-workitem", Mode: "Lite", Gate: "Release", ShouldPass: false, Rule: "WORKITEM-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "not-required-in-rollback", Path: "tests/fixtures/invalid-not-required-rollback", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "RELEASE-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "mode-downgrade-project-default", Path: "examples/STRICT-HIGH-RISK", Mode: "Lite", Gate: "Release", ShouldPass: false, Rule: "MODE-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "mode-downgrade-workitem-escalation", Path: "tests/fixtures/invalid-mode-downgrade-workitem", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "MODE-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "path-unrecognized-execution-path", Path: "tests/fixtures/invalid-path-unrecognized", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "PATH-001", ExpectedLevel: "WARN", Type: "negative", FailOnWarning: true },
  { Name: "path-active-execution-package-warns", Path: "tests/fixtures/invalid-path-active-execution", Mode: "Lite", Gate: "Draft", ShouldPass: false, Rule: "PATH-002", ExpectedLevel: "WARN", Type: "negative", FailOnWarning: true },
  { Name: "invalid-task-source-conflict", Path: "tests/fixtures/invalid-task-source-conflict", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "TASK-002", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-delivery-task-source-missing", Path: "tests/fixtures/invalid-delivery-task-source-missing", Mode: "Standard", Gate: "Scope", ShouldPass: false, Rule: "TASK-001", ExpectedLevel: "WARN", Type: "negative", FailOnWarning: true },
  { Name: "invalid-workitem-header-missing", Path: "tests/fixtures/invalid-workitem-header-missing", Mode: "Standard", Gate: "Scope", ShouldPass: false, Rule: "WORKITEM-001", ExpectedLevel: "WARN", Type: "negative", FailOnWarning: true },
  { Name: "invalid-workitem-owner-missing", Path: "tests/fixtures/invalid-workitem-owner-missing", Mode: "Standard", Gate: "Scope", ShouldPass: false, Rule: "WORKITEM-001", ExpectedLevel: "WARN", Type: "negative", FailOnWarning: true },
  { Name: "invalid-strict-trigger-standard", Path: "tests/fixtures/invalid-strict-trigger-standard", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "STRICT-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-strict-missing-rtm", Path: "tests/fixtures/invalid-strict-missing-rtm", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "STRICT-002", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-strict-missing-review", Path: "tests/fixtures/invalid-strict-missing-review", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "QA-REVIEW-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-open-blocker", Path: "tests/fixtures/invalid-open-blocker", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "BLOCKER-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-missing-rollback", Path: "tests/fixtures/invalid-missing-rollback", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "RELEASE-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-unstructured-rollback", Path: "tests/fixtures/invalid-unstructured-rollback", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "RELEASE-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "missing-requirement-at-release", Path: "tests/fixtures/invalid-missing-requirement-release", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "SOURCE-001", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: ["REF-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001", "TEST-SUMMARY-001"] },
  { Name: "workitem-mode-not-in-enum", Path: "tests/fixtures/invalid-part2-matrix", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "ENUM-001", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: ["REF-001", "APPROVAL-002", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001", "TEST-SUMMARY-001"] },
  { Name: "status-not-in-enum", Path: "tests/fixtures/invalid-part2-matrix", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "ENUM-001", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: ["REF-001", "APPROVAL-002", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001", "TEST-SUMMARY-001"] },
  { Name: "review-stage-not-in-enum", Path: "tests/fixtures/invalid-part2-matrix", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "ENUM-001", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: ["REF-001", "APPROVAL-002", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001", "TEST-SUMMARY-001"] },
  { Name: "requirement-ref-not-exist", Path: "tests/fixtures/invalid-part2-matrix", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "REF-001", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: ["ENUM-001", "APPROVAL-002", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001", "TEST-SUMMARY-001"] },
  { Name: "design-ref-file-missing", Path: "tests/fixtures/invalid-part2-matrix", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "REF-001", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: ["ENUM-001", "APPROVAL-002", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001", "TEST-SUMMARY-001"] },
  { Name: "approval-evidence-id-not-exist", Path: "tests/fixtures/invalid-part2-matrix", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "APPROVAL-002", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: ["ENUM-001", "REF-001", "RELEASE-001", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001", "TEST-SUMMARY-001"] },
  { Name: "rollback-rows-empty", Path: "tests/fixtures/invalid-part2-matrix", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "RELEASE-001", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: ["ENUM-001", "REF-001", "APPROVAL-002", "QA-REVIEW-001", "RELEASE-STATUS-001", "TEST-EVIDENCE-001", "TEST-SUMMARY-001"] },
  { Name: "empty-RTM", Path: "tests/fixtures/invalid-empty-rtm", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "RTM-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "RTM-references-missing-requirement", Path: "tests/fixtures/invalid-rtm-references-missing-requirement", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "RTM-002", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "rtm-broken-delivery-ref", Path: "tests/fixtures/invalid-rtm-broken-delivery-ref", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "RTM-003", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "rtm-broken-test-ref", Path: "tests/fixtures/invalid-rtm-broken-test-ref", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "RTM-004", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "rtm-broken-evidence-ref", Path: "tests/fixtures/invalid-rtm-broken-evidence-ref", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "RTM-005", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "rtm-broken-release-ref", Path: "tests/fixtures/invalid-rtm-broken-release-ref", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "RTM-006", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "rtm-orphan-row", Path: "tests/fixtures/invalid-rtm-orphan-row", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "RTM-007", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "rtm-bad-source-ref", Path: "tests/fixtures/invalid-rtm-bad-source-ref", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "RTM-008", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "rtm-missing-design-file", Path: "tests/fixtures/invalid-rtm-missing-design-file", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "RTM-009", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "rtm-bad-status", Path: "tests/fixtures/invalid-rtm-bad-status", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "RTM-010", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "rtm-freetext-evidence", Path: "tests/fixtures/invalid-rtm-freetext-evidence", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "RTM-005", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-broken-link", Path: "tests/fixtures/invalid-broken-link", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "LINK-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "invalid-sensitive-env", Path: "tests/fixtures/invalid-sensitive-env", Mode: "Standard", Gate: "Scope", ShouldPass: false, Rule: "SENSITIVE-001", ExpectedLevel: "WARN", Type: "negative", FailOnWarning: true },
  { Name: "invalid-placeholder-release", Path: "tests/fixtures/invalid-placeholder-release", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "PLACEHOLDER-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "release-status-not-done", Path: "tests/fixtures/invalid-release-status-not-done", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "RELEASE-STATUS-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "release-scope-excluded-no-reason", Path: "tests/fixtures/invalid-release-scope-excluded-no-reason", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "RELEASE-SCOPE-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "test-evidence-unresolvable", Path: "tests/fixtures/invalid-test-evidence-unresolvable", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "TEST-EVIDENCE-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "review-stage-none-at-release", Path: "tests/fixtures/invalid-review-stage-none-release", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "REVIEW-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "qa-review-missing", Path: "tests/fixtures/invalid-qa-review-missing", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "QA-REVIEW-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "lite-rollback-waiver-valid", Path: "tests/fixtures/valid-lite-rollback-waiver", Mode: "Lite", Gate: "Release", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive" },
  { Name: "source-broken-link-non-blocking", Path: "tests/fixtures/valid-source-broken-link-non-blocking", Mode: "Standard", Gate: "Release", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive", FailOnWarning: true },
  { Name: "security-review-pending", Path: "tests/fixtures/invalid-security-review-pending", Mode: "Strict", Gate: "Release", ShouldPass: false, Rule: "SECURITY-REVIEW-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "evidence-file-missing", Path: "tests/fixtures/invalid-evidence-file-missing", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "TEST-EVIDENCE-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "malformed-external-evidence", Path: "tests/fixtures/invalid-malformed-external-evidence", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "QA-REVIEW-001", ExpectedLevel: "FAIL", Type: "negative" },
  { Name: "handoff-demo-standard", Path: "examples/HANDOFF-DEMO", Mode: "Standard", Gate: "Handoff", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive", FailOnWarning: true },
  { Name: "handoff-demo-design-gate-unaffected", Path: "examples/HANDOFF-DEMO", Mode: "Standard", Gate: "Design", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive", FailOnWarning: true },
  { Name: "handoff-demo-scope-gate-unaffected", Path: "examples/HANDOFF-DEMO", Mode: "Standard", Gate: "Scope", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive", FailOnWarning: true },
  { Name: "example-standard-feature-handoff", Path: "examples/STANDARD-FEATURE", Mode: "Standard", Gate: "Handoff", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive", FailOnWarning: true },
  { Name: "valid-handoff-lite", Path: "tests/fixtures/valid-handoff-lite", Mode: "Lite", Gate: "Handoff", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive", FailOnWarning: true },
  { Name: "valid-handoff-strict", Path: "tests/fixtures/valid-handoff-strict", Mode: "Strict", Gate: "Handoff", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive", FailOnWarning: true },
  { Name: "valid-handoff-action-blocks-demo", Path: "tests/fixtures/valid-handoff-action-blocks-demo", Mode: "Standard", Gate: "Handoff", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive", FailOnWarning: true },
  { Name: "handoff-missing", Path: "tests/fixtures/invalid-handoff-missing", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-001", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: ["STRUCT-001", "LINK-001"] },
  { Name: "handoff-missing-buildspec", Path: "tests/fixtures/invalid-handoff-missing-buildspec", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-001", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: ["STRUCT-001", "LINK-001", "REF-001"] },
  { Name: "handoff-metadata-incomplete", Path: "tests/fixtures/invalid-handoff-metadata-incomplete", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-001", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-scope-incomplete", Path: "tests/fixtures/invalid-handoff-scope-incomplete", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-002", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-scope-unresolved-ref", Path: "tests/fixtures/invalid-handoff-scope-unresolved-ref", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-002", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: ["HANDOFF-004"] },
  { Name: "handoff-generic-owner", Path: "tests/fixtures/invalid-handoff-generic-owner", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-003", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-workitem-generic-owner", Path: "tests/fixtures/invalid-handoff-workitem-generic-owner", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-003", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-lite-generic-owner-warns", Path: "tests/fixtures/invalid-handoff-lite-generic-owner", Mode: "Lite", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-003", ExpectedLevel: "WARN", Type: "negative", FailOnWarning: true, AllowedSecondaryRules: [] },
  { Name: "handoff-dependency-missing", Path: "tests/fixtures/invalid-handoff-dependency-missing", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-004", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-sequence-inverted", Path: "tests/fixtures/invalid-handoff-sequence-inverted", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-004", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-sequence-blank-depends", Path: "tests/fixtures/invalid-handoff-sequence-blank-depends", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-004", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-buildspec-section-missing", Path: "tests/fixtures/invalid-handoff-buildspec-section-missing", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-005", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-buildspec-waiver-no-rationale", Path: "tests/fixtures/invalid-handoff-buildspec-waiver-no-rationale", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-005", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-buildspec-waiver-not-allowed", Path: "tests/fixtures/invalid-handoff-buildspec-waiver-not-allowed", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-005", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-acceptance-no-execution", Path: "tests/fixtures/invalid-handoff-acceptance-no-execution", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-006", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-acceptance-no-fixture", Path: "tests/fixtures/invalid-handoff-acceptance-no-fixture", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-007", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-demo-no-integrator", Path: "tests/fixtures/invalid-handoff-demo-no-integrator", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-008", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-demo-no-reset", Path: "tests/fixtures/invalid-handoff-demo-no-reset", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-008", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-action-no-owner", Path: "tests/fixtures/invalid-handoff-action-no-owner", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-009", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-action-no-blocking-point", Path: "tests/fixtures/invalid-handoff-action-no-blocking-point", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-009", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-review-missing", Path: "tests/fixtures/invalid-handoff-review-missing", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-010", ExpectedLevel: "WARN", Type: "negative", FailOnWarning: true, AllowedSecondaryRules: ["LINK-001"] },
  { Name: "handoff-review-stale", Path: "tests/fixtures/invalid-handoff-review-stale", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-010", ExpectedLevel: "WARN", Type: "negative", FailOnWarning: true, AllowedSecondaryRules: [] },
  { Name: "handoff-review-unknown-lens", Path: "tests/fixtures/invalid-handoff-review-unknown-lens", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-010", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-review-finding-no-owner", Path: "tests/fixtures/invalid-handoff-review-finding-no-owner", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-010", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-review-open-critical-warns", Path: "tests/fixtures/invalid-handoff-review-open-critical", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-010", ExpectedLevel: "WARN", Type: "negative", FailOnWarning: true, AllowedSecondaryRules: [] },
  { Name: "handoff-sensitive-no-decision", Path: "tests/fixtures/invalid-handoff-sensitive-no-decision", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-011", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-capability-unresolved", Path: "tests/fixtures/invalid-handoff-capability-unresolved", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-012", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-environment-unresolved", Path: "tests/fixtures/invalid-handoff-environment-unresolved", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-012", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-ai-closed-human-lens", Path: "tests/fixtures/invalid-handoff-ai-closed-human-lens", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-010", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-accepted-risk-no-decision", Path: "tests/fixtures/invalid-handoff-accepted-risk-no-decision", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-010", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-closed-unresolvable-decision", Path: "tests/fixtures/invalid-handoff-closed-unresolvable-decision", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-010", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-review-stale-inputs", Path: "tests/fixtures/invalid-handoff-review-stale-inputs", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-010", ExpectedLevel: "WARN", Type: "negative", FailOnWarning: true, AllowedSecondaryRules: [] },
  { Name: "handoff-review-no-input-digest", Path: "tests/fixtures/invalid-handoff-review-no-input-digest", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-010", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-acceptance-unresolved-requirement", Path: "tests/fixtures/invalid-handoff-acceptance-unresolved-requirement", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-006", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-sensitive-freetext-decision", Path: "tests/fixtures/invalid-handoff-sensitive-freetext-decision", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-011", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-environment-freetext-decision", Path: "tests/fixtures/invalid-handoff-environment-freetext-decision", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-012", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-mode-mismatch", Path: "tests/fixtures/invalid-handoff-mode-mismatch", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-001", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-horizon-not-a-date", Path: "tests/fixtures/invalid-handoff-horizon-not-a-date", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-001", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-buildspec-ref-missing", Path: "tests/fixtures/invalid-handoff-buildspec-ref-missing", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-001", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-sensitive-undeclared", Path: "tests/fixtures/invalid-handoff-sensitive-undeclared", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-011", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-human-closure-generic-decider", Path: "tests/fixtures/invalid-handoff-human-closure-generic-decider", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-010", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-human-closure-no-decision-log", Path: "tests/fixtures/invalid-handoff-human-closure-no-decision-log", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-010", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-header-renamed", Path: "tests/fixtures/invalid-handoff-header-renamed", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-013", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: ["HANDOFF-009"] },
  { Name: "handoff-header-reordered", Path: "tests/fixtures/invalid-handoff-header-reordered", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-013", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: ["HANDOFF-004"] },
  { Name: "handoff-header-buildspec", Path: "tests/fixtures/invalid-handoff-header-buildspec", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-013", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-project-mismatch", Path: "tests/fixtures/invalid-handoff-project-mismatch", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-014", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "handoff-review-project-mismatch", Path: "tests/fixtures/invalid-handoff-review-project-mismatch", Mode: "Standard", Gate: "Handoff", ShouldPass: false, Rule: "HANDOFF-014", ExpectedLevel: "FAIL", Type: "negative", AllowedSecondaryRules: [] },
  { Name: "optional-tracks-design", Path: "examples/OPTIONAL-TRACKS", Mode: "Standard", Gate: "Design", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive", FailOnWarning: true },
  { Name: "optional-tracks-handoff", Path: "examples/OPTIONAL-TRACKS", Mode: "Standard", Gate: "Handoff", ShouldPass: true, Rule: "", ExpectedLevel: "", Type: "positive", FailOnWarning: true },
  { Name: "optional-tracks-release", Path: "examples/OPTIONAL-TRACKS", Mode: "Standard", Gate: "Release", ShouldPass: false, Rule: "", ExpectedLevel: "", Type: "negative" },
];

interface DoctorCase {
  Name: string;
  SkillRoot?: string;
  TemplateRoot?: string;
  Rule: string;
}

const DOCTOR_CASES: DoctorCase[] = [
  { Name: "skill-without-frontmatter", SkillRoot: "tests/doctor-fixtures/skill-without-frontmatter/skills", Rule: "DOCTOR-SKILL-001" },
  { Name: "skill-name-mismatch", SkillRoot: "tests/doctor-fixtures/skill-name-mismatch/skills", Rule: "DOCTOR-SKILL-001" },
  { Name: "broken-table-missing-column", TemplateRoot: "tests/doctor-fixtures/broken-table-missing-column/templates", Rule: "TABLE-001" },
  { Name: "broken-table-extra-column", TemplateRoot: "tests/doctor-fixtures/broken-table-extra-column/templates", Rule: "TABLE-001" },
  { Name: "broken-table-wrong-order-column", TemplateRoot: "tests/doctor-fixtures/broken-table-wrong-order-column/templates", Rule: "TABLE-001" },
];

export interface ValidationFixturesResult {
  output: string;
  exitCode: number;
}

export function runValidationFixtures(repoRoot: string, verifyGolden: boolean, goldenMasterDir?: string): ValidationFixturesResult {
  const repo = resolve(repoRoot);
  const goldenDir = goldenMasterDir ? resolve(goldenMasterDir) : join(repo, "tests/golden");
  const out: string[] = [];
  let pass = 0;
  let fail = 0;
  const positive = CASES.filter((c) => c.Type === "positive").length;
  const negative = CASES.filter((c) => c.Type === "negative").length;

  out.push(`Axiom-PMO Validation Fixture Tests: ${repo}`);
  out.push(`Matrix: positive=${positive} negative=${negative} doctor-negative=${DOCTOR_CASES.length} total=${CASES.length + DOCTOR_CASES.length}`);
  out.push("");

  const goldenMismatches: string[] = [];
  const goldenDiffReports: Array<{ name: string; lines: string[] }> = [];

  for (const c of CASES) {
    const projectPath = join(repo, c.Path);
    const r = runValidateEnvelope(repo, projectPath, c.Mode, c.Gate, Boolean(c.FailOnWarning), "Json");
    // The JSON envelope embeds the resolved absolute project path, which
    // differs by checkout location -- stripped to the same "<REPO_ROOT>"
    // placeholder the committed golden masters already use, so golden text
    // captured on one machine verifies correctly on any other.
    const rawOutput = `${r.output.trimEnd().split(repo).join("<REPO_ROOT>")}\nEXIT_CODE=${r.exitCode}`;

    if (verifyGolden) {
      const goldenFile = join(goldenDir, `${c.Name}.txt`);
      if (!existsSync(goldenFile)) {
        goldenMismatches.push(`${c.Name}: no golden file recorded`);
      } else {
        const expected = readFileSync(goldenFile, "utf8");
        if (!testGoldenMatch(expected, rawOutput)) {
          goldenMismatches.push(`${c.Name}: output differs from golden master`);
          goldenDiffReports.push({ name: c.Name, lines: getGoldenDiffReport(expected, rawOutput) });
        }
      }
    }

    const actualPass = r.exitCode === 0;
    let results: Array<{ rule_id: string; level: string }> = [];
    try {
      results = (JSON.parse(r.output) as { results?: Array<{ rule_id: string; level: string }> }).results ?? [];
    } catch {
      results = [];
    }

    let ruleOk = true;
    let unexpectedRuleOk = true;
    if (!c.ShouldPass && c.Rule) {
      ruleOk = results.some((x) => x.rule_id === c.Rule && x.level === c.ExpectedLevel);

      // Presence check, not truthiness: an explicitly-supplied empty
      // AllowedSecondaryRules means "this fixture must fire nothing else",
      // and an empty array is not distinguishable from "absent" by
      // truthiness alone -- that would silently turn the strictest possible
      // assertion into no assertion at all.
      if (c.AllowedSecondaryRules !== undefined || c.ForbiddenRules !== undefined) {
        const primaryAndAllowed = [c.Rule, ...(c.AllowedSecondaryRules ?? [])];
        const observedBlockingRules = [...new Set(
          results.filter((x) => x.level === "FAIL" || (c.FailOnWarning && x.level === "WARN")).map((x) => x.rule_id),
        )];
        const unexpectedBlockingRules = observedBlockingRules.filter((x) => !primaryAndAllowed.includes(x));
        unexpectedRuleOk = unexpectedBlockingRules.length === 0;
      }
      if (c.ForbiddenRules && c.ForbiddenRules.length > 0) {
        const forbiddenHits = results.filter((x) => c.ForbiddenRules!.includes(x.rule_id));
        if (forbiddenHits.length > 0) unexpectedRuleOk = false;
      }
    }

    if (actualPass === c.ShouldPass && ruleOk && unexpectedRuleOk) {
      pass++;
      out.push(`[PASS] ${c.Name}`);
    } else {
      fail++;
      const expected = c.ShouldPass ? "pass" : "fail";
      const actual = actualPass ? "pass" : "fail";
      const ruleMessage = c.Rule ? ` expected ${c.ExpectedLevel} ${c.Rule}` : "";
      out.push(`[FAIL] ${c.Name} expected ${expected}${ruleMessage} but got ${actual}`);
    }
  }

  for (const c of DOCTOR_CASES) {
    const result = runPmoDoctor(repo, c.SkillRoot ? join(repo, c.SkillRoot) : "", c.TemplateRoot ? join(repo, c.TemplateRoot) : "");
    const fired = result.rows.some((row) => row.level === "FAIL" && row.rule_id === c.Rule);
    if (result.fail > 0 && fired) {
      pass++;
      out.push(`[PASS] doctor-${c.Name}`);
    } else {
      fail++;
      out.push(`[FAIL] doctor-${c.Name} expected FAIL ${c.Rule} but got exit ${result.fail > 0 ? 1 : 0}`);
    }
  }

  out.push("");
  out.push(`Summary: PASS=${pass} FAIL=${fail}`);

  if (verifyGolden) {
    if (goldenMismatches.length > 0) {
      out.push("");
      out.push(`Golden master verification FAILED (${goldenMismatches.length} mismatch(es)):`);
      for (const m of goldenMismatches) out.push(`  - ${m}`);
      if (goldenDiffReports.length > 0) {
        out.push("");
        out.push("Differing lines (canonical form, the same comparison testGoldenMatch makes):");
        for (const report of goldenDiffReports) {
          out.push(`    ${report.name}:`);
          for (const line of report.lines) out.push(line);
        }
      }
    } else {
      out.push(`Golden master verification: all ${CASES.length} case(s) match (canonical comparison)`);
    }
  }

  const exitCode = fail > 0 || (verifyGolden && goldenMismatches.length > 0) ? 1 : 0;
  return { output: out.join("\n") + "\n", exitCode };
}
