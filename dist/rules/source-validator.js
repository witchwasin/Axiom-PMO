// Source classification, PROJECT.md scope/requirement checks, placeholder
// scanning, sensitive-filename scanning, and broken-link checks. Ported from
// scripts/lib/source-validator.ps1.
import { readFileSync } from "node:fs";
import { join, dirname, relative, basename } from "node:path";
import { existsSync } from "node:fs";
import { getTableRowsAfterHeading, getIdsFromRows } from "../markdown/table-parser.js";
import { testPlaceholderContent } from "../config/config-loader.js";
import { testApproval } from "./approval-validator.js";
import { resolveReference } from "../core/reference-resolver.js";
import { addResult } from "../core/result-writer.js";
export function testUserSourcePath(relativePath) {
    return /^(source|MOM|REQ|Transcript|Others)[\\/]/.test(relativePath);
}
export function testGovernedPlaceholders(acc, catalog, governedFiles, project, gate) {
    const placeholderHits = [];
    for (const file of governedFiles) {
        let content;
        try {
            content = readFileSync(file, "utf8");
        }
        catch {
            continue;
        }
        const ext = file.includes(".") ? "." + file.split(".").pop().toLowerCase() : "";
        if (testPlaceholderContent(content, ext)) {
            placeholderHits.push(relative(project, file));
        }
    }
    if (placeholderHits.length === 0) {
        addResult(acc, catalog, "PASS", "No placeholder/TODO/TBD markers found", { ruleId: "PLACEHOLDER-001" });
    }
    else if (gate === "Draft") {
        addResult(acc, catalog, "INFO", `Draft placeholders found in: ${placeholderHits.slice(0, 8).join(", ")}`, { ruleId: "PLACEHOLDER-001" });
    }
    else if (gate === "Release") {
        addResult(acc, catalog, "FAIL", `Release gate has placeholder/TODO/TBD markers in: ${placeholderHits.slice(0, 8).join(", ")}`, { ruleId: "PLACEHOLDER-001" });
    }
    else {
        addResult(acc, catalog, "WARN", `Placeholder/TODO/TBD markers found in: ${placeholderHits.slice(0, 8).join(", ")}`, { ruleId: "PLACEHOLDER-001" });
    }
}
export function testProjectSourceSection(acc, catalog, ctx, projectText, mode, gate, sourceRefRegex, policyEnums, decisionIds) {
    let projectTaskSource = null;
    const taskSourceMatch = /^\s*>?\s*Task source:\s*(file|github)\s*$/m.exec(projectText);
    if (taskSourceMatch) {
        projectTaskSource = taskSourceMatch[1];
        addResult(acc, catalog, "PASS", "Task source is declared", { ruleId: "TASK-001" });
    }
    else {
        const taskSourceLevel = gate === "Release" ? "FAIL" : "WARN";
        addResult(acc, catalog, taskSourceLevel, "Task source is not declared as file or github", { ruleId: "TASK-001" });
    }
    if (projectText.includes("## Source Snapshot")) {
        if (/Last Synced At|synced_at/.test(projectText)) {
            addResult(acc, catalog, "PASS", "Source Snapshot section exists", { ruleId: "SOURCE-002" });
        }
        else {
            addResult(acc, catalog, "WARN", "Source Snapshot exists but does not show sync time", { ruleId: "SOURCE-002" });
        }
    }
    else {
        addResult(acc, catalog, "WARN", "Source Snapshot section is missing; PROJECT.md may become stale", { ruleId: "SOURCE-002" });
    }
    let projectReqIds = [];
    let projectBusinessIds = [];
    const reqRows = getTableRowsAfterHeading(projectText, "^###\\s+In Scope");
    if (reqRows.length === 0) {
        const noReqLevel = gate === "Draft" ? "INFO" : "FAIL";
        addResult(acc, catalog, noReqLevel, "No REQ-### entries found in PROJECT.md", { ruleId: "SOURCE-001" });
    }
    else {
        projectReqIds = getIdsFromRows(reqRows);
        const idCounts = new Map();
        for (const id of projectReqIds)
            idCounts.set(id, (idCounts.get(id) ?? 0) + 1);
        const duplicates = [...idCounts.entries()].filter(([, c]) => c > 1).map(([id]) => id);
        if (duplicates.length > 0) {
            addResult(acc, catalog, "FAIL", `Duplicate requirement IDs: ${duplicates.join(", ")}`, { ruleId: "SOURCE-003" });
        }
        const missingSource = reqRows.filter((r) => !new RegExp(sourceRefRegex).test(r["Source Ref"] ?? ""));
        const validEvidence = policyEnums["evidence_statuses"] ?? [];
        const missingEvidence = reqRows.filter((r) => !validEvidence.includes(r["Evidence Status"] ?? ""));
        const missingLevel = gate === "Release" ? "FAIL" : "WARN";
        if (missingSource.length === 0) {
            addResult(acc, catalog, "PASS", "Requirement lines include source references", { ruleId: "SOURCE-001" });
        }
        else {
            addResult(acc, catalog, missingLevel, `${missingSource.length} requirement line(s) may be missing source_ref`, { ruleId: "SOURCE-001" });
        }
        if (missingEvidence.length === 0) {
            addResult(acc, catalog, "PASS", "Requirement lines include valid evidence status", { ruleId: "EVIDENCE-001" });
        }
        else {
            addResult(acc, catalog, missingLevel, `${missingEvidence.length} requirement line(s) may be missing or invalid evidence status`, { ruleId: "EVIDENCE-001" });
        }
        const isFullSpecDepth = /^\s*>?\s*Spec depth:\s*full\s*$/im.test(projectText);
        if (isFullSpecDepth) {
            const validReqTypes = policyEnums["requirement_types"] ?? [];
            const invalidTypes = reqRows.filter((r) => !validReqTypes.includes((r["Type"] ?? "").trim().toLowerCase()));
            if (invalidTypes.length === 0) {
                addResult(acc, catalog, "PASS", "Requirement lines include valid requirement type", { ruleId: "REQ-TYPE-001" });
            }
            else {
                const typeLevel = gate === "Draft" ? "INFO" : "FAIL";
                for (const r of invalidTypes) {
                    addResult(acc, catalog, typeLevel, `Requirement ${r["ID"] ?? "unknown"} has invalid or missing Type '${r["Type"] ?? ""}' (expected one of: ${validReqTypes.join(", ")})`, { ruleId: "REQ-TYPE-001", artifact: "PROJECT.md", itemId: r["ID"] ?? null, field: "Type" });
                }
            }
        }
    }
    const sourceRows = [
        ...getTableRowsAfterHeading(projectText, "^##\\s+Source Snapshot"),
        ...getTableRowsAfterHeading(projectText, "^##\\s+Source Inventory"),
    ];
    const projectSourceIds = [...new Set(sourceRows.filter((r) => r["Source ID"]).map((r) => r["Source ID"].trim()))].sort();
    projectBusinessIds = getIdsFromRows(getTableRowsAfterHeading(projectText, "^##\\s+Business Rules"));
    const requireDecisionEvidence = mode !== "Lite";
    const checkpoints = ctx.policy["approval_checkpoints"] ?? {};
    if (!checkpoints || Object.keys(checkpoints).length === 0) {
        throw new Error("policy.json is missing approval_checkpoints; refusing to guess which approvals a gate requires.");
    }
    for (const approvalGate of ["Scope Approved", "Design Ready", "Release Approved"]) {
        const spec = checkpoints[approvalGate];
        if (!spec)
            continue;
        const gates = spec.gates ?? [];
        const exemptModes = spec.exempt_modes ?? [];
        if (!gates.includes(gate))
            continue;
        if (exemptModes.includes(mode))
            continue;
        testApproval(acc, catalog, ctx, projectText, approvalGate, decisionIds, requireDecisionEvidence, mode);
    }
    if (mode !== "Lite" && projectSourceIds.length > 0 && reqRows.length > 0) {
        const missingSourceIds = new Set();
        const srcRefRx = new RegExp(sourceRefRegex, "g");
        for (const row of reqRows) {
            for (const m of (row["Source Ref"] ?? "").matchAll(srcRefRx)) {
                const value = m[0];
                if (/^(MOM|REQ|TR)-/.test(value) && !projectSourceIds.includes(value)) {
                    missingSourceIds.add(value);
                }
            }
        }
        const missing = [...missingSourceIds].sort();
        if (missing.length > 0) {
            addResult(acc, catalog, "FAIL", `Source references not found in Source Inventory/Snapshot: ${missing.join(", ")}`, { ruleId: "REF-001" });
        }
    }
    return { projectReqIds, projectBusinessIds, projectTaskSource, projectSourceIds };
}
const SENSITIVE_PATTERNS = [
    /\.env$/,
    /\.env\./,
    /API[_-]?KEY/,
    /SECRET/,
    /TOKEN/,
    /PASSWORD/,
    /\.wav$/,
    /\.mp3$/,
    /\.m4a$/,
    /Pricing/,
    /Quotation/,
];
export function testSensitiveFilenames(acc, catalog, allProjectFiles, project) {
    const sensitiveHitsGoverned = [];
    const sensitiveHitsSource = [];
    for (const file of allProjectFiles) {
        const rel = relative(project, file);
        for (const pattern of SENSITIVE_PATTERNS) {
            if (pattern.test(rel)) {
                if (testUserSourcePath(rel))
                    sensitiveHitsSource.push(rel);
                else
                    sensitiveHitsGoverned.push(rel);
                break;
            }
        }
    }
    if (sensitiveHitsGoverned.length === 0) {
        addResult(acc, catalog, "PASS", "No obvious sensitive filenames found in governed files", { ruleId: "SENSITIVE-001" });
    }
    else {
        addResult(acc, catalog, "WARN", `Potential sensitive filenames: ${sensitiveHitsGoverned.slice(0, 8).join(", ")}`, { ruleId: "SENSITIVE-001", blocking: true });
    }
    if (sensitiveHitsSource.length > 0) {
        addResult(acc, catalog, "WARN", `Potential sensitive filenames in user-owned source (informational, does not block): ${sensitiveHitsSource.slice(0, 8).join(", ")}`, { ruleId: "SENSITIVE-001", blocking: false });
    }
}
function findBrokenLinks(files) {
    const hits = [];
    for (const file of files) {
        let content;
        try {
            content = readFileSync(file, "utf8");
        }
        catch {
            continue;
        }
        const linkMatches = content.matchAll(/\[[^\]]+\]\((?!https?:\/\/)([^)#]+)(?:#[^)]+)?\)/g);
        for (const m of linkMatches) {
            const target = m[1];
            if (/^\s*$|^mailto:/.test(target))
                continue;
            const base = dirname(file);
            const resolved = join(base, target);
            if (!existsSync(resolved)) {
                hits.push(`${basename(file)} -> ${target}`);
            }
        }
    }
    return hits;
}
export function testLinks(acc, catalog, governedFiles, userSourceFiles, gate) {
    const linkHits = findBrokenLinks(governedFiles);
    if (linkHits.length === 0) {
        addResult(acc, catalog, "PASS", "No broken local markdown links found", { ruleId: "LINK-001" });
    }
    else {
        const linkLevel = gate === "Release" ? "FAIL" : "WARN";
        addResult(acc, catalog, linkLevel, `Broken local links: ${linkHits.slice(0, 8).join(", ")}`, { ruleId: "LINK-001" });
    }
    const sourceLinkHits = findBrokenLinks(userSourceFiles);
    if (sourceLinkHits.length === 0) {
        addResult(acc, catalog, "INFO", "No broken user-source links found", { ruleId: "SOURCE-LINK-001" });
    }
    else {
        addResult(acc, catalog, "WARN", `Broken user-source links: ${sourceLinkHits.slice(0, 8).join(", ")}`, { ruleId: "SOURCE-LINK-001", blocking: false });
    }
}
