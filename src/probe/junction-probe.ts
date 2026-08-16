// CR-017 containment probe: NTFS junctions vs SETUP-003 (Windows only).
//
// Fixed_plan/phase8/CR-017-review-material.md §5 flagged one thing nothing in
// the project had actually verified: SETUP-003 refuses a symlinked instruction
// file via lstatSync(...).isSymbolicLink(), but an NTFS junction is a different
// reparse-point type (IO_REPARSE_TAG_MOUNT_POINT, not SYMLINK), and nothing
// confirmed the check catches a real junction on a real Windows host.
//
// A junction cannot point at a file (junctions are directory-only), so the
// realistic junction attack on setup is the project ROOT being a junction:
// `project` resolves through it and AGENTS.md physically lives in the junction
// target -- setup then edits a file outside the path it was asked to change,
// the same class of escape the symlink case exists to refuse.
//
// This probe runs only on Windows (junctions exist only on NTFS). It drives
// BOTH the TS port (in-process) and the PS reference (subprocess) against a
// junctioned project root and asserts the SETUP-003 refusal plus that the
// pointed-at file is untouched -- the exact same assertions the symlink case
// makes. Non-Windows hosts print a skip and exit 0.
//
// Wired into pmo-checks.yml's canary-matrix Windows cells so it runs on a real
// Windows host on every qualifying push (the one place junctions can be made).

import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, rmSync, lstatSync, statSync, symlinkSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { setupClaudeIntegration } from "../tools/setup-claude-integration.js";
import { resolvePwsh } from "./pwsh-resolver.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

let pass = 0, fail = 0, skip = 0;
function check(name: string, ok: boolean, detail = ""): void {
  if (ok) { pass++; console.log(`[PASS] ${name}`); }
  else { fail++; console.log(`[FAIL] ${name}${detail ? " -- " + detail : ""}`); }
}

if (process.platform !== "win32") {
  console.log("[SKIP] NTFS junctions exist only on Windows; junction containment case not exercised here");
  console.log("\nSummary: PASS=0 FAIL=0 SKIP=1");
  process.exit(0);
}

const PWSH = resolvePwsh();

function freshDir(prefix: string): string {
  return mkdtempSync(join(tmpdir(), prefix));
}

function psSetup(projectPath: string): { status: number | null; text: string } {
  const r = spawnSync(PWSH, [
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
    join(REPO_ROOT, "scripts/setup-claude-integration.ps1"),
    "-ProjectPath", projectPath,
  ], { encoding: "utf8" });
  return { status: r.status, text: `${r.stdout ?? ""}${r.stderr ?? ""}` };
}

const REAL_CONTENT = "# Real rules.\n";

// sandbox holds ONLY the junction; realDir is the junction target. Kept
// separate so cleanup order cannot matter (both are throwaway temp dirs).
const sandbox = freshDir("junction-probe-sandbox-");
const realDir = freshDir("junction-probe-real-");
let junctionCreated = false;
try {
  // mkdtempSync already created realDir; no mkdirSync here.
  writeFileSync(join(realDir, "AGENTS.md"), REAL_CONTENT);

  // fs.symlinkSync(type "junction") creates an NTFS junction on Windows
  // (IO_REPARSE_TAG_MOUNT_POINT) -- no elevation needed, unlike symlinks.
  const junction = join(sandbox, "proj");
  symlinkSync(realDir, junction, "junction");
  junctionCreated = true;

  check("junction was created (path resolves through it)",
    statSync(junction).isDirectory(), "junction path did not resolve");
  // Node's lstat on Windows reports junctions as symbolic links (libuv maps
  // both IO_REPARSE_TAG_MOUNT_POINT and SYMLINK to S_IFLNK). If this is false
  // the finding is bigger than the project-root case: even a direct lstat of
  // the junction would not flag it.
  check("lstat reports the junction as a reparse point",
    lstatSync(junction).isSymbolicLink(),
    "isSymbolicLink() was false for a junction -- the check as written cannot catch one");

  // ---- TS port (in-process) --------------------------------------------
  const ts = setupClaudeIntegration(junction, false, false, false, "AGENTS.md");
  check("TS refuses a junctioned project root (SETUP-003)",
    ts.exitCode !== 0 && ts.output.includes("SETUP-003"),
    `exit=${ts.exitCode} ${ts.output.split("\n")[0] ?? ""}`);
  check("TS: the pointed-at file is untouched",
    readFileSync(join(realDir, "AGENTS.md"), "utf8") === REAL_CONTENT,
    readFileSync(join(realDir, "AGENTS.md"), "utf8").slice(0, 60));

  // ---- PS reference (subprocess) ---------------------------------------
  const ps = psSetup(junction);
  check("reference refuses a junctioned project root (SETUP-003)",
    ps.status !== 0 && ps.text.includes("SETUP-003"),
    `exit=${ps.status} ${(ps.text.split("\n")[0] ?? "").trim()}`);
  check("reference: the pointed-at file is untouched",
    readFileSync(join(realDir, "AGENTS.md"), "utf8") === REAL_CONTENT,
    readFileSync(join(realDir, "AGENTS.md"), "utf8").slice(0, 60));
} finally {
  if (junctionCreated) {
    try { rmSync(join(sandbox, "proj"), { recursive: true, force: true }); } catch { /* best effort */ }
  }
  try { rmSync(sandbox, { recursive: true, force: true }); } catch { /* best effort */ }
  try { rmSync(realDir, { recursive: true, force: true }); } catch { /* best effort */ }
}

