// Execution-contract verification orchestration, ported from
// scripts/lib/execution-contract-validator.ps1.
import { existsSync, readFileSync } from "node:fs";
import { join, resolve, dirname } from "node:path";
import { readExecutionContract, readExecutionResult, readExecutionContractPolicy, resolveTestEvidenceEntries, resolveDecisionRecord, testDecisionAuthorityBinding, } from "./execution-contract-schema.js";
import { getExecutionGitObservation } from "./execution-contract-git.js";
import { testEvidenceEntryVerified } from "./execution-contract-evidence.js";
import { convertToScopeGlobRegex } from "../rules/scope-diff-matcher.js";
import { getTableRowsAfterHeading, getIdsFromRows } from "../markdown/table-parser.js";
import { addResult } from "../core/result-writer.js";
import { testAdversarialReviewEvidence, getEffectiveModeForVerification } from "./adversarial-review-validator.js";
export function invokeExecutionContractVerification(acc, catalog, projectPath, resultPath, gitRepoRoot, frameworkRoot, contractPath, preflight) {
    const resolvedResultPath = resultPath;
    if (!contractPath)
        contractPath = join(dirname(resolvedResultPath), "EXECUTION-CONTRACT.json");
    const policy = readExecutionContractPolicy(frameworkRoot);
    const verdict = {
        contract_path: contractPath,
        result_path: resolvedResultPath,
        work_item_id: null,
        contract_sha256: null,
        base_sha: null,
        head_sha: null,
        observed_commit_count: 0,
        changed_files_observed: [],
        changed_files_out_of_scope: [],
        unverified_required_tests: [],
        authority_violations: [],
        verdict: "fail",
    };
    // 1. Contract intact (EXEC-002)
    const contract = readExecutionContract(contractPath);
    if (!contract.present) {
        addResult(acc, catalog, "FAIL", "No execution contract found at the expected location. A result cannot be verified without the approved contract it claims to satisfy -- there is nothing to check it against.", { ruleId: "EXEC-002", artifact: "EXECUTION-CONTRACT.json" });
        verdict.verdict = "contract_missing";
        return verdict;
    }
    if (!contract.valid) {
        addResult(acc, catalog, "FAIL", `Execution contract is invalid: ${contract.error}`, { ruleId: "EXEC-002", artifact: "EXECUTION-CONTRACT.json" });
        verdict.verdict = "contract_invalid";
        return verdict;
    }
    verdict.contract_sha256 = contract.digest;
    verdict.work_item_id = String(contract.document["work_item_id"] ?? "");
    verdict.base_sha = String(contract.document["base_sha"] ?? "");
    const sidecarPath = contractPath + ".sha256";
    if (!existsSync(sidecarPath)) {
        addResult(acc, catalog, "FAIL", `No digest sidecar found for the execution contract (${sidecarPath}). Without the digest recorded at export time, there is no approved version to check the contract against -- a missing sidecar is treated the same as a missing contract, not as an unverified pass.`, { ruleId: "EXEC-002", artifact: "EXECUTION-CONTRACT.json.sha256", itemId: verdict.work_item_id });
        verdict.verdict = "contract_digest_missing";
        return verdict;
    }
    const sidecarText = readFileSync(sidecarPath, "utf8").trim().toLowerCase();
    if (!/^[0-9a-f]{64}$/.test(sidecarText)) {
        addResult(acc, catalog, "FAIL", `The digest sidecar (${sidecarPath}) does not contain a well-formed SHA-256 digest.`, { ruleId: "EXEC-002", artifact: "EXECUTION-CONTRACT.json.sha256", itemId: verdict.work_item_id });
        verdict.verdict = "contract_digest_malformed";
        return verdict;
    }
    if (sidecarText !== contract.digest) {
        addResult(acc, catalog, "FAIL", "The execution contract's contents no longer match the digest recorded when it was exported. The contract was modified after approval.", { ruleId: "EXEC-002", artifact: "EXECUTION-CONTRACT.json", itemId: verdict.work_item_id, field: "contract_sha256" });
        verdict.verdict = "contract_tampered";
        return verdict;
    }
    // 2. Result well-formed (EXEC-001)
    const result = readExecutionResult(resolvedResultPath);
    if (!result.present) {
        addResult(acc, catalog, "FAIL", "No execution result found at the supplied path.", { ruleId: "EXEC-001", artifact: "EXECUTION-RESULT.json" });
        verdict.verdict = "result_missing";
        return verdict;
    }
    if (!result.valid) {
        addResult(acc, catalog, "FAIL", `Execution result is invalid: ${result.error}`, { ruleId: "EXEC-001", artifact: "EXECUTION-RESULT.json" });
        verdict.verdict = "result_invalid";
        return verdict;
    }
    const doc = result.document;
    // 3. Answers this contract
    if (String(doc["contract_sha256"] ?? "") !== contract.digest) {
        addResult(acc, catalog, "FAIL", "The execution result answers a different version of the contract than the one on disk. Its contract_sha256 does not match the approved contract's digest.", { ruleId: "EXEC-002", artifact: "EXECUTION-RESULT.json", itemId: verdict.work_item_id, field: "contract_sha256" });
        verdict.verdict = "contract_mismatch";
        return verdict;
    }
    const contractDoc = contract.document;
    if (String(doc["work_item_id"] ?? "") !== String(contractDoc["work_item_id"] ?? "")) {
        addResult(acc, catalog, "FAIL", "The execution result names a different work item than the contract it claims to satisfy.", { ruleId: "EXEC-003", artifact: "EXECUTION-RESULT.json", itemId: String(doc["work_item_id"] ?? ""), field: "work_item_id" });
    }
    if (String(doc["base_sha"] ?? "") !== String(contractDoc["base_sha"] ?? "")) {
        addResult(acc, catalog, "FAIL", "The execution result reports a different base commit than the contract approved. Work that did not start from the approved base is not the work that was approved.", { ruleId: "EXEC-003", artifact: "EXECUTION-RESULT.json", itemId: verdict.work_item_id, field: "base_sha" });
    }
    const contractRequirements = (contractDoc["requirement_refs"] ?? []).map((r) => String(r));
    if (doc["requirement_refs"] !== undefined) {
        for (const req of doc["requirement_refs"] ?? []) {
            const reqText = String(req);
            if (!contractRequirements.includes(reqText)) {
                addResult(acc, catalog, "FAIL", `The execution result claims a requirement the contract does not cover: ${reqText}`, { ruleId: "EXEC-003", artifact: "EXECUTION-RESULT.json", itemId: reqText, field: "requirement_refs" });
            }
        }
    }
    // 4. Git ground truth (EXEC-008)
    const headRef = String(doc["head_sha"] ?? "");
    if (!headRef.trim()) {
        addResult(acc, catalog, "FAIL", "The execution result does not report a head commit, so nothing it claims can be checked against the repository.", { ruleId: "EXEC-008", artifact: "EXECUTION-RESULT.json", itemId: verdict.work_item_id, field: "head_sha" });
        verdict.verdict = "unverifiable";
        return verdict;
    }
    const observation = getExecutionGitObservation(gitRepoRoot, String(contractDoc["base_sha"] ?? ""), headRef);
    if (!observation.ok) {
        addResult(acc, catalog, "FAIL", `Could not verify the execution result against git: ${observation.errorDetail}`, { ruleId: "EXEC-008", artifact: "EXECUTION-RESULT.json", itemId: verdict.work_item_id });
        verdict.verdict = "git_error";
        return verdict;
    }
    verdict.base_sha = observation.baseSha;
    verdict.head_sha = observation.headSha;
    verdict.observed_commit_count = observation.commitCount;
    if (!observation.headDescendsFromBase) {
        addResult(acc, catalog, "FAIL", "The head commit the result reports does not descend from the contract's approved base commit.", { ruleId: "EXEC-008", artifact: "EXECUTION-RESULT.json", itemId: verdict.work_item_id, field: "head_sha" });
    }
    const exemptRegexes = (policy["verification_exempt_paths"] ?? []).map((e) => new RegExp(convertToScopeGlobRegex(String(e["pattern"]))));
    const testExemptPath = (path) => exemptRegexes.some((rx) => rx.test(path));
    const observedPaths = [];
    for (const change of observation.changes) {
        const path = change.path;
        if (!testExemptPath(path))
            observedPaths.push(path);
        if (change.oldPath && !testExemptPath(change.oldPath))
            observedPaths.push(change.oldPath);
    }
    verdict.changed_files_observed = observedPaths;
    let decisionLogRelPath = null;
    const decisionLogFullPath = join(projectPath, "decision-log.md");
    const normalizedGitRoot = gitRepoRoot.replace(/[/\\]+$/, "");
    if (decisionLogFullPath.startsWith(normalizedGitRoot)) {
        decisionLogRelPath = decisionLogFullPath.substring(normalizedGitRoot.length).replace(/^[/\\]/, "").replace(/\\/g, "/");
    }
    if (doc["changed_files"] !== undefined) {
        const claimedPaths = (doc["changed_files"] ?? []).map((p) => String(p));
        for (const observed of observedPaths) {
            if (!claimedPaths.includes(observed)) {
                addResult(acc, catalog, "FAIL", `A file changed between the approved base and the reported head is not declared in the result's changed_files: ${observed}`, { ruleId: "EXEC-008", artifact: observed, itemId: verdict.work_item_id, field: "changed_files" });
            }
        }
        const observedSet = [...new Set(observedPaths)];
        for (const claimed of claimedPaths) {
            if (!claimed.trim())
                continue;
            if (!observedSet.includes(claimed)) {
                addResult(acc, catalog, "FAIL", `The result's changed_files claims a file that git shows no evidence of changing between the approved base and the reported head: ${claimed}`, { ruleId: "EXEC-008", artifact: claimed, itemId: verdict.work_item_id, field: "changed_files" });
            }
        }
    }
    // 5. Scope (EXEC-004)
    const allowedRegexes = (contractDoc["allowed_paths"] ?? []).map((p) => new RegExp(convertToScopeGlobRegex(p)));
    const prohibitedRegexes = (contractDoc["prohibited_paths"] ?? []).map((p) => new RegExp(convertToScopeGlobRegex(p)));
    const outOfScope = [];
    for (const path of [...new Set(observedPaths)]) {
        const prohibited = prohibitedRegexes.some((rx) => rx.test(path));
        if (prohibited) {
            outOfScope.push(path);
            addResult(acc, catalog, "FAIL", `A changed file matches a path the contract explicitly prohibited: ${path}`, { ruleId: "EXEC-004", artifact: path, itemId: verdict.work_item_id, field: "prohibited_paths" });
            continue;
        }
        const allowed = allowedRegexes.some((rx) => rx.test(path));
        if (!allowed) {
            outOfScope.push(path);
            addResult(acc, catalog, "FAIL", `A changed file is outside the paths the contract approved: ${path}`, { ruleId: "EXEC-004", artifact: path, itemId: verdict.work_item_id, field: "allowed_paths" });
        }
    }
    verdict.changed_files_out_of_scope = outOfScope;
    // 6. Required-test evidence (EXEC-005)
    const evidence = resolveTestEvidenceEntries(doc, policy);
    const evidenceProvenance = policy["evidence_provenance"] ?? {};
    const satisfyingTiers = [];
    for (const [tier, spec] of Object.entries(evidenceProvenance)) {
        if (tier === "_note")
            continue;
        if (spec["satisfies_required_test"] === true)
            satisfyingTiers.push(tier);
    }
    const requiredTestSatisfaction = policy["required_test_satisfaction"] ?? {};
    const humanVouchType = String(requiredTestSatisfaction["human_vouch_claim_type"] ?? "test-evidence-accepted");
    function resolveEvidenceVouch(claims, vouchType, testName, entry, evidenceDigest, workItemId, contractDigest, projectPath, decisionLogRel, observedPaths) {
        const candidates = claims.filter((c) => String(c["type"] ?? "") === vouchType);
        if (candidates.length === 0)
            return `no ${vouchType} claim is present`;
        let lastReason = null;
        for (const claim of candidates) {
            if (String(claim["actor"] ?? "") !== "human") {
                lastReason = `the vouch is from actor '${claim["actor"]}', and only a human may accept test evidence`;
                continue;
            }
            const claimTest = String(claim["test_name"] ?? "");
            if (!claimTest.trim()) {
                lastReason = "the vouch names no test_name, so it cannot be tied to any particular required test";
                continue;
            }
            if (claimTest !== testName) {
                lastReason = `the only vouch present is for test '${claimTest}', not '${testName}'`;
                continue;
            }
            const claimDigest = String(claim["evidence_sha256"] ?? "").trim().toLowerCase();
            if (!claimDigest.trim()) {
                lastReason = "the vouch names no evidence_sha256, so it does not identify which artifact was accepted";
                continue;
            }
            if (claimDigest !== evidenceDigest) {
                lastReason = `the vouch accepts artifact digest ${claimDigest}, but the evidence actually presented digests to ${evidenceDigest}`;
                continue;
            }
            if (claim["evidence_type"] !== undefined && String(claim["evidence_type"] ?? "").trim() !== "" && String(claim["evidence_type"]) !== entry.type) {
                lastReason = `the vouch is for '${claim["evidence_type"]}' evidence, but this entry is '${entry.type}'`;
                continue;
            }
            if (claim["work_item_id"] !== undefined && String(claim["work_item_id"] ?? "").trim() !== "" && String(claim["work_item_id"]) !== workItemId) {
                lastReason = `the vouch is bound to work item '${claim["work_item_id"]}', not '${workItemId}'`;
                continue;
            }
            if (claim["contract_sha256"] !== undefined && String(claim["contract_sha256"] ?? "").trim() !== "" && String(claim["contract_sha256"]).toLowerCase() !== contractDigest) {
                lastReason = "the vouch is bound to a different contract digest than the one being verified";
                continue;
            }
            const vouchRef = String(claim["decision_ref"] ?? "");
            if (!vouchRef.trim()) {
                lastReason = "the vouch cites no decision record";
                continue;
            }
            const resolved = resolveDecisionRecord(projectPath, vouchRef);
            if (!resolved.found) {
                lastReason = `the vouch cites decision record '${vouchRef}', which could not be resolved: ${resolved.reason}`;
                continue;
            }
            if (decisionLogRel && observedPaths.includes(decisionLogRel)) {
                lastReason = `the vouch cites '${vouchRef}', but decision-log.md was itself changed within the commit range under verification`;
                continue;
            }
            const bindingProblem = testDecisionAuthorityBinding(resolved.row, vouchType, workItemId, contractDigest, testName, evidenceDigest);
            if (bindingProblem) {
                lastReason = `decision record '${vouchRef}' does not authorize this: ${bindingProblem}`;
                continue;
            }
            return null;
        }
        return lastReason;
    }
    const unverified = [];
    if (contractDoc["required_tests"] !== undefined) {
        for (const required of contractDoc["required_tests"] ?? []) {
            const requiredName = String(required);
            const match = evidence.find((e) => e.name === requiredName);
            if (!match) {
                unverified.push(requiredName);
                addResult(acc, catalog, "FAIL", `A test the contract requires has no evidence entry in the result at all: ${requiredName}`, { ruleId: "EXEC-005", artifact: "EXECUTION-RESULT.json", itemId: requiredName, field: "test_evidence" });
                continue;
            }
            const verification = testEvidenceEntryVerified(match, projectPath, gitRepoRoot, contract.digest, verdict.work_item_id);
            if (!verification.verified) {
                unverified.push(requiredName);
                addResult(acc, catalog, "FAIL", `A test the contract requires is not backed by verified evidence -- its '${match.type}' entry did not verify: ${verification.reason}. An agent's own assertion that a test passed is a claim, not evidence.`, { ruleId: "EXEC-005", artifact: "EXECUTION-RESULT.json", itemId: requiredName, field: "test_evidence" });
                continue;
            }
            if (satisfyingTiers.includes(match.provenance))
                continue;
            const claims = (doc["authority_claims"] ?? []);
            const vouchProblem = resolveEvidenceVouch(claims, humanVouchType, requiredName, match, verification.evidenceDigest, verdict.work_item_id, contract.digest, projectPath, decisionLogRelPath, observedPaths);
            if (vouchProblem) {
                unverified.push(requiredName);
                let staleEvidenceNote = "";
                if (match.type === "junit-artifact" && match.raw["path"]) {
                    const evidencePath = String(match.raw["path"]);
                    const evidenceFull = resolve(join(projectPath, evidencePath));
                    if (evidenceFull.startsWith(normalizedGitRoot)) {
                        const evidenceRel = evidenceFull.substring(normalizedGitRoot.length).replace(/^[/\\]/, "").replace(/\\/g, "/");
                        if (!observedPaths.includes(evidenceRel)) {
                            staleEvidenceNote = "The evidence file was not changed within the verified commit range, so it cannot be the output of a test run of the code under verification -- a report that predates the work cannot prove the changed code passes. ";
                        }
                    }
                }
                addResult(acc, catalog, "FAIL", `A test the contract requires is backed only by '${match.type}' evidence, which is ${match.provenance}: the artifact is well-formed and matches its declared digest, but it lives where the actor being verified can write it, so nothing here establishes who produced it. ${staleEvidenceNote}No human acceptance applies to it either -- ${vouchProblem}. Satisfy this with evidence from a source the actor cannot impersonate (a ci-check), or have a human accept this specific artifact: a '${humanVouchType}' claim naming test_name and evidence_sha256, citing a decision record whose row names that same digest.`, { ruleId: "EXEC-005", artifact: "EXECUTION-RESULT.json", itemId: requiredName, field: "test_evidence" });
            }
        }
    }
    verdict.unverified_required_tests = unverified;
    // 7. Git authority (EXEC-006)
    const authority = contractDoc["git_authority"] ?? {};
    const testGrantedAction = (action) => authority[action] === true;
    const violations = [];
    if (observation.commitCount > 0 && !testGrantedAction("commit")) {
        violations.push("commit");
        addResult(acc, catalog, "FAIL", `The repository shows ${observation.commitCount} commit(s) between the approved base and the reported head, but the contract did not grant commit authority.`, { ruleId: "EXEC-006", artifact: "EXECUTION-CONTRACT.json", itemId: verdict.work_item_id, field: "git_authority.commit" });
    }
    if (observation.headOnRemote === true && !testGrantedAction("push")) {
        violations.push("push");
        addResult(acc, catalog, "FAIL", "The reported head commit is present on a remote-tracking ref, but the contract did not grant push authority.", { ruleId: "EXEC-006", artifact: "EXECUTION-CONTRACT.json", itemId: verdict.work_item_id, field: "git_authority.push" });
    }
    if (doc["git_actions_performed"] !== undefined) {
        for (const action of doc["git_actions_performed"] ?? []) {
            const actionText = String(action);
            if (!actionText.trim())
                continue;
            if (!testGrantedAction(actionText)) {
                if (!violations.includes(actionText))
                    violations.push(actionText);
                addResult(acc, catalog, "FAIL", `The result reports performing a git action the contract did not grant: ${actionText}`, { ruleId: "EXEC-006", artifact: "EXECUTION-RESULT.json", itemId: verdict.work_item_id, field: "git_actions_performed" });
            }
        }
    }
    // 8. Authority claims / self-approval (EXEC-007)
    if (doc["authority_claims"] !== undefined) {
        const actorAuthority = policy["actor_authority"] ?? {};
        const authorityClaimTypes = policy["authority_claim_types"] ?? {};
        for (const claim of doc["authority_claims"] ?? []) {
            const claimType = String(claim["type"] ?? "");
            const actor = String(claim["actor"] ?? "");
            if (!claimType.trim())
                continue;
            const actorPolicy = actorAuthority[actor];
            if (!actorPolicy) {
                violations.push(`authority:${claimType}`);
                addResult(acc, catalog, "FAIL", `The result carries an authority claim from an unrecognized actor type '${actor}'. An actor the policy does not know cannot be granted any authority.`, { ruleId: "EXEC-007", artifact: "EXECUTION-RESULT.json", itemId: claimType, field: "authority_claims" });
                continue;
            }
            const mayGrant = (actorPolicy["may_grant"] ?? []).map((g) => String(g));
            if (!mayGrant.includes(claimType)) {
                violations.push(`authority:${claimType}`);
                addResult(acc, catalog, "FAIL", `The result claims '${claimType}' authority as actor '${actor}', which is not authorized to grant it. An execution agent cannot approve its own work.`, { ruleId: "EXEC-007", artifact: "EXECUTION-RESULT.json", itemId: claimType, field: "authority_claims" });
                continue;
            }
            const typePolicy = authorityClaimTypes[claimType];
            if (typePolicy && typePolicy["human_only"] === true) {
                const decisionRef = claim["decision_ref"] !== undefined ? String(claim["decision_ref"]) : null;
                if (!decisionRef || !decisionRef.trim()) {
                    violations.push(`authority:${claimType}`);
                    addResult(acc, catalog, "FAIL", `A human-only authority claim ('${claimType}') cites no decision record. Commit authorship alone does not prove a human actor; the claim must reference a DEC-### in decision-log.md.`, { ruleId: "EXEC-007", artifact: "EXECUTION-RESULT.json", itemId: claimType, field: "authority_claims.decision_ref" });
                }
                else {
                    const resolved = resolveDecisionRecord(projectPath, decisionRef);
                    if (!resolved.found) {
                        violations.push(`authority:${claimType}`);
                        addResult(acc, catalog, "FAIL", `A human-only authority claim ('${claimType}') cites decision record '${decisionRef}', which could not be resolved: ${resolved.reason}. A citation that does not resolve to a real, unique row is not authority.`, { ruleId: "EXEC-007", artifact: "EXECUTION-RESULT.json", itemId: claimType, field: "authority_claims.decision_ref" });
                    }
                    else if (decisionLogRelPath && observedPaths.includes(decisionLogRelPath)) {
                        violations.push(`authority:${claimType}`);
                        addResult(acc, catalog, "FAIL", `A human-only authority claim ('${claimType}') cites decision record '${decisionRef}', but decision-log.md was itself changed within the commit range under verification. A decision the execution's own commits could have introduced cannot serve as independent human authority for that same execution.`, { ruleId: "EXEC-007", artifact: "decision-log.md", itemId: claimType, field: "authority_claims.decision_ref" });
                    }
                    else {
                        const claimTestName = claimType === humanVouchType ? String(claim["test_name"] ?? "") : null;
                        const claimEvidence = claimType === humanVouchType ? String(claim["evidence_sha256"] ?? "") : null;
                        const bindProblem = testDecisionAuthorityBinding(resolved.row, claimType, verdict.work_item_id, contract.digest, claimTestName, claimEvidence);
                        if (bindProblem) {
                            violations.push(`authority:${claimType}`);
                            addResult(acc, catalog, "FAIL", `A human-only authority claim ('${claimType}') cites decision record '${decisionRef}', which resolves but does not authorize this claim: ${bindProblem}`, { ruleId: "EXEC-007", artifact: "decision-log.md", itemId: claimType, field: "authority_claims.decision_ref" });
                        }
                    }
                }
            }
        }
    }
    verdict.authority_violations = violations;
    // AREV-*
    if (!preflight) {
        let projectReqIds = [];
        const projectTextPath = join(projectPath, "PROJECT.md");
        if (existsSync(projectTextPath)) {
            const projectText = readFileSync(projectTextPath, "utf8");
            projectReqIds = getIdsFromRows(getTableRowsAfterHeading(projectText, "^###\\s+In Scope"));
        }
        const effectiveModeForArev = getEffectiveModeForVerification(projectPath);
        testAdversarialReviewEvidence(acc, catalog, projectPath, contractPath, contract, effectiveModeForArev, doc, verdict.base_sha, verdict.head_sha, verdict.work_item_id, frameworkRoot, gitRepoRoot, observedPaths, decisionLogRelPath, projectReqIds);
    }
    const failed = acc.messages.filter((m) => m.level === "FAIL" && (m.rule_id.startsWith("EXEC-") || m.rule_id.startsWith("AREV-"))).length;
    if (failed === 0) {
        addResult(acc, catalog, "PASS", `Execution result verified against the approved contract and observed git state: ${observation.commitCount} commit(s), ${[...new Set(observedPaths)].length} changed file(s), all within approved scope.`, { ruleId: "EXEC-001" });
        verdict.verdict = "pass";
    }
    return verdict;
}
// Re-exported for the verify-execution-result entrypoint.
export { readExecutionContractPolicy } from "./execution-contract-schema.js";
