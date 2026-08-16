// `axiom setup claude`, ported from scripts/setup-claude-integration.ps1.
// Stateful (mutates AGENTS.md/CLAUDE.md) — reuses the ported marker-block
// (pure transforms) and marker-io (filesystem I/O). Verified by §8.6 fresh-tree.
//
// The stdout here is transcribed from the reference line-for-line (same
// messages, same exit codes, same blank-line placement), so a cutover to this
// port changes nothing a user or a test sees on the terminal.
import { existsSync, statSync, lstatSync, readdirSync } from "node:fs";
import { join, resolve, basename, dirname } from "node:path";
import { readTextFileState, writeTextFileAtomic, newAxiomBackup } from "../marker/marker-io.js";
import { findAxiomBlock, testAxiomBlockOwnership, getAxiomCanonicalBody, setAxiomBlock, removeAxiomBlock, newAxiomBlockText } from "../marker/marker-block.js";
const EXIT_OK = 0;
const EXIT_CONFLICT = 1;
const EXIT_USAGE = 2;
function joinLines(lines) {
    return lines.join("\n") + "\n";
}
export function setupClaudeIntegration(projectPath, dryRun, uninstall, force, file) {
    // ---- SETUP-001/002: resolve and contain the target -----------------------
    // The reference refuses a missing path, a non-directory, and a target file
    // that escapes the resolved project root before doing anything else.
    if (!existsSync(projectPath)) {
        return { output: `[FAIL] SETUP-001 Project path does not exist: ${projectPath}\n`, exitCode: EXIT_USAGE };
    }
    if (!statSync(projectPath).isDirectory()) {
        return { output: `[FAIL] SETUP-001 Project path is not a directory: ${projectPath}\n`, exitCode: EXIT_USAGE };
    }
    const project = resolve(projectPath);
    const targetPath = join(project, file);
    const resolvedParent = resolve(dirname(targetPath));
    if (resolvedParent !== project) {
        return {
            output: "[FAIL] SETUP-002 Refusing to write outside the project directory.\n" +
                `  project: ${project}\n` +
                `  target:  ${targetPath}\n`,
            exitCode: EXIT_CONFLICT,
        };
    }
    // ---- SETUP-003: a symlinked instruction file points elsewhere ------------
    if (existsSync(targetPath)) {
        try {
            if (lstatSync(targetPath).isSymbolicLink()) {
                return {
                    output: `[FAIL] SETUP-003 ${file} is a symbolic link or reparse point.\n` +
                        "  Refusing to follow it: the real file lies outside what this command was asked to change.\n" +
                        "  Fix: edit the real file directly, or replace the link with a regular file.\n",
                    exitCode: EXIT_CONFLICT,
                };
            }
        }
        catch { }
    }
    // ---- Inspect what is already here ----------------------------------------
    const state = readTextFileState(targetPath);
    // SETUP-008: encoding gate, before a backup or a byte is written.
    if (!state.supported) {
        return {
            output: `[FAIL] SETUP-008 ${file} is ${state.encoding}; Axiom-PMO only edits UTF-8.\n` +
                "\n" +
                "  Nothing was read as text, nothing was written, and no backup was taken --\n" +
                "  there is nothing to protect the file from, because nothing is going to touch it.\n" +
                "\n" +
                "  Why this refuses instead of converting: rewriting the file would re-encode\n" +
                "  every byte in it, not just the block. A command that promises to append one\n" +
                "  section must not silently rewrite the other 99% of the document.\n" +
                "\n" +
                `  Fix: convert ${file} to UTF-8 yourself, then re-run. On PowerShell:\n` +
                `    $t = Get-Content -LiteralPath '${file}' -Raw\n` +
                `    Set-Content -LiteralPath '${file}' -Value $t -Encoding utf8\n` +
                "\n" +
                "Summary: PASS=0 FAIL=1\n",
            exitCode: EXIT_CONFLICT,
        };
    }
    const block = findAxiomBlock(state.text);
    const ownership = testAxiomBlockOwnership(block);
    // Header block, exactly as the reference prints it (including the trailing
    // space after the target-file name when the file already exists).
    const out = [];
    const section = (text) => { out.push(""); out.push(text); };
    out.push("Axiom-PMO Claude Code integration");
    out.push(`  Project:      ${project}`);
    out.push(`  Target file:  ${file} ${state.exists ? "" : "(will be created)"}`);
    out.push(`  Axiom block:  ${block.status}${block.status === "present" ? ` (${ownership})` : ""}`);
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
    if (neighbours.length > 0) {
        out.push(`  Detected:     ${neighbours.join("; ")}`);
        out.push("                left untouched -- this command only manages its own fenced block");
    }
    const body = getAxiomCanonicalBody("1");
    if (block.status === "malformed") {
        section(`[FAIL] SETUP-004 The Axiom-PMO markers in ${file} are malformed.`);
        out.push(`  ${block.reason}`);
        out.push("");
        out.push("  Refusing to guess which marker belongs to which. Repair the file by hand --");
        out.push("  the markers look like:");
        out.push("    <!-- AXIOM-PMO:BEGIN v1 sha256=... -->  ...  <!-- AXIOM-PMO:END -->");
        return { output: joinLines(out), exitCode: EXIT_CONFLICT };
    }
    // ---- Uninstall ------------------------------------------------------------
    if (uninstall) {
        if (!state.exists) {
            section(`Nothing to remove: ${file} does not exist.`);
            return { output: joinLines(out), exitCode: EXIT_OK };
        }
        const removal = removeAxiomBlock(state.text, state.newline, force);
        if (removal.action === "absent") {
            section(`Nothing to remove: ${file} has no Axiom-PMO block.`);
            return { output: joinLines(out), exitCode: EXIT_OK };
        }
        if (removal.action === "blocked") {
            section("[FAIL] SETUP-005 Refusing to remove the Axiom-PMO block.");
            out.push(`  ${removal.reason}`);
            out.push("");
            out.push("  Nothing was changed. Either move your edits out of the block and re-run,");
            out.push("  or re-run with -Force to remove the block and the edits inside it.");
            return { output: joinLines(out), exitCode: EXIT_CONFLICT };
        }
        if (dryRun) {
            section("Dry run -- nothing was written.");
            out.push(`  Would remove the Axiom-PMO block from ${file}.`);
            out.push(`  ${state.text.length} bytes -> ${removal.text.length} bytes`);
            return { output: joinLines(out), exitCode: EXIT_OK };
        }
        try {
            const backup = newAxiomBackup(targetPath);
            writeTextFileAtomic(targetPath, removal.text, state.hasBom);
            section(`Removed the Axiom-PMO block from ${file}.`);
            out.push(`  Backup: ${basename(backup)}`);
            if (removal.text.trim() === "") {
                out.push(`  ${file} is now empty. It is left in place rather than deleted -- this command`);
                out.push("  cannot tell a file it created from one that was already empty.");
            }
            return { output: joinLines(out), exitCode: EXIT_OK };
        }
        catch (e) {
            section(`[FAIL] SETUP-007 Could not write ${file}.`);
            out.push(`  ${e.message}`);
            out.push("");
            out.push("  The file was not modified -- the write is atomic, so it is either fully");
            out.push("  updated or untouched.");
            return { output: joinLines(out), exitCode: EXIT_CONFLICT };
        }
    }
    // ---- Install / update -----------------------------------------------------
    const result = setAxiomBlock(state.text, body, state.newline, force);
    if (result.action === "blocked") {
        section("[FAIL] SETUP-006 Refusing to modify the Axiom-PMO block.");
        out.push(`  ${result.reason}`);
        out.push("");
        out.push("  Nothing was changed. Re-run with -Force to overwrite the block as it stands.");
        return { output: joinLines(out), exitCode: EXIT_CONFLICT };
    }
    if (result.action === "unchanged") {
        section(`Already up to date -- ${file} is unchanged.`);
        return { output: joinLines(out), exitCode: EXIT_OK };
    }
    if (dryRun) {
        section("Dry run -- nothing was written.");
        out.push(`  Would ${result.action === "inserted" ? "add" : "update"} the Axiom-PMO block in ${file}.`);
        out.push(`  ${state.text.length} bytes -> ${result.text.length} bytes`);
        out.push("");
        out.push("  --- block that would be written ---");
        for (const line of newAxiomBlockText(body, "\n").split("\n"))
            out.push(`  | ${line}`);
        out.push("  --- end ---");
        out.push("");
        out.push("  Nothing outside those markers is written, and nothing outside them would be");
        out.push("  removed by -Uninstall -- the block is appended with no separator, so");
        out.push("  install followed by uninstall returns this file to its current bytes exactly.");
        return { output: joinLines(out), exitCode: EXIT_OK };
    }
    let backup = null;
    try {
        if (state.exists)
            backup = newAxiomBackup(targetPath);
        writeTextFileAtomic(targetPath, result.text, state.hasBom);
        section(`${result.action === "inserted" ? "Added" : "Updated"} the Axiom-PMO block in ${file}.`);
        if (backup)
            out.push(`  Backup: ${basename(backup)}`);
        out.push("  Remove it again with: -Uninstall");
        return { output: joinLines(out), exitCode: EXIT_OK };
    }
    catch (e) {
        section(`[FAIL] SETUP-007 Could not write ${file}.`);
        out.push(`  ${e.message}`);
        out.push("");
        out.push("  The file was not modified -- the write is atomic, so it is either fully");
        out.push("  updated or untouched.");
        if (backup)
            out.push(`  A backup was taken first: ${basename(backup)}`);
        return { output: joinLines(out), exitCode: EXIT_CONFLICT };
    }
}
