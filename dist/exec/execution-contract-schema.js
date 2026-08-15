// Execution-contract and execution-result schema handling, ported from
// scripts/lib/execution-contract-schema.ps1. Pure byte->structure parsing; no
// git, no filesystem walking, no diagnostics. Git ground truth lives in
// execution-contract-git.ts; diagnostics in execution-contract-validator.ts.
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { createHash } from "node:crypto";
import { getTableRowsAfterHeading } from "../markdown/table-parser.js";
import { testScopeGlobSyntax } from "../rules/scope-diff-matcher.js";
export function getExecutionFileDigest(path) {
    if (!existsSync(path))
        return null;
    return createHash("sha256").update(readFileSync(path)).digest("hex").toLowerCase();
}
export function readExecutionContractPolicy(frameworkRoot) {
    const policyPath = join(frameworkRoot, "pmo-config/execution-contract-policy.json");
    if (!existsSync(policyPath))
        throw new Error(`Missing runtime execution-contract policy config: ${policyPath}`);
    return JSON.parse(readFileSync(policyPath, "utf8"));
}
const EXECUTION_CONTRACT_REQUIRED = ["contract_version", "project_id", "work_item_id", "mode", "base_sha", "allowed_paths", "git_authority"];
export function readExecutionContract(path) {
    const result = { present: false, valid: false, error: null, document: null, digest: null, path };
    if (!existsSync(path))
        return result;
    result.present = true;
    result.digest = getExecutionFileDigest(path);
    let doc;
    try {
        doc = JSON.parse(readFileSync(path, "utf8"));
    }
    catch (e) {
        result.error = `EXECUTION-CONTRACT.json is not valid JSON: ${e.message}`;
        return result;
    }
    for (const field of EXECUTION_CONTRACT_REQUIRED) {
        if (!(field in doc)) {
            result.error = `EXECUTION-CONTRACT.json is missing required field '${field}'`;
            return result;
        }
    }
    const allowed = doc["allowed_paths"] ?? [];
    if (allowed.length === 0) {
        result.error = "EXECUTION-CONTRACT.json declares an empty allowed_paths; a contract must name at least one path the work may touch";
        return result;
    }
    for (const pattern of allowed) {
        if (typeof pattern !== "string") {
            result.error = "EXECUTION-CONTRACT.json allowed_paths entries must all be strings";
            return result;
        }
        const syntaxError = testScopeGlobSyntax(pattern);
        if (syntaxError) {
            result.error = `EXECUTION-CONTRACT.json allowed_paths entry '${pattern}' is invalid: ${syntaxError}`;
            return result;
        }
    }
    result.valid = true;
    result.document = doc;
    return result;
}
const EXECUTION_RESULT_REQUIRED = ["contract_version", "work_item_id", "contract_sha256", "base_sha", "execution_status"];
const EXECUTION_STATUS_VALUES = ["completed", "partial", "blocked", "failed"];
export function readExecutionResult(path) {
    const result = { present: false, valid: false, error: null, document: null, path };
    if (!existsSync(path))
        return result;
    result.present = true;
    let doc;
    try {
        doc = JSON.parse(readFileSync(path, "utf8"));
    }
    catch (e) {
        result.error = `EXECUTION-RESULT.json is not valid JSON: ${e.message}`;
        return result;
    }
    for (const field of EXECUTION_RESULT_REQUIRED) {
        if (!(field in doc)) {
            result.error = `EXECUTION-RESULT.json is missing required field '${field}'`;
            return result;
        }
    }
    if (!EXECUTION_STATUS_VALUES.includes(String(doc["execution_status"]))) {
        result.error = `EXECUTION-RESULT.json execution_status must be one of: ${EXECUTION_STATUS_VALUES.join(", ")}`;
        return result;
    }
    if (!/^[0-9a-f]{64}$/.test(String(doc["contract_sha256"]))) {
        result.error = "EXECUTION-RESULT.json contract_sha256 is not a lowercase 64-character SHA-256 digest";
        return result;
    }
    result.valid = true;
    result.document = doc;
    return result;
}
export function resolveTestEvidenceEntries(result, policy) {
    const entries = [];
    const rawEntries = result["test_evidence"] ?? [];
    const adapters = policy["test_evidence_adapters"] ?? [];
    for (const item of rawEntries) {
        const type = String(item["type"] ?? "");
        const adapter = adapters.find((c) => String(c["type"]) === type);
        const missingFields = [];
        if (adapter) {
            for (const required of adapter["requires"] ?? []) {
                if (item[required] === undefined || String(item[required] ?? "").trim() === "")
                    missingFields.push(required);
            }
        }
        let provenance = "agent-claimed";
        if (adapter && String(adapter["provenance"] ?? "").trim() !== "")
            provenance = String(adapter["provenance"]);
        entries.push({
            type,
            name: String(item["name"] ?? ""),
            known: adapter !== undefined,
            fieldsPresent: adapter !== undefined && missingFields.length === 0,
            missingFields,
            provenance,
            raw: item,
        });
    }
    return entries;
}
export function readDecisionLog(projectPath) {
    const path = join(projectPath, "decision-log.md");
    if (!existsSync(path))
        return { present: false, rows: [], path };
    const text = readFileSync(path, "utf8");
    const rows = getTableRowsAfterHeading(text, "(?m)^#\\s+Decision Log");
    return { present: true, rows, path };
}
export function resolveDecisionRecord(projectPath, decisionRef) {
    const result = { found: false, row: null, reason: null, logPath: null };
    const trimmed = String(decisionRef ?? "").trim();
    if (trimmed === "") {
        result.reason = "empty";
        return result;
    }
    if (!/^DEC-\d+$/.test(trimmed)) {
        result.reason = `'${trimmed}' is not a well-formed DEC-### id`;
        return result;
    }
    const log = readDecisionLog(projectPath);
    result.logPath = log.path;
    if (!log.present) {
        result.reason = "no decision-log.md exists in this project";
        return result;
    }
    const matches = log.rows.filter((r) => String(r["Decision ID"] ?? "").trim() === trimmed);
    if (matches.length === 0) {
        result.reason = `'${trimmed}' does not appear in decision-log.md`;
        return result;
    }
    if (matches.length > 1) {
        result.reason = `'${trimmed}' appears ${matches.length} times in decision-log.md, which is ambiguous`;
        return result;
    }
    result.found = true;
    result.row = matches[0];
    return result;
}
export function readDecisionAuthorityBindings(row) {
    const bindings = [];
    if (!row)
        return bindings;
    const cellTexts = Object.values(row).map((v) => String(v ?? ""));
    const payloads = [];
    for (const cell of cellTexts) {
        for (const m of cell.matchAll(/axiom-authority\s*:\s*(.*?)(?=axiom-authority\s*:|$)/gi)) {
            payloads.push(m[1]);
        }
    }
    for (const payload of payloads) {
        const fields = {};
        for (const pair of payload.split(";")) {
            const idx = pair.indexOf("=");
            if (idx < 0)
                continue;
            const k = pair.slice(0, idx).trim().toLowerCase();
            const v = pair.slice(idx + 1).trim();
            if (k)
                fields[k] = v;
        }
        if (Object.keys(fields).length > 0)
            bindings.push(fields);
    }
    return bindings;
}
export function testDecisionAuthorityBinding(row, claimType, workItemId, contractSha256, testName = null, evidenceSha256 = null) {
    const bindings = readDecisionAuthorityBindings(row);
    if (bindings.length === 0) {
        return "the decision record carries no 'axiom-authority:' binding, so it does not state what it approves. A decision that only mentions a value does not authorize a claim about it -- add a binding token naming the claim type, work item, contract, and (for test evidence) the test and artifact digest.";
    }
    let lastReason = null;
    for (const b of bindings) {
        if (!("type" in b)) {
            lastReason = "a binding on the decision record names no claim type";
            continue;
        }
        if (b["type"] !== claimType) {
            lastReason = `the decision record authorizes '${b["type"]}', not '${claimType}'`;
            continue;
        }
        if (!("work_item" in b)) {
            lastReason = "the decision record's binding names no work_item";
            continue;
        }
        if (b["work_item"] !== workItemId) {
            lastReason = `the decision record authorizes work item '${b["work_item"]}', not '${workItemId}'`;
            continue;
        }
        if (!("contract" in b)) {
            lastReason = "the decision record's binding names no contract digest";
            continue;
        }
        if (b["contract"].toLowerCase() !== contractSha256.toLowerCase()) {
            lastReason = "the decision record authorizes a different contract digest than the one being verified";
            continue;
        }
        if (testName) {
            if (!("test" in b)) {
                lastReason = "the decision record's binding names no test";
                continue;
            }
            if (b["test"] !== testName) {
                lastReason = `the decision record approves evidence for test '${b["test"]}', not '${testName}'`;
                continue;
            }
        }
        if (evidenceSha256) {
            if (!("evidence" in b)) {
                lastReason = "the decision record's binding names no evidence digest";
                continue;
            }
            if (b["evidence"].toLowerCase() !== evidenceSha256.toLowerCase()) {
                lastReason = "the decision record approves a different artifact digest than the evidence presented";
                continue;
            }
        }
        return null;
    }
    return lastReason;
}
