// §8.6 fresh-tree probe for setup-claude-integration: install + uninstall via
// the TS candidate on a temp tree; the one case (install) that used to also
// drive the PS reference now compares against a golden fixture frozen from
// that reference instead (Phase 9: the reference no longer exists to compare
// against live).
import { readFileSync, writeFileSync, rmSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { setupClaudeIntegration } from "../tools/setup-claude-integration.js";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const FIXTURE = resolve(REPO_ROOT, "tests/golden/probes/setup-probe.json");
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
function freshTree() {
    return mkdtempSync(join(tmpdir(), "setup-probe-"));
}
function writeAgents(dir, content) {
    writeFileSync(join(dir, "AGENTS.md"), content);
}
// Case 1: install on fresh file → identical bytes to golden
{
    const tsTree = freshTree();
    try {
        writeAgents(tsTree, "# User rules\n\nBe careful.\n");
        setupClaudeIntegration(tsTree, false, false, false, "AGENTS.md");
        const ts = readFileSync(join(tsTree, "AGENTS.md"), "utf8");
        check("install: bytes identical", golden.installed_agents_md === ts, `${golden.installed_agents_md.length} vs ${ts.length}`);
    }
    finally {
        rmSync(tsTree, { recursive: true, force: true });
    }
}
// Case 2: uninstall round-trips to original
{
    const tsTree = freshTree();
    try {
        writeAgents(tsTree, "# User rules\n");
        setupClaudeIntegration(tsTree, false, false, false, "AGENTS.md");
        setupClaudeIntegration(tsTree, false, true, false, "AGENTS.md");
        const after = readFileSync(join(tsTree, "AGENTS.md"), "utf8");
        check("uninstall: round-trip returns original", after === "# User rules\n");
    }
    finally {
        rmSync(tsTree, { recursive: true, force: true });
    }
}
// Case 3: edited block blocks without force, both PS and TS
{
    const tsTree = freshTree();
    try {
        writeAgents(tsTree, "# User rules\n");
        setupClaudeIntegration(tsTree, false, false, false, "AGENTS.md");
        // edit the block by hand
        const p = join(tsTree, "AGENTS.md");
        const edited = readFileSync(p, "utf8").replace("You may not approve", "You CAN approve");
        writeFileSync(p, edited);
        const blocked = setupClaudeIntegration(tsTree, false, false, false, "AGENTS.md");
        check("edited: uninstall blocks without force", blocked.exitCode === 1, `exit ${blocked.exitCode}`);
        const forced = setupClaudeIntegration(tsTree, false, true, true, "AGENTS.md");
        check("edited: forced uninstall succeeds", forced.exitCode === 0, `exit ${forced.exitCode}`);
    }
    finally {
        rmSync(tsTree, { recursive: true, force: true });
    }
}
console.log(`\nSummary: PASS=${pass} FAIL=${fail}`);
if (fail > 0)
    process.exitCode = 1;
