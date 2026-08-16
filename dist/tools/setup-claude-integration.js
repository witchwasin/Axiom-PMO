// `axiom setup claude`, ported from scripts/setup-claude-integration.ps1.
// Stateful (mutates AGENTS.md/CLAUDE.md) — reuses the ported marker-block
// (pure transforms) and marker-io (filesystem I/O). Verified by §8.6 fresh-tree.
import { existsSync, statSync, lstatSync, readdirSync } from "node:fs";
import { join, resolve, basename } from "node:path";
import { readTextFileState, writeTextFileAtomic, newAxiomBackup } from "../marker/marker-io.js";
import { findAxiomBlock, testAxiomBlockOwnership, getAxiomCanonicalBody, setAxiomBlock, removeAxiomBlock } from "../marker/marker-block.js";
const EXIT_OK = 0;
const EXIT_CONFLICT = 1;
export function setupClaudeIntegration(projectPath, dryRun, uninstall, force, file) {
    const project = resolve(projectPath);
    const targetPath = join(project, file);
    // SETUP-003: refuse symlink/reparse point
    if (existsSync(targetPath)) {
        try {
            if (lstatSync(targetPath).isSymbolicLink()) {
                return { output: `[FAIL] SETUP-003 ${file} is a symbolic link or reparse point.\n`, exitCode: EXIT_CONFLICT };
            }
        }
        catch { }
    }
    const state = readTextFileState(targetPath);
    if (!state.supported) {
        return { output: `[FAIL] SETUP-008 ${file} is ${state.encoding}; Axiom-PMO only edits UTF-8.\n`, exitCode: EXIT_CONFLICT };
    }
    const block = findAxiomBlock(state.text);
    const ownership = testAxiomBlockOwnership(block);
    const neighbours = [];
    for (const probe of [
        { path: ".claude/skills", label: "Claude skills" },
        { path: ".claude/commands", label: "Claude commands" },
        { path: ".claude/settings.json", label: "Claude settings" },
        { path: ".claude/hooks", label: "Claude hooks" },
        { path: ".claude-plugin", label: "a plugin manifest" },
        { path: "CLAUDE.md", label: "CLAUDE.md" },
        { path: "AGENTS.md", label: "AGENTS.md" },
        { path: ".bmad-core", label: "BMAD" },
        { path: "bmad-core", label: "BMAD" },
        { path: ".superpowers", label: "Superpowers" },
        { path: "skills", label: "a skills directory" },
    ]) {
        if (existsSync(join(project, probe.path)))
            neighbours.push(`${probe.label} (${probe.path})`);
    }
    const body = getAxiomCanonicalBody("1");
    if (uninstall) {
        if (!state.exists)
            return { output: `Nothing to remove: ${file} does not exist.\n`, exitCode: EXIT_OK };
        const removal = removeAxiomBlock(state.text, state.newline, force);
        if (removal.action === "absent")
            return { output: `Nothing to remove: ${file} has no Axiom-PMO block.\n`, exitCode: EXIT_OK };
        if (removal.action === "blocked") {
            return { output: `[FAIL] SETUP-005 Refusing to remove the Axiom-PMO block.\n  ${removal.reason}\n`, exitCode: EXIT_CONFLICT };
        }
        if (dryRun) {
            return { output: `Dry run -- nothing was written.\n  Would remove the Axiom-PMO block from ${file}.\n  ${state.text.length} bytes -> ${removal.text.length} bytes\n`, exitCode: EXIT_OK };
        }
        try {
            const backup = newAxiomBackup(targetPath);
            writeTextFileAtomic(targetPath, removal.text, state.hasBom);
            return { output: `Removed the Axiom-PMO block from ${file}.\n  Backup: ${basename(backup)}\n`, exitCode: EXIT_OK };
        }
        catch (e) {
            return { output: `[FAIL] SETUP-007 Could not write ${file}.\n  ${e.message}\n`, exitCode: EXIT_CONFLICT };
        }
    }
    const result = setAxiomBlock(state.text, body, state.newline, force);
    if (result.action === "blocked") {
        return { output: `[FAIL] SETUP-006 Refusing to modify the Axiom-PMO block.\n  ${result.reason}\n`, exitCode: EXIT_CONFLICT };
    }
    if (result.action === "unchanged") {
        return { output: `Already up to date -- ${file} is unchanged.\n`, exitCode: EXIT_OK };
    }
    if (dryRun) {
        return { output: `Dry run -- nothing was written.\n  Would ${result.action === "inserted" ? "add" : "update"} the Axiom-PMO block in ${file}.\n  ${state.text.length} bytes -> ${result.text.length} bytes\n`, exitCode: EXIT_OK };
    }
    let backup = null;
    try {
        if (state.exists)
            backup = newAxiomBackup(targetPath);
        writeTextFileAtomic(targetPath, result.text, state.hasBom);
        return { output: `${result.action === "inserted" ? "Added" : "Updated"} the Axiom-PMO block in ${file}.\n${backup ? `  Backup: ${basename(backup)}\n` : ""}  Remove it again with: -Uninstall\n`, exitCode: EXIT_OK };
    }
    catch (e) {
        return { output: `[FAIL] SETUP-007 Could not write ${file}.\n  ${e.message}\n`, exitCode: EXIT_CONFLICT };
    }
}
