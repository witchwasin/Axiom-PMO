// Release readiness, ported from scripts/lib/release-validator.ps1.

import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { getTableRowsAfterHeading, getTableLinesAfterHeading, type TableRow } from "../markdown/table-parser.js";
import { testPlaceholderValue, testDateValue } from "../config/config-loader.js";
import { resolveReference, type ReferenceTypesConfig } from "../core/reference-resolver.js";
import { addResult } from "../core/result-writer.js";
import type { ResultAccumulator, ValidationRules } from "../core/context.js";
import type { Mode, Gate } from "../core/types.js";
import { getReleaseRegistry, testTestSummary, testRtmTraceability, type ReleaseRegistry } from "./rtm-validator.js";

export interface ApproverContext {
  project: string;
  referenceTypesConfig: ReferenceTypesConfig;
  policy: Record<string, unknown>;
}

export function testRaidBlocker(acc: ResultAccumulator, catalog: ValidationRules | undefined, project: string, gate: Gate): void {
  const raidPath = join(project, "RAID-log.md");
  if (!existsSync(raidPath)) return;
  const raidText = readFileSync(raidPath, "utf8");
  const blockerOpen = /\bblocker\b.*\bopen\b|\bopen\b.*\bblocker\b/i.test(raidText);
  if (gate === "Release" && blockerOpen) {
    addResult(acc, catalog, "FAIL", "Open blocker found in RAID-log.md during release validation", { ruleId: "BLOCKER-001" });
  } else if (blockerOpen) {
    addResult(acc, catalog, "WARN", "Open blocker found in RAID-log.md", { ruleId: "BLOCKER-001" });
  } else {
    addResult(acc, catalog, "PASS", "No open blocker pattern found", { ruleId: "BLOCKER-001" });
  }
}

function testReviewRow(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  ctx: ApproverContext,
  releaseText: string,
  reviewType: string,
  ruleId: string,
  approvalMode: Mode,
  decisionIds: string[] | null,
  registry: ReleaseRegistry,
): boolean {
  const rows = getTableRowsAfterHeading(releaseText, "^##\\s+QA\\s*/\\s*Security Review");
  const row = rows.find((r) => r["Review Type"] === reviewType);
  if (!row) {
    addResult(acc, catalog, "FAIL", `${reviewType} review row not found in QA / Security Review table`, { ruleId });
    return false;
  }

  const invalid: string[] = [];
  if (row["Status"] !== "approved") invalid.push("status");
  if (testPlaceholderValue(row["Reviewer"] ?? "")) invalid.push("reviewer");
  if (testPlaceholderValue(row["Role"] ?? "")) invalid.push("role");
  if (testPlaceholderValue(row["Date"] ?? "") || !testDateValue(row["Date"] ?? "")) invalid.push("date");
  if (testPlaceholderValue(row["Evidence"] ?? "")) {
    invalid.push("evidence");
  } else {
    const ref = resolveReference(row["Evidence"]!, ctx.referenceTypesConfig, ctx.project, decisionIds, null, null, registry.testIds);
    if (ref.pathEscaped) {
      addResult(acc, catalog, "FAIL", `${reviewType} review evidence '${row["Evidence"]}' points outside the project root`, { ruleId: "REF-002" });
      return false;
    }
    if (ref.externallyUnverified) {
      addResult(acc, catalog, "FAIL", `${reviewType} review evidence '${row["Evidence"]}' is an external reference the validator cannot verify as a decision`, { ruleId: "APPROVAL-004" });
      return false;
    }
    if (!ref.type) invalid.push("evidence_unrecognized_type");
    else if (!ref.resolved) invalid.push("evidence_not_found");
  }

  if (invalid.length > 0) {
    addResult(acc, catalog, "FAIL", `${reviewType} review row has invalid or placeholder fields: ${invalid.join(", ")}`, { ruleId });
    return false;
  }

  const allowedRoles = (ctx.policy["approval_roles"] as Record<string, unknown> | undefined)?.[`${reviewType} Approved`] as string[] | undefined;
  if (allowedRoles && !allowedRoles.includes(row["Role"]!)) {
    if (approvalMode === "Strict") {
      addResult(acc, catalog, "FAIL", `${reviewType} reviewer role '${row["Role"]}' is not in the allowed role matrix (${allowedRoles.join(", ")})`, { ruleId });
      return false;
    } else {
      addResult(acc, catalog, "WARN", `${reviewType} reviewer role '${row["Role"]}' is not in the allowed role matrix (${allowedRoles.join(", ")})`, { ruleId, blocking: true });
    }
  }

  addResult(acc, catalog, "PASS", `${reviewType} review is valid`, { ruleId });
  return true;
}

