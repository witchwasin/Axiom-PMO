// Effective mode resolution, ported from scripts/lib/mode-resolver.ps1.
// CLI -Mode may upgrade but never silently downgrade a project's enforcement.
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { getTableRowsAfterHeading } from "../markdown/table-parser.js";
import { addResult } from "./result-writer.js";
const MODE_RANK = { Lite: 1, Standard: 2, Strict: 3 };
export function getProjectDefaultMode(projectRoot) {
    const path = join(projectRoot, "PROJECT.md");
    if (!existsSync(path))
        return null;
    const text = readFileSync(path, "utf8");
    const m = /^\s*>?\s*Default mode:\s*(.+?)\s*$/m.exec(text);
    return m ? m[1].trim() : null;
}
export function getDeliveryModeSignals(projectRoot) {
    const result = { highestMode: null, hasStrictTrigger: false, strictTriggerItem: null };
    const path = join(projectRoot, "DELIVERY.md");
    if (!existsSync(path))
        return result;
    const text = readFileSync(path, "utf8");
    const rows = getTableRowsAfterHeading(text, "^##\\s+Work Items");
    let highest = 0;
    for (const row of rows) {
        const mode = row["Mode"];
        if (mode && MODE_RANK[mode] !== undefined && MODE_RANK[mode] > highest) {
            highest = MODE_RANK[mode];
        }
        const strict = row["Strict Trigger"];
        if (strict && strict !== "none" && !result.hasStrictTrigger) {
            result.hasStrictTrigger = true;
            result.strictTriggerItem = row["ID"] ?? null;
        }
    }
    if (highest > 0) {
        result.highestMode = Object.entries(MODE_RANK).find(([, r]) => r === highest)?.[0] ?? null;
    }
    return result;
}
export function resolveEffectiveMode(acc, catalog, project, requestedMode, gate) {
    const projectDefaultModeRaw = getProjectDefaultMode(project);
    if (projectDefaultModeRaw && MODE_RANK[projectDefaultModeRaw] === undefined) {
        addResult(acc, catalog, "WARN", `PROJECT.md Default mode '${projectDefaultModeRaw}' is not a recognized mode (Lite/Standard/Strict)`, { ruleId: "MODE-002" });
    }
    const deliverySignals = getDeliveryModeSignals(project);
    let effectiveMode = requestedMode;
    const effectiveReasons = [];
    if (projectDefaultModeRaw && MODE_RANK[projectDefaultModeRaw] !== undefined && MODE_RANK[projectDefaultModeRaw] > MODE_RANK[effectiveMode]) {
        effectiveMode = projectDefaultModeRaw;
        effectiveReasons.push(`PROJECT.md Default mode is ${projectDefaultModeRaw}`);
    }
    if (deliverySignals.highestMode && MODE_RANK[deliverySignals.highestMode] > MODE_RANK[effectiveMode]) {
        effectiveMode = deliverySignals.highestMode;
        effectiveReasons.push(`highest work item mode is ${deliverySignals.highestMode}`);
    }
    if (deliverySignals.hasStrictTrigger && MODE_RANK["Strict"] > MODE_RANK[effectiveMode]) {
        effectiveMode = "Strict";
        effectiveReasons.push(`work item ${deliverySignals.strictTriggerItem} has a strict trigger`);
    }
    if (MODE_RANK[effectiveMode] > MODE_RANK[requestedMode]) {
        const modeLevel = gate === "Release" ? "FAIL" : "WARN";
        addResult(acc, catalog, modeLevel, `Requested mode ${requestedMode} cannot be used; effective mode is ${effectiveMode} (${effectiveReasons.join("; ")})`, { ruleId: "MODE-001" });
        if (deliverySignals.hasStrictTrigger && effectiveMode === "Strict") {
            addResult(acc, catalog, "INFO", `Strict escalation triggered by work item ${deliverySignals.strictTriggerItem}`, { ruleId: "MODE-003" });
        }
    }
    else {
        addResult(acc, catalog, "PASS", `Effective mode (${effectiveMode}) matches requested mode (${requestedMode})`, { ruleId: "MODE-001" });
    }
    return effectiveMode;
}
