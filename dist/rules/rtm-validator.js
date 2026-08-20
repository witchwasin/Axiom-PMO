// Release registry + RTM.json traceability, ported from scripts/lib/rtm-validator.ps1.
import { readFileSync, existsSync, statSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { getTableRowsAfterHeading, getIdsFromRows } from "../markdown/table-parser.js";
import { testPlaceholderValue } from "../config/config-loader.js";
import { resolveReference } from "../core/reference-resolver.js";
import { addResult } from "../core/result-writer.js";
export function getReleaseRegistry(releaseText) {
    const result = { releaseId: null, testIds: [], testRows: [] };
    if (!releaseText)
        return result;
    const rid = /^\s*>?\s*Release ID:\s*(REL-\d{3})\s*$/m.exec(releaseText);
    if (rid)
        result.releaseId = rid[1];
    const testRows = getTableRowsAfterHeading(releaseText, "^##\\s+Test Summary");
    result.testRows = testRows.filter((r) => /^TEST-\d{3}$/.test(r["ID"] ?? ""));
    result.testIds = result.testRows.map((r) => r["ID"].trim());
    return result;
}
export function testTestSummary(acc, catalog, registry, project, referenceTypesConfig, decisionIds, mode) {
    for (const row of registry.testRows) {
        const result = (row["Result"] ?? "").trim().toLowerCase();
        if (result === "skipped") {
            if (testPlaceholderValue(row["Notes"] ?? "")) {
                addResult(acc, catalog, "FAIL", `${row["ID"]} is marked skipped but Notes does not state a reason`, { ruleId: "TEST-RESULT-001" });
                continue;
            }
            if (mode === "Strict") {
                if (testPlaceholderValue(row["Evidence"] ?? "")) {
                    addResult(acc, catalog, "FAIL", `${row["ID"]} is marked skipped but Strict requires resolvable Evidence, not just a Notes reason`, { ruleId: "TEST-RESULT-001" });
                    continue;
                }
                const skipRef = resolveReference(row["Evidence"], referenceTypesConfig, project, decisionIds);
                if (!skipRef.type || !skipRef.resolved) {
                    addResult(acc, catalog, "FAIL", `${row["ID"]} is marked skipped but Evidence '${row["Evidence"]}' does not resolve to a real reference`, { ruleId: "TEST-RESULT-001" });
                    continue;
                }
            }
            addResult(acc, catalog, "PASS", `${row["ID"]} is validly skipped (reason recorded)`, { ruleId: "TEST-RESULT-001" });
            continue;
        }
        if (result !== "passed") {
            addResult(acc, catalog, "FAIL", `${row["ID"]} has Result '${row["Result"]}', expected passed (or skipped with a reason in Notes)`, { ruleId: "TEST-RESULT-001" });
            continue;
        }
        if (testPlaceholderValue(row["Evidence"] ?? "")) {
            addResult(acc, catalog, "FAIL", `${row["ID"]} is passed but Evidence is empty`, { ruleId: "TEST-EVIDENCE-002" });
            continue;
        }
        const ref = resolveReference(row["Evidence"], referenceTypesConfig, project, decisionIds);
        if (!ref.type || !ref.resolved) {
            addResult(acc, catalog, "FAIL", `${row["ID"]} is passed but Evidence '${row["Evidence"]}' does not resolve to a real reference`, { ruleId: "TEST-EVIDENCE-002" });
        }
        else {
            addResult(acc, catalog, "PASS", `${row["ID"]} is passed with resolvable evidence`, { ruleId: "TEST-EVIDENCE-002" });
        }
    }
}
export function testTestEvidenceGitGroundTruth(acc, catalog, registry, project, referenceTypesConfig, mode, baseRef, headRef) {
    const rows = registry.testRows;
    if (rows.length === 0)
        return;
    if (mode === "Lite")
        return;
    const candidates = [];
    for (const row of rows) {
        const result = (row["Result"] ?? "").trim().toLowerCase();
        if (result !== "passed")
            continue;
        if (testPlaceholderValue(row["Evidence"] ?? ""))
            continue;
        const ref = resolveReference(row["Evidence"], referenceTypesConfig, project, null, null, null, registry.testIds);
        if (ref.type !== "file" || !ref.resolved || ref.pathEscaped)
            continue;
        candidates.push(row);
    }
    if (candidates.length === 0)
        return;
    const gitRoot = spawnSync("git", ["-C", project, "rev-parse", "--show-toplevel"], { encoding: "utf8" }).stdout?.trim() ?? "";
    if (!gitRoot) {
        addResult(acc, catalog, "FAIL", "Cannot reconcile release test evidence against git ground truth: the project is not inside a git repository, so no commit range can be verified. Supply -ReleaseDiffBase/-ReleaseDiffHead only when the project lives in a git checkout.", { ruleId: "TEST-EVIDENCE-003" });
        return;
    }
    const baseSha = spawnSync("git", ["-C", gitRoot, "rev-parse", "--verify", "--quiet", `${baseRef}^{commit}`], { encoding: "utf8" }).stdout?.trim() ?? "";
    if (!baseSha) {
        addResult(acc, catalog, "FAIL", `Cannot reconcile release test evidence against git ground truth: the base commit (${baseRef}) could not be resolved in this checkout. This is commonly a shallow checkout: actions/checkout defaults to fetch-depth 1, which does not include the base commit. Increase fetch-depth (or use fetch-depth: 0).`, { ruleId: "TEST-EVIDENCE-003" });
        return;
    }
    const headSha = spawnSync("git", ["-C", gitRoot, "rev-parse", "--verify", "--quiet", `${headRef}^{commit}`], { encoding: "utf8" }).stdout?.trim() ?? "";
    if (!headSha) {
        addResult(acc, catalog, "FAIL", `Cannot reconcile release test evidence against git ground truth: the head commit (${headRef}) could not be resolved in this checkout.`, { ruleId: "TEST-EVIDENCE-003" });
        return;
    }
    const diff = spawnSync("git", ["-C", gitRoot, "--no-pager", "diff", "--no-color", "--name-only", "-z", baseSha, headSha], { encoding: "utf8" });
    if (diff.status !== 0) {
        const stderr = (diff.stderr ?? "").trim();
        if (stderr)
            process.stderr.write(stderr + "\n");
        addResult(acc, catalog, "FAIL", `Cannot reconcile release test evidence against git ground truth: git diff exited ${diff.status} comparing ${baseSha} to ${headSha}. See the run log for the underlying git error.`, { ruleId: "TEST-EVIDENCE-003" });
        return;
    }
    const changedPaths = new Set((diff.stdout ?? "").split("\0").filter((t) => t !== ""));
    for (const row of candidates) {
        const evidenceValue = (row["Evidence"] ?? "").trim();
        const filePath = evidenceValue.substring(5).replace(/\\/g, "/");
        const ls = spawnSync("git", ["-C", project, "ls-files", "--full-name", "--error-unmatch", "--", filePath], { encoding: "utf8" });
        const gitRelPath = (ls.stdout ?? "").trim();
        if (ls.status !== 0 || !gitRelPath)
            continue;
        if (changedPaths.has(gitRelPath)) {
            addResult(acc, catalog, "PASS", `${row["ID"]} evidence '${gitRelPath}' is part of the release's verified commit range`, { ruleId: "TEST-EVIDENCE-003" });
            continue;
        }
        const status = spawnSync("git", ["-C", gitRoot, "status", "--porcelain", "--", gitRelPath], { encoding: "utf8" }).stdout?.trim() ?? "";
        const uncommittedNote = status ? " The file also has uncommitted changes, so its current content is not part of the verified range." : "";
        const message = `${row["ID"]} is passed but cites FILE:evidence '${gitRelPath}', which was not changed within the release's verified commit range ${baseRef}..${headRef} -- a report that predates this release's work cannot prove the released code passes.${uncommittedNote}`;
        if (mode === "Strict") {
            addResult(acc, catalog, "FAIL", message, { ruleId: "TEST-EVIDENCE-003", artifact: gitRelPath });
        }
        else {
            addResult(acc, catalog, "WARN", message, { ruleId: "TEST-EVIDENCE-003", artifact: gitRelPath, blocking: true });
        }
    }
}
export function testRtmTraceability(acc, catalog, project, referenceTypesConfig, policyEnums, sourceRefRegex, projectReqIds, deliveryIds, decisionIds, registry, projectSourceIds) {
    const rtmPath = join(project, "RTM.json");
    if (!existsSync(rtmPath))
        return;
    let rtmDoc = null;
    try {
        rtmDoc = JSON.parse(readFileSync(rtmPath, "utf8"));
    }
    catch {
        rtmDoc = null;
    }
    if (!rtmDoc || !rtmDoc.schema_version || !rtmDoc.traceability || rtmDoc.traceability.length === 0) {
        addResult(acc, catalog, "FAIL", "RTM.json is empty, invalid, or missing schema_version/traceability", { ruleId: "RTM-001" });
        return;
    }
    const rows = rtmDoc.traceability;
    const rtmReqIds = [...new Set(rows.filter((r) => r.requirement_id).map((r) => r.requirement_id))].sort();
    for (const reqId of projectReqIds) {
        if (!rtmReqIds.includes(reqId)) {
            addResult(acc, catalog, "FAIL", `RTM missing requirement: ${reqId}`, { ruleId: "RTM-002" });
        }
    }
    for (const rtmReqId of rtmReqIds) {
        if (!projectReqIds.includes(rtmReqId)) {
            addResult(acc, catalog, "FAIL", `RTM traceability row references a requirement not in PROJECT.md: ${rtmReqId}`, { ruleId: "RTM-007" });
        }
    }
    const seen = new Set();
    for (const row of rows) {
        const rid = String(row.requirement_id ?? "");
        if (rid && seen.has(rid)) {
            addResult(acc, catalog, "FAIL", `RTM has a duplicate traceability row for: ${rid}`, { ruleId: "RTM-007" });
        }
        if (rid)
            seen.add(rid);
        if (!row.delivery_ref || !deliveryIds.includes(row.delivery_ref)) {
            addResult(acc, catalog, "FAIL", `RTM row ${rid} has a broken delivery_ref: ${row.delivery_ref}`, { ruleId: "RTM-003" });
        }
        if (!row.test_ref || !registry.testIds.includes(row.test_ref)) {
            addResult(acc, catalog, "FAIL", `RTM row ${rid} has a broken test_ref: ${row.test_ref}`, { ruleId: "RTM-004" });
        }
        const evidenceRef = String(row.evidence_ref ?? "");
        if (!evidenceRef || testPlaceholderValue(evidenceRef)) {
            addResult(acc, catalog, "FAIL", `RTM row ${rid} has a missing evidence_ref`, { ruleId: "RTM-005" });
        }
        else {
            const ref = resolveReference(evidenceRef, referenceTypesConfig, project, decisionIds);
            if (!ref.type) {
                addResult(acc, catalog, "FAIL", `RTM row ${rid} has an unrecognized evidence_ref type: ${evidenceRef}`, { ruleId: "RTM-005" });
            }
            else if (!ref.resolved) {
                addResult(acc, catalog, "FAIL", `RTM row ${rid} has an unresolvable evidence_ref: ${evidenceRef}`, { ruleId: "RTM-005" });
            }
        }
        if (!row.release_ref || !registry.releaseId || row.release_ref !== registry.releaseId) {
            addResult(acc, catalog, "FAIL", `RTM row ${rid} has a broken release_ref: ${row.release_ref}`, { ruleId: "RTM-006" });
        }
        if (!row.source_ref || !new RegExp(sourceRefRegex).test(row.source_ref)) {
            addResult(acc, catalog, "FAIL", `RTM row ${rid} has a missing or malformed source_ref: ${row.source_ref}`, { ruleId: "RTM-008" });
        }
        else if (projectSourceIds && projectSourceIds.length > 0) {
            const sourceIdMatch = /(MOM|REQ|TR)-\d{8}/.exec(row.source_ref);
            if (sourceIdMatch && !projectSourceIds.includes(sourceIdMatch[0])) {
                addResult(acc, catalog, "FAIL", `RTM row ${rid} source_ref '${row.source_ref}' does not exist in PROJECT.md's Source Snapshot/Inventory`, { ruleId: "RTM-008" });
            }
        }
        const designRef = String(row.design_ref ?? "");
        if (!designRef || testPlaceholderValue(designRef)) {
            addResult(acc, catalog, "FAIL", `RTM row ${rid} has a missing design_ref`, { ruleId: "RTM-009" });
        }
        else {
            const designPath = /(DESIGN[\\/][^\s,|]+?\.(puml|md|html))/.exec(designRef)?.[1];
            if (!designPath || !(existsSync(join(project, designPath)) && statSync(join(project, designPath)).isFile())) {
                addResult(acc, catalog, "FAIL", `RTM row ${rid} design_ref does not resolve to an existing design file: ${designRef}`, { ruleId: "RTM-009" });
            }
        }
        const validStatuses = policyEnums["evidence_statuses"] ?? [];
        if (!row.status || !validStatuses.includes(row.status)) {
            addResult(acc, catalog, "FAIL", `RTM row ${rid} has an invalid status: ${row.status}`, { ruleId: "RTM-010" });
        }
        else if (row.status === "verified") {
            const projPath = join(project, "PROJECT.md");
            const projText = existsSync(projPath) ? readFileSync(projPath, "utf8") : "";
            const isFullSpecDepth = /^\s*>?\s*Spec depth:\s*full\s*$/im.test(projText);
            if (isFullSpecDepth) {
                // Condition 1: delivery_ref.Status == Done
                const deliveryPath = join(project, "DELIVERY.md");
                const deliveryText = existsSync(deliveryPath) ? readFileSync(deliveryPath, "utf8") : "";
                const deliveryRows = getTableRowsAfterHeading(deliveryText, "^##\\s+Work Items");
                const deliveryRow = deliveryRows.find((r) => r["ID"] === row.delivery_ref);
                const deliveryStatus = (deliveryRow?.["Status"] ?? "").trim();
                if (deliveryStatus !== "Done") {
                    addResult(acc, catalog, "FAIL", `RTM row ${rid} claims status: verified but delivery item ${row.delivery_ref} Status is '${deliveryStatus || "missing"}' (expected Done)`, { ruleId: "RTM-011", artifact: "RTM.json", itemId: rid });
                }
                // Condition 2: test_ref.Result == passed
                const hasPassedTest = registry.testRows.some((t) => t["ID"] === row.test_ref && (t["Result"] ?? "").trim().toLowerCase() === "passed");
                if (!hasPassedTest) {
                    addResult(acc, catalog, "FAIL", `RTM row ${rid} claims status: verified but test ${row.test_ref} Result is not passed in Test Summary`, { ruleId: "RTM-011", artifact: "RTM.json", itemId: rid });
                }
                // Condition 3: Release Approved == approved in PROJECT.md
                const approvalRows = getTableRowsAfterHeading(projText, "^##\\s+Approvals");
                const releaseApprovalRow = approvalRows.find((r) => (r["Gate"] ?? "").trim() === "Release Approved");
                const releaseApprovalStatus = (releaseApprovalRow?.["Approval Status"] ?? "").trim().toLowerCase();
                if (releaseApprovalStatus !== "approved") {
                    addResult(acc, catalog, "FAIL", `RTM row ${rid} claims status: verified but Release Approved gate is '${releaseApprovalStatus || "missing"}' (expected approved)`, { ruleId: "RTM-011", artifact: "RTM.json", itemId: rid });
                }
            }
        }
    }
}