export interface ReleaseArtifactResult {
  releaseText: string;
  releaseRegistry: ReleaseRegistry;
}

export function testReleaseArtifact(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  ctx: ApproverContext,
  project: string,
  mode: Mode,
  gate: Gate,
  deliveryIds: string[],
  decisionIds: string[] | null,
): ReleaseArtifactResult {
  let releaseText = "";
  const releasePath = join(project, "RELEASE.md");
  let releaseRegistry: ReleaseRegistry = { releaseId: null, testIds: [], testRows: [] };
  if (!(gate === "Release" && existsSync(releasePath))) {
    return { releaseText, releaseRegistry };
  }

  releaseText = readFileSync(releasePath, "utf8");
  releaseRegistry = getReleaseRegistry(releaseText);

  const rollbackSectionLines = getTableLinesAfterHeading(releaseText, "^##\\s+Structured Rollback Plan");
  const waiverMatch = /^##\s+Structured Rollback Plan\s*([\s\S]*?)(?=^##\s|(?![\s\S]))/m.exec(releaseText);
  let waiver: { changeType: string; reason: string; approver: string } | null = null;
  if (waiverMatch && /^\s*rollback_required:\s*false\s*$/m.test(waiverMatch[1]!)) {
    const section = waiverMatch[1]!;
    waiver = {
      changeType: /^\s*change_type:\s*(.+?)\s*$/m.exec(section)?.[1] ?? "",
      reason: /^\s*reason:\s*(.+?)\s*$/m.exec(section)?.[1] ?? "",
      approver: /^\s*approver:\s*(.+?)\s*$/m.exec(section)?.[1] ?? "",
    };
  }

  if (waiver) {
    const waiverRule = (ctx.policy["rollback_waiver"] as Record<string, unknown>) ?? {};
    const waiverAllowedModes = (waiverRule["allowed_modes"] as string[]) ?? [];
    const waiverAllowedTypes = (waiverRule["allowed_change_types"] as string[]) ?? [];
    const waiverInvalid: string[] = [];
    if (!waiverAllowedModes.includes(mode)) waiverInvalid.push(`mode ${mode} is not allowed to waive rollback`);
    if (!waiverAllowedTypes.includes(waiver.changeType)) waiverInvalid.push(`change_type '${waiver.changeType}' is not on the waiver allowlist`);
    if (testPlaceholderValue(waiver.reason)) waiverInvalid.push("reason is missing");
    if (testPlaceholderValue(waiver.approver)) waiverInvalid.push("approver is missing");
    if (waiverInvalid.length === 0) {
      addResult(acc, catalog, "PASS", `Release rollback is validly waived (change_type=${waiver.changeType})`, { ruleId: "RELEASE-001" });
    } else {
      addResult(acc, catalog, "FAIL", `Release rollback waiver is invalid: ${waiverInvalid.join("; ")}`, { ruleId: "RELEASE-001" });
    }
  } else {
    const badRollbackRows: string[] = [];
    let rollbackDataRows = 0;
    if (rollbackSectionLines.length >= 3) {
      for (const line of rollbackSectionLines.slice(2)) {
        const parts = line.split("|");
        const cells: string[] = [];
        for (let i = 1; i < parts.length - 1; i++) cells.push(parts[i]!.trim());
        if (cells.length < 5) {
          badRollbackRows.push(line);
          continue;
        }
        rollbackDataRows++;
        if (cells.slice(0, 5).some((c) => testPlaceholderValue(c))) badRollbackRows.push(line);
      }
    }
    if (rollbackDataRows > 0 && badRollbackRows.length === 0) {
      addResult(acc, catalog, "PASS", "Release includes structured rollback plan", { ruleId: "RELEASE-001" });
    } else {
      addResult(acc, catalog, "FAIL", "Release rollback table is missing or has empty rows", { ruleId: "RELEASE-001" });
    }
  }

  const scopeMatches = releaseText.match(/\bD-\d{3}\b/g) ?? [];
  const missingReleaseRefs = [...new Set(scopeMatches.filter((d) => !deliveryIds.includes(d)))].sort();
  if (missingReleaseRefs.length > 0) {
    addResult(acc, catalog, "FAIL", `Release references missing delivery item(s): ${missingReleaseRefs.join(", ")}`, { ruleId: "REF-001" });
  }

  if (mode !== "Lite") {
    testReviewRow(acc, catalog, ctx, releaseText, "QA", "QA-REVIEW-001", mode, decisionIds, releaseRegistry);
    if (mode === "Strict") {
      testReviewRow(acc, catalog, ctx, releaseText, "Security", "SECURITY-REVIEW-001", mode, decisionIds, releaseRegistry);
    }
    testTestSummary(acc, catalog, releaseRegistry, project, ctx.referenceTypesConfig, decisionIds, mode);

    const testWaiverMatch = /^##\s+Test Summary\s*([\s\S]*?)(?=^##\s|(?![\s\S]))/m.exec(releaseText);
    let testWaiver: { reason: string; approvedBy: string; evidence: string } | null = null;
    if (testWaiverMatch && /^\s*test_required:\s*false\s*$/m.test(testWaiverMatch[1]!)) {
      const section = testWaiverMatch[1]!;
      testWaiver = {
        reason: /^\s*reason:\s*(.+?)\s*$/m.exec(section)?.[1] ?? "",
        approvedBy: /^\s*approved_by:\s*(.+?)\s*$/m.exec(section)?.[1] ?? "",
        evidence: /^\s*evidence:\s*(.+?)\s*$/m.exec(section)?.[1] ?? "",
      };
    }

    if (releaseRegistry.testRows.length === 0) {
      if (testWaiver) {
        const testWaiverRule = (ctx.policy["test_waiver"] as Record<string, unknown>) ?? {};
        const testWaiverAllowedModes = (testWaiverRule["allowed_modes"] as string[]) ?? [];
        const testWaiverInvalid: string[] = [];
        if (!testWaiverAllowedModes.includes(mode)) testWaiverInvalid.push(`mode ${mode} is not allowed to waive testing`);
        if (testPlaceholderValue(testWaiver.reason)) testWaiverInvalid.push("reason is missing");
        if (testPlaceholderValue(testWaiver.approvedBy)) testWaiverInvalid.push("approved_by is missing");
        if (testPlaceholderValue(testWaiver.evidence)) {
          testWaiverInvalid.push("evidence is missing");
        } else {
          const testWaiverRef = resolveReference(testWaiver.evidence, ctx.referenceTypesConfig, ctx.project, decisionIds);
          if (!testWaiverRef.type || !testWaiverRef.resolved) testWaiverInvalid.push("evidence does not resolve");
        }
        if (testWaiverInvalid.length === 0) {
          addResult(acc, catalog, "PASS", "Release testing is validly waived (reason recorded)", { ruleId: "TEST-SUMMARY-001" });
        } else {
          addResult(acc, catalog, "FAIL", `Release test waiver is invalid: ${testWaiverInvalid.join("; ")}`, { ruleId: "TEST-SUMMARY-001" });
        }
      } else {
        addResult(acc, catalog, "FAIL", `${mode} Release requires at least one Test Summary row (or a valid test_required: false waiver)`, { ruleId: "TEST-SUMMARY-001" });
      }
    } else {
      addResult(acc, catalog, "PASS", "Release includes at least one Test Summary row", { ruleId: "TEST-SUMMARY-001" });
      if (mode === "Strict") {
        const passedRows = releaseRegistry.testRows.filter((r) => (r["Result"] ?? "").trim().toLowerCase() === "passed");
        if (passedRows.length === 0) {
          addResult(acc, catalog, "FAIL", "Strict release cannot have every Test Summary row skipped; at least one row must be passed", { ruleId: "TEST-SUMMARY-001" });
        }
      }
    }
  }

  return { releaseText, releaseRegistry };
}

