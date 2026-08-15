// Decision-log helpers shared by approval, change-control, and handoff
// validators. Ported from approval-validator.ps1 Get-DecisionIds and
// handoff-validator.ps1 Get-DecisionDecider.
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { getTableRowsAfterHeading } from "../markdown/table-parser.js";
export function getDecisionIds(project) {
    const path = join(project, "decision-log.md");
    if (!existsSync(path))
        return null;
    const text = readFileSync(path, "utf8");
    const ids = text.match(/DEC-\d{3}/g) ?? [];
    const unique = [...new Set(ids)].sort();
    // PowerShell collapses a zero-result `return @()` to $null, so callers see
    // "no id set supplied" (resolve shape-match) rather than "empty set"
    // (nothing resolves). Replicate that: zero ids -> null.
    return unique.length === 0 ? null : unique;
}
/** PowerShell `-contains` semantics: null set contains nothing. */
export function contains(ids, value) {
    return (ids ?? []).includes(value);
}
export function getDecisionDecider(project, decisionId) {
    const path = join(project, "decision-log.md");
    if (!existsSync(path))
        return null;
    const raw = readFileSync(path, "utf8");
    let rows = getTableRowsAfterHeading(raw, "^#\\s+Decision Log");
    if (rows.length === 0) {
        rows = getTableRowsAfterHeading(raw, "^##?\\s+");
    }
    for (const row of rows) {
        if (String(row["ID"] ?? "").trim() !== decisionId)
            continue;
        for (const column of ["Decided By", "Owner", "Approved By", "Decider"]) {
            const value = row[column];
            if (value && value.trim() !== "")
                return value.trim();
        }
        return "";
    }
    return null;
}
