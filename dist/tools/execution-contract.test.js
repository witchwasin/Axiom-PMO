// Ported from tests/helpers/execution-contract-tests.ps1 (M5 execution-contract
// verification), adapted for the Node port.
//
// Behaviour tests for the execution-contract feature, exercised END TO END
// through the real entry points -- exportExecutionContract,
// runExecutionCommand and runVerifyExecutionResult -- never by touching the
// internal rules directly. The PS originals spawn scripts/export-...ps1,
// scripts/run-execution-command.ps1 and scripts/verify-execution-result.ps1 as
// subprocesses; the port calls their Node equivalents in-process (the same
// calls stateful-probe.ts and clean-room.test.ts already drive), per the
// established pattern.
//
// Same fixture strategy as the PS original, for the same reason: this
// feature's entire job is comparing an agent's claims against real git
// history, so each case builds a small disposable repository with real
// commits rather than mocking the git layer.
//
// The cases are written adversarially on purpose. A verifier that only
// handles well-behaved input verifies nothing -- the interesting cases are
// the ones where the result is wrong, self-serving, or actively lying,
// because that is the threat model this milestone exists for
// (docs/architecture/execution-contract-verification.md section 3).
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync, readdirSync, existsSync, } from "node:fs";
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
// fixture helpers (port of the PS file's fixture section)
// ---------------------------------------------------------------------------
function sha256(data) {
    return createHash("sha256").update(data).digest("hex").toLowerCase();
}
// Invoke-FixtureGit equivalent: fire and forget, stderr never contaminates.
function git(dir, ...args) {
    spawnSync("git", ["-C", dir, ...args], { encoding: "utf8" });
}
// Get-FixtureGit equivalent: first line of stdout, trimmed, "" when nothing.
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
function newExecFixture() {
    const dir = mkdtempSync(join(tmpdir(), "axiom-exec-"));
    mkdirSync(join(dir, "src/payments"), { recursive: true });
    writeExecFile(dir, "PROJECT.md", "# P99-EXEC\n");
    writeExecFile(dir, "SCOPE.json", '{"schema_version":"1.0","project":"P99-EXEC","implementation_scope":{"include":["src/payments/**","tests/payments/**"],"exclude":["src/payments/generated/**"]}}');
    writeExecFile(dir, "DELIVERY.md", [
        "# DELIVERY - P99-EXEC", "",
        "## Work Items", "",
        "| ID | Mode | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Status |",
        "|---|---|---|---|---|---|---|---|---|",
        "| D-001 | Standard | Checkout flow | REQ-001, REQ-002 | DESIGN/FLOW.puml | Card payment succeeds | unit tests | Dev | To Do |",
    ].join("\n"));
    writeExecFile(dir, "src/payments/app.ts", "seed");
    // Committed in the base commit, deliberately: artifact-observed evidence no
    // longer satisfies a required test on its own, and the decision-log.md the
    // fixture carries is the vouch's anchor -- it lives in the *base* commit so
    // it is never inside the range under verification.
    writeExecFile(dir, "decision-log.md", [
        "# Decision Log - P99-EXEC", "",
        "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
        "|---|---|---|---|---|---|---|---|",
        "| 2026-07-30 | DEC-100 | Accept local test artifacts for D-001 | accept / require CI | accept | reviewed the artifacts by hand | none | test evidence accepted |",
    ].join("\n"));
    gitInit(dir);
    git(dir, "config", "user.email", "test@axiom-pmo.local");
    git(dir, "config", "user.name", "Axiom Exec Tests");
    git(dir, "config", "core.autocrlf", "false");
    git(dir, "config", "core.safecrlf", "false");
    git(dir, "add", "-A");
    git(dir, "commit", "-q", "-m", "base");
    return dir;
}
function removeFixture(dir) {
    rmSync(dir, { recursive: true, force: true });
}
function exportContract(dir, grant = "") {
    return exportExecutionContract(REPO_ROOT, dir, "D-001", null, null, grant, true);
}
function contractDigestOf(dir) {
    return readFileSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json.sha256"), "utf8").trim();
}
function verifyResult(dir, resultPath) {
    const rp = resultPath ?? join(dir, ".execution/D-001/EXECUTION-RESULT.json");
    const r = runVerifyExecutionResult(REPO_ROOT, dir, rp, null, null, false);
    return { env: r.envelope, exitCode: r.exitCode };
}
function ruleIds(env, level = "FAIL") {
    if (!env)
        return [];
    return env.results.filter((r) => r.level === level).map((r) => r.rule_id);
}
function row(env, ruleId, level = "FAIL") {
    return env.results.find((r) => r.level === level && r.rule_id === ruleId);
}
// Produces a REAL sealed runner-exit-record by actually invoking the runner
// (runExecutionCommand) -- not a hand-typed claim shape. The "clean" cases
// then exercise containment, digest recomputation, work-item/contract binding
// and exit code for real.
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
// Writes decision-log.md with a DEC-100 row that names $Digest through a
// structured axiom-authority: binding token. Uncommitted on purpose -- the row
// must sit outside the verified commit range.
function setDecisionLogWithDigest(dir, digest, opts = {}) {
    const decisionId = opts.decisionId ?? "DEC-100";
    const testName = opts.testName ?? "unit tests";
    const workItem = opts.workItem ?? "D-001";
    const contractDigest = opts.contractDigest ?? contractDigestOf(dir);
    const claimType = opts.claimType ?? "test-evidence-accepted";
    const token = `axiom-authority: type=${claimType}; work_item=${workItem}; contract=${contractDigest}; test=${testName}; evidence=${digest}`;
    writeExecFile(dir, "decision-log.md", [
        "# Decision Log - P99-EXEC", "",
        "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
        "|---|---|---|---|---|---|---|---|",
        `| 2026-07-31 | ${decisionId} | Accept ${testName} evidence for ${workItem} | accept / require CI | accept | reviewed the artifact by hand. ${token} | none | test evidence accepted |`,
    ].join("\n"));
}
function baseResultFields(dir) {
    return {
        digest: contractDigestOf(dir),
        contract: JSON.parse(readFileSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json"), "utf8")),
        head: gitOut(dir, "rev-parse", "HEAD"),
    };
}
function writeResultDoc(dir, doc) {
    const path = join(dir, ".execution/D-001/EXECUTION-RESULT.json");
    writeFileSync(path, JSON.stringify(doc));
    return path;
}
// The default result: a real sealed runner record vouched by a fully bound
// human decision (token names the test and the exact artifact digest). Cases
// asserting the tier and binding rules override fields away.
function newResult(dir, overrides = {}) {
    const digest = contractDigestOf(dir);
    const contract = JSON.parse(readFileSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json"), "utf8"));
    const head = gitOut(dir, "rev-parse", "HEAD");
    const relRunRecordPath = realRunRecord(dir);
    const recordDigest = sha256(readFileSync(join(dir, relRunRecordPath)));
    setDecisionLogWithDigest(dir, recordDigest);
    const doc = {
        contract_version: "1.0",
        work_item_id: "D-001",
        contract_sha256: digest,
        base_sha: String(contract.base_sha),
        head_sha: head,
        execution_status: "completed",
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
    return writeResultDoc(dir, doc);
}
// The digest of the run record the default result vouches for.
function vouchedRecordDigest(dir) {
    const doc = JSON.parse(readFileSync(join(dir, ".execution/D-001/EXECUTION-RESULT.json"), "utf8"));
    return sha256(readFileSync(join(dir, doc.test_evidence[0].run_record_path)));
}
function appendClaim(dir, claim) {
    const resultPath = join(dir, ".execution/D-001/EXECUTION-RESULT.json");
    const doc = JSON.parse(readFileSync(resultPath, "utf8"));
    doc.authority_claims = [...(doc.authority_claims ?? []), claim];
    writeFileSync(resultPath, JSON.stringify(doc));
}
function appendLogRow(dir, rowText) {
    const existing = readFileSync(join(dir, "decision-log.md"), "utf8");
    writeFileSync(join(dir, "decision-log.md"), existing.trimEnd() + "\n" + rowText);
}
// ---------------------------------------------------------------------------
// Case 1: export produces a contract, a digest, and derives scope
// ---------------------------------------------------------------------------
test("export: contract, digest, and scope derivation", () => {
    const dir = newExecFixture();
    try {
        const r = exportContract(dir);
        assert.equal(r.exitCode, 0, `export: exits 0 -- ${r.output}`);
        const contractPath = join(dir, ".execution/D-001/EXECUTION-CONTRACT.json");
        assert.ok(existsSync(contractPath), "export: contract file written");
        assert.ok(existsSync(contractPath + ".sha256"), "export: digest sidecar written");
        const contract = JSON.parse(readFileSync(contractPath, "utf8"));
        const allowed = contract["allowed_paths"] ?? [];
        const prohibited = contract["prohibited_paths"] ?? [];
        assert.ok(allowed.includes("src/payments/**") && allowed.includes("tests/payments/**"), "export: allowed_paths derived from SCOPE.json include");
        assert.ok(prohibited.includes("src/payments/generated/**"), "export: prohibited_paths derived from SCOPE.json exclude");
        assert.ok(/^[0-9a-f]{40}$/.test(String(contract["base_sha"])), "export: base_sha is a resolved commit, not a branch name");
        const ga = contract["git_authority"] ?? {};
        assert.ok(ga["commit"] === false && ga["push"] === false && ga["merge"] === false && ga["deploy"] === false, "export: git authority denies commit/push/merge/deploy by default");
        const reqs = contract["requirement_refs"] ?? [];
        assert.ok(reqs.includes("REQ-001") && reqs.includes("REQ-002"), "export: requirement refs carried from the work item");
        const sidecar = contractDigestOf(dir);
        assert.equal(sidecar, sha256(readFileSync(contractPath)), "export: sidecar digest matches the contract file's real hash");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 2: export refuses without an approved SCOPE.json
// ---------------------------------------------------------------------------
test("export: fails closed without an approved SCOPE.json", () => {
    const dir = newExecFixture();
    try {
        rmSync(join(dir, "SCOPE.json"), { force: true });
        const r = exportContract(dir);
        assert.notEqual(r.exitCode, 0, "export: fails closed when the project has no approved scope");
        assert.ok(r.output.includes("SCOPE.json"), "export: says why (allowed_paths come from approved scope)");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 3: -Grant is the only way to widen authority
// ---------------------------------------------------------------------------
test("grant: -Grant is the only way to widen authority", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit,push");
        const contract = JSON.parse(readFileSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json"), "utf8"));
        const ga = contract["git_authority"] ?? {};
        assert.ok(ga["commit"] === true && ga["push"] === true, "grant: named actions granted");
        assert.ok(ga["merge"] === false && ga["deploy"] === false, "grant: unnamed actions stay denied");
        const r = exportContract(dir, "sudo");
        assert.notEqual(r.exitCode, 0, "grant: an unknown action is rejected, not silently ignored");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 4: clean run verifies (the no-false-positive proof)
// ---------------------------------------------------------------------------
test("clean: verdict pass, no FAIL rows", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        writeExecFile(dir, "src/payments/app.ts", "implemented");
        writeExecFile(dir, "tests/payments/app.test.ts", "tested");
        git(dir, "add", "-A");
        git(dir, "commit", "-q", "-m", "impl");
        newResult(dir, { changed_files: ["src/payments/app.ts", "tests/payments/app.test.ts"], git_actions_performed: ["commit"] });
        const { env, exitCode } = verifyResult(dir);
        assert.equal(env.execution_verification.verdict, "pass", `clean: verdict pass -- verdict=${env.execution_verification.verdict} fails=${ruleIds(env).join(",")}`);
        assert.equal(exitCode, 0, "clean: exit code 0");
        assert.equal(ruleIds(env).length, 0, "clean: no FAIL rows at all");
        const observed = env.execution_verification.changed_files_observed ?? [];
        assert.ok(!observed.some((p) => /^\.execution\//.test(p)), "clean: the contract's own bookkeeping files are not counted as implementation");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 5: change outside approved scope -> EXEC-004
// ---------------------------------------------------------------------------
test("out-of-scope: EXEC-004 with the offending path named", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        writeExecFile(dir, "src/payments/app.ts", "implemented");
        writeExecFile(dir, "src/auth/tokens.ts", "wandered off");
        git(dir, "add", "-A");
        git(dir, "commit", "-q", "-m", "impl");
        newResult(dir, { changed_files: ["src/payments/app.ts", "src/auth/tokens.ts"], git_actions_performed: ["commit"] });
        const { env, exitCode } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-004"), "out-of-scope: EXEC-004 raised");
        assert.ok((env.execution_verification.changed_files_out_of_scope ?? []).includes("src/auth/tokens.ts"), "out-of-scope: the offending path is named");
        assert.notEqual(exitCode, 0, "out-of-scope: exit code is non-zero");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 6: change matching prohibited_paths -> EXEC-004
// ---------------------------------------------------------------------------
test("prohibited: EXEC-004 even inside the include tree", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        writeExecFile(dir, "src/payments/generated/client.ts", "touched a carve-out");
        git(dir, "add", "-A");
        git(dir, "commit", "-q", "-m", "impl");
        newResult(dir, { changed_files: ["src/payments/generated/client.ts"], git_actions_performed: ["commit"] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-004"), "prohibited: EXEC-004 raised even though the path is inside the include tree");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 7: scope matching is case-sensitive
// ---------------------------------------------------------------------------
test("case-sensitivity: wrong-case path does not satisfy allowed_paths", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        // Injected through the index rather than the working tree: on a
        // case-insensitive filesystem writing SRC/PAYMENTS/ would silently land in
        // the existing src/payments/ and hide the very bug this asserts against.
        git(dir, "add", "-A");
        const blob = spawnSync("git", ["-C", dir, "hash-object", "-w", "--stdin"], { input: "case", encoding: "utf8" }).stdout.trim();
        git(dir, "update-index", "--add", "--cacheinfo", `100644,${blob},SRC/PAYMENTS/sneaky.ts`);
        git(dir, "commit", "-q", "-m", "impl");
        newResult(dir, { changed_files: ["SRC/PAYMENTS/sneaky.ts"], git_actions_performed: ["commit"] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-004"), "case-sensitivity: a wrong-case path does not satisfy allowed_paths");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 8: contract edited after export -> EXEC-002
// ---------------------------------------------------------------------------
test("tampered contract: EXEC-002, verdict contract_tampered", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        // Edited through the parsed object, not by string-replacing JSON text.
        const contractPath = join(dir, ".execution/D-001/EXECUTION-CONTRACT.json");
        const doc = JSON.parse(readFileSync(contractPath, "utf8"));
        doc["git_authority"]["push"] = true;
        writeFileSync(contractPath, JSON.stringify(doc));
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-002"), "tampered contract: EXEC-002 raised");
        assert.equal(env.execution_verification.verdict, "contract_tampered", `tampered contract: verdict names tampering -- verdict=${env.execution_verification.verdict}`);
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 9: result answers a different contract version -> EXEC-002
// ---------------------------------------------------------------------------
test("digest mismatch: EXEC-002, verdict contract_mismatch", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { contract_sha256: "0".repeat(64) });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-002"), "digest mismatch: EXEC-002 raised");
        assert.equal(env.execution_verification.verdict, "contract_mismatch", "digest mismatch: verdict is contract_mismatch");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 10: requirement the contract does not cover -> EXEC-003
// ---------------------------------------------------------------------------
test("requirement drift: EXEC-003 for the uncovered requirement", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { requirement_refs: ["REQ-001", "REQ-999"] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-003"), "requirement drift: EXEC-003 raised for the uncovered requirement");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 11: fewer requirements than approved is legitimate
// ---------------------------------------------------------------------------
test("partial work: satisfying fewer requirements is not a violation", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { requirement_refs: ["REQ-001"], execution_status: "partial" });
        const { env } = verifyResult(dir);
        assert.ok(!ruleIds(env).includes("EXEC-003"), "partial work: satisfying fewer requirements is not a violation");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 12: committed without commit authority -> EXEC-006
// ---------------------------------------------------------------------------
test("ungranted commit: EXEC-006 from observed history, authority_violations", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir); // no -Grant: commit stays denied
        writeExecFile(dir, "src/payments/app.ts", "implemented");
        git(dir, "add", "-A");
        git(dir, "commit", "-q", "-m", "impl");
        newResult(dir, { changed_files: ["src/payments/app.ts"] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-006"), "ungranted commit: EXEC-006 raised from observed history, not from the result's own admission");
        assert.ok((env.execution_verification.authority_violations ?? []).includes("commit"), "ungranted commit: recorded in the structured verdict");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 13: result admits an action the contract withheld -> EXEC-006
// ---------------------------------------------------------------------------
test("self-reported ungranted action: EXEC-006 names deploy", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { git_actions_performed: ["commit", "deploy"] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-006"), "self-reported ungranted action: EXEC-006 raised");
        assert.ok((env.execution_verification.authority_violations ?? []).includes("deploy"), "self-reported ungranted action: deploy named in the verdict");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 14: agent approving its own work -> EXEC-007
// ---------------------------------------------------------------------------
test("self-approval: EXEC-007, exit non-zero", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { authority_claims: [{ type: "release-approval", actor: "agent", claim: "approved" }] });
        const { env, exitCode } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-007"), "self-approval: EXEC-007 raised");
        assert.notEqual(exitCode, 0, "self-approval: exit code is non-zero");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 15: human approval claim with no decision record -> EXEC-007
// ---------------------------------------------------------------------------
test("unanchored human claim: EXEC-007 (actor 'human' is not self-proving)", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { authority_claims: [{ type: "release-approval", actor: "human", claim: "approved" }] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-007"), "unanchored human claim: EXEC-007 raised");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 16: agent may report implementation-complete
// ---------------------------------------------------------------------------
test("permitted claim: implementation-complete from an agent is allowed", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { authority_claims: [{ type: "implementation-complete", actor: "agent", claim: "done" }] });
        const { env } = verifyResult(dir);
        assert.ok(!ruleIds(env).includes("EXEC-007"), "permitted claim: implementation-complete from an agent is allowed");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 17: unknown actor type -> EXEC-007
// ---------------------------------------------------------------------------
test("unknown actor: EXEC-007 rather than defaulting to permitted", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { authority_claims: [{ type: "release-approval", actor: "ci-robot", claim: "approved" }] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-007"), "unknown actor: EXEC-007 raised rather than defaulting to permitted");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 18: required test backed only by an agent assertion -> EXEC-005
// ---------------------------------------------------------------------------
test("agent-asserted test: EXEC-005 names the test in the verdict", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { test_evidence: [{ type: "agent-assertion", name: "unit tests", result: "passed" }] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "agent-asserted test: EXEC-005 raised");
        assert.ok((env.execution_verification.unverified_required_tests ?? []).includes("unit tests"), "agent-asserted test: named in the structured verdict");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 19: verifiable adapter missing its evidence fields -> EXEC-005
// ---------------------------------------------------------------------------
test("hollow evidence: EXEC-005 for an adapter with no evidence fields", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { test_evidence: [{ type: "ci-check", name: "unit tests" }] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "hollow evidence: EXEC-005 raised for an adapter with no evidence fields");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 20: required test with no evidence entry at all -> EXEC-005
// ---------------------------------------------------------------------------
test("missing evidence: EXEC-005", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { test_evidence: [] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "missing evidence: EXEC-005 raised");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 21: undeclared changed file -> EXEC-008
// ---------------------------------------------------------------------------
test("undeclared change: EXEC-008, and in-scope path alone does not excuse it", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        writeExecFile(dir, "src/payments/app.ts", "implemented");
        writeExecFile(dir, "src/payments/quiet.ts", "changed but not declared");
        git(dir, "add", "-A");
        git(dir, "commit", "-q", "-m", "impl");
        newResult(dir, { changed_files: ["src/payments/app.ts"], git_actions_performed: ["commit"] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-008"), "undeclared change: EXEC-008 raised");
        assert.ok(!ruleIds(env).includes("EXEC-004"), "undeclared change: in-scope path alone does not excuse the omission");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 22: head does not descend from the approved base -> EXEC-008
// ---------------------------------------------------------------------------
test("no ancestry: EXEC-008 for an orphan-branch head", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        const contract = JSON.parse(readFileSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json"), "utf8"));
        // An orphan branch: real commits, real SHAs, no ancestry to the approved base.
        git(dir, "checkout", "-q", "--orphan", "elsewhere");
        writeExecFile(dir, "src/payments/app.ts", "built somewhere else entirely");
        git(dir, "add", "-A");
        git(dir, "commit", "-q", "-m", "orphan");
        const orphanHead = gitOut(dir, "rev-parse", "HEAD");
        const doc = {
            contract_version: "1.0",
            work_item_id: "D-001",
            contract_sha256: contractDigestOf(dir),
            base_sha: String(contract["base_sha"]),
            head_sha: orphanHead,
            execution_status: "completed",
            changed_files: ["src/payments/app.ts"],
            git_actions_performed: ["commit"],
            test_evidence: [{ type: "runner-exit-record", name: "unit tests", command: "npm test", exit_code: 0, recorded_by: "axiom-runner" }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-008"), "no ancestry: EXEC-008 raised");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 23: unresolvable head commit -> EXEC-008 infrastructure failure
// ---------------------------------------------------------------------------
test("unresolvable head: EXEC-008, verdict git_error", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { head_sha: "0".repeat(40) });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-008"), "unresolvable head: EXEC-008 raised");
        assert.equal(env.execution_verification.verdict, "git_error", "unresolvable head: reported as git_error, not as a clean pass");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 24: missing contract -> EXEC-002, never a silent pass
// ---------------------------------------------------------------------------
test("missing contract: EXEC-002, exit code 1", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        rmSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json"), { force: true });
        rmSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json.sha256"), { force: true });
        const { env, exitCode } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-002"), "missing contract: EXEC-002 raised");
        assert.equal(exitCode, 1, "missing contract: exit code 1, not a pass");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 25: malformed result -> EXEC-001
// ---------------------------------------------------------------------------
test("malformed result: EXEC-001, verdict result_invalid", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        writeExecFile(dir, ".execution/D-001/EXECUTION-RESULT.json", "{ not json at all");
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-001"), "malformed result: EXEC-001 raised");
        assert.equal(env.execution_verification.verdict, "result_invalid", "malformed result: verdict is result_invalid");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 26: result missing a required field -> EXEC-001
// ---------------------------------------------------------------------------
test("incomplete result: EXEC-001", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        writeExecFile(dir, ".execution/D-001/EXECUTION-RESULT.json", '{"contract_version":"1.0","work_item_id":"D-001"}');
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-001"), "incomplete result: EXEC-001 raised");
    }
    finally {
        removeFixture(dir);
    }
});
// ---------------------------------------------------------------------------
// Case 27: diagnostics follow the shared contract
// ---------------------------------------------------------------------------
test("diagnostics: shared schema envelope, row fields, summary agreement", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { authority_claims: [{ type: "release-approval", actor: "agent", claim: "approved" }] });
        const { env } = verifyResult(dir);
        const exec007 = row(env, "EXEC-007");
        assert.equal(env.schema_version, "1.1", "diagnostics: envelope carries the shared schema version");
        assert.ok(exec007 !== undefined
            && exec007.artifact !== undefined && exec007.item_id !== undefined
            && exec007.field !== undefined && exec007.suggestion !== undefined
            && exec007.documentation_url !== undefined, "diagnostics: every declared row field is present");
        assert.ok(exec007 !== undefined && typeof exec007.suggestion === "string" && exec007.suggestion.trim() !== "", "diagnostics: FAIL rows carry a suggestion");
        assert.ok(exec007 !== undefined && typeof exec007.documentation_url === "string" && exec007.documentation_url.trim() !== "", "diagnostics: FAIL rows carry a documentation url");
        assert.equal(env.summary.fail, env.results.filter((r) => r.level === "FAIL").length, "diagnostics: summary counters agree with the results array");
    }
    finally {
        removeFixture(dir);
    }
});
// ===========================================================================
// Independent AI Reviewer's 2026-07-30 code review: the tests above proved
// the SHAPE of verification worked without proving the checks were real.
// These cases are the direct response -- 1 FATAL and 2 MAJOR findings, each
// reproduced first, then confirmed fixed.
// ===========================================================================
// ---- FATAL fix: junit-artifact must be real, not just present-fielded ------
test("junit fabricated hash: EXEC-005, reason names the mismatch", () => {
    const dir = newExecFixture();
    try {
        writeExecFile(dir, "reports/junit.xml", '<testsuite name="s" tests="1" failures="0" errors="0"><testcase name="a"/></testsuite>');
        git(dir, "add", "-A");
        git(dir, "commit", "-q", "-m", "junit");
        exportContract(dir, "commit");
        const f = baseResultFields(dir);
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
            changed_files: [],
            test_evidence: [{ type: "junit-artifact", name: "unit tests", path: "reports/junit.xml", sha256: "0".repeat(64) }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "junit fabricated hash: EXEC-005 raised");
        assert.match(row(env, "EXEC-005").message, /does not match the claimed/, "junit fabricated hash: reason names the real vs. claimed mismatch");
    }
    finally {
        removeFixture(dir);
    }
});
test("junit missing file: EXEC-005", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        const f = baseResultFields(dir);
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
            changed_files: [],
            test_evidence: [{ type: "junit-artifact", name: "unit tests", path: "reports/does-not-exist.xml", sha256: "a".repeat(64) }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "junit missing file: EXEC-005 raised");
    }
    finally {
        removeFixture(dir);
    }
});
test("junit path traversal: EXEC-005, containment breach named", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        const f = baseResultFields(dir);
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
            changed_files: [],
            test_evidence: [{ type: "junit-artifact", name: "unit tests", path: "../../../../etc/passwd", sha256: "a".repeat(64) }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "junit path traversal: EXEC-005 raised");
        assert.match(row(env, "EXEC-005").message, /containment breach/, "junit path traversal: reported as a containment breach, not silently resolved");
    }
    finally {
        removeFixture(dir);
    }
});
test("junit real failures: EXEC-005 even with a correct hash", () => {
    const dir = newExecFixture();
    try {
        writeExecFile(dir, "reports/junit.xml", '<testsuite name="s" tests="2" failures="1" errors="0"><testcase name="a"/><testcase name="b"><failure/></testcase></testsuite>');
        git(dir, "add", "-A");
        git(dir, "commit", "-q", "-m", "junit");
        exportContract(dir, "commit");
        const f = baseResultFields(dir);
        const realHash = sha256(readFileSync(join(dir, "reports/junit.xml")));
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
            changed_files: [],
            test_evidence: [{ type: "junit-artifact", name: "unit tests", path: "reports/junit.xml", sha256: realHash }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "junit real failures: EXEC-005 raised even with a correct hash");
    }
    finally {
        removeFixture(dir);
    }
});
test("junit real pass, human-vouched: verdict pass", () => {
    const dir = newExecFixture();
    try {
        writeExecFile(dir, "reports/junit.xml", '<testsuite name="s" tests="3" failures="0" errors="0"><testcase name="a"/><testcase name="b"/><testcase name="c"/></testsuite>');
        git(dir, "add", "-A");
        git(dir, "commit", "-q", "-m", "junit");
        exportContract(dir, "commit");
        const f = baseResultFields(dir);
        const realHash = sha256(readFileSync(join(dir, "reports/junit.xml")));
        setDecisionLogWithDigest(dir, realHash);
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
            changed_files: [],
            test_evidence: [{ type: "junit-artifact", name: "unit tests", path: "reports/junit.xml", sha256: realHash }],
            authority_claims: [{
                    type: "test-evidence-accepted", actor: "human", claim: "accepted",
                    decision_ref: "DEC-100", test_name: "unit tests", evidence_sha256: realHash,
                }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.equal(env.execution_verification.verdict, "pass", `junit real pass, human-vouched: verdict pass -- fails=${ruleIds(env).join(",")}`);
    }
    finally {
        removeFixture(dir);
    }
});
// ---- M4 (L2 completion): junit evidence must be reconcilable with the diff --
test("M4 stale junit: EXEC-005, reason names the git-ground-truth defect", () => {
    const dir = newExecFixture();
    try {
        writeExecFile(dir, "reports/junit.xml", '<testsuite name="s" tests="1" failures="0" errors="0"><testcase name="a"/></testsuite>');
        git(dir, "add", "-A");
        git(dir, "commit", "-q", "-m", "junit");
        exportContract(dir, "commit");
        const f = baseResultFields(dir);
        const realHash = sha256(readFileSync(join(dir, "reports/junit.xml")));
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
            changed_files: [],
            test_evidence: [{ type: "junit-artifact", name: "unit tests", path: "reports/junit.xml", sha256: realHash }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "M4 stale junit: EXEC-005 raised");
        assert.match(row(env, "EXEC-005").message, /was not changed within the verified commit range/, "M4 stale junit: reason names the git-ground-truth defect");
    }
    finally {
        removeFixture(dir);
    }
});
test("M4 fresh junit, no vouch: EXEC-005 on provenance, not staleness", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        const f = baseResultFields(dir);
        writeExecFile(dir, "tests/payments/junit.xml", '<testsuite name="s" tests="1" failures="0" errors="0"><testcase name="a"/></testsuite>');
        git(dir, "add", "-A");
        git(dir, "commit", "-q", "-m", "run output");
        const realHash = sha256(readFileSync(join(dir, "tests/payments/junit.xml")));
        const head = gitOut(dir, "rev-parse", "HEAD");
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: head, execution_status: "completed",
            changed_files: ["tests/payments/junit.xml"],
            test_evidence: [{ type: "junit-artifact", name: "unit tests", path: "tests/payments/junit.xml", sha256: realHash }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "M4 fresh junit, no vouch: EXEC-005 raised (provenance, not stale)");
        assert.ok(!/was not changed within the verified commit range/.test(row(env, "EXEC-005").message), "M4 fresh junit, no vouch: reason does NOT claim staleness");
    }
    finally {
        removeFixture(dir);
    }
});
// ---- FATAL fix: runner-exit-record must be a real sealed record -----------
test("hand-typed run record with no sidecar: EXEC-005 (unsealed)", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        const f = baseResultFields(dir);
        const fakeRecordDir = join(dir, ".execution/D-001/runs");
        mkdirSync(fakeRecordDir, { recursive: true });
        writeFileSync(join(fakeRecordDir, "fake.json"), JSON.stringify({
            run_id: "fake", work_item_id: "D-001", contract_sha256: f.digest,
            command: "npm test", cwd: ".", exit_code: 0,
            started_at: "x", ended_at: "x", stdout_sha256: "x", sealed_by: "axiom-runner",
        }));
        // Deliberately no fake.json.sha256 sidecar -- exactly the "agent
        // hand-types a plausible JSON object" attack.
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
            changed_files: [],
            test_evidence: [{ type: "runner-exit-record", name: "unit tests", run_record_path: ".execution/D-001/runs/fake.json" }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "hand-typed run record: EXEC-005 raised (no sidecar = unsealed)");
    }
    finally {
        removeFixture(dir);
    }
});
test("forged record + genuinely matching sidecar: EXEC-005, verdict not pass", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        const f = baseResultFields(dir);
        const runsDir = join(dir, ".execution/D-001/runs");
        mkdirSync(runsDir, { recursive: true });
        const forgedPath = join(runsDir, "forged.json");
        const forged = {
            run_id: "forged-by-hand",
            work_item_id: "D-001",
            contract_sha256: f.digest,
            command: "npm test",
            cwd: ".",
            exit_code: 0,
            started_at: "2026-01-01T00:00:00.0000000+00:00",
            ended_at: "2026-01-01T00:00:01.0000000+00:00",
            stdout_sha256: "0".repeat(64),
            sealed_by: "axiom-runner",
        };
        writeFileSync(forgedPath, JSON.stringify(forged));
        // The "seal" an attacker can trivially produce for themselves.
        const forgedDigest = sha256(readFileSync(forgedPath));
        writeFileSync(forgedPath + ".sha256", forgedDigest + "\n");
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
            changed_files: [],
            test_evidence: [{ type: "runner-exit-record", name: "unit tests", run_record_path: ".execution/D-001/runs/forged.json" }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), `forged record + valid sidecar, runner never invoked: EXEC-005 raised -- verdict=${env.execution_verification.verdict}`);
        assert.notEqual(env.execution_verification.verdict, "pass", "forged record + valid sidecar: verdict is not pass");
        assert.match(row(env, "EXEC-005").message, /who produced|provenance|independently/, "forged record: the reason names provenance, not integrity");
    }
    finally {
        removeFixture(dir);
    }
});
test("genuine runner record without a vouch: EXEC-005 on provenance", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { authority_claims: [] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), `genuine runner record without a vouch: EXEC-005 raised -- verdict=${env.execution_verification.verdict}`);
        assert.match(row(env, "EXEC-005").message, /artifact-observed/, "genuine runner record without a vouch: reason names artifact-observed");
    }
    finally {
        removeFixture(dir);
    }
});
test("vouch citing an unresolvable decision: EXEC-005 + EXEC-007", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { authority_claims: [{ type: "test-evidence-accepted", actor: "human", claim: "accepted", decision_ref: "DEC-404" }] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "vouch citing an unresolvable decision: does not promote the evidence");
        assert.ok(ruleIds(env).includes("EXEC-007"), "vouch citing an unresolvable decision: also raises EXEC-007");
    }
    finally {
        removeFixture(dir);
    }
});
test("agent self-vouch: EXEC-007 + EXEC-005 (evidence stays unpromoted)", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { authority_claims: [{ type: "test-evidence-accepted", actor: "agent", claim: "accepted", decision_ref: "DEC-100" }] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-007"), "agent self-vouch: EXEC-007 raised");
        assert.ok(ruleIds(env).includes("EXEC-005"), "agent self-vouch: evidence stays unpromoted, EXEC-005 raised");
    }
    finally {
        removeFixture(dir);
    }
});
test("vouch citing a real but unrelated decision: EXEC-005, verdict not pass", () => {
    const dir = newExecFixture();
    try {
        writeExecFile(dir, "reports/junit.xml", '<testsuite name="fabricated" tests="99" failures="0" errors="0"><testcase name="a"/></testsuite>');
        exportContract(dir, "commit");
        const f = baseResultFields(dir);
        const fakeHash = sha256(readFileSync(join(dir, "reports/junit.xml")));
        // A decision that resolves, is unique, predates the range -- and has
        // nothing whatever to do with test evidence.
        writeExecFile(dir, "decision-log.md", [
            "# Decision Log - P99-EXEC", "",
            "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
            "|---|---|---|---|---|---|---|---|",
            "| 2026-01-01 | DEC-100 | Pick a logging library | winston / pino | pino | faster | none | none |",
        ].join("\n"));
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
            changed_files: [],
            test_evidence: [{ type: "junit-artifact", name: "unit tests", path: "reports/junit.xml", sha256: fakeHash }],
            authority_claims: [{ type: "test-evidence-accepted", actor: "human", claim: "accepted", decision_ref: "DEC-100" }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), `vouch citing a real but unrelated decision: EXEC-005 raised -- verdict=${env.execution_verification.verdict}`);
        assert.notEqual(env.execution_verification.verdict, "pass", "unbound vouch: verdict is not pass");
    }
    finally {
        removeFixture(dir);
    }
});
test("self-consistent bindings, decision row silent on the digest: EXEC-005", () => {
    const dir = newExecFixture();
    try {
        writeExecFile(dir, "reports/junit.xml", '<testsuite name="fabricated" tests="99" failures="0" errors="0"><testcase name="a"/></testsuite>');
        exportContract(dir, "commit");
        const f = baseResultFields(dir);
        const fakeHash = sha256(readFileSync(join(dir, "reports/junit.xml")));
        writeExecFile(dir, "decision-log.md", [
            "# Decision Log - P99-EXEC", "",
            "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
            "|---|---|---|---|---|---|---|---|",
            "| 2026-01-01 | DEC-100 | Pick a logging library | winston / pino | pino | faster | none | none |",
        ].join("\n"));
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
            changed_files: [],
            test_evidence: [{ type: "junit-artifact", name: "unit tests", path: "reports/junit.xml", sha256: fakeHash }],
            authority_claims: [{
                    type: "test-evidence-accepted", actor: "human", claim: "accepted", decision_ref: "DEC-100",
                    test_name: "unit tests", evidence_sha256: fakeHash,
                    evidence_type: "junit-artifact", work_item_id: "D-001", contract_sha256: f.digest,
                }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), `self-consistent bindings, decision row silent on the digest: EXEC-005 raised -- verdict=${env.execution_verification.verdict}`);
        assert.match(row(env, "EXEC-005").message, /carries no 'axiom-authority:' binding/, "self-consistent bindings: reason is the missing binding token");
    }
    finally {
        removeFixture(dir);
    }
});
// ==========================================================================
// Round-4 findings: the vouch check searched the decision row for the digest
// as a substring. The row now has to carry a structured `axiom-authority:`
// token, parsed field by field.
// ==========================================================================
test("structured binding, every field matching: verdict pass", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        const { env } = verifyResult(dir);
        assert.equal(env.execution_verification.verdict, "pass", `structured binding, every field matching: verdict pass -- fails=${ruleIds(env).join(",")}`);
    }
    finally {
        removeFixture(dir);
    }
});
test("artifact approved for another test is not reusable: EXEC-005", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        setDecisionLogWithDigest(dir, vouchedRecordDigest(dir), { testName: "integration tests" });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), `artifact approved for another test is not reusable: EXEC-005 -- verdict=${env.execution_verification.verdict}`);
        assert.match(row(env, "EXEC-005").message, /approves evidence for test 'integration tests'/, "and the reason names the test mismatch");
    }
    finally {
        removeFixture(dir);
    }
});
test("binding scoped to another work item does not authorize: EXEC-005", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        setDecisionLogWithDigest(dir, vouchedRecordDigest(dir), { workItem: "D-999" });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), `binding scoped to another work item does not authorize: EXEC-005 -- verdict=${env.execution_verification.verdict}`);
    }
    finally {
        removeFixture(dir);
    }
});
test("binding scoped to another contract does not authorize: EXEC-005", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        setDecisionLogWithDigest(dir, vouchedRecordDigest(dir), { contractDigest: "c".repeat(64) });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), `binding scoped to another contract does not authorize: EXEC-005 -- verdict=${env.execution_verification.verdict}`);
    }
    finally {
        removeFixture(dir);
    }
});
test("a release approval is not a test-evidence acceptance: EXEC-005", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        setDecisionLogWithDigest(dir, vouchedRecordDigest(dir), { claimType: "release-approval" });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), `a release approval is not a test-evidence acceptance: EXEC-005 -- verdict=${env.execution_verification.verdict}`);
    }
    finally {
        removeFixture(dir);
    }
});
test("digest mentioned in prose is not an approval: EXEC-005", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        const recordDigest = vouchedRecordDigest(dir);
        writeExecFile(dir, "decision-log.md", [
            "# Decision Log - P99-EXEC", "",
            "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
            "|---|---|---|---|---|---|---|---|",
            `| 2026-07-31 | DEC-100 | Discuss artifact naming | keep / rename | keep | we looked at ${recordDigest} while deciding | none | none |`,
        ].join("\n"));
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), `digest mentioned in prose is not an approval: EXEC-005 -- verdict=${env.execution_verification.verdict}`);
    }
    finally {
        removeFixture(dir);
    }
});
test("release-approval citing an unrelated decision: EXEC-007", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        appendClaim(dir, { type: "release-approval", actor: "human", claim: "approved", decision_ref: "DEC-100" });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-007"), `release-approval citing an unrelated decision: EXEC-007 -- verdict=${env.execution_verification.verdict}`);
    }
    finally {
        removeFixture(dir);
    }
});
test("release-approval bound to another work item: EXEC-007", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        appendClaim(dir, { type: "release-approval", actor: "human", claim: "approved", decision_ref: "DEC-200" });
        const contractDigest = contractDigestOf(dir);
        const token = `axiom-authority: type=release-approval; work_item=D-777; contract=${contractDigest}`;
        appendLogRow(dir, `| 2026-07-31 | DEC-200 | Approve release | ship / hold | ship | ${token} | none | approved |`);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-007"), `release-approval bound to another work item: EXEC-007 -- verdict=${env.execution_verification.verdict}`);
    }
    finally {
        removeFixture(dir);
    }
});
test("correctly bound release-approval: verdict pass", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        appendClaim(dir, { type: "release-approval", actor: "human", claim: "approved", decision_ref: "DEC-200" });
        const contractDigest = contractDigestOf(dir);
        const token = `axiom-authority: type=release-approval; work_item=D-001; contract=${contractDigest}`;
        appendLogRow(dir, `| 2026-07-31 | DEC-200 | Approve release | ship / hold | ship | ${token} | none | approved |`);
        const { env } = verifyResult(dir);
        assert.equal(env.execution_verification.verdict, "pass", `correctly bound release-approval: verdict pass -- fails=${ruleIds(env).join(",")}`);
    }
    finally {
        removeFixture(dir);
    }
});
test("two bindings in one cell, both parsed: verdict pass", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        appendClaim(dir, { type: "release-approval", actor: "human", claim: "approved", decision_ref: "DEC-100" });
        // One DEC-100 row, one cell, two bindings: the test vouch New-Result needs
        // plus a release approval. Under a greedy match the second swallows the
        // first and neither claim resolves.
        const contractDigest = contractDigestOf(dir);
        const recordDigest = vouchedRecordDigest(dir);
        const tokens = `axiom-authority: type=test-evidence-accepted; work_item=D-001; contract=${contractDigest}; test=unit tests; evidence=${recordDigest} ` +
            `axiom-authority: type=release-approval; work_item=D-001; contract=${contractDigest}`;
        writeExecFile(dir, "decision-log.md", [
            "# Decision Log - P99-EXEC", "",
            "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
            "|---|---|---|---|---|---|---|---|",
            `| 2026-07-31 | DEC-100 | Accept evidence and approve release of D-001 | accept / hold | accept | reviewed both. ${tokens} | none | accepted |`,
        ].join("\n"));
        const { env } = verifyResult(dir);
        assert.equal(env.execution_verification.verdict, "pass", `two bindings in one cell: both claims authorized, verdict pass -- fails=${ruleIds(env).join(",")}`);
    }
    finally {
        removeFixture(dir);
    }
});
test("two near-miss bindings do not combine into an authorization: EXEC-005", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        const contractDigest = contractDigestOf(dir);
        const recordDigest = vouchedRecordDigest(dir);
        const tokens = `axiom-authority: type=test-evidence-accepted; work_item=D-999; contract=${contractDigest}; test=unit tests; evidence=${recordDigest} ` +
            `axiom-authority: type=test-evidence-accepted; work_item=D-001; contract=${contractDigest}; test=other tests; evidence=${recordDigest}`;
        writeExecFile(dir, "decision-log.md", [
            "# Decision Log - P99-EXEC", "",
            "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
            "|---|---|---|---|---|---|---|---|",
            `| 2026-07-31 | DEC-100 | Accept evidence | accept | accept | ${tokens} | none | accepted |`,
        ].join("\n"));
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), `two near-miss bindings do not combine into an authorization: EXEC-005 -- verdict=${env.execution_verification.verdict}`);
    }
    finally {
        removeFixture(dir);
    }
});
test("vouch bound to a different test does not promote this one: EXEC-005", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        const resultPath = join(dir, ".execution/D-001/EXECUTION-RESULT.json");
        const rd = JSON.parse(readFileSync(resultPath, "utf8"));
        rd.authority_claims[0]["test_name"] = "some other test";
        writeFileSync(resultPath, JSON.stringify(rd));
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "vouch bound to a different test does not promote this one");
    }
    finally {
        removeFixture(dir);
    }
});
test("vouch naming a different artifact digest does not promote this one: EXEC-005", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        const resultPath = join(dir, ".execution/D-001/EXECUTION-RESULT.json");
        const rd = JSON.parse(readFileSync(resultPath, "utf8"));
        rd.authority_claims[0]["evidence_sha256"] = "b".repeat(64);
        writeFileSync(resultPath, JSON.stringify(rd));
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "vouch naming a different artifact digest does not promote this one");
    }
    finally {
        removeFixture(dir);
    }
});
test("legacy unbound vouch fails closed: EXEC-005, reason names no test", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        const resultPath = join(dir, ".execution/D-001/EXECUTION-RESULT.json");
        const rd = JSON.parse(readFileSync(resultPath, "utf8"));
        rd.authority_claims = [{ type: "test-evidence-accepted", actor: "human", claim: "accepted", decision_ref: "DEC-100" }];
        writeFileSync(resultPath, JSON.stringify(rd));
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "legacy unbound vouch fails closed");
        assert.match(row(env, "EXEC-005").message, /names no test_name/, "legacy unbound vouch: reason says it names no test");
    }
    finally {
        removeFixture(dir);
    }
});
test("vouch bound to another work item does not promote this one: EXEC-005", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        const resultPath = join(dir, ".execution/D-001/EXECUTION-RESULT.json");
        const rd = JSON.parse(readFileSync(resultPath, "utf8"));
        rd.authority_claims[0]["work_item_id"] = "D-999";
        writeFileSync(resultPath, JSON.stringify(rd));
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "vouch bound to another work item does not promote this one");
    }
    finally {
        removeFixture(dir);
    }
});
// ---- sealed-record integrity ----------------------------------------------
test("tampered run record: EXEC-005, reason names the mismatch", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        const relRunRecordPath = realRunRecord(dir);
        const recordFull = join(dir, relRunRecordPath);
        const record = JSON.parse(readFileSync(recordFull, "utf8"));
        record.exit_code = 1;
        writeFileSync(recordFull, JSON.stringify(record));
        // Sidecar left untouched -- it still reflects the pre-edit bytes.
        const f = baseResultFields(dir);
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
            changed_files: [],
            test_evidence: [{ type: "runner-exit-record", name: "unit tests", run_record_path: relRunRecordPath }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "tampered run record: EXEC-005 raised (digest no longer matches)");
        assert.match(row(env, "EXEC-005").message, /modified after/, "tampered run record: reason names the mismatch");
    }
    finally {
        removeFixture(dir);
    }
});
test("run record for wrong work item: EXEC-005", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        const relRunRecordPath = realRunRecord(dir);
        const recordFull = join(dir, relRunRecordPath);
        // Re-seal with a different work_item_id, the same way the runner would
        // for other work -- proves the binding check, not just presence.
        const record = JSON.parse(readFileSync(recordFull, "utf8"));
        record.work_item_id = "D-999";
        writeFileSync(recordFull, JSON.stringify(record));
        const newDigest = sha256(readFileSync(recordFull));
        writeFileSync(recordFull + ".sha256", newDigest + "\n");
        const f = baseResultFields(dir);
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
            changed_files: [],
            test_evidence: [{ type: "runner-exit-record", name: "unit tests", run_record_path: relRunRecordPath }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "run record for wrong work item: EXEC-005 raised");
    }
    finally {
        removeFixture(dir);
    }
});
test("real failing command: EXEC-005 (sealed exit code was 1)", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        const run = runExecutionCommand(dir, "D-001", "unit tests", "exit 1");
        const recordFile = readdirSync(join(dir, ".execution/D-001/runs")).find((f) => f.endsWith(".json") && !f.endsWith(".sha256"));
        if (!recordFile)
            throw new Error(`no run record produced: ${run.output}`);
        const relRunRecordPath = `.execution/D-001/runs/${recordFile}`;
        const f = baseResultFields(dir);
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
            changed_files: [],
            test_evidence: [{ type: "runner-exit-record", name: "unit tests", run_record_path: relRunRecordPath }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), "real failing command: EXEC-005 raised (sealed exit code was 1)");
    }
    finally {
        removeFixture(dir);
    }
});
test("stderr-writing command still seals and verifies", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        // The command writes to stderr AND exits 0 -- the shape of essentially
        // every real test runner (npm, pytest, jest all emit progress/warnings on
        // stderr while passing). On Windows PowerShell 5.1 native stderr under
        // ErrorActionPreference="Stop" was a terminating error, so the runner
        // would die before sealing a record -- an ordinary passing test suite
        // reported as a crash. The Node runner captures stdout+stderr and treats
        // stderr as non-fatal, so the sealed record must still verify.
        const run = runExecutionCommand(dir, "D-001", "unit tests", "echo 'warning: noisy but fine' 1>&2; echo ok");
        const recordFile = readdirSync(join(dir, ".execution/D-001/runs")).find((f) => f.endsWith(".json") && !f.endsWith(".sha256"));
        assert.ok(recordFile !== undefined, `stderr-writing command: a sealed record was still produced -- ${run.output}`);
        if (recordFile) {
            const relRunRecordPath = `.execution/D-001/runs/${recordFile}`;
            const stderrRecordDigest = sha256(readFileSync(join(dir, relRunRecordPath)));
            setDecisionLogWithDigest(dir, stderrRecordDigest);
            const f = baseResultFields(dir);
            const doc = {
                contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
                base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
                changed_files: [],
                test_evidence: [{ type: "runner-exit-record", name: "unit tests", run_record_path: relRunRecordPath }],
                authority_claims: [{
                        type: "test-evidence-accepted", actor: "human", claim: "accepted",
                        decision_ref: "DEC-100", test_name: "unit tests", evidence_sha256: stderrRecordDigest,
                    }],
            };
            writeResultDoc(dir, doc);
            const { env } = verifyResult(dir);
            assert.equal(env.execution_verification.verdict, "pass", `stderr-writing command: verdict pass (stderr is not failure) -- verdict=${env.execution_verification.verdict} fails=${ruleIds(env).join(",")}`);
        }
    }
    finally {
        removeFixture(dir);
    }
});
// ---- FATAL fix: ci-check must query live, never trust the result's claim ---
test("ci-check no remote: EXEC-005, claimed conclusion never authoritative", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        const f = baseResultFields(dir);
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
            changed_files: [],
            test_evidence: [{ type: "ci-check", name: "unit tests", commit_sha: f.head, conclusion: "success" }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        const hasExec005 = ruleIds(env).includes("EXEC-005");
        assert.ok(hasExec005, "ci-check no remote: EXEC-005 raised, never a silent pass on the claimed conclusion");
        assert.ok(!/success.*success/.test(row(env, "EXEC-005").message), "ci-check no remote: the result's own claimed conclusion is never read as authoritative");
    }
    finally {
        removeFixture(dir);
    }
});
test("ci-check check_run_id, no remote: EXEC-005, claimed conclusion never trusted", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        const f = baseResultFields(dir);
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
            changed_files: [],
            test_evidence: [{ type: "ci-check", name: "unit tests", commit_sha: f.head, check_run_id: "123456789", conclusion: "success" }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), `ci-check check_run_id, no remote: EXEC-005 raised -- verdict=${env.execution_verification.verdict}`);
        assert.ok(!/success.*success/.test(row(env, "EXEC-005").message), "ci-check check_run_id, no remote: the claimed conclusion is still never trusted");
    }
    finally {
        removeFixture(dir);
    }
});
test("ci-check non-numeric check_run_id: EXEC-005, not a crash", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        const f = baseResultFields(dir);
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: f.head, execution_status: "completed",
            changed_files: [],
            test_evidence: [{ type: "ci-check", name: "unit tests", commit_sha: f.head, check_run_id: "not-a-number" }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-005"), `ci-check non-numeric check_run_id: EXEC-005 raised, not a crash -- verdict=${env.execution_verification.verdict}`);
    }
    finally {
        removeFixture(dir);
    }
});
// ---- MAJOR fix: contract digest sidecar is mandatory, not best-effort ------
test("deleted sidecar: EXEC-002, verdict contract_digest_missing, exit non-zero", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        rmSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json.sha256"), { force: true });
        const { env, exitCode } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-002"), "deleted sidecar: EXEC-002 raised");
        assert.equal(env.execution_verification.verdict, "contract_digest_missing", "deleted sidecar: verdict names the missing digest, not a pass");
        assert.notEqual(exitCode, 0, "deleted sidecar: exit code is non-zero");
    }
    finally {
        removeFixture(dir);
    }
});
test("empty sidecar: EXEC-002, verdict contract_digest_malformed", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        writeFileSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json.sha256"), "");
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-002"), "empty sidecar: EXEC-002 raised");
        assert.equal(env.execution_verification.verdict, "contract_digest_malformed", "empty sidecar: verdict names malformed, not tampered or missing");
    }
    finally {
        removeFixture(dir);
    }
});
test("malformed sidecar: EXEC-002, verdict contract_digest_malformed", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        writeFileSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json.sha256"), "not-a-digest");
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-002"), "malformed sidecar: EXEC-002 raised");
        assert.equal(env.execution_verification.verdict, "contract_digest_malformed", "malformed sidecar: verdict is contract_digest_malformed");
    }
    finally {
        removeFixture(dir);
    }
});
test("uppercase/whitespace sidecar still resolves to a pass", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir);
        const digest = contractDigestOf(dir);
        writeFileSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json.sha256"), `  ${digest.toUpperCase()}  \n`);
        const { env } = verifyResult(dir);
        assert.equal(env.execution_verification.verdict, "pass", `uppercase/whitespace sidecar: still resolves to a pass, not a false tamper report -- verdict=${env.execution_verification.verdict}`);
    }
    finally {
        removeFixture(dir);
    }
});
// ---- MAJOR fix: human decision_ref must resolve against decision-log.md ----
test("fake decision ref, no decision-log.md at all: EXEC-007, reason says it did not resolve", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { authority_claims: [{ type: "release-approval", actor: "human", claim: "approved", decision_ref: "DEC-999-NOT-REAL" }] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-007"), "fake decision ref, no decision-log.md at all: EXEC-007 raised");
        assert.match(row(env, "EXEC-007").message, /could not be resolved/, "fake decision ref: reason says it did not resolve");
    }
    finally {
        removeFixture(dir);
    }
});
test("non-DEC decision ref: EXEC-007", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { authority_claims: [{ type: "release-approval", actor: "human", claim: "approved", decision_ref: "see the chat log" }] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-007"), "non-DEC decision ref: EXEC-007 raised");
    }
    finally {
        removeFixture(dir);
    }
});
test("real decision ref, log committed before the export: verdict pass", () => {
    const dir = newExecFixture();
    try {
        // Overwrites the fixture's own decision log, so DEC-100 has to be carried
        // forward here too -- the default result cites it to promote its
        // artifact-observed runner evidence.
        writeExecFile(dir, "decision-log.md", [
            "# Decision Log - T", "",
            "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
            "|---|---|---|---|---|---|---|---|",
            "| 2026-07-30 | DEC-001 | ship it | A/B | A | because | src | ok |",
            "| 2026-07-30 | DEC-100 | Accept local test artifacts for D-001 | accept / require CI | accept | reviewed by hand | none | test evidence accepted |",
        ].join("\n"));
        git(dir, "add", "-A");
        git(dir, "commit", "-q", "-m", "record decision");
        exportContract(dir, "commit");
        // One New-Result call, then append the release-approval claim to what it
        // already wrote. Calling it twice would mint a second run record.
        newResult(dir);
        appendClaim(dir, { type: "release-approval", actor: "human", claim: "approved", decision_ref: "DEC-001" });
        // New-Result rewrote the log carrying DEC-100 with the record's real
        // digest; DEC-001 has to be restored alongside it -- and it needs its own
        // binding token, since every human-only claim must say what it approves.
        const contractDigest = contractDigestOf(dir);
        const releaseToken = `axiom-authority: type=release-approval; work_item=D-001; contract=${contractDigest}`;
        appendLogRow(dir, `| 2026-07-30 | DEC-001 | ship it | A/B | A | because. ${releaseToken} | src | ok |`);
        const { env } = verifyResult(dir);
        assert.equal(env.execution_verification.verdict, "pass", `real decision ref, log committed before the export: verdict pass -- fails=${ruleIds(env).join(",")}`);
    }
    finally {
        removeFixture(dir);
    }
});
test("ambiguous decision ref (appears twice): EXEC-007", () => {
    const dir = newExecFixture();
    try {
        writeExecFile(dir, "decision-log.md", [
            "# Decision Log - T", "",
            "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
            "|---|---|---|---|---|---|---|---|",
            "| 2026-07-30 | DEC-001 | first | A | A | x | src | ok |",
            "| 2026-07-30 | DEC-001 | duplicate id | A | A | x | src | ok |",
        ].join("\n"));
        git(dir, "add", "-A");
        git(dir, "commit", "-q", "-m", "record decision");
        exportContract(dir, "commit");
        newResult(dir, { authority_claims: [{ type: "release-approval", actor: "human", claim: "approved", decision_ref: "DEC-001" }] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-007"), "ambiguous decision ref (appears twice): EXEC-007 raised");
    }
    finally {
        removeFixture(dir);
    }
});
test("self-forged decision: EXEC-007 even though DEC-001 resolves", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        const f = baseResultFields(dir);
        const relRunRecordPath = realRunRecord(dir);
        // The attack: within the SAME commit range under verification, the agent
        // adds a decision-log.md row approving its own release, then cites it.
        writeExecFile(dir, "decision-log.md", [
            "# Decision Log - T", "",
            "| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |",
            "|---|---|---|---|---|---|---|---|",
            "| 2026-07-30 | DEC-001 | forged | A | A | agent wrote this | none | none |",
        ].join("\n"));
        writeExecFile(dir, "src/payments/app.ts", "implemented");
        git(dir, "add", "-A");
        git(dir, "commit", "-q", "-m", "impl + self-forged decision");
        const head = gitOut(dir, "rev-parse", "HEAD");
        const doc = {
            contract_version: "1.0", work_item_id: "D-001", contract_sha256: f.digest,
            base_sha: String(f.contract["base_sha"]), head_sha: head, execution_status: "completed",
            changed_files: ["src/payments/app.ts", "decision-log.md"],
            git_actions_performed: ["commit"],
            test_evidence: [{ type: "runner-exit-record", name: "unit tests", run_record_path: relRunRecordPath }],
            authority_claims: [{ type: "release-approval", actor: "human", claim: "approved", decision_ref: "DEC-001" }],
        };
        writeResultDoc(dir, doc);
        const { env } = verifyResult(dir);
        const exec007Log = env.results.find((r) => r.level === "FAIL" && r.rule_id === "EXEC-007" && r.artifact === "decision-log.md");
        assert.ok(ruleIds(env).includes("EXEC-007"), "self-forged decision: EXEC-007 raised even though DEC-001 resolves");
        assert.match(exec007Log.message, /changed within the commit range/, "self-forged decision: reason names decision-log.md as changed within the verified range");
    }
    finally {
        removeFixture(dir);
    }
});
// ---- MINOR fix: claimed-not-observed direction -----------------------------
test("claimed-not-observed: EXEC-008, message names the false claim", () => {
    const dir = newExecFixture();
    try {
        exportContract(dir, "commit");
        newResult(dir, { changed_files: ["src/payments/never-touched.ts"] });
        const { env } = verifyResult(dir);
        assert.ok(ruleIds(env).includes("EXEC-008"), "claimed-not-observed: EXEC-008 raised");
        assert.match(row(env, "EXEC-008").message, /claims a file that git shows no evidence/, "claimed-not-observed: message names the false claim");
    }
    finally {
        removeFixture(dir);
    }
});