export function testReleaseScopeCompletion(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  ctx: ApproverContext,
  workItems: TableRow[],
  releaseText: string,
  mode: Mode,
  gate: Gate,
  decisionIds: string[] | null,
  releaseRegistry: ReleaseRegistry,
): void {
  if (!(gate === "Release" && workItems && workItems.length > 0)) return;

  let releaseScopeRows: TableRow[] = [];
  if (releaseText) releaseScopeRows = getTableRowsAfterHeading(releaseText, "^##\\s+Release Scope");
  for (const item of workItems) {
    const scopeRow = releaseScopeRows.find((r) => r["Deliverable"] === item["ID"]);
    let included = true;
    if (scopeRow) {
      included = scopeRow["Included?"] !== "no";
    } else if (releaseScopeRows.length > 0) {
      addResult(acc, catalog, "FAIL", `${item["ID"]} is not listed in the Release Scope table`, { ruleId: "RELEASE-SCOPE-001" });
      continue;
    }

    if (!included) {
      if (testPlaceholderValue(scopeRow?.["Notes"] ?? "")) {
        addResult(acc, catalog, "FAIL", `${item["ID"]} is excluded from release scope but Notes does not state a reason`, { ruleId: "RELEASE-SCOPE-001" });
      } else {
        addResult(acc, catalog, "PASS", `${item["ID"]} is intentionally excluded from release scope`, { ruleId: "RELEASE-SCOPE-001" });
      }
      continue;
    }

    if (item["Status"] !== "Done") {
      addResult(acc, catalog, "FAIL", `${item["ID"]} is in release scope but Status is '${item["Status"]}', not Done`, { ruleId: "RELEASE-STATUS-001" });
    }
    if (mode !== "Lite" && item["Review Stage"] === "none") {
      addResult(acc, catalog, "FAIL", `${item["ID"]} is in release scope but has no Review Stage`, { ruleId: "REVIEW-001" });
    }
    if (testPlaceholderValue(item["Test Checklist"] ?? "")) {
      addResult(acc, catalog, "FAIL", `${item["ID"]} is in release scope but Test Checklist is empty`, { ruleId: "TEST-EVIDENCE-001" });
    }
    if (mode !== "Lite") {
      const itemEvidence = resolveReference(item["Evidence Ref"] ?? "", ctx.referenceTypesConfig, ctx.project, decisionIds, null, null, releaseRegistry.testIds);
      if (!itemEvidence.type || !itemEvidence.resolved) {
        addResult(acc, catalog, "FAIL", `${item["ID"]} is in release scope but Evidence Ref '${item["Evidence Ref"]}' does not resolve to a real reference`, { ruleId: "TEST-EVIDENCE-001" });
      }
    } else if (testPlaceholderValue(item["Evidence Ref"] ?? "")) {
      addResult(acc, catalog, "FAIL", `${item["ID"]} is in release scope but Evidence Ref is empty`, { ruleId: "TEST-EVIDENCE-001" });
    } else {
      const liteItemEvidence = resolveReference(item["Evidence Ref"]!, ctx.referenceTypesConfig, ctx.project, decisionIds, null, null, releaseRegistry.testIds);
      if (!liteItemEvidence.type || !liteItemEvidence.resolved) {
        addResult(acc, catalog, "WARN", `${item["ID"]} Evidence Ref '${item["Evidence Ref"]}' is not a resolvable reference (use DEC-###, ISSUE:n, FILE:path, TEST-###)`, { ruleId: "TEST-EVIDENCE-001", blocking: true });
      }
    }
  }
}

