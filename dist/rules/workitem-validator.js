// DELIVERY.md work-item table validation, ported from
// scripts/lib/workitem-validator.ps1.
import { readFileSync, existsSync, statSync } from "node:fs";
import { join } from "node:path";
import { getTableRowsAfterHeading, getIdsFromRows, splitReferenceValues } from "../markdown/table-parser.js";
import { testFieldValue } from "../config/field-value.js";
import { addResult } from "../core/result-writer.js";
function getDesignPathFromRef(value) {
    const m = /(DESIGN[\\/][^\s,|]+?\.(puml|md|html))/.exec(value);
    return m ? m[1] : "";
}
export function testDeliveryWorkItems(acc, catalog, project, deliveryPath, gate, policyEnums, sentinelRules, projectReqIds, projectBusinessIds, projectTaskSource) {
    let deliveryText = null;
    let workItems = [];
    let deliveryIds = [];
    if (existsSync(deliveryPath)) {
        deliveryText = readFileSync(deliveryPath, "utf8");
        let deliveryTaskSource = null;
        const m = /^\s*-\s*Task source of truth:\s*`?(file|github)`?\s*$/m.exec(deliveryText);
        if (m) {
            deliveryTaskSource = m[1];
            addResult(acc, catalog, "PASS", "Delivery task source of truth is explicit", { ruleId: "TASK-001" });
        }
        else {
            const lvl = gate === "Release" ? "FAIL" : "WARN";
            addResult(acc, catalog, lvl, "Delivery task source of truth should be file or github", { ruleId: "TASK-001" });
        }
        if (projectTaskSource && deliveryTaskSource && projectTaskSource !== deliveryTaskSource) {
            addResult(acc, catalog, "FAIL", `PROJECT.md task source (${projectTaskSource}) does not match DELIVERY.md task source (${deliveryTaskSource})`, { ruleId: "TASK-002" });
        }
        const hasHeaders = deliveryText.includes("| Mode |") &&
            deliveryText.includes("| Strict Trigger |") &&
            deliveryText.includes("| Mode Reason |") &&
            deliveryText.includes("| Mode Approved By |") &&
            deliveryText.includes("| Review Stage |") &&
            deliveryText.includes("| Evidence Ref |");
        if (hasHeaders) {
            addResult(acc, catalog, "PASS", "Delivery work items include mode, strict trigger, reason, approval, review, and evidence fields", { ruleId: "WORKITEM-001" });
        }
        else {
            const lvl = gate === "Release" ? "FAIL" : "WARN";
            addResult(acc, catalog, lvl, "Delivery work items should include Mode, Strict Trigger, Mode Reason, Mode Approved By, Review Stage, and Evidence Ref", { ruleId: "WORKITEM-001" });
        }
        workItems = getTableRowsAfterHeading(deliveryText, "^##\\s+Work Items");
        deliveryIds = getIdsFromRows(workItems);
        const modes = policyEnums["modes"] ?? [];
        const statuses = policyEnums["statuses"] ?? [];
        const reviewStages = policyEnums["review_stages"] ?? [];
        const strictTriggers = policyEnums["strict_triggers"] ?? [];
        for (const item of workItems) {
            const requiredFields = ["ID", "Mode", "Mode Reason", "Mode Approved By", "Requirement Ref", "Design Ref", "Acceptance Criteria", "Test Checklist", "Owner", "Status", "Review Stage", "Evidence Ref"];
            const blankFields = requiredFields.filter((f) => !item[f] || testFieldValue(f, item[f], item["Mode"] ?? "", sentinelRules));
            if (blankFields.length > 0) {
                const lvl = gate === "Release" ? "FAIL" : "WARN";
                addResult(acc, catalog, lvl, `${item["ID"]} has missing work item fields: ${blankFields.join(", ")}`, { ruleId: "WORKITEM-001" });
            }
            if (!modes.includes(item["Mode"] ?? "")) {
                addResult(acc, catalog, "FAIL", `${item["ID"]} has invalid Mode: ${item["Mode"]}`, { ruleId: "ENUM-001" });
            }
            if (!statuses.includes(item["Status"] ?? "")) {
                addResult(acc, catalog, "FAIL", `${item["ID"]} has invalid Status: ${item["Status"]}`, { ruleId: "ENUM-001" });
            }
            if (!reviewStages.includes(item["Review Stage"] ?? "")) {
                addResult(acc, catalog, "FAIL", `${item["ID"]} has invalid Review Stage: ${item["Review Stage"]}`, { ruleId: "ENUM-001" });
            }
            const strict = item["Strict Trigger"];
            if (strict && strict !== "none" && !strictTriggers.includes(strict)) {
                addResult(acc, catalog, "FAIL", `${item["ID"]} has invalid Strict Trigger: ${strict}`, { ruleId: "ENUM-001" });
            }
            if (strict && strict !== "none" && item["Mode"] !== "Strict") {
                addResult(acc, catalog, "FAIL", `${item["ID"]} has strict trigger but mode is ${item["Mode"]}`, { ruleId: "STRICT-001" });
            }
            for (const ref of splitReferenceValues(item["Requirement Ref"] ?? "")) {
                const refId = /\b(REQ-\d{3}|BR-\d{3})\b/.exec(ref)?.[0];
                if (refId && ![...projectReqIds, ...projectBusinessIds].includes(refId)) {
                    addResult(acc, catalog, "FAIL", `${item["ID"]} references missing requirement/business rule: ${refId}`, { ruleId: "REF-001" });
                }
            }
            for (const designRef of splitReferenceValues(item["Design Ref"] ?? "")) {
                if (designRef === "not_required" && !testFieldValue("Design Ref", designRef, item["Mode"] ?? "", sentinelRules))
                    continue;
                const designPath = getDesignPathFromRef(designRef);
                if (designPath && !(existsSync(join(project, designPath)) && statSync(join(project, designPath)).isFile())) {
                    addResult(acc, catalog, "FAIL", `${item["ID"]} references missing design file: ${designPath}`, { ruleId: "REF-001" });
                }
                if (item["Mode"] !== "Lite" && !designPath) {
                    addResult(acc, catalog, "FAIL", `${item["ID"]} is missing a resolvable design reference`, { ruleId: "REF-001" });
                }
            }
        }
    }
    return { deliveryText, workItems, deliveryIds };
}
