// Ported from tests/helpers/adversarial-review-tests.ps1 (Milestone 8.1
// adversarial review evidence), adapted for the Node port.
//
// Behaviour tests for the AREV-001..007 rules, exercised end to end through
// the real entry points -- exportExecutionContract and
// runVerifyExecutionResult -- using real disposable git repositories, the
// same strategy and the same reason as execution-contract.test.ts: this
// feature's job is comparing a review artifact's claims against a contract
// and against who is allowed to close what, so a mock would prove the code
// agrees with the mock. Cases are written adversarially: the interesting ones
// are where the review is self-served, unbound, or closed by an actor
// without authority to close it.
//
// The PS originals spawn scripts/export-execution-contract.ps1 and
// scripts/verify-execution-result.ps1 as subprocesses; the port calls their
// Node equivalents in-process, per the established pattern.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync, readdirSync, cpSync, existsSync, } from "node:fs";
import { tmpdir } from "node:os";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { exportExecutionContract } from "./export-execution-contract.js";
import { runExecutionCommand } from "./run-execution-command.js";
import { runVerifyExecutionResult } from "../exec/verify-execution-result.js";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
// ---------------------------------------------------------------------------
// fixture helpers
// ---------------------------------------------------------------------------
function sha256(data) {
    return createHash("sha256").update(data).digest("hex").toLowerCase();
}
function git(dir, ...args) {
    spawnSync("git", ["-C", dir, ...args], { encoding: "utf8" });
}
function gitOut(dir, ...args) {
    const r = spawnSync("git", ["-C", dir, ...args], { encoding: "utf8" });
    const out = (r.stdout ?? "").trim();
    return out === "" ? "" : out.split("\n")[0].trim();
}
function gitInit(dir) {
    const r = spawnSync("git", ["-C", dir, "init", "-q", "--initial-branch=main"], { encoding: "utf8" });
    if (r.status !== 0)
        spawnSync("git", ["-C", dir, "init", "-q"], { encoding: "utf8" });
}
function writeExecFile(dir, rel, content) {
    const full = join(dir, rel);
    mkdirSync(dirname(full), { recursive: true });
    writeFileSync(full, content);
}
function newReviewFixture(mode) {
    const dir = mkdtempSync(join(tmpdir(), "axiom-arev-"));
    mkdirSync(join(dir, "src"), { recursive: true });
    // The In Scope table exists because AREV-007 resolves each finding's
    // requirement_ref against PROJECT.md In Scope (same source RTM-002 reads).
    // REQ-001 is the one id every finding in this suite that cites a
    // requirement is allowed to cite.
    writeExecFile(dir, "PROJECT.md", [
        "# P99-AREV", "",
        `> Default mode: ${mode}`, "",
        "### In Scope", "",
        "| ID | Requirement | Source Ref | Evidence Status |",
        "|---|---|---|---|",
        "| REQ-001 | Checkout flow | MOM-001 | verified |",
    ].join("\n"));
    writeExecFile(dir, "SCOPE.json", '{"schema_version":"1.0","project":"P99-AREV","implementation_scope":{"include":["src/**"],"exclude":[]}}');
    writeExecFile(dir, "DELIVERY.md", [
        "# DELIVERY - P99-AREV", "",
        "## Work Items", "",
        "| ID | Mode | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Status |",
        "|---|---|---|---|---|---|---|---|---|",
        `| D-001 | ${mode} | Checkout flow | REQ-001 | DESIGN/FLOW.puml | Works | unit tests | Dev | To Do |`,
    ].join("\n"));
    writeExecFile(dir, "src/app.ts", "seed");
    writeExecFile(dir, "decision-log.md", "# Decision Log - P99-AREV\n\n| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |\n|---|---|---|---|---|---|---|---|\n");
    gitInit(dir);
    git(dir, "config", "user.email", "test@axiom-pmo.local");
    git(dir, "config", "user.name", "Axiom Adversarial Review Tests");
    git(dir, "config", "core.autocrlf", "false");
    git(dir, "config", "core.safecrlf", "false");
    git(dir, "add", "-A");
    git(dir, "commit", "-q", "-m", "base");
    return dir;
}
function removeFixture(dir) {
    rmSync(dir, { recursive: true, force: true });
}
function exportContract(dir) {
    const r = exportExecutionContract(REPO_ROOT, dir, "D-001", null, null, "", true);
    if (r.exitCode !== 0)
        throw new Error(`export failed: ${r.output}`);
}
function contractDigestOf(dir) {
    return readFileSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json.sha256"), "utf8").trim();
}
function verifyResult(dir, preflight = false) {
    const resultPath = join(dir, ".execution/D-001/EXECUTION-RESULT.json");
    const r = runVerifyExecutionResult(REPO_ROOT, dir, resultPath, null, null, preflight);
    return r.envelope;
}
function ruleIds(env, level = "FAIL") {
    if (!env)
        return [];
    return env.results.filter((r) => r.level === level).map((r) => r.rule_id);
}
function rows(env, ruleId, level = "FAIL") {
    return env.results.filter((r) => r.level === level && r.rule_id === ruleId);
}
function realRunRecord(dir) {
    const r = runExecutionCommand(dir, "D-001", "unit tests", "echo ok");
    if (r.exitCode !== 0)
        throw new Error(`realRunRecord: runner failed: ${r.output}`);
    const runsDir = join(dir, ".execution/D-001/runs");
    const recordFile = readdirSync(runsDir).find((f) => f.endsWith(".json") && !f.endsWith(".sha256"));
    if (!recordFile)
        throw new Error(`realRunRecord: no run record produced: ${r.output}`);
    return `.execution/D-001/runs/${recordFile}`;
}
// Base EXECUTION-RESULT.json every case starts from: clean, satisfies EXEC-*
// on its own (real run record, human-vouched via a decision row outside the
// verified range), so a failure any of these cases assert is attributable to
// AREV-*, not to an unrelated EXEC-* problem.
function baseResult(dir, overrides = {}) {
    const digest = contractDigestOf(dir);
    const contract = JSON.parse(readFileSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json"), "utf8"));
    const head = gitOut(dir, "rev-parse", "HEAD");
    const relRunRecordPath = realRunRecord(dir);
    const recordDigest = sha256(readFileSync(join(dir, relRunRecordPath)));
    writeExecFile(dir, "decision-log.md", [
        "# Decision Log - P99-AREV", "",
        "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
        "|---|---|---|---|---|---|---|---|",
        `| 2026-07-31 | DEC-100 | Accept unit tests for D-001 | accept / require CI | accept | axiom-authority: type=test-evidence-accepted; work_item=D-001; contract=${digest}; test=unit tests; evidence=${recordDigest} | none | test evidence accepted |`,
    ].join("\n"));
    const doc = {
        contract_version: "1.0", work_item_id: "D-001", contract_sha256: digest,
        base_sha: String(contract["base_sha"]), head_sha: head, execution_status: "completed",
        changed_files: [],
        test_evidence: [{ type: "runner-exit-record", name: "unit tests", run_record_path: relRunRecordPath }],
        authority_claims: [{
                type: "test-evidence-accepted", actor: "human", claim: "accepted",
                decision_ref: "DEC-100", test_name: "unit tests", evidence_sha256: recordDigest,
                evidence_type: "runner-exit-record", work_item_id: "D-001",
            }],
    };
    for (const [k, v] of Object.entries(overrides))
        doc[k] = v;
    writeFileSync(join(dir, ".execution/D-001/EXECUTION-RESULT.json"), JSON.stringify(doc));
    return { digest, head, baseSha: String(contract["base_sha"]) };
}
function newReview(dir, identity, overrides = {}, findings = []) {
    const doc = {
        schema_version: "1.0", review_id: "AR-001",
        contract_sha256: identity.digest, base_sha: identity.baseSha, head_sha: identity.head,
        reviewed_at: "2026-08-05", reviewer_kind: "ai", reviewer: "test-reviewer",
        provenance: { tier: "artifact-observed", check_run_id: null },
        findings,
        recommendation: { verdict: "request_changes", notes: "test" },
    };
    for (const [k, v] of Object.entries(overrides))
        doc[k] = v;
    writeFileSync(join(dir, ".execution/D-001/EXECUTION-REVIEW.json"), JSON.stringify(doc));
}
// ---------------------------------------------------------------------------
// Case 1: Lite mode -- disabled, no diagnostic at all
// ---------------------------------------------------------------------------
test("Lite mode: no EXECUTION-REVIEW.json, no AREV-001 diagnostic, verdict pass", () => {
    const dir = newReviewFixture("Lite");
    try {
        exportContract(dir);
        baseResult(dir);
        const env = verifyResult(dir);
        assert.equal(rows(env, "AREV-001", "FAIL").length + rows(env, "AREV-001", "WARN").length, 0, "Lite mode: no EXECUTION-REVIEW.json, no AREV-001 diagnostic at all");
        assert.equal(env.execution_verification.verdict, "pass", "Lite mode: verdict still pass");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 2: Standard mode -- missing review is advisory, not blocking
// ---------------------------------------------------------------------------
test("Standard mode: missing review is WARN, does not block the verdict", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        baseResult(dir);
        const env = verifyResult(dir);
        const arev001 = rows(env, "AREV-001", "WARN");
        assert.equal(arev001.length, 1, "Standard mode: missing review is WARN, not FAIL");
        assert.equal(env.execution_verification.verdict, "pass", "Standard mode: missing review does not block the verdict");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 3: Strict mode -- missing review fails closed
// ---------------------------------------------------------------------------
test("Strict mode: missing review is FAIL and blocks the verdict", () => {
    const dir = newReviewFixture("Strict");
    try {
        exportContract(dir);
        baseResult(dir);
        const env = verifyResult(dir);
        assert.ok(ruleIds(env).includes("AREV-001"), "Strict mode: missing review is FAIL");
        assert.notEqual(env.execution_verification.verdict, "pass", "Strict mode: missing review blocks the verdict");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 4: Strict mode -- --preflight skips AREV entirely
// ---------------------------------------------------------------------------
test("--preflight: no AREV-* diagnostic at all, verdict still pass", () => {
    const dir = newReviewFixture("Strict");
    try {
        exportContract(dir);
        baseResult(dir);
        const env = verifyResult(dir, true);
        assert.equal(env.results.filter((r) => /^AREV-/.test(r.rule_id)).length, 0, "--preflight: no AREV-* diagnostic at all, even in Strict with no review");
        assert.equal(env.execution_verification.verdict, "pass", "--preflight: verdict still pass (mechanical checks alone are clean)");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 5: Strict mode -- artifact-observed alone never satisfies
// ---------------------------------------------------------------------------
test("artifact-observed alone: AREV-003 raised, blocks the verdict", () => {
    const dir = newReviewFixture("Strict");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        newReview(dir, id);
        const env = verifyResult(dir);
        assert.ok(ruleIds(env).includes("AREV-003"), "artifact-observed alone: AREV-003 raised");
        assert.notEqual(env.execution_verification.verdict, "pass", "artifact-observed alone: blocks the verdict");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 6: artifact-observed, promoted by a bound human claim, satisfies
// ---------------------------------------------------------------------------
test("artifact-observed promoted: AREV-003 not raised, verdict pass", () => {
    const dir = newReviewFixture("Strict");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        newReview(dir, id);
        const resultPath = join(dir, ".execution/D-001/EXECUTION-RESULT.json");
        const resultDoc = JSON.parse(readFileSync(resultPath, "utf8"));
        resultDoc.authority_claims = [...resultDoc.authority_claims,
            { type: "review-evidence-accepted", actor: "human", claim: "accepted", decision_ref: "DEC-101", work_item_id: "D-001" }];
        writeFileSync(resultPath, JSON.stringify(resultDoc));
        const logPath = join(dir, "decision-log.md");
        const existing = readFileSync(logPath, "utf8");
        writeFileSync(logPath, existing.trimEnd() + `\n| 2026-07-31 | DEC-101 | Accept the review for D-001 | accept | accept | axiom-authority: type=review-evidence-accepted; work_item=D-001; contract=${id.digest} | none | review accepted |`);
        const env = verifyResult(dir);
        assert.ok(!ruleIds(env).includes("AREV-003"), "artifact-observed promoted: AREV-003 not raised");
        assert.equal(env.execution_verification.verdict, "pass", "artifact-observed promoted: verdict pass");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 7: review answers a different contract
// ---------------------------------------------------------------------------
test("wrong contract digest: AREV-002 raised", () => {
    const dir = newReviewFixture("Strict");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        newReview(dir, id, { contract_sha256: "0".repeat(64) });
        const env = verifyResult(dir);
        assert.ok(ruleIds(env).includes("AREV-002"), "wrong contract digest: AREV-002 raised");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 8: finding missing required fields
// ---------------------------------------------------------------------------
test("malformed finding: AREV-004 raised", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        newReview(dir, id, {}, [{ finding_id: "AF-001", category: "not-a-real-category", severity: "major", status: "open", description: "", suggestion: "", requirement_ref: "REQ-001", implementation_claim: "x", test_claim: "x", owner: "Alice Chen" }]);
        const env = verifyResult(dir);
        assert.ok(ruleIds(env).includes("AREV-004"), "malformed finding: AREV-004 raised");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 9: executor tries to close its own finding
// ---------------------------------------------------------------------------
test("executor self-closure attempt: AREV-005 names EXECUTION-RESULT.json", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        const id = baseResult(dir, { review_finding_dispositions: [{ finding_id: "AF-001", status: "accepted_risk" }] });
        newReview(dir, id, {}, [{ finding_id: "AF-001", category: "other", severity: "minor", status: "open", description: "d", suggestion: "s", requirement_ref: "REQ-001", implementation_claim: "x", test_claim: "x", owner: "Alice Chen" }]);
        const env = verifyResult(dir);
        assert.ok(ruleIds(env).includes("AREV-005"), "executor self-closure attempt: AREV-005 raised");
        assert.ok(rows(env, "AREV-005").some((r) => r.artifact === "EXECUTION-RESULT.json"), "executor self-closure attempt: names EXECUTION-RESULT.json as the artifact");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 10: AI reviewer closes a human-only-category finding
// ---------------------------------------------------------------------------
test("AI closes human-only category: AREV-005 raised", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        newReview(dir, id, {}, [{ finding_id: "AF-001", category: "security", severity: "critical", status: "resolved", description: "d", suggestion: "s", requirement_ref: "REQ-001", implementation_claim: "x", test_claim: "x", owner: "Alice Chen" }]);
        const env = verifyResult(dir);
        assert.ok(ruleIds(env).includes("AREV-005"), "AI closes human-only category: AREV-005 raised");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 11: disputed is not a closure, stays out of AREV-005
// ---------------------------------------------------------------------------
test("disputed status alone: no AREV-005", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        newReview(dir, id, {}, [{ finding_id: "AF-001", category: "other", severity: "minor", status: "disputed", description: "d", suggestion: "s", requirement_ref: "REQ-001", implementation_claim: "x", test_claim: "x", owner: "Alice Chen" }]);
        // The verify call itself is the anti-vacuous anchor: if verification
        // crashed outright the test fails here, rather than reporting PASS
        // against empty output.
        const env = verifyResult(dir);
        assert.ok(!ruleIds(env).includes("AREV-005"), "disputed status alone: no AREV-005");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 12: ai reviewer sets accepted_risk on a NON-human-only-category finding,
// with a valid independent decision
// ---------------------------------------------------------------------------
test("ai reviewer setting accepted_risk on a non-human-only-category finding: AREV-005 raised", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        const logPath = join(dir, "decision-log.md");
        const existing = readFileSync(logPath, "utf8");
        writeFileSync(logPath, existing.trimEnd() + `\n| 2026-07-31 | DEC-300 | Accept the risk for AF-001 | accept | accept | axiom-authority: type=review-finding-disposition; work_item=AF-001; contract=${id.digest} | none | risk accepted |`);
        newReview(dir, id, { reviewer_kind: "ai" }, [{ finding_id: "AF-001", category: "other", severity: "minor", status: "accepted_risk", description: "d", suggestion: "s", decision_ref: "DEC-300", requirement_ref: "REQ-001", implementation_claim: "x", test_claim: "x", owner: "Alice Chen" }]);
        const env = verifyResult(dir);
        assert.ok(ruleIds(env).includes("AREV-005"), "ai reviewer setting accepted_risk on a non-human-only-category finding: AREV-005 raised");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 13: accepted_risk with an unresolvable decision_ref
// ---------------------------------------------------------------------------
test("unresolvable decision_ref: AREV-006 raised", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        newReview(dir, id, {}, [{ finding_id: "AF-001", category: "other", severity: "minor", status: "accepted_risk", description: "d", suggestion: "s", decision_ref: "DEC-999", requirement_ref: "REQ-001", implementation_claim: "x", test_claim: "x", owner: "Alice Chen" }]);
        const env = verifyResult(dir);
        assert.ok(ruleIds(env).includes("AREV-006"), "unresolvable decision_ref: AREV-006 raised");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 14: accepted_risk citing a decision added within the verified range
// ---------------------------------------------------------------------------
test("decision added within verified range: AREV-006 even though DEC-200 resolves", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        const digest = contractDigestOf(dir);
        const contract = JSON.parse(readFileSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json"), "utf8"));
        const relRunRecordPath = realRunRecord(dir);
        // The forged-decision attack: within the SAME commit range under
        // verification, add a decision row that resolves and cite it.
        writeExecFile(dir, "decision-log.md", [
            "# Decision Log - P99-AREV", "",
            "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
            "|---|---|---|---|---|---|---|---|",
            "| 2026-07-30 | DEC-200 | forged | A | A | agent wrote this | none | none |",
        ].join("\n"));
        git(dir, "add", "-A");
        git(dir, "commit", "-q", "-m", "self-forged decision");
        const head = gitOut(dir, "rev-parse", "HEAD");
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: digest,
            base_sha: String(contract["base_sha"]), head_sha: head, execution_status: "completed",
            changed_files: ["decision-log.md"],
            test_evidence: [{ type: "runner-exit-record", name: "unit tests", run_record_path: relRunRecordPath }],
        };
        writeFileSync(join(dir, ".execution/D-001/EXECUTION-RESULT.json"), JSON.stringify(doc));
        const identity = { digest, head, baseSha: String(contract["base_sha"]) };
        newReview(dir, identity, {}, [{ finding_id: "AF-001", category: "other", severity: "minor", status: "accepted_risk", description: "d", suggestion: "s", decision_ref: "DEC-200", requirement_ref: "REQ-001", implementation_claim: "x", test_claim: "x", owner: "Alice Chen" }]);
        const env = verifyResult(dir);
        assert.ok(ruleIds(env).includes("AREV-006"), "decision added within verified range: AREV-006 raised even though DEC-200 resolves");
        assert.ok(rows(env, "AREV-006").some((r) => r.artifact === "decision-log.md"), "decision added within verified range: reason names decision-log.md");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 15: AREV-007 -- semantic output contract (M3), request_changes verdict
// ---------------------------------------------------------------------------
test("request_changes verdict, contract-valid finding: AREV-007 not raised, execution verdict unaffected", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        newReview(dir, id, { recommendation: { verdict: "request_changes", notes: "the review disagrees with this execution" } }, [{ finding_id: "AF-001", category: "acceptance-criteria-gap", severity: "major", status: "open", description: "d", suggestion: "s", requirement_ref: "REQ-001", implementation_claim: "the implementation misses the acceptance case", test_claim: "no test covers the acceptance case", owner: "Alice Chen" }]);
        const env = verifyResult(dir);
        assert.ok(!ruleIds(env).includes("AREV-007"), "request_changes verdict, contract-valid finding: AREV-007 not raised");
        assert.equal(env.execution_verification.verdict, "pass", "request_changes verdict, contract-valid finding: execution verdict unaffected (still pass)");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 16: finding missing requirement_ref
// ---------------------------------------------------------------------------
test("missing requirement_ref: AREV-007 names the finding id and field, blocks the verdict", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        newReview(dir, id, {}, [{ finding_id: "AF-001", category: "acceptance-criteria-gap", severity: "major", status: "open", description: "d", suggestion: "s", implementation_claim: "x", test_claim: "x", owner: "Alice Chen" }]);
        const env = verifyResult(dir);
        const arev007 = rows(env, "AREV-007");
        assert.ok(ruleIds(env).includes("AREV-007"), "missing requirement_ref: AREV-007 raised");
        assert.equal(arev007[0]?.item_id, "AF-001", "missing requirement_ref: reason names the finding id");
        assert.equal(arev007[0]?.field, "requirement_ref", "missing requirement_ref: reason names the field");
        assert.notEqual(env.execution_verification.verdict, "pass", "missing requirement_ref: blocks the verdict on its own");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 17: requirement_ref does not resolve
// ---------------------------------------------------------------------------
test("unresolvable requirement_ref: AREV-007 names the bogus id", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        newReview(dir, id, {}, [{ finding_id: "AF-001", category: "acceptance-criteria-gap", severity: "major", status: "open", description: "d", suggestion: "s", requirement_ref: "REQ-999", implementation_claim: "x", test_claim: "x", owner: "Alice Chen" }]);
        const env = verifyResult(dir);
        assert.ok(ruleIds(env).includes("AREV-007"), "unresolvable requirement_ref: AREV-007 raised");
        assert.match(rows(env, "AREV-007")[0].message, /REQ-999/, "unresolvable requirement_ref: reason names the bogus id");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 18: claim fields missing without the N/A marker
// ---------------------------------------------------------------------------
test("missing implementation_claim without N/A: AREV-007 with the field", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        newReview(dir, id, {}, [{ finding_id: "AF-001", category: "acceptance-criteria-gap", severity: "major", status: "open", description: "d", suggestion: "s", requirement_ref: "REQ-001", test_claim: "x", owner: "Alice Chen" }]);
        const env = verifyResult(dir);
        const implRows = rows(env, "AREV-007").filter((r) => r.field === "implementation_claim");
        assert.ok(implRows.length > 0, "missing implementation_claim without N/A: AREV-007 raised with the field");
        assert.equal(implRows[0].item_id, "AF-001", "missing implementation_claim without N/A: reason names the finding id");
    }
    finally {
        removeFixture(dir);
    }
});
test("missing test_claim without N/A: AREV-007 with the field", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        newReview(dir, id, {}, [{ finding_id: "AF-001", category: "acceptance-criteria-gap", severity: "major", status: "open", description: "d", suggestion: "s", requirement_ref: "REQ-001", implementation_claim: "x", owner: "Alice Chen" }]);
        const env = verifyResult(dir);
        const testRows = rows(env, "AREV-007").filter((r) => r.field === "test_claim");
        assert.ok(testRows.length > 0, "missing test_claim without N/A: AREV-007 raised with the field");
        assert.equal(testRows[0].item_id, "AF-001", "missing test_claim without N/A: reason names the finding id");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 19: the explicit N/A marker is accepted
// ---------------------------------------------------------------------------
test("explicit N/A marker on both claims: AREV-007 not raised, verdict pass", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        newReview(dir, id, {}, [{ finding_id: "AF-001", category: "acceptance-criteria-gap", severity: "major", status: "open", description: "d", suggestion: "s", requirement_ref: "REQ-001", implementation_claim: "N/A", test_claim: "N/A", owner: "Alice Chen" }]);
        const env = verifyResult(dir);
        assert.ok(!ruleIds(env).includes("AREV-007"), "explicit N/A marker on both claims: AREV-007 not raised");
        assert.equal(env.execution_verification.verdict, "pass", "explicit N/A marker on both claims: verdict pass");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 20: finding missing owner
// ---------------------------------------------------------------------------
test("missing owner: AREV-007 names the field, blocks the verdict", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        newReview(dir, id, {}, [{ finding_id: "AF-001", category: "acceptance-criteria-gap", severity: "major", status: "open", description: "d", suggestion: "s", requirement_ref: "REQ-001", implementation_claim: "x", test_claim: "x" }]);
        const env = verifyResult(dir);
        const ownerRows = rows(env, "AREV-007").filter((r) => r.field === "owner");
        assert.ok(ownerRows.length > 0, "missing owner: AREV-007 raised with the field");
        assert.equal(ownerRows[0].item_id, "AF-001", "missing owner: reason names the finding id");
        assert.notEqual(env.execution_verification.verdict, "pass", "missing owner: blocks the verdict on its own");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 21: generic group token as owner
// ---------------------------------------------------------------------------
test("generic group owner: AREV-007 names the token, blocks the verdict", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        newReview(dir, id, {}, [{ finding_id: "AF-001", category: "acceptance-criteria-gap", severity: "major", status: "open", description: "d", suggestion: "s", requirement_ref: "REQ-001", implementation_claim: "x", test_claim: "x", owner: "Dev Team" }]);
        const env = verifyResult(dir);
        const ownerRows = rows(env, "AREV-007").filter((r) => r.field === "owner");
        assert.ok(ownerRows.length > 0, "generic group owner: AREV-007 raised with the field");
        assert.match(ownerRows[0].message, /Dev Team/, "generic group owner: reason names the token");
        assert.notEqual(env.execution_verification.verdict, "pass", "generic group owner: blocks the verdict");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 22: valid named owner passes
// ---------------------------------------------------------------------------
test("valid named owner: AREV-007 not raised, verdict pass", () => {
    const dir = newReviewFixture("Standard");
    try {
        exportContract(dir);
        const id = baseResult(dir);
        newReview(dir, id, {}, [{ finding_id: "AF-001", category: "acceptance-criteria-gap", severity: "major", status: "open", description: "d", suggestion: "s", requirement_ref: "REQ-001", implementation_claim: "x", test_claim: "x", owner: "Alicia Wu" }]);
        const env = verifyResult(dir);
        assert.ok(!ruleIds(env).includes("AREV-007"), "valid named owner: AREV-007 not raised");
        assert.equal(env.execution_verification.verdict, "pass", "valid named owner: verdict pass");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 23: externally-observed binding -- check run must be attributable to
// the pinned workflow (the FATAL fix)
// ---------------------------------------------------------------------------
test("externally-observed: workflow attribution enforced via a stubbed gh", () => {
    const isolatedFramework = mkdtempSync(join(tmpdir(), "axiom-arev-ext-"));
    const dir = newReviewFixture("Strict");
    const stubBinDir = mkdtempSync(join(tmpdir(), "axiom-arev-stub-"));
    const previousPath = process.env.PATH ?? "";
    try {
        cpSync(join(REPO_ROOT, "pmo-config"), join(isolatedFramework, "pmo-config"), { recursive: true });
        const workflowRelPath = ".github/workflows/adversarial-review.yml";
        const workflowContent = "name: adversarial-review\non: [pull_request]\n";
        const workflowFullPath = join(dir, workflowRelPath);
        writeExecFile(dir, workflowRelPath, workflowContent);
        git(dir, "add", "-A");
        git(dir, "commit", "-q", "-m", "add pinned review workflow");
        git(dir, "remote", "add", "origin", "https://github.com/fake-owner/fake-repo.git");
        exportContract(dir);
        const id = baseResult(dir);
        const realWorkflowDigest = sha256(readFileSync(workflowFullPath));
        const isolatedPolicyPath = join(isolatedFramework, "pmo-config/adversarial-review-policy.json");
        const isolatedPolicy = JSON.parse(readFileSync(isolatedPolicyPath, "utf8"));
        const binding = isolatedPolicy["externally_observed_binding"] ?? {};
        binding["pinned_workflow_path"] = workflowRelPath;
        binding["pinned_workflow_digest"] = realWorkflowDigest;
        writeFileSync(isolatedPolicyPath, JSON.stringify(isolatedPolicy, null, 2));
        // Each scenario regenerates the stub AFTER writing the review file, so
        // the digest the stub echoes is always the real digest of the bytes on
        // disk at that moment.
        const stubGhPath = join(stubBinDir, "gh");
        function writeStubGh(checkSuiteId, workflowPathForSuite, digest) {
            if (process.platform === "win32") {
                rmSync(stubGhPath, { force: true });
                writeExecFile(stubBinDir, "gh-logic.mjs", `
import { readFileSync } from "node:fs";
const path = process.argv[2] ?? "";
const head = ${JSON.stringify(id.head)};
const digest = ${JSON.stringify(digest)};
const suiteId = ${JSON.stringify(checkSuiteId)};
const workflowPath = ${JSON.stringify(workflowPathForSuite)};
if (path.includes("check-runs")) {
  process.stdout.write(JSON.stringify({ head_sha: head, status: "completed", conclusion: "success", output: { summary: digest, text: "" }, check_suite: { id: Number(suiteId) } }));
} else if (path.includes("check_suite_id=" + suiteId)) {
  process.stdout.write(JSON.stringify({ workflow_runs: [{ path: workflowPath }] }));
} else {
  process.stdout.write("{}");
}
`);
                writeExecFile(stubBinDir, "gh.cmd", `@echo off\r\nnode "%~dp0gh-logic.mjs" %*\r\n`);
            }
            else {
                rmSync(join(stubBinDir, "gh.cmd"), { force: true });
                const stub = `#!/usr/bin/env bash
set -e
path="$2"
case "$path" in
  repos/*/check-runs/*)
    echo '{"head_sha":"${id.head}","status":"completed","conclusion":"success","output":{"summary":"${digest}","text":""},"check_suite":{"id":${checkSuiteId}}}'
    ;;
  repos/*/actions/runs?check_suite_id=${checkSuiteId})
    echo '{"workflow_runs":[{"path":"${workflowPathForSuite}"}]}'
    ;;
  *)
    echo '{}'
    ;;
esac
`;
                writeFileSync(stubGhPath, stub);
                spawnSync("chmod", ["+x", stubGhPath]);
            }
        }
        function verifyWithStub() {
            const resultPath = join(dir, ".execution/D-001/EXECUTION-RESULT.json");
            const r = runVerifyExecutionResult(isolatedFramework, dir, resultPath, null, null, false);
            return r.envelope;
        }
        // Attack: check run belongs to a check suite whose workflow run path is
        // UNRELATED to the pinned one.
        newReview(dir, id, { provenance: { tier: "externally-observed", check_run_id: "456" } });
        const attackDigest = sha256(readFileSync(join(dir, ".execution/D-001/EXECUTION-REVIEW.json")));
        writeStubGh("888", ".github/workflows/unrelated.yml", attackDigest);
        process.env.PATH = stubBinDir + (process.platform === "win32" ? ";" : ":") + previousPath;
        const attackEnv = verifyWithStub();
        assert.ok(ruleIds(attackEnv).includes("AREV-003"), "unrelated successful check run on the same commit: AREV-003 still raised (workflow attribution missing)");
        // Legitimate: check run belongs to a check suite whose workflow run path
        // IS the pinned one.
        newReview(dir, id, { provenance: { tier: "externally-observed", check_run_id: "123" } });
        const legitDigest = sha256(readFileSync(join(dir, ".execution/D-001/EXECUTION-REVIEW.json")));
        writeStubGh("999", workflowRelPath, legitDigest);
        const legitEnv = verifyWithStub();
        assert.ok(!ruleIds(legitEnv).includes("AREV-003"), "check run genuinely attributed to the pinned workflow: AREV-003 not raised");
        // Compatibility: a legitimate GitHub API response can carry a trailing
        // @ref on the workflow run's path -- must still match once normalized.
        newReview(dir, id, { provenance: { tier: "externally-observed", check_run_id: "123" } });
        const refSuffixDigest = sha256(readFileSync(join(dir, ".execution/D-001/EXECUTION-REVIEW.json")));
        writeStubGh("999", `${workflowRelPath}@main`, refSuffixDigest);
        const refSuffixEnv = verifyWithStub();
        assert.ok(!ruleIds(refSuffixEnv).includes("AREV-003"), "workflow run path with a trailing @ref still matches the pinned path: AREV-003 not raised");
    }
    finally {
        process.env.PATH = previousPath;
        removeFixture(dir);
        rmSync(isolatedFramework, { recursive: true, force: true });
        rmSync(stubBinDir, { recursive: true, force: true });
    }
});
