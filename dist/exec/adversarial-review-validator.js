// Adversarial Review Evidence (AREV-001..007), ported from
// scripts/lib/adversarial-review-validator.ps1.
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { getExecutionFileDigest, readDecisionLog, resolveDecisionRecord, testDecisionAuthorityBinding } from "./execution-contract-schema.js";
import { testGenericOwner } from "../core/owner-policy.js";
import { getProjectDefaultMode, getDeliveryModeSignals } from "../core/mode-resolver.js";
import { addResult } from "../core/result-writer.js";
function readAdversarialReviewPolicy(frameworkRoot) {
    const policyPath = join(frameworkRoot, "pmo-config/adversarial-review-policy.json");
    if (!existsSync(policyPath))
        throw new Error(`Missing runtime adversarial-review policy config: ${policyPath}`);
    return JSON.parse(readFileSync(policyPath, "utf8"));
}
function getEffectiveModeForVerification(projectPath) {
    const modeRank = { Lite: 1, Standard: 2, Strict: 3 };
    const projectDefaultModeRaw = getProjectDefaultMode(projectPath);
    let effectiveMode = projectDefaultModeRaw && modeRank[projectDefaultModeRaw] !== undefined ? projectDefaultModeRaw : "Standard";
    const deliverySignals = getDeliveryModeSignals(projectPath);
    if (deliverySignals.highestMode && modeRank[deliverySignals.highestMode] > modeRank[effectiveMode])
        effectiveMode = deliverySignals.highestMode;
    if (deliverySignals.hasStrictTrigger)
        effectiveMode = "Strict";
    return effectiveMode;
}
function readExecutionReview(path) {
    const out = { present: false, valid: false, document: null, digest: null, error: null };
    if (!existsSync(path))
        return out;
    out.present = true;
    out.digest = getExecutionFileDigest(path);
    try {
        out.document = JSON.parse(readFileSync(path, "utf8"));
        out.valid = true;
    }
    catch (e) {
        out.error = e.message;
    }
    return out;
}
export function testAdversarialReviewEvidence(acc, catalog, projectPath, contractPath, contract, effectiveMode, resultDocument, verdictBaseSha, verdictHeadSha, workItemId, frameworkRoot, gitRepoRoot, observedPaths, decisionLogRelPath, projectReqIds) {
    const policy = readAdversarialReviewPolicy(frameworkRoot);
    const enforcement = policy["enforcement_by_mode"]?.[effectiveMode];
    if (!enforcement || enforcement === "disabled")
        return;
    const reviewPath = join(contractPath ? join(contractPath, "..") : projectPath, "EXECUTION-REVIEW.json");
    const review = readExecutionReview(reviewPath);
    const severityWhenMissing = policy["severity_when_missing"]?.[effectiveMode];
    if (!review.present) {
        const severity = severityWhenMissing ? String(severityWhenMissing).toUpperCase() : null;
        if (severity) {
            addResult(acc, catalog, severity, `No EXECUTION-REVIEW.json found. In ${effectiveMode} mode, adversarial review evidence is ${enforcement}.`, { ruleId: "AREV-001", artifact: "EXECUTION-REVIEW.json", itemId: workItemId });
        }
        return;
    }
    if (!review.valid) {
        addResult(acc, catalog, "FAIL", `EXECUTION-REVIEW.json is present but invalid: ${review.error}`, { ruleId: "AREV-001", artifact: "EXECUTION-REVIEW.json", itemId: workItemId });
        return;
    }
    addResult(acc, catalog, "PASS", "EXECUTION-REVIEW.json is present and structurally valid.", { ruleId: "AREV-001", artifact: "EXECUTION-REVIEW.json", itemId: workItemId });
    const doc = review.document;
    // AREV-002: contract identity
    let identityOk = true;
    if (String(doc["contract_sha256"] ?? "") !== contract.digest) {
        identityOk = false;
        addResult(acc, catalog, "FAIL", "The review answers a different contract than the one under verification (contract_sha256 mismatch).", { ruleId: "AREV-002", artifact: "EXECUTION-REVIEW.json", itemId: workItemId, field: "contract_sha256" });
    }
    if (String(doc["base_sha"] ?? "") !== verdictBaseSha || String(doc["head_sha"] ?? "") !== verdictHeadSha) {
        identityOk = false;
        addResult(acc, catalog, "FAIL", "The review's base_sha/head_sha do not match the commits under verification -- it cannot be cited as evidence for a different diff.", { ruleId: "AREV-002", artifact: "EXECUTION-REVIEW.json", itemId: workItemId, field: "base_sha/head_sha" });
    }
    if (identityOk) {
        addResult(acc, catalog, "PASS", "The review's contract_sha256, base_sha, and head_sha match the execution under verification.", { ruleId: "AREV-002", artifact: "EXECUTION-REVIEW.json", itemId: workItemId });
    }
    // AREV-003: provenance tier
    const validTiers = ["artifact-observed", "externally-observed", "human-attested"];
    const provenance = doc["provenance"] ?? {};
    const tier = String(provenance["tier"] ?? "");
    if (!validTiers.includes(tier)) {
        addResult(acc, catalog, "FAIL", `provenance.tier '${tier}' is not a recognized tier (${validTiers.join(" / ")}).`, { ruleId: "AREV-003", artifact: "EXECUTION-REVIEW.json", itemId: workItemId, field: "provenance.tier" });
    }
    else if (enforcement === "required") {
        if (tier === "human-attested") {
            if (String(doc["reviewer"] ?? "") && resultDocument["executor"] !== undefined && String(doc["reviewer"]) === String(resultDocument["executor"])) {
                addResult(acc, catalog, "FAIL", "provenance.tier is human-attested, but the named reviewer is the same actor as the executor -- a reviewer cannot review its own work.", { ruleId: "AREV-003", artifact: "EXECUTION-REVIEW.json", itemId: workItemId, field: "reviewer" });
            }
            else {
                addResult(acc, catalog, "PASS", "provenance.tier is human-attested, satisfying Strict directly.", { ruleId: "AREV-003", artifact: "EXECUTION-REVIEW.json", itemId: workItemId });
            }
        }
        else if (tier === "externally-observed") {
            // Pinned workflow binding: fails closed unless an org pins a workflow digest.
            addResult(acc, catalog, "FAIL", "provenance.tier is externally-observed but could not be independently verified: no pinned_workflow_digest is configured in pmo-config/adversarial-review-policy.json -- an externally-observed review cannot be trusted for a required check until an organization pins its own review workflow's digest", { ruleId: "AREV-003", artifact: "EXECUTION-REVIEW.json", itemId: workItemId, field: "provenance" });
        }
        else {
            // artifact-observed: never satisfies alone; needs promotion.
            let promoted = false;
            let promotionReason = "no review-evidence-accepted authority claim was found";
            if (resultDocument["authority_claims"] !== undefined) {
                for (const claim of resultDocument["authority_claims"] ?? []) {
                    if (String(claim["type"] ?? "") !== "review-evidence-accepted")
                        continue;
                    const decisionRef = claim["decision_ref"] !== undefined ? String(claim["decision_ref"]) : null;
                    const resolved = resolveDecisionRecord(projectPath, decisionRef);
                    if (!resolved.found) {
                        promotionReason = `authority claim cites decision record '${decisionRef}', which could not be resolved: ${resolved.reason}`;
                        continue;
                    }
                    if (decisionLogRelPath && observedPaths.includes(decisionLogRelPath)) {
                        promotionReason = `decision record '${decisionRef}' exists, but decision-log.md was itself changed within the commit range under verification -- not independent of the execution it would authorize`;
                        continue;
                    }
                    const bindProblem = testDecisionAuthorityBinding(resolved.row, "review-evidence-accepted", workItemId, contract.digest);
                    if (bindProblem) {
                        promotionReason = `decision record '${decisionRef}' resolves but does not authorize this claim: ${bindProblem}`;
                        continue;
                    }
                    promoted = true;
                    break;
                }
            }
            if (promoted) {
                addResult(acc, catalog, "PASS", "provenance.tier is artifact-observed, promoted by a bound, resolvable human review-evidence-accepted claim.", { ruleId: "AREV-003", artifact: "EXECUTION-REVIEW.json", itemId: workItemId });
            }
            else {
                addResult(acc, catalog, "FAIL", `provenance.tier is artifact-observed, which never satisfies Strict on its own: ${promotionReason}.`, { ruleId: "AREV-003", artifact: "EXECUTION-REVIEW.json", itemId: workItemId, field: "provenance.tier" });
            }
        }
    }
    else {
        addResult(acc, catalog, "PASS", `provenance.tier is ${tier} (advisory mode; not required to satisfy a check).`, { ruleId: "AREV-003", artifact: "EXECUTION-REVIEW.json", itemId: workItemId });
    }
    // AREV-004: finding schema
    const severities = policy["finding_severities"] ?? [];
    const categories = policy["finding_categories"] ?? [];
    const statuses = policy["finding_statuses"] ?? [];
    const findingProblems = [];
    for (const finding of doc["findings"] ?? []) {
        const findingId = String(finding["finding_id"] ?? "");
        if (!findingId.trim()) {
            findingProblems.push("a finding is missing finding_id");
            continue;
        }
        if (!severities.includes(String(finding["severity"] ?? "")))
            findingProblems.push(`${findingId} has invalid severity '${finding["severity"]}'`);
        if (!categories.includes(String(finding["category"] ?? "")))
            findingProblems.push(`${findingId} has invalid category '${finding["category"]}'`);
        if (!statuses.includes(String(finding["status"] ?? "")))
            findingProblems.push(`${findingId} has invalid status '${finding["status"]}'`);
        if (!String(finding["description"] ?? "").trim())
            findingProblems.push(`${findingId} is missing a description`);
        if (!String(finding["suggestion"] ?? "").trim())
            findingProblems.push(`${findingId} is missing a suggestion`);
    }
    if (findingProblems.length === 0) {
        addResult(acc, catalog, "PASS", "Every finding carries a valid finding_id, severity, category, status, description, and suggestion.", { ruleId: "AREV-004", artifact: "EXECUTION-REVIEW.json", itemId: workItemId });
    }
    else {
        addResult(acc, catalog, "FAIL", `Finding schema problems: ${findingProblems.join("; ")}`, { ruleId: "AREV-004", artifact: "EXECUTION-REVIEW.json", itemId: workItemId, field: "findings" });
    }
    // AREV-007: semantic finding contract
    const outputContract = policy["output_contract"] ?? {};
    let nAMarker = "N/A";
    if (outputContract && String(outputContract["n_a_marker"] ?? "").trim() !== "")
        nAMarker = String(outputContract["n_a_marker"]);
    const ownerPolicy = JSON.parse(readFileSync(join(frameworkRoot, "pmo-config/handoff-policy.json"), "utf8"))["owner_policy"] ?? {};
    let contractClean = true;
    for (const finding of doc["findings"] ?? []) {
        const findingId = String(finding["finding_id"] ?? "");
        if (!findingId.trim())
            continue;
        const reqRef = String(finding["requirement_ref"] ?? "");
        if (!reqRef.trim()) {
            contractClean = false;
            addResult(acc, catalog, "FAIL", `Finding ${findingId} is missing requirement_ref -- every semantic finding must name the REQ-### it speaks about.`, { ruleId: "AREV-007", artifact: "EXECUTION-REVIEW.json", itemId: findingId, field: "requirement_ref" });
        }
        else if (!projectReqIds.includes(reqRef)) {
            contractClean = false;
            addResult(acc, catalog, "FAIL", `Finding ${findingId} cites requirement_ref '${reqRef}', which is not declared in PROJECT.md In Scope.`, { ruleId: "AREV-007", artifact: "EXECUTION-REVIEW.json", itemId: findingId, field: "requirement_ref" });
        }
        for (const claimField of ["implementation_claim", "test_claim"]) {
            const claim = String(finding[claimField] ?? "");
            if (!claim.trim()) {
                contractClean = false;
                addResult(acc, catalog, "FAIL", `Finding ${findingId} is missing ${claimField} -- provide the claim, or the explicit N/A marker '${nAMarker}' when the finding has no natural claim to make.`, { ruleId: "AREV-007", artifact: "EXECUTION-REVIEW.json", itemId: findingId, field: claimField });
            }
        }
        const owner = String(finding["owner"] ?? "");
        if (!owner.trim()) {
            contractClean = false;
            addResult(acc, catalog, "FAIL", `Finding ${findingId} is missing owner -- every semantic finding must name the human accountable for it.`, { ruleId: "AREV-007", artifact: "EXECUTION-REVIEW.json", itemId: findingId, field: "owner" });
        }
        else if (testGenericOwner(owner, ownerPolicy)) {
            contractClean = false;
            addResult(acc, catalog, "FAIL", `Finding ${findingId} owner '${owner}' is a generic group or placeholder, not a named person.`, { ruleId: "AREV-007", artifact: "EXECUTION-REVIEW.json", itemId: findingId, field: "owner" });
        }
    }
    if (contractClean) {
        addResult(acc, catalog, "PASS", "Every finding carries a resolvable requirement_ref, an implementation_claim/test_claim (or the explicit N/A marker), and a named owner.", { ruleId: "AREV-007", artifact: "EXECUTION-REVIEW.json", itemId: workItemId });
    }
    // AREV-005/006: finding lifecycle authority
    const closurePolicy = policy["closure_policy"] ?? {};
    const settableBy = closurePolicy["settable_by"] ?? {};
    const nonClosure = closurePolicy["non_closure_statuses"] ?? [];
    const requiresDecisionRef = closurePolicy["statuses_requiring_decision_ref"] ?? [];
    const humanOnlyCategories = closurePolicy["human_only_categories"] ?? [];
    const reviewerKind = String(doc["reviewer_kind"] ?? "");
    const humanOnlyStatuses = [];
    for (const [status, allowedRolesRaw] of Object.entries(settableBy)) {
        const allowedRoles = allowedRolesRaw.map((r) => String(r));
        if (allowedRoles.length === 1 && allowedRoles[0] === "human")
            humanOnlyStatuses.push(status);
    }
    for (const finding of doc["findings"] ?? []) {
        const findingId = String(finding["finding_id"] ?? "");
        const status = String(finding["status"] ?? "");
        const category = String(finding["category"] ?? "");
        if (!statuses.includes(status))
            continue;
        if (requiresDecisionRef.includes(status)) {
            const decisionRef = finding["decision_ref"] !== undefined ? String(finding["decision_ref"]) : null;
            const resolved = resolveDecisionRecord(projectPath, decisionRef);
            if (!resolved.found) {
                addResult(acc, catalog, "FAIL", `${findingId} has status '${status}', which requires a resolvable decision record, but '${decisionRef}' does not resolve: ${resolved.reason}`, { ruleId: "AREV-006", artifact: "EXECUTION-REVIEW.json", itemId: findingId, field: "decision_ref" });
            }
            else if (decisionLogRelPath && observedPaths.includes(decisionLogRelPath)) {
                addResult(acc, catalog, "FAIL", `${findingId} cites decision record '${decisionRef}' for its '${status}' status, but decision-log.md was itself changed within the commit range under verification.`, { ruleId: "AREV-006", artifact: "decision-log.md", itemId: findingId, field: "decision_ref" });
            }
            else {
                addResult(acc, catalog, "PASS", `${findingId}'s '${status}' status resolves to a real, independent decision record.`, { ruleId: "AREV-006", artifact: "EXECUTION-REVIEW.json", itemId: findingId });
            }
        }
        if (humanOnlyStatuses.includes(status) && reviewerKind !== "human") {
            addResult(acc, catalog, "FAIL", `${findingId} has status '${status}', which closure_policy.settable_by restricts to human authority, but reviewer_kind is '${reviewerKind}'. An ai-kind reviewer may not set this status on any finding, human-only category or not.`, { ruleId: "AREV-005", artifact: "EXECUTION-REVIEW.json", itemId: findingId, field: "status" });
        }
        else if (humanOnlyCategories.includes(category) && status === "resolved" && reviewerKind !== "human") {
            addResult(acc, catalog, "FAIL", `${findingId} is category '${category}' (human-only) and was set to 'resolved' by a non-human reviewer (reviewer_kind: ${reviewerKind}). An AI reviewer may never close a human-only-category finding under any status.`, { ruleId: "AREV-005", artifact: "EXECUTION-REVIEW.json", itemId: findingId, field: "status" });
        }
        else if (nonClosure.includes(status)) {
            continue;
        }
    }
    if (resultDocument["review_finding_dispositions"] !== undefined) {
        for (const disposition of resultDocument["review_finding_dispositions"] ?? []) {
            const status = String(disposition["status"] ?? "");
            if (!nonClosure.includes(status)) {
                addResult(acc, catalog, "FAIL", `EXECUTION-RESULT.json claims to have set finding '${disposition["finding_id"]}' to '${status}'. The executor may only move a finding to 'disputed', with evidence -- never to a closure or acceptance state.`, { ruleId: "AREV-005", artifact: "EXECUTION-RESULT.json", itemId: String(disposition["finding_id"] ?? ""), field: "review_finding_dispositions" });
            }
        }
    }
}
// Re-export for potential external use.
export { getEffectiveModeForVerification, readAdversarialReviewPolicy };
