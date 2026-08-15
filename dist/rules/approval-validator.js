// Approval gate validation + decision-log ID lookup, ported from
// scripts/lib/approval-validator.ps1.
import { readFileSync, existsSync } from "node:fs";
import { join, relative } from "node:path";
import { getTableRowsAfterHeading } from "../markdown/table-parser.js";
import { testPlaceholderValue, testDateValue } from "../config/config-loader.js";
import { resolveReference } from "../core/reference-resolver.js";
import { testGenericOwner, getHandoffPolicySeverity } from "../core/owner-policy.js";
import { addResult } from "../core/result-writer.js";
export function getDecisionIds(project) {
    const path = join(project, "decision-log.md");
    if (!existsSync(path))
        return [];
    const text = readFileSync(path, "utf8");
    const ids = text.match(/DEC-\d{3}/g) ?? [];
    return [...new Set(ids)].sort();
}
export function testApproval(acc, catalog, ctx, projectText, gateName, decisionIds, requireEvidenceExists, approvalMode) {
    const approvalRows = getTableRowsAfterHeading(projectText, "^##\\s+Approvals");
    const row = approvalRows.find((r) => r["Gate"] === gateName);
    if (!row) {
        addResult(acc, catalog, "FAIL", `Approval row not found for ${gateName}`, { ruleId: "APPROVAL-001" });
        return;
    }
    const status = row["Approval Status"];
    const approver = row["Approver"];
    const role = row["Role"];
    const date = row["Date"];
    const evidence = row["Evidence"];
    const invalid = [];
    if (status !== "approved")
        invalid.push("approval_status");
    if (testPlaceholderValue(approver ?? ""))
        invalid.push("approver");
    if (testPlaceholderValue(role ?? ""))
        invalid.push("role");
    if (testPlaceholderValue(date ?? "") || !testDateValue(date ?? ""))
        invalid.push("date");
    if (testPlaceholderValue(evidence ?? ""))
        invalid.push("evidence");
    if (requireEvidenceExists && !testPlaceholderValue(evidence ?? "")) {
        const ref = resolveReference(evidence, ctx.referenceTypesConfig, ctx.project, decisionIds);
        if (ref.pathEscaped) {
            addResult(acc, catalog, "FAIL", `${gateName} approval evidence '${evidence}' points outside the project root`, { ruleId: "REF-002" });
            return;
        }
        if (ref.externallyUnverified) {
            addResult(acc, catalog, "FAIL", `${gateName} approval evidence '${evidence}' is an external reference the validator cannot verify as a decision`, { ruleId: "APPROVAL-004" });
            return;
        }
        if (!ref.type)
            invalid.push("evidence_unrecognized_type");
        else if (!ref.resolved)
            invalid.push("evidence_not_found");
    }
    if (invalid.length > 0) {
        addResult(acc, catalog, "FAIL", `${gateName} approval has invalid or placeholder fields: ${invalid.join(", ")}`, { ruleId: "APPROVAL-002" });
        return;
    }
    if (!testPlaceholderValue(approver ?? "")) {
        const ownerPolicy = ctx.handoffPolicy["owner_policy"] ?? {};
        if (testGenericOwner(approver, ownerPolicy)) {
            const severityMap = ownerPolicy["severity_by_mode"] ?? null;
            const ownerLevel = getHandoffPolicySeverity(severityMap, approvalMode);
            if (ownerLevel === "FAIL") {
                addResult(acc, catalog, "FAIL", `${gateName} approver '${approver}' is a generic group, not a named person`, { ruleId: "APPROVAL-005" });
                return;
            }
            addResult(acc, catalog, "WARN", `${gateName} approver '${approver}' is a generic group, not a named person`, { ruleId: "APPROVAL-005", blocking: true });
        }
    }
    if (!requireEvidenceExists && !testPlaceholderValue(evidence ?? "")) {
        const liteRef = resolveReference(evidence, ctx.referenceTypesConfig, ctx.project, decisionIds);
        if (!liteRef.type || !liteRef.resolved) {
            addResult(acc, catalog, "WARN", `${gateName} approval evidence '${evidence}' is not a resolvable reference (use DEC-###, ISSUE:n, FILE:path, URL:...)`, { ruleId: "APPROVAL-002", blocking: true });
            addResult(acc, catalog, "PASS", `${gateName} approval is valid`, { ruleId: "APPROVAL-002" });
            return;
        }
    }
    const allowedRoles = ctx.policy["approval_roles"]?.[gateName];
    if (allowedRoles && !testPlaceholderValue(role ?? "") && !allowedRoles.includes(role)) {
        if (approvalMode === "Strict") {
            addResult(acc, catalog, "FAIL", `${gateName} approver role '${role}' is not in the allowed role matrix (${allowedRoles.join(", ")})`, { ruleId: "APPROVAL-003" });
            return;
        }
        else if (approvalMode !== "Lite") {
            addResult(acc, catalog, "WARN", `${gateName} approver role '${role}' is not in the allowed role matrix (${allowedRoles.join(", ")})`, { ruleId: "APPROVAL-003", blocking: true });
        }
    }
    addResult(acc, catalog, "PASS", `${gateName} approval is valid`, { ruleId: "APPROVAL-002" });
}
void relative;
