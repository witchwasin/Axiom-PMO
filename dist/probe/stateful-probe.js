// §8.6 fresh-tree probe for stateful commands: export-execution-contract and
// run-execution-command. Runs the TS candidate on a fresh temp tree and
// compares the resulting file bytes + digest sidecars against a golden
// fixture frozen from the PS reference on the same fixture-construction path
// (Phase 9: the reference no longer exists to compare against live).
import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync, readdirSync, statSync, rmSync, mkdtempSync } from "node:fs";
import { createHash } from "node:crypto";
import { tmpdir } from "node:os";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { exportExecutionContract } from "../tools/export-execution-contract.js";
import { runExecutionCommand } from "../tools/run-execution-command.js";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const FIXTURE = resolve(REPO_ROOT, "tests/golden/probes/stateful-probe.json");
const golden = JSON.parse(readFileSync(FIXTURE, "utf8"));
let pass = 0, fail = 0;
function check(name, ok, detail = "") {
    if (ok) {
        pass++;
        console.log(`[PASS] ${name}`);
    }
    else {
        fail++;
        console.log(`[FAIL] ${name}${detail ? " -- " + detail : ""}`);
    }
}
function git(dir, ...args) {
    spawnSync("git", ["-C", dir, ...args], { encoding: "utf8" });
}
// Fixed commit date so two independently-created fixture repos (one for the
// PS reference, one for the TS candidate) always produce byte-identical
// commits -- and therefore identical base_sha -- regardless of how much
// wall-clock time elapses between the two `git commit` calls. Without this,
// a >=1s skew under load (a real risk in a long back-to-back probe/test run)
// changes the commit hash even though the tree content is identical,
// producing a false-negative "export: contract bytes identical" failure.
const FIXTURE_COMMIT_ENV = {
    ...process.env,
    GIT_AUTHOR_DATE: "2026-01-01T00:00:00+00:00",
    GIT_COMMITTER_DATE: "2026-01-01T00:00:00+00:00",
};
function gitCommit(dir, message) {
    spawnSync("git", ["-C", dir, "commit", "-q", "-m", message], { encoding: "utf8", env: FIXTURE_COMMIT_ENV });
}
function write(dir, rel, content) {
    const full = join(dir, rel);
    mkdirSync(dirname(full), { recursive: true });
    writeFileSync(full, content);
}
function newProjectFixture() {
    const dir = mkdtempSync(join(tmpdir(), "stateful-probe-"));
    git(dir, "init", "-q", "--initial-branch=main");
    git(dir, "config", "user.email", "test@axiom-pmo.local");
    git(dir, "config", "user.name", "Stateful Probe");
    write(dir, "PROJECT.md", "# P99-EXEC\n");
    write(dir, "SCOPE.json", '{"schema_version":"1.0","project":"P99-EXEC","implementation_scope":{"include":["src/payments/**","tests/payments/**"],"exclude":["src/payments/generated/**"]}}');
    write(dir, "DELIVERY.md", "# DELIVERY - P99-EXEC\n\n## Work Items\n\n| ID | Mode | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Status |\n|---|---|---|---|---|---|---|---|---|\n| D-001 | Standard | Checkout flow | REQ-001 | DESIGN/FLOW.puml | Works | unit tests | Dev | To Do |\n");
    git(dir, "add", "-A");
    gitCommit(dir, "base");
    return dir;
}
function treeSnapshot(dir, exclude = []) {
    const out = {};
    const walk = (d) => {
        for (const entry of readdirSync(d)) {
            if (entry === ".git")
                continue;
            const full = join(d, entry);
            if (statSync(full).isDirectory())
                walk(full);
            else {
                const rel = full.substring(dir.length + 1);
                if (exclude.some((e) => rel.includes(e)))
                    continue;
                out[rel] = readFileSync(full).toString("base64");
            }
        }
    };
    walk(dir);
    return out;
}
// --- Case 1: export contract, compare TS bytes vs golden ---
{
    const tsTree = newProjectFixture();
    try {
        exportExecutionContract(REPO_ROOT, tsTree, "D-001", null, null, "", true);
        const tsSnap = treeSnapshot(tsTree);
        // Compare contract + sidecar (exclude timestamps/nondeterministic: none in export)
        const contractKey = ".execution/D-001/EXECUTION-CONTRACT.json";
        const sidecarKey = ".execution/D-001/EXECUTION-CONTRACT.json.sha256";
        check("export: contract bytes identical", golden.export_tree[contractKey] === tsSnap[contractKey], `${golden.export_tree[contractKey]?.length ?? 0} vs ${tsSnap[contractKey]?.length ?? 0}`);
        check("export: sidecar bytes identical", golden.export_tree[sidecarKey] === tsSnap[sidecarKey]);
        check("export: no unrelated files", JSON.stringify(Object.keys(golden.export_tree).sort()) === JSON.stringify(Object.keys(tsSnap).sort()));
    }
    finally {
        rmSync(tsTree, { recursive: true, force: true });
    }
}
// --- Case 2: run-execution-command, compare record structure (exclude nondeterministic run_id/timestamps) ---
{
    const tsTree = newProjectFixture();
    try {
        // export first
        exportExecutionContract(REPO_ROOT, tsTree, "D-001", null, null, "", true);
        // run
        const tsRun = runExecutionCommand(tsTree, "D-001", "unit tests", "echo ok");
        check("run: exit code matches", golden.run_exit_code === tsRun.exitCode, `${golden.run_exit_code} vs ${tsRun.exitCode}`);
        // Compare record JSON structure ignoring run_id + timestamps
        const tsRecord = JSON.parse(readFileSync(join(tsTree, ".execution/D-001/runs/" + readdirSync(join(tsTree, ".execution/D-001/runs")).find(f => f.endsWith('.json') && !f.endsWith('.sha256'))), "utf8"));
        const stable = (r) => { const { run_id, started_at, ended_at, ...rest } = r; return rest; };
        check("run: record structure identical (modulo run_id/timestamps)", JSON.stringify(golden.run_record_stable) === JSON.stringify(stable(tsRecord)));
        // Verify sidecar integrity for TS record
        const tsRecordFile = readdirSync(join(tsTree, ".execution/D-001/runs")).find(f => f.endsWith('.json') && !f.endsWith('.sha256'));
        const tsSidecar = readFileSync(join(tsTree, ".execution/D-001/runs", tsRecordFile + ".sha256"), "utf8").trim();
        const tsRecordDigest = createHash("sha256").update(readFileSync(join(tsTree, ".execution/D-001/runs", tsRecordFile))).digest("hex").toLowerCase();
        check("run: TS sidecar matches record digest", tsSidecar === tsRecordDigest);
    }
    finally {
        rmSync(tsTree, { recursive: true, force: true });
    }
}
console.log(`\nSummary: PASS=${pass} FAIL=${fail}`);
if (fail > 0)
    process.exitCode = 1;
