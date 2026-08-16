// §8.6 fresh-tree probe for setup-claude-integration: install + uninstall via
// PS reference vs TS candidate on separate temp trees, compare file bytes.

import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync, rmSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { setupClaudeIntegration } from "../tools/setup-claude-integration.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const PWSH = process.env.AXIOM_PWSH ?? "/Users/arm/tools/pwsh/pwsh";

let pass = 0, fail = 0;
function check(name: string, ok: boolean, detail = ""): void {
  if (ok) { pass++; console.log(`[PASS] ${name}`); }
  else { fail++; console.log(`[FAIL] ${name}${detail ? " -- " + detail : ""}`); }
}

function freshTree(): string {
  return mkdtempSync(join(tmpdir(), "setup-probe-"));
}

function writeAgents(dir: string, content: string): void {
  writeFileSync(join(dir, "AGENTS.md"), content);
}

function psSetup(dir: string, action: "install" | "remove", force = false): void {
  const args = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", join(REPO_ROOT, "scripts/setup-claude-integration.ps1"),
    "-ProjectPath", dir, ...(action === "remove" ? ["-Uninstall"] : []), ...(force ? ["-Force"] : [])];
  const r = spawnSync(PWSH, args, { encoding: "utf8" });
  if (r.status !== 0) throw new Error(`ps setup ${action} failed: ${r.stderr}`);
}

// Case 1: install on fresh file → identical bytes
{
  const psTree = freshTree();
  const tsTree = freshTree();
  try {
    writeAgents(psTree, "# User rules\n\nBe careful.\n");
    writeAgents(tsTree, "# User rules\n\nBe careful.\n");
    psSetup(psTree, "install");
    setupClaudeIntegration(tsTree, false, false, false, "AGENTS.md");
    const ps = readFileSync(join(psTree, "AGENTS.md"), "utf8");
    const ts = readFileSync(join(tsTree, "AGENTS.md"), "utf8");
    check("install: bytes identical", ps === ts, `${ps.length} vs ${ts.length}`);
  } finally { rmSync(psTree, { recursive: true, force: true }); rmSync(tsTree, { recursive: true, force: true }); }
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
  } finally { rmSync(tsTree, { recursive: true, force: true }); }
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
  } finally { rmSync(tsTree, { recursive: true, force: true }); }
}

console.log(`\nSummary: PASS=${pass} FAIL=${fail}`);
if (fail > 0) process.exitCode = 1;
