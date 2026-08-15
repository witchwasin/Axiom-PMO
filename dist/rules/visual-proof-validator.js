// Conditional Visual Proof validation (VPROOF-001/002), ported from
// scripts/lib/visual-proof-validator.ps1. Verifies repository facts only:
// structure, capture existence + hash, and review freshness.
import { createHash } from "node:crypto";
import { readFileSync, existsSync, statSync, readdirSync, openSync, readSync, closeSync } from "node:fs";
import { join, resolve, relative } from "node:path";
import { getTableRowsAfterHeading } from "../markdown/table-parser.js";
import { testGenericOwner } from "../core/owner-policy.js";
import { addResult } from "../core/result-writer.js";
function getVisualProofSeverity(severityMap, mode, def = "fail") {
    let value = def;
    if (severityMap) {
        const p = severityMap[mode];
        if (p !== undefined)
            value = String(p);
    }
    return value === "warn" ? "WARN" : "FAIL";
}
export function testVisualProofActivated(project, policy) {
    const activation = policy["activation"] ?? {};
    const requiredArtifacts = activation["required_artifacts"] ?? [];
    for (const relativePath of requiredArtifacts) {
        if (!existsSync(join(project, String(relativePath))))
            return false;
    }
    return true;
}
function getTextSha256(text) {
    return createHash("sha256").update(text, "utf8").digest("hex").toLowerCase();
}
function getVisualProofNormalizedTextHash(path) {
    let content = readFileSync(path, "utf8");
    const normalized = content.replace(/\r\n/g, "\n").replace(/[ \t]+(?=\n)/g, "");
    return getTextSha256(normalized.trimEnd());
}
function getVisualProofFileHash(path) {
    return createHash("sha256").update(readFileSync(path)).digest("hex").toLowerCase();
}
function getVisualProofRelativePath(project, path) {
    const projectRoot = resolve(project).replace(/\\/g, "/");
    const resolved = resolve(path).replace(/\\/g, "/");
    const prefix = projectRoot + "/";
    if (resolved !== projectRoot && !resolved.toLowerCase().startsWith(prefix.toLowerCase())) {
        throw new Error(`Visual Proof file resolves outside the project root: ${path}`);
    }
    return resolved.substring(projectRoot.length).replace(/^\//, "");
}
function sortOrdinal(values) {
    return [...values].sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
}
export function getVisualProofReviewInputDigest(project, policy) {
    const parts = [];
    const freshness = policy["freshness"] ?? {};
    const textExtensions = (freshness["normalized_text_extensions"] ?? []).map((e) => e.toLowerCase());
    for (const relativePath of sortOrdinal(freshness["review_input_files"] ?? [])) {
        const path = join(project, relativePath);
        if (!existsSync(path)) {
            parts.push(`${relativePath}\n<absent>`);
            continue;
        }
        const extension = (relativePath.includes(".") ? "." + relativePath.split(".").pop() : "").toLowerCase();
        const digest = textExtensions.includes(extension) ? getVisualProofNormalizedTextHash(path) : getVisualProofFileHash(path);
        parts.push(`${relativePath}\n${digest}`);
    }
    for (const directory of sortOrdinal(freshness["review_input_directories"] ?? [])) {
        const directoryPath = join(project, directory);
        if (!existsSync(directoryPath) || !statSync(directoryPath).isDirectory()) {
            parts.push(`${directory}/\n<absent>`);
            continue;
        }
        const files = [];
        const walk = (dir) => {
            for (const entry of readdirSync(dir)) {
                const full = join(dir, entry);
                const st = statSync(full);
                if (st.isDirectory())
                    walk(full);
                else if (st.isFile())
                    files.push(full);
            }
        };
        walk(directoryPath);
        if (files.length === 0) {
            parts.push(`${directory}/\n<empty>`);
            continue;
        }
        files.sort((a, b) => getVisualProofRelativePath(project, a).localeCompare(getVisualProofRelativePath(project, b)));
        for (const file of files) {
            const rel = getVisualProofRelativePath(project, file);
            const ext = (file.includes(".") ? "." + file.split(".").pop() : "").toLowerCase();
            const digest = textExtensions.includes(ext) ? getVisualProofNormalizedTextHash(file) : getVisualProofFileHash(file);
            parts.push(`${rel}\n${digest}`);
        }
    }
    return getTextSha256(parts.join("\n--\n"));
}
function getVisualProofPngDimensions(path) {
    let fd;
    try {
        fd = openSync(path, "r");
    }
    catch {
        return null;
    }
    const buffer = Buffer.alloc(24);
    let read = 0;
    try {
        read = readSync(fd, buffer, 0, 24, 0);
    }
    finally {
        closeSync(fd);
    }
    if (read < 24)
        return null;
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    for (let i = 0; i < signature.length; i++) {
        if (buffer[i] !== signature[i])
            return null;
    }
    if (buffer[12] !== 73 || buffer[13] !== 72 || buffer[14] !== 68 || buffer[15] !== 82)
        return null;
    const width = (buffer[16] << 24) | (buffer[17] << 16) | (buffer[18] << 8) | buffer[19];
    const height = (buffer[20] << 24) | (buffer[21] << 16) | (buffer[22] << 8) | buffer[23];
    if (width === 0 || height === 0)
        return null;
    return { width, height };
}
function getStringProperty(obj, name) {
    if (obj == null)
        return "";
    const v = obj[name];
    if (v === undefined || v === null)
        return "";
    if (typeof v === "object") {
        // datetimeoffset / datetime: accept ISO string; else serialize.
        if (v instanceof Date)
            return v.toISOString();
        return String(v).trim();
    }
    return String(v).trim();
}
function getObjectProperty(obj, name) {
    if (obj == null)
        return null;
    return obj[name] ?? null;
}
function testMinimumInteger(obj, name, minimum) {
    const value = getStringProperty(obj, name);
    const parsed = Number.parseInt(value, 10);
    if (Number.isNaN(parsed))
        return false;
    return parsed >= minimum;
}
function getVisualProofDirectionField(text, names) {
    for (const name of names) {
        const pattern = new RegExp(`^\\s*(?:-\\s*)?${name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*:\\s*(.+?)\\s*$`, "im");
        const m = pattern.exec(text);
        if (m)
            return m[1].trim().replace(/^`|`$/g, "").trim();
        const tablePattern = new RegExp(`^\\s*\\|\\s*${name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*\\|\\s*([^|]+?)\\s*\\|`, "im");
        const tm = tablePattern.exec(text);
        if (tm)
            return tm[1].trim().replace(/^`|`$/g, "").trim();
    }
    return "";
}
function getVisualProofDirectionDeclaration(path) {
    const text = existsSync(path) ? readFileSync(path, "utf8") : "";
    return {
        status: getVisualProofDirectionField(text, ["direction_status", "Direction status"]),
        selectedDirection: getVisualProofDirectionField(text, ["selected_direction", "Selected direction", "Direction"]),
        decisionRef: getVisualProofDirectionField(text, ["direction_decision_ref", "decision_ref", "Direction decision ref", "Human decision ref"]),
    };
}
function getVisualProofProjectCode(projectText) {
    const m = /^#\s+PROJECT\s+-\s+(.+?)\s*$/m.exec(projectText);
    return m ? m[1].trim() : "";
}
function getVisualProofDecisionDecider(project, decisionId) {
    const path = join(project, "decision-log.md");
    if (!existsSync(path))
        return null;
    const text = readFileSync(path, "utf8");
    let rows = getTableRowsAfterHeading(text, "^#\\s+Decision Log");
    if (rows.length === 0)
        rows = getTableRowsAfterHeading(text, "^##?\\s+");
    for (const row of rows) {
        let rowId = "";
        for (const idColumn of ["ID", "Decision ID"]) {
            const v = row[idColumn];
            if (v && v.trim() !== "") {
                rowId = v.trim();
                break;
            }
        }
        if (rowId !== decisionId)
            continue;
        for (const deciderColumn of ["Decided By", "Owner", "Approved By", "Decider", "Approver"]) {
            const v = row[deciderColumn];
            if (v && v.trim() !== "")
                return v.trim();
        }
        return "";
    }
    return null;
}
function testVisualProofDate(value) {
    if (!value || value.trim() === "")
        return false;
    const dateOnly = /^\d{4}-\d{2}-\d{2}$/;
    const timestamp = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|[+-]\d{2}:\d{2})$/;
    if (!dateOnly.test(value) && !timestamp.test(value))
        return false;
    const parsed = new Date(value);
    return !Number.isNaN(parsed.getTime());
}
export function testVisualProofReview(acc, catalog, project, mode, handoffPolicy, projectText, decisionIds) {
    const proof = handoffPolicy["visual_proof"] ?? null;
    if (!proof)
        throw new Error("handoff-policy.json is missing visual_proof; refusing to guess M10 evidence policy.");
    if (!testVisualProofActivated(project, proof))
        return;
    const reviewRelative = String(proof["artifact"] ?? "DESIGN/VISUAL-REVIEW.json");
    const reviewPath = join(project, reviewRelative);
    const severity = getVisualProofSeverity(proof["severity_by_mode"] ?? null, mode);
    if (!existsSync(reviewPath)) {
        addResult(acc, catalog, severity, `${reviewRelative} is required when a project carries visual direction and both design-system artifacts`, { ruleId: "VPROOF-001", blocking: true, artifact: reviewRelative });
        return;
    }
    let review;
    try {
        review = JSON.parse(readFileSync(reviewPath, "utf8"));
    }
    catch {
        addResult(acc, catalog, severity, `${reviewRelative} is not valid JSON`, { ruleId: "VPROOF-001", blocking: true, artifact: reviewRelative });
        return;
    }
    const problems = [];
    const projectCode = getVisualProofProjectCode(projectText);
    if (getStringProperty(review, "schema_version") !== String(proof["schema_version"]))
        problems.push("schema_version does not match the policy");
    if (!projectCode)
        problems.push("PROJECT.md does not declare a project code");
    else if (getStringProperty(review, "project_code") !== projectCode)
        problems.push("project_code does not match PROJECT.md");
    if (!testVisualProofDate(getStringProperty(review, "reviewed_at")))
        problems.push("reviewed_at is not an ISO date");
    if (!(proof["reviewer_kinds"] ?? []).includes(getStringProperty(review, "reviewer_kind")))
        problems.push("reviewer_kind is not declared by policy");
    const ownerPolicy = handoffPolicy["owner_policy"] ?? {};
    if (testGenericOwner(getStringProperty(review, "reviewer"), ownerPolicy))
        problems.push("reviewer is not a named person or identifier");
    const reviewDecision = getStringProperty(review, "decision_ref");
    if (!/^DEC-\d{3}$/.test(reviewDecision) || !(decisionIds ?? []).includes(reviewDecision))
        problems.push("decision_ref is not a resolvable project decision");
    else {
        const decider = getVisualProofDecisionDecider(project, reviewDecision);
        if (decider === null || testGenericOwner(decider, ownerPolicy))
            problems.push("decision_ref has no named decision owner");
    }
    const directionPath = join(project, "DESIGN/VISUAL-DIRECTION.md");
    const direction = getVisualProofDirectionDeclaration(directionPath);
    if (!["selected", "conformance"].includes(direction.status.toLowerCase()))
        problems.push("visual direction is not selected or conformance");
    if (!direction.selectedDirection.trim())
        problems.push("visual direction records no selected direction");
    if (!/^DEC-\d{3}$/.test(direction.decisionRef) || !(decisionIds ?? []).includes(direction.decisionRef))
        problems.push("visual direction has no resolvable selection decision");
    const reviewDirection = getObjectProperty(review, "visual_direction");
    if (reviewDirection == null)
        problems.push("visual_direction is not recorded");
    else {
        if (getStringProperty(reviewDirection, "selected_direction") !== direction.selectedDirection)
            problems.push("visual_direction.selected_direction does not match the selected direction");
        if (getStringProperty(reviewDirection, "decision_ref") !== direction.decisionRef)
            problems.push("visual_direction.decision_ref does not match the selection decision");
    }
    const reviewedRubric = review["rubric"] ?? [];
    const policyRubricIds = (proof["rubric"] ?? []).map((r) => String(r["id"]));
    const rubricStatuses = proof["rubric_statuses"] ?? [];
    const seenRubricIds = [];
    for (const item of reviewedRubric) {
        const id = getStringProperty(item, "id");
        const status = getStringProperty(item, "status");
        seenRubricIds.push(id);
        if (!policyRubricIds.includes(id)) {
            problems.push(`rubric contains unknown id '${id}'`);
            continue;
        }
        if (!rubricStatuses.includes(status)) {
            problems.push(`rubric '${id}' has invalid status`);
            continue;
        }
        if (status !== "reviewed")
            problems.push(`rubric '${id}' is not reviewed`);
    }
    for (const id of policyRubricIds) {
        if (seenRubricIds.filter((s) => s === id).length !== 1)
            problems.push(`rubric '${id}' is missing or duplicated`);
    }
    const captures = review["captures"] ?? [];
    const captureIds = captures.map((c) => getStringProperty(c, "id"));
    const captureMethods = proof["capture_methods"] ?? [];
    for (const expected of (proof["captures"] ?? [])) {
        const id = String(expected["id"]);
        const matching = captures.filter((c) => getStringProperty(c, "id") === id);
        if (matching.length !== 1) {
            problems.push(`capture '${id}' is missing or duplicated`);
            continue;
        }
        const capture = matching[0];
        const expectedPath = String(expected["path"]);
        const capturePath = getStringProperty(capture, "path");
        if (capturePath !== expectedPath) {
            problems.push(`capture '${id}' path is not the required local path`);
            continue;
        }
        const absoluteCapturePath = join(project, expectedPath);
        if (!existsSync(absoluteCapturePath)) {
            problems.push(`capture '${id}' file is missing`);
            continue;
        }
        const dimensions = getVisualProofPngDimensions(absoluteCapturePath);
        if (dimensions === null)
            problems.push(`capture '${id}' does not have a PNG signature and IHDR dimensions`);
        else if (dimensions.width < Number(expected["min_width"]) || dimensions.height < Number(expected["min_height"]))
            problems.push(`capture '${id}' is below the configured minimum dimensions`);
        const recordedHash = getStringProperty(capture, "sha256").toLowerCase();
        if (!/^[a-f0-9]{64}$/.test(recordedHash) || recordedHash !== getVisualProofFileHash(absoluteCapturePath))
            problems.push(`capture '${id}' sha256 does not match the committed file`);
        const viewport = getObjectProperty(capture, "viewport");
        if (viewport == null || !testMinimumInteger(viewport, "width", Number(expected["min_viewport_width"])) || !testMinimumInteger(viewport, "height", Number(expected["min_viewport_height"])))
            problems.push(`capture '${id}' viewport is below the configured minimum`);
        if (!captureMethods.includes(getStringProperty(capture, "capture_method")))
            problems.push(`capture '${id}' has an unsupported capture_method`);
        if (!testVisualProofDate(getStringProperty(capture, "captured_at")))
            problems.push(`capture '${id}' captured_at is not an ISO date`);
    }
    for (const id of captureIds) {
        if (!(proof["captures"] ?? []).some((c) => String(c["id"]) === id))
            problems.push(`capture '${id}' is not declared by policy`);
    }
    const recommendation = getObjectProperty(review, "recommendation");
    if (recommendation == null || getStringProperty(recommendation, "status") !== "accepted")
        problems.push("recommendation.status is not accepted");
    if (problems.length > 0) {
        for (const problem of problems) {
            addResult(acc, catalog, severity, `Visual Proof is incomplete: ${problem}`, { ruleId: "VPROOF-001", blocking: true, artifact: reviewRelative });
        }
        return;
    }
    const recordedDigest = getStringProperty(getObjectProperty(review, "review_inputs"), "digest");
    const currentDigest = getVisualProofReviewInputDigest(project, proof);
    if (!/^[a-f0-9]{64}$/.test(recordedDigest) || recordedDigest.toLowerCase() !== currentDigest) {
        addResult(acc, catalog, severity, "Visual Proof is stale: a reviewed creative artifact, brand asset, or committed capture changed", { ruleId: "VPROOF-002", blocking: true, artifact: reviewRelative, field: "review_inputs.digest" });
        return;
    }
    addResult(acc, catalog, "PASS", `Visual Proof covers all ${policyRubricIds.length} rubric items and is current against its committed captures`, { ruleId: "VPROOF-001" });
    addResult(acc, catalog, "PASS", "Visual Proof freshness digest matches the current creative artifacts and captures", { ruleId: "VPROOF-002" });
}
void relative;
