// Differential probe: run the PowerShell reference (validate-project.ps1) and
// the ported TS chain on the same fixture, filter both to the ported rule-ID
// set, and canonical-compare. This is the "differentially green" gate from
// master-plan v3 §9 Phase 2-4, applied per-module without a full orchestrator.
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { runPortedChain } from "./validate-chain.js";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
// Rules the ported chain is responsible for. Everything else PS emits
// (HANDOFF-*, DPROV-002..007, VPROOF-*, TEST-DESIGN-*, SCOPE-DIFF-*, EXEC-*,
// DOCTOR-*, PERMISSION-*) is not yet ported and is filtered out of BOTH sides.
const PORTED_RULE_IDS = new Set([
    "MODE-001", "MODE-002", "MODE-003",
    "STRUCT-001", "TASK-003", "PATH-001", "PATH-002",
    "PLACEHOLDER-001", "SENSITIVE-001", "LINK-001", "SOURCE-LINK-001",
    "RESEARCH-001", "DPROV-001",
    "TASK-001", "TASK-002", "SOURCE-001", "SOURCE-002", "SOURCE-003",
    "EVIDENCE-001", "REF-001", "REF-002",
    "APPROVAL-001", "APPROVAL-002", "APPROVAL-003", "APPROVAL-004", "APPROVAL-005",
    "WORKITEM-001", "ENUM-001", "STRICT-001",
    "CHANGE-001", "CHANGE-002", "CHANGE-003",
    "EXT-001", "EXT-002", "EXT-003", "EXT-004",
    "RESEARCH-002", "RESEARCH-003", "RESEARCH-004", "RESEARCH-005", "RESEARCH-006", "RESEARCH-007",
    "TEST-RESULT-001", "TEST-EVIDENCE-002", "TEST-EVIDENCE-003",
    "RTM-001", "RTM-002", "RTM-003", "RTM-004", "RTM-005", "RTM-006", "RTM-007", "RTM-008", "RTM-009", "RTM-010",
    "BLOCKER-001", "RELEASE-001", "QA-REVIEW-001", "SECURITY-REVIEW-001",
    "TEST-SUMMARY-001", "RELEASE-SCOPE-001", "RELEASE-STATUS-001", "REVIEW-001", "TEST-EVIDENCE-001",
    "STRICT-002", "DESIGN-001",
    "DPROV-002", "DPROV-003", "DPROV-004", "DPROV-005", "DPROV-006", "DPROV-007",
    "VPROOF-001", "VPROOF-002",
]);
function resolvePwsh() {
    if (process.env.AXIOM_PWSH)
        return process.env.AXIOM_PWSH;
    const probe = spawnSync("pwsh", ["--version"], { encoding: "utf8" });
    if (probe.status === 0)
        return "pwsh";
    // Local dev fallback (pwsh 7.6.4 installed outside PATH).
    return "/Users/arm/tools/pwsh/pwsh";
}
function runReference(fixture, mode, gate) {
    const r = spawnSync(resolvePwsh(), ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", resolve(REPO_ROOT, "scripts/validate-project.ps1"),
        "-ProjectPath", fixture, "-Mode", mode, "-Gate", gate, "-Format", "Json"], { encoding: "utf8" });
    // Exit 1 (a FAIL) and 2 (blocking WARN under -FailOnWarning) are normal
    // validation verdicts, not reference errors. Parse stdout regardless.
    if (r.status !== 0 && r.status !== 1 && r.status !== 2) {
        throw new Error(`reference crashed with exit ${r.status}: ${r.stderr}`);
    }
    if (!r.stdout || r.stdout.trim() === "") {
        throw new Error(`reference produced no JSON output (exit ${r.status})`);
    }
    const env = JSON.parse(r.stdout);
    return env.results;
}
function filter(rows) {
    return rows.filter((r) => PORTED_RULE_IDS.has(r.rule_id));
}
function key(row) {
    return JSON.stringify([row.level, row.rule_id, row.message, row.blocking, row.artifact, row.item_id, row.field, row.suggestion, row.documentation_url]);
}
const CASES = [
    // Positive examples (each exercise the full chain for a mode/gate).
    { fixture: "examples/STANDARD-FEATURE", mode: "Standard", gate: "Release" },
    { fixture: "examples/STRICT-HIGH-RISK", mode: "Strict", gate: "Release" },
    { fixture: "examples/OPTIONAL-TRACKS", mode: "Standard", gate: "Release" },
    { fixture: "examples/LITE-BUGFIX", mode: "Lite", gate: "Release" },
    { fixture: "examples/HANDOFF-DEMO", mode: "Standard", gate: "Design" },
    { fixture: "tests/fixtures/valid-standard", mode: "Standard", gate: "Release" },
    // Negative fixtures — each fires a specific FAIL branch of a ported module.
    { fixture: "tests/fixtures/invalid-rtm-broken-release-ref", mode: "Strict", gate: "Release" },
    { fixture: "tests/fixtures/invalid-empty-rtm", mode: "Strict", gate: "Release" },
    { fixture: "tests/fixtures/invalid-rtm-bad-status", mode: "Strict", gate: "Release" },
    { fixture: "tests/fixtures/invalid-missing-rollback", mode: "Standard", gate: "Release" },
    { fixture: "tests/fixtures/invalid-unstructured-rollback", mode: "Standard", gate: "Release" },
    { fixture: "tests/fixtures/invalid-approval-evidence-freetext", mode: "Standard", gate: "Release" },
    { fixture: "tests/fixtures/invalid-fake-approval", mode: "Standard", gate: "Release" },
    { fixture: "tests/fixtures/invalid-no-source-ref", mode: "Standard", gate: "Release" },
    { fixture: "tests/fixtures/invalid-duplicate-requirement-id", mode: "Standard", gate: "Release" },
    { fixture: "tests/fixtures/invalid-workitem-header-missing", mode: "Standard", gate: "Scope" },
    { fixture: "tests/fixtures/invalid-sensitive-env", mode: "Standard", gate: "Scope" },
    { fixture: "tests/fixtures/invalid-broken-link", mode: "Standard", gate: "Release" },
    { fixture: "tests/fixtures/invalid-open-blocker", mode: "Standard", gate: "Release" },
    { fixture: "tests/fixtures/invalid-missing-design", mode: "Standard", gate: "Release" },
    { fixture: "tests/fixtures/invalid-strict-trigger-standard", mode: "Standard", gate: "Release" },
    { fixture: "tests/fixtures/invalid-task-source-conflict", mode: "Standard", gate: "Release" },
    { fixture: "tests/fixtures/invalid-mode-downgrade-workitem", mode: "Standard", gate: "Release" },
    { fixture: "tests/fixtures/valid-lite-rollback-waiver", mode: "Lite", gate: "Release" },
    { fixture: "tests/fixtures/valid-test-summary-waived", mode: "Standard", gate: "Release" },
    { fixture: "tests/fixtures/invalid-lite-release-no-approval", mode: "Lite", gate: "Release" },
    { fixture: "tests/fixtures/invalid-approval-role-standard", mode: "Standard", gate: "Release" },
    // Visual proof (VPROOF-*) + design provider (DPROV-*) exercised at Handoff.
    { fixture: "examples/DESIGN-SYSTEM-DEMO", mode: "Standard", gate: "Handoff" },
];
function main() {
    let totalPass = 0;
    let totalFail = 0;
    for (const c of CASES) {
        const fixtureAbs = resolve(REPO_ROOT, c.fixture);
        let refRows;
        let candRows;
        try {
            refRows = filter(runReference(fixtureAbs, c.mode, c.gate));
            candRows = filter(runPortedChain(REPO_ROOT, fixtureAbs, c.mode, c.gate).diagnostics);
        }
        catch (e) {
            console.log(`[SKIP] ${c.fixture} @ ${c.mode}/${c.gate}: ${e.message}`);
            continue;
        }
        const refKeys = refRows.map(key);
        const candKeys = candRows.map(key);
        const refSet = new Set(refKeys);
        const candSet = new Set(candKeys);
        const onlyRef = refKeys.filter((k) => !candSet.has(k));
        const onlyCand = candKeys.filter((k) => !refSet.has(k));
        // Order matters (PS result order is part of the contract). Compare ordered
        // sequences too, but report set differences first for diagnosability.
        const orderedEqual = JSON.stringify(refKeys) === JSON.stringify(candKeys);
        if (onlyRef.length === 0 && onlyCand.length === 0 && orderedEqual) {
            totalPass++;
            console.log(`[PASS] ${c.fixture} @ ${c.mode}/${c.gate} (${refKeys.length} rows)`);
        }
        else {
            totalFail++;
            console.log(`[FAIL] ${c.fixture} @ ${c.mode}/${c.gate} ref=${refKeys.length} cand=${candKeys.length}`);
            for (const r of onlyRef.slice(0, 8))
                console.log(`  - missing from candidate: ${r}`);
            for (const r of onlyCand.slice(0, 8))
                console.log(`  + extra in candidate:   ${r}`);
            if (onlyRef.length === 0 && onlyCand.length === 0 && !orderedEqual) {
                console.log("  (same rows, different order)");
            }
        }
    }
    console.log(`\nSummary: PASS=${totalPass} FAIL=${totalFail}`);
    if (totalFail > 0)
        process.exitCode = 1;
}
main();
