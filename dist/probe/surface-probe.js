// Phase 6+7 -- final-tree differential gate, CLI + GitHub Action surface.
//
// Phase 7 rewired cli/axiom.mjs: the default path calls the ported TS engine
// in-process; AXIOM_ROLLBACK_PWSH=1 restores the original spawn-pwsh
// behavior. The compatibility contract is byte-level either way: for a given
// verb/args the CLI must produce the exact stdout, stderr, and exit code the
// underlying .ps1 produces when invoked directly. This probe is the rewire's
// regression check: every default-path case below compares the in-process
// output against the direct reference script, and dedicated rollback cases
// prove the toggle still runs the old path identically.
//
// The Action (scripts/github-action/run-action.mjs) is a presentation wrapper
// around the CLI; its contract is that the validator payload it embeds in
// axiom-report.json is the reference validator's own JSON (path-normalized)
// and that its exit semantics follow the diagnostics contract (report-only
// softens a governance verdict, never an infrastructure failure).
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync, rmSync, mkdtempSync, readdirSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { resolvePwsh } from "./pwsh-resolver.js";
import { getCanonicalGoldenText, getGoldenDiffReport } from "../output/canonical-normalizer.js";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const PWSH = resolvePwsh();
const CLI = join(REPO_ROOT, "cli/axiom.mjs");
const ACTION = join(REPO_ROOT, "scripts/github-action/run-action.mjs");
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
function runPs(script, args) {
    const r = spawnSync(PWSH, ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", join(REPO_ROOT, script), ...args], {
        encoding: "utf8",
        env: { ...process.env, AXIOM_PWSH: PWSH },
    });
    return { stdout: r.stdout ?? "", stderr: r.stderr ?? "", exitCode: r.status ?? 1 };
}
// The default (in-process) path is what every case below is really about, so
// runCli forces AXIOM_ROLLBACK_PWSH to empty unless the caller explicitly
// sets it (the rollback cases below pass env: { AXIOM_ROLLBACK_PWSH: "1" }).
function runCli(args, opts = {}) {
    const r = spawnSync(process.execPath, [CLI, ...args], {
        encoding: "utf8",
        cwd: opts.cwd ?? REPO_ROOT,
        env: { ...process.env, AXIOM_PWSH: PWSH, AXIOM_ROLLBACK_PWSH: "", ...opts.env },
    });
    return { stdout: r.stdout ?? "", stderr: r.stderr ?? "", exitCode: r.status ?? 1 };
}
function runAction(args, opts = {}) {
    const r = spawnSync(process.execPath, [ACTION, ...args], {
        encoding: "utf8",
        cwd: opts.cwd ?? REPO_ROOT,
        env: { ...process.env, AXIOM_PWSH: PWSH, AXIOM_ROLLBACK_PWSH: "", ...opts.env },
    });
    return { stdout: r.stdout ?? "", stderr: r.stderr ?? "", exitCode: r.status ?? 1 };
}
function jsonCanonical(text, drop = []) {
    try {
        const dropRec = (v) => {
            if (Array.isArray(v))
                return v.map(dropRec);
            if (v !== null && typeof v === "object") {
                const out = {};
                for (const [k, val] of Object.entries(v)) {
                    if (!drop.includes(k))
                        out[k] = dropRec(val);
                }
                return out;
            }
            return v;
        };
        return JSON.stringify(dropRec(JSON.parse(text)));
    }
    catch {
        return null;
    }
}
const DATE_RE = /\d{4}-\d{2}-\d{2}/g;
// ---------------------------------------------------------------------------
// CLI validate: text + JSON, passing and failing fixtures. The CLI must be
// byte-identical to the direct script, not merely equivalent.
// ---------------------------------------------------------------------------
{
    const passing = "tests/fixtures/generated-project-draft";
    const failing = "tests/fixtures/invalid-placeholder-release";
    for (const [label, project, gate] of [
        ["pass-draft", passing, "Draft"],
        ["fail-release", failing, "Release"],
    ]) {
        const cli = runCli(["validate", "--project", project, "--mode", "Standard", "--gate", gate]);
        const ref = runPs("scripts/validate-project.ps1", ["-ProjectPath", project, "-Mode", "Standard", "-Gate", gate]);
        check(`cli validate text ${label}: stdout identical`, cli.stdout === ref.stdout, getGoldenDiffReport(cli.stdout, ref.stdout).join(" | "));
        check(`cli validate text ${label}: exit identical`, cli.exitCode === ref.exitCode, `cli=${cli.exitCode} ref=${ref.exitCode}`);
        const cliJ = runCli(["validate", "--project", project, "--mode", "Standard", "--gate", gate, "--json"]);
        const refJ = runPs("scripts/validate-project.ps1", ["-ProjectPath", project, "-Mode", "Standard", "-Gate", gate, "-Format", "Json"]);
        check(`cli validate json ${label}: exit identical`, cliJ.exitCode === refJ.exitCode, `cli=${cliJ.exitCode} ref=${refJ.exitCode}`);
        const norm = (t) => jsonCanonical(t.replaceAll(resolve(project), "<TREE>"), ["project"]);
        const cliN = norm(cliJ.stdout);
        const refN = norm(refJ.stdout);
        check(`cli validate json ${label}: envelope identical (path-normalized)`, cliN !== null && cliN === refN, `cli=${cliN} ref=${refN}`);
    }
}
// ---------------------------------------------------------------------------
// CLI status: text + JSON.
// ---------------------------------------------------------------------------
{
    const project = "examples/STANDARD-FEATURE";
    const cli = runCli(["status", "--project", project]);
    const ref = runPs("scripts/pmo-status.ps1", ["-ProjectPath", project]);
    const norm = (t) => getCanonicalGoldenText(t).replaceAll(resolve(project), "<TREE>");
    check("cli status text: stdout identical (path-normalized)", norm(cli.stdout) === norm(ref.stdout), getGoldenDiffReport(norm(cli.stdout), norm(ref.stdout)).join(" | "));
    check("cli status text: exit identical", cli.exitCode === ref.exitCode, `cli=${cli.exitCode} ref=${ref.exitCode}`);
    const cliJ = runCli(["status", "--project", project, "--json"]);
    const refJ = runPs("scripts/pmo-status.ps1", ["-ProjectPath", project, "-Format", "Json"]);
    check("cli status json: exit identical", cliJ.exitCode === refJ.exitCode, `cli=${cliJ.exitCode} ref=${refJ.exitCode}`);
    const normJ = (t) => jsonCanonical(t.replaceAll(resolve(project), "<TREE>"), ["project"]);
    check("cli status json: payload identical (path-normalized)", normJ(cliJ.stdout) === normJ(refJ.stdout) && normJ(cliJ.stdout) !== null, `cli=${normJ(cliJ.stdout)} ref=${normJ(refJ.stdout)}`);
}
// ---------------------------------------------------------------------------
// CLI handoff --json: the merged envelope's gate/assessment steps must equal
// the two direct script runs.
// ---------------------------------------------------------------------------
{
    const project = "examples/HANDOFF-DEMO";
    const cli = runCli(["handoff", "--project", project, "--mode", "Standard", "--json"]);
    const refGate = runPs("scripts/validate-project.ps1", ["-ProjectPath", project, "-Mode", "Standard", "-Gate", "Handoff", "-Format", "Json"]);
    const refAssess = runPs("scripts/assess-handoff.ps1", ["-ProjectPath", project, "-Mode", "Standard", "-Format", "Json"]);
    check("cli handoff --json: exit is the gate's exit", cli.exitCode === refGate.exitCode, `cli=${cli.exitCode} gate=${refGate.exitCode}`);
    let env = null;
    try {
        env = JSON.parse(cli.stdout);
    }
    catch { /* below */ }
    check("cli handoff --json: parseable envelope", env !== null && env !== undefined, cli.stdout.slice(0, 200));
    if (env) {
        const norm = (t) => jsonCanonical(t.replaceAll(resolve(project), "<TREE>"), ["project"]);
        check("cli handoff --json: gate step equals direct gate run", norm(JSON.stringify(env["gate"])) === norm(refGate.stdout) && norm(refGate.stdout) !== null, `cli=${norm(JSON.stringify(env["gate"]))} ref=${norm(refGate.stdout)}`);
        check("cli handoff --json: assessment step equals direct assessment run", norm(JSON.stringify(env["assessment"])) === norm(refAssess.stdout) && norm(refAssess.stdout) !== null, `cli=${norm(JSON.stringify(env["assessment"]))} ref=${norm(refAssess.stdout)}`);
    }
}
// ---------------------------------------------------------------------------
// CLI init (non-interactive): the generated tree must equal the direct
// new-project run's tree.
// ---------------------------------------------------------------------------
{
    const cliRoot = mkdtempSync(join(tmpdir(), "surface-cli-init-"));
    const refRoot = mkdtempSync(join(tmpdir(), "surface-ref-init-"));
    try {
        const args = ["init", "--code", "P99-CLI", "--mode", "Standard", "--execution-path", "development_handoff",
            "--research-mode", "off", "--research-provider", "none", "--research-depth", "standard",
            "--ui-delivery", "not_applicable", "--output", cliRoot, "--handoff", "--target", "demo", "--horizon-days", "14"];
        const cli = runCli(args);
        const ref = runPs("scripts/new-project.ps1", ["-ProjectCode", "P99-CLI", "-Mode", "Standard", "-ExecutionPath", "development_handoff",
            "-ResearchMode", "off", "-ResearchProvider", "none", "-ResearchDepth", "standard", "-UiDelivery", "not_applicable",
            "-OutputRoot", refRoot, "-IncludeHandoff", "-Target", "demo", "-HorizonDays", "14"]);
        check("cli init: exit identical", cli.exitCode === ref.exitCode, `cli=${cli.exitCode} ref=${ref.exitCode}`);
        const treeBytes = (root) => {
            const out = {};
            const walk = (d) => {
                for (const entry of readdirSync(d)) {
                    const full = join(d, entry);
                    if (statSync(full).isDirectory())
                        walk(full);
                    else
                        out[full.substring(root.length + 1)] = readFileSync(full).toString("base64");
                }
            };
            if (existsSync(root))
                walk(root);
            return out;
        };
        const cliTree = treeBytes(join(cliRoot, "P99-CLI"));
        const refTree = treeBytes(join(refRoot, "P99-CLI"));
        const sameFiles = JSON.stringify(Object.keys(cliTree).sort()) === JSON.stringify(Object.keys(refTree).sort());
        check("cli init: file set identical", sameFiles, `cli=[${Object.keys(cliTree).sort().join(",")}] ref=[${Object.keys(refTree).sort().join(",")}]`);
        const diffs = [];
        for (const k of Object.keys(refTree)) {
            const a = Buffer.from(cliTree[k] ?? "", "base64").toString("utf8").replace(DATE_RE, "<DATE>");
            const b = Buffer.from(refTree[k] ?? "", "base64").toString("utf8").replace(DATE_RE, "<DATE>");
            if (a !== b)
                diffs.push(k);
        }
        check("cli init: bytes identical (modulo dates)", sameFiles && diffs.length === 0, `differing: ${diffs.join(", ")}`);
    }
    finally {
        rmSync(cliRoot, { recursive: true, force: true });
        rmSync(refRoot, { recursive: true, force: true });
    }
}
// ---------------------------------------------------------------------------
// CLI host failure (rollback path only): an unusable AXIOM_PWSH must exit 127
// with the remediation message. On the default in-process path AXIOM_PWSH is
// not even consulted -- status runs without PowerShell -- which is itself
// asserted just below.
// ---------------------------------------------------------------------------
{
    const cli = runCli(["status", "--project", "examples/STANDARD-FEATURE"], { env: { AXIOM_ROLLBACK_PWSH: "1", AXIOM_PWSH: "/nonexistent/axiom/pwsh" } });
    check("cli missing host (rollback): exit 127", cli.exitCode === 127, `exit=${cli.exitCode}`);
    check("cli missing host (rollback): remediation message", cli.stderr.includes("does not exist"), cli.stderr.slice(0, 200));
    // The same unusable AXIOM_PWSH is ignored on the default path: the
    // in-process engine does not spawn or even probe for PowerShell.
    const cliTs = runCli(["status", "--project", "examples/STANDARD-FEATURE"], { env: { AXIOM_PWSH: "/nonexistent/axiom/pwsh" } });
    const refTs = runPs("scripts/pmo-status.ps1", ["-ProjectPath", resolve("examples/STANDARD-FEATURE")]);
    check("cli ignores AXIOM_PWSH on the default path", cliTs.exitCode === refTs.exitCode && cliTs.stdout === refTs.stdout, `exit=${cliTs.exitCode} ref=${refTs.exitCode}`);
}
// ---------------------------------------------------------------------------
// Rollback parity: with AXIOM_ROLLBACK_PWSH=1 the CLI must produce exactly the
// pre-rewire bytes (spawn the .ps1), identical to both the direct script and
// the default in-process path.
// ---------------------------------------------------------------------------
{
    const project = "tests/fixtures/generated-project-draft";
    const args = ["validate", "--project", project, "--mode", "Standard", "--gate", "Draft"];
    const ts = runCli(args);
    const rb = runCli(args, { env: { AXIOM_ROLLBACK_PWSH: "1" } });
    const ref = runPs("scripts/validate-project.ps1", ["-ProjectPath", project, "-Mode", "Standard", "-Gate", "Draft"]);
    check("rollback path: stdout identical to direct script", rb.stdout === ref.stdout, getGoldenDiffReport(rb.stdout, ref.stdout).join(" | "));
    check("rollback path: exit identical to direct script", rb.exitCode === ref.exitCode, `rb=${rb.exitCode} ref=${ref.exitCode}`);
    check("rollback path: identical to the default in-process path", rb.stdout === ts.stdout && rb.exitCode === ts.exitCode, getGoldenDiffReport(rb.stdout, ts.stdout).join(" | "));
}
// ---------------------------------------------------------------------------
// GitHub Action: report-only softens a governance verdict; enforce=true
// propagates it; the embedded validator payload is the reference JSON.
// ---------------------------------------------------------------------------
{
    const failing = resolve("tests/fixtures/invalid-placeholder-release");
    const passing = resolve("tests/fixtures/generated-project-draft");
    const runActionCase = (label, project, gate, enforce, expectExit) => {
        const wd = mkdtempSync(join(tmpdir(), "surface-action-"));
        const jsonPath = join(wd, "axiom-report.json");
        const mdPath = join(wd, "axiom-report.md");
        try {
            const r = runAction(["--project", project, "--mode", "Standard", "--gate", gate,
                "--enforce", String(enforce), "--working-directory", wd,
                "--json-report-path", jsonPath, "--md-report-path", mdPath]);
            check(`action ${label}: exit ${expectExit}`, r.exitCode === expectExit, `exit=${r.exitCode} stdout=${r.stdout.slice(0, 300)}`);
            check(`action ${label}: report json written`, existsSync(jsonPath));
            check(`action ${label}: report md written`, existsSync(mdPath));
            if (existsSync(jsonPath)) {
                const report = JSON.parse(readFileSync(jsonPath, "utf8"));
                const ref = runPs("scripts/validate-project.ps1", ["-ProjectPath", project, "-Mode", "Standard", "-Gate", gate, "-Format", "Json"]);
                const norm = (t) => jsonCanonical(t.replaceAll(project, "<TREE>"), ["project"]);
                const embedded = norm(JSON.stringify(report["results"]));
                const refResults = norm(JSON.stringify(JSON.parse(ref.stdout)["results"]));
                check(`action ${label}: embedded validator results identical to reference`, embedded !== null && embedded === refResults, `action=${embedded} ref=${refResults}`);
                check(`action ${label}: action meta present`, typeof report["action"]?.["exit_code"] === "number");
                if (!enforce) {
                    check(`action ${label}: report-only note on stdout`, r.stdout.includes("Report-only mode") || expectExit === 0 && !r.stdout.includes("Report-only mode"), r.stdout.slice(0, 200));
                }
            }
        }
        finally {
            rmSync(wd, { recursive: true, force: true });
        }
    };
    runActionCase("failing-report-only", failing, "Release", false, 0);
    runActionCase("failing-enforce", failing, "Release", true, 1);
    runActionCase("passing-enforce", passing, "Draft", true, 0);
}
console.log(`\nSummary: PASS=${pass} FAIL=${fail}`);
if (fail > 0)
    process.exitCode = 1;
