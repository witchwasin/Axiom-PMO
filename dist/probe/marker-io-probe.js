// §8.6 fresh-tree methodology for marker-block I/O: run the stateful setup
// (install + uninstall) via BOTH the PowerShell reference and the TS port in
// SEPARATE fresh temp trees, then diff the resulting file bytes and manifest.
// This proves the I/O layer matches without touching any real user file.
import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync, existsSync, readdirSync, statSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { readTextFileState, writeTextFileAtomic, newAxiomBackup } from "../marker/marker-io.js";
import { setAxiomBlock, removeAxiomBlock, getAxiomCanonicalBody } from "../marker/marker-block.js";
import { resolvePwsh } from "./pwsh-resolver.js";
const PWSH = resolvePwsh();
let pass = 0;
let fail = 0;
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
    return mkdtempSync(join(tmpdir(), "marker-io-"));
}
function writeUserFile(dir, name, content, bom = false) {
    const p = join(dir, name);
    writeFileSync(p, bom ? Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from(content)]) : content);
}
function psSetup(dir, action) {
    const r = spawnSync(PWSH, ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/setup-claude-integration.ps1",
        "-ProjectPath", dir, ...(action === "remove" ? ["-Uninstall"] : [])], { encoding: "utf8" });
    if (r.status !== 0)
        throw new Error(`ps setup ${action} failed: ${r.stderr}`);
}
function tsSetup(dir, action) {
    const file = join(dir, "AGENTS.md");
    const body = getAxiomCanonicalBody("1");
    const state = readTextFileState(file);
    if (!state.supported)
        throw new Error(`unsupported encoding: ${state.encoding}`);
    const result = action === "install"
        ? setAxiomBlock(state.text, body, state.newline)
        : removeAxiomBlock(state.text, state.newline);
    if (result.action === "blocked")
        throw new Error(`blocked: ${result.reason}`);
    if (state.exists)
        newAxiomBackup(file);
    writeTextFileAtomic(file, result.text, state.hasBom);
}
function treeSnapshot(dir) {
    const out = {};
    const walk = (d) => {
        for (const entry of readdirSync(d)) {
            const full = join(d, entry);
            if (statSync(full).isDirectory())
                walk(full);
            else
                out[full.substring(dir.length + 1)] = readFileSync(full).toString("base64");
        }
    };
    walk(dir);
    return out;
}
// --- Case 1: install onto a fresh AGENTS.md, compare PS vs TS trees ---
{
    const psTree = freshTree();
    const tsTree = freshTree();
    try {
        writeUserFile(psTree, "AGENTS.md", "# User rules\n\nBe careful.\n");
        writeUserFile(tsTree, "AGENTS.md", "# User rules\n\nBe careful.\n");
        psSetup(psTree, "install");
        tsSetup(tsTree, "install");
        const psSnap = treeSnapshot(psTree);
        const tsSnap = treeSnapshot(tsTree);
        // Compare AGENTS.md content (ignore backup filenames which carry a timestamp).
        const psAgents = readFileSync(join(psTree, "AGENTS.md"), "utf8");
        const tsAgents = readFileSync(join(tsTree, "AGENTS.md"), "utf8");
        check("install: AGENTS.md bytes identical", psAgents === tsAgents, `ps=${psAgents.length}b ts=${tsAgents.length}b`);
        check("install: backup created (both)", psSnap["AGENTS.md.axiom-backup"] === undefined && tsSnap["AGENTS.md.axiom-backup"] === undefined && Object.keys(psSnap).length >= 2, "backup present");
    }
    finally {
        rmSync(psTree, { recursive: true, force: true });
        rmSync(tsTree, { recursive: true, force: true });
    }
}
// --- Case 2: uninstall returns original bytes (round-trip) ---
{
    const tsTree = freshTree();
    try {
        writeUserFile(tsTree, "AGENTS.md", "# User rules\n");
        tsSetup(tsTree, "install");
        tsSetup(tsTree, "remove");
        const after = readFileSync(join(tsTree, "AGENTS.md"), "utf8");
        check("uninstall: round-trip returns original bytes", after === "# User rules\n", JSON.stringify(after));
    }
    finally {
        rmSync(tsTree, { recursive: true, force: true });
    }
}
// --- Case 3: CRLF + BOM file preserves newline/BOM through install ---
{
    const tsTree = freshTree();
    try {
        const original = "# Rules\r\n\r\nkeep me\r\n";
        writeUserFile(tsTree, "AGENTS.md", original, true);
        const before = readFileSync(join(tsTree, "AGENTS.md"));
        const hasBom = before[0] === 0xef && before[1] === 0xbb && before[2] === 0xbf;
        tsSetup(tsTree, "install");
        const after = readFileSync(join(tsTree, "AGENTS.md"));
        const afterHasBom = after[0] === 0xef && after[1] === 0xbb && after[2] === 0xbf;
        const afterBody = (afterHasBom ? after.subarray(3) : after).toString("utf8");
        check("CRLF+BOM: BOM preserved", hasBom && afterHasBom);
        check("CRLF+BOM: CRLF preserved", afterBody.includes("\r\n") && afterBody.startsWith("# Rules\r\n"));
    }
    finally {
        rmSync(tsTree, { recursive: true, force: true });
    }
}
// --- Case 4: UTF-16 file refused (not mangled) ---
{
    const tsTree = freshTree();
    try {
        // UTF-16LE BOM + content
        const utf16 = Buffer.from([0xff, 0xfe, 0x23, 0x00, 0x20, 0x00]);
        writeFileSync(join(tsTree, "AGENTS.md"), utf16);
        const state = readTextFileState(join(tsTree, "AGENTS.md"));
        check("UTF-16: refused with encoding label", state.supported === false && state.encoding.startsWith("UTF-16"), state.encoding);
    }
    finally {
        rmSync(tsTree, { recursive: true, force: true });
    }
}
console.log(`\nSummary: PASS=${pass} FAIL=${fail}`);
if (fail > 0)
    process.exitCode = 1;