export function testStrictReleaseGuardrails(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  ctx: ApproverContext,
  policyEnums: Record<string, unknown>,
  sourceRefRegex: string,
  project: string,
  mode: Mode,
  gate: Gate,
  projectReqIds: string[],
  deliveryIds: string[],
  decisionIds: string[] | null,
  releaseRegistry: ReleaseRegistry,
  projectSourceIds: string[],
): void {
  if (!(mode === "Strict" && gate === "Release")) return;

  const strictMissing: string[] = [];
  if (!existsSync(join(project, "RTM.json"))) strictMissing.push("RTM.json");
  if (!existsSync(join(project, "RAID-log.md"))) strictMissing.push("RAID-log.md");
  if (!existsSync(join(project, "decision-log.md"))) strictMissing.push("decision-log.md");

  testRtmTraceability(acc, catalog, project, ctx.referenceTypesConfig, policyEnums, sourceRefRegex, projectReqIds, deliveryIds, decisionIds, releaseRegistry, projectSourceIds);

  if (strictMissing.length > 0) {
    addResult(acc, catalog, "FAIL", `Strict release is missing required guardrails: ${strictMissing.join(", ")}`, { ruleId: "STRICT-002" });
  } else {
    addResult(acc, catalog, "PASS", "Strict release includes traceability, review, and release evidence guardrails", { ruleId: "STRICT-002" });
  }
}