// ---- Case 2: the junction is an ANCESTOR of the project, not the project
// root itself. Found by auditing for the same "final-component-only" gap
// class this file's Case 1 originally closed: the old SETUP-003 check only
// ever inspected the project directory's own lstat, never anything above it.
// A junction one level ABOVE an otherwise-ordinary real directory silently
// redirected reads/writes through it (confirmed by direct reproduction with a
// POSIX symlink locally before this Windows case was written; see
// setup-integration.test.ts's "ANCESTOR of the project root" case for the
// symlink-side proof and src/core/path-containment.ts's
// findAncestorReparsePoint for the fix, which subsumes Case 1 above).
{
  const ancestorSandbox = freshDir("junction-probe-ancestor-sandbox-");
  const ancestorRealParent = freshDir("junction-probe-ancestor-real-");
  let ancestorJunctionCreated = false;
  try {
    const realSubdir = join(ancestorRealParent, "subdir");
    mkdirSync(realSubdir, { recursive: true });
    writeFileSync(join(realSubdir, "AGENTS.md"), REAL_CONTENT);

    const junctionParent = join(ancestorSandbox, "linked-parent");
    symlinkSync(ancestorRealParent, junctionParent, "junction");
    ancestorJunctionCreated = true;
    // The project argument itself is an ORDINARY real directory; only its
    // parent is the junction.
    const project = join(junctionParent, "subdir");

    const ts = setupClaudeIntegration(project, false, false, false, "AGENTS.md");
    check("TS refuses a project root with a junctioned ANCESTOR (SETUP-003)",
      ts.exitCode !== 0 && ts.output.includes("SETUP-003"),
      `exit=${ts.exitCode} ${ts.output.split("\n")[0] ?? ""}`);
    check("TS (ancestor case): the pointed-at file is untouched",
      readFileSync(join(realSubdir, "AGENTS.md"), "utf8") === REAL_CONTENT,
      readFileSync(join(realSubdir, "AGENTS.md"), "utf8").slice(0, 60));

    const ps = psSetup(project);
    check("reference refuses a project root with a junctioned ANCESTOR (SETUP-003)",
      ps.status !== 0 && ps.text.includes("SETUP-003"),
      `exit=${ps.status} ${(ps.text.split("\n")[0] ?? "").trim()}`);
    check("reference (ancestor case): the pointed-at file is untouched",
      readFileSync(join(realSubdir, "AGENTS.md"), "utf8") === REAL_CONTENT,
      readFileSync(join(realSubdir, "AGENTS.md"), "utf8").slice(0, 60));
  } finally {
    if (ancestorJunctionCreated) {
      try { rmSync(join(ancestorSandbox, "linked-parent"), { recursive: true, force: true }); } catch { /* best effort */ }
    }
    try { rmSync(ancestorSandbox, { recursive: true, force: true }); } catch { /* best effort */ }
    try { rmSync(ancestorRealParent, { recursive: true, force: true }); } catch { /* best effort */ }
  }
}

// ---- Case 3: the junction target has NO AGENTS.md yet -- proves refusal
// isn't merely a side effect of the file-level symlink check never firing
// because the file happens not to exist yet. Setup's create path must also
// refuse, not silently create AGENTS.md through the junction into a directory
// the caller never named.
{
  const emptySandbox = freshDir("junction-probe-empty-sandbox-");
  const emptyRealDir = freshDir("junction-probe-empty-real-");
  let emptyJunctionCreated = false;
  try {
    // emptyRealDir intentionally has no AGENTS.md -- mkdtempSync already
    // created the directory itself, nothing more to set up.
    const junction = join(emptySandbox, "proj");
    symlinkSync(emptyRealDir, junction, "junction");
    emptyJunctionCreated = true;

    const ts = setupClaudeIntegration(junction, false, false, false, "AGENTS.md");
    check("TS refuses a junctioned project root even with no AGENTS.md yet (SETUP-003)",
      ts.exitCode !== 0 && ts.output.includes("SETUP-003"),
      `exit=${ts.exitCode} ${ts.output.split("\n")[0] ?? ""}`);
    check("TS (empty-target case): nothing was created through the junction",
      !existsSync(join(emptyRealDir, "AGENTS.md")),
      "AGENTS.md was created through the junction despite the refusal");

    const ps = psSetup(junction);
    check("reference refuses a junctioned project root even with no AGENTS.md yet (SETUP-003)",
      ps.status !== 0 && ps.text.includes("SETUP-003"),
      `exit=${ps.status} ${(ps.text.split("\n")[0] ?? "").trim()}`);
    check("reference (empty-target case): nothing was created through the junction",
      !existsSync(join(emptyRealDir, "AGENTS.md")),
      "AGENTS.md was created through the junction despite the refusal");
  } finally {
    if (emptyJunctionCreated) {
      try { rmSync(join(emptySandbox, "proj"), { recursive: true, force: true }); } catch { /* best effort */ }
    }
    try { rmSync(emptySandbox, { recursive: true, force: true }); } catch { /* best effort */ }
    try { rmSync(emptyRealDir, { recursive: true, force: true }); } catch { /* best effort */ }
  }
}

console.log(`\nSummary: PASS=${pass} FAIL=${fail} SKIP=${skip}`);
if (fail > 0) process.exitCode = 1;
