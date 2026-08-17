// Phase 6+7+8 -- final-tree differential gate, CLI + GitHub Action surface.
//
// Phase 7 rewired cli/axiom.mjs to call the ported TS engine in-process, with
// an AXIOM_ROLLBACK_PWSH=1 toggle to fall back to spawning the reference
// .ps1. Phase 8 (DEC-030/031) removed that toggle entirely -- the CLI now
// only ever runs the in-process engine, unconditionally. This probe's job is
// unchanged in spirit: every case below compares the CLI's in-process output
// against the direct reference script, byte for byte. The dedicated rollback-
// specific cases that used to prove the toggle worked were removed along with
// the toggle itself.
//
// The Action (scripts/github-action/run-action.mjs) is a presentation wrapper
// around the CLI; its contract is that the validator payload it embeds in
// axiom-report.json is the reference validator's own JSON (path-normalized)
// and that its exit semantics follow the diagnostics contract (report-only
// softens a governance verdict, never an infrastructure failure).
//
// Phase 9: every runPs() call below used to spawn the PS reference live; it
// now looks up a golden fixture frozen from that reference instead (the
// reference no longer exists to compare against live). Call sites that used
// identical (script, args) pairs share one fixture entry, same as they
// shared one live PS process before conversion.
//
// The fixture was captured on the machine that ran the capture, so any
// absolute path it embeds (validate-project.ps1 and friends print the
// resolved project path in their own banners) is baked in as a "<REPO_ROOT>"
// token rather than that machine's literal checkout path -- otherwise this
// probe would only pass on the exact machine that captured it, and would
// leak that machine's local path into a committed file besides (caught by
// this repo's own check-public-hygiene LOCAL-PATH-002 rule). Substituted
// back to this machine's real REPO_ROOT at load time below.

import { existsSync, mkdirSync, readFileSync, writeFileSync, rmSync, mkdtempSync, readdirSync, statSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { getCanonicalGoldenText, getGoldenDiffReport } from "../output/canonical-normalizer.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const CLI = join(REPO_ROOT, "cli/axiom.mjs");
const ACTION = join(REPO_ROOT, "scripts/github-action/run-action.mjs");
const FIXTURE = resolve(REPO_ROOT, "tests/golden/probes/surface-probe.json");
const REPO_TOKEN = "<REPO_ROOT>";
function detokenize(s: string): string {
  return s.split(REPO_TOKEN).join(REPO_ROOT);
}
const rawGolden = JSON.parse(readFileSync(FIXTURE, "utf8")) as {
  cases: Record<string, { stdout: string; stderr: string; exitCode: number }>;
  init_exit_code: number;
  init_tree: Record<string, string>;
};
const golden = {
  ...rawGolden,
  cases: Object.fromEntries(Object.entries(rawGolden.cases).map(([k, v]) => [k, { ...v, stdout: detokenize(v.stdout), stderr: detokenize(v.stderr) }])),
};

let pass = 0;
let fail = 0;
function check(name: string, ok: boolean, detail = ""): void {
  if (ok) { pass++; console.log(`[PASS] ${name}`); }
  else { fail++; console.log(`[FAIL] ${name}${detail ? " -- " + detail : ""}`); }
}

function goldenCase(label: string): { stdout: string; stderr: string; exitCode: number } {
  const c = golden.cases[label];
  if (!c) throw new Error(`no golden fixture case: ${label}`);
  return c;
}

function runCli(args: string[], opts: { cwd?: string; env?: Record<string, string> } = {}): { stdout: string; stderr: string; exitCode: number } {
  const r = spawnSync(process.execPath, [CLI, ...args], {
    encoding: "utf8",
    cwd: opts.cwd ?? REPO_ROOT,
    env: { ...process.env, ...opts.env },
  });
  return { stdout: r.stdout ?? "", stderr: r.stderr ?? "", exitCode: r.status ?? 1 };
}

function runAction(args: string[], opts: { cwd?: string; env?: Record<string, string> } = {}): { stdout: string; stderr: string; exitCode: number } {
  const r = spawnSync(process.execPath, [ACTION, ...args], {
    encoding: "utf8",
    cwd: opts.cwd ?? REPO_ROOT,
    env: { ...process.env, ...opts.env },
  });
  return { stdout: r.stdout ?? "", stderr: r.stderr ?? "", exitCode: r.status ?? 1 };
}

function jsonCanonical(text: string, drop: string[] = []): string | null {
  try {
    const dropRec = (v: unknown): unknown => {
      if (Array.isArray(v)) return v.map(dropRec);
      if (v !== null && typeof v === "object") {
        const out: Record<string, unknown> = {};
        for (const [k, val] of Object.entries(v as Record<string, unknown>)) {
          if (!drop.includes(k)) out[k] = dropRec(val);
        }
        return out;
      }
      return v;
    };
    return JSON.stringify(dropRec(JSON.parse(text)));
  } catch { return null; }
}

const DATE_RE = /\d{4}-\d{2}-\d{2}/g;

// ---------------------------------------------------------------------------
// CLI validate: text + JSON, passing and failing fixtures. The CLI must be
// byte-identical to the direct script, not merely equivalent.
// ---------------------------------------------------------------------------
{
  const passing = "tests/fixtures/generated-project-draft";
  const failing = "tests/fixtures/invalid-placeholder-release";

  for (const [label, project, gate, textFixture, jsonFixture] of [
    ["pass-draft", passing, "Draft", "validate-text-pass-draft", "validate-json-pass-draft"],
    ["fail-release", failing, "Release", "validate-text-fail-release", "validate-json-fail-release"],
  ] as Array<[string, string, string, string, string]>) {
    const cli = runCli(["validate", "--project", project, "--mode", "Standard", "--gate", gate]);
    const ref = goldenCase(textFixture);
    check(`cli validate text ${label}: stdout identical`, cli.stdout === ref.stdout,
      getGoldenDiffReport(cli.stdout, ref.stdout).join(" | "));
    check(`cli validate text ${label}: exit identical`, cli.exitCode === ref.exitCode, `cli=${cli.exitCode} ref=${ref.exitCode}`);

    const cliJ = runCli(["validate", "--project", project, "--mode", "Standard", "--gate", gate, "--json"]);
    const refJ = goldenCase(jsonFixture);
    check(`cli validate json ${label}: exit identical`, cliJ.exitCode === refJ.exitCode, `cli=${cliJ.exitCode} ref=${refJ.exitCode}`);
    const norm = (t: string) => jsonCanonical(t.replaceAll(resolve(project), "<TREE>"), ["project"]);
    const cliN = norm(cliJ.stdout);
    const refN = norm(refJ.stdout);
    check(`cli validate json ${label}: envelope identical (path-normalized)`, cliN !== null && cliN === refN,
      `cli=${cliN} ref=${refN}`);
  }
}

// ---------------------------------------------------------------------------
// CLI status: text + JSON.
// ---------------------------------------------------------------------------
{
  const project = "examples/STANDARD-FEATURE";
  const cli = runCli(["status", "--project", project]);
  const ref = goldenCase("status-text");
  const norm = (t: string) => getCanonicalGoldenText(t).replaceAll(resolve(project), "<TREE>");
  check("cli status text: stdout identical (path-normalized)", norm(cli.stdout) === norm(ref.stdout),
    getGoldenDiffReport(norm(cli.stdout), norm(ref.stdout)).join(" | "));
  check("cli status text: exit identical", cli.exitCode === ref.exitCode, `cli=${cli.exitCode} ref=${ref.exitCode}`);

  const cliJ = runCli(["status", "--project", project, "--json"]);
  const refJ = goldenCase("status-json");
  check("cli status json: exit identical", cliJ.exitCode === refJ.exitCode, `cli=${cliJ.exitCode} ref=${refJ.exitCode}`);
  const normJ = (t: string) => jsonCanonical(t.replaceAll(resolve(project), "<TREE>"), ["project"]);
  check("cli status json: payload identical (path-normalized)", normJ(cliJ.stdout) === normJ(refJ.stdout) && normJ(cliJ.stdout) !== null,
    `cli=${normJ(cliJ.stdout)} ref=${normJ(refJ.stdout)}`);
}

// ---------------------------------------------------------------------------
// CLI handoff --json: the merged envelope's gate/assessment steps must equal
// the two direct script runs.
// ---------------------------------------------------------------------------
{
  const project = "examples/HANDOFF-DEMO";
  const cli = runCli(["handoff", "--project", project, "--mode", "Standard", "--json"]);
  const refGate = goldenCase("handoff-gate-json");
  const refAssess = goldenCase("handoff-assess-json");
  check("cli handoff --json: exit is the gate's exit", cli.exitCode === refGate.exitCode, `cli=${cli.exitCode} gate=${refGate.exitCode}`);
  let env: Record<string, unknown> | null = null;
  try { env = JSON.parse(cli.stdout); } catch { /* below */ }
  check("cli handoff --json: parseable envelope", env !== null && env !== undefined, cli.stdout.slice(0, 200));
  if (env) {
    const norm = (t: string) => jsonCanonical(t.replaceAll(resolve(project), "<TREE>"), ["project"]);
    check("cli handoff --json: gate step equals direct gate run",
      norm(JSON.stringify(env["gate"])) === norm(refGate.stdout) && norm(refGate.stdout) !== null,
      `cli=${norm(JSON.stringify(env["gate"]))} ref=${norm(refGate.stdout)}`);
    check("cli handoff --json: assessment step equals direct assessment run",
      norm(JSON.stringify(env["assessment"])) === norm(refAssess.stdout) && norm(refAssess.stdout) !== null,
      `cli=${norm(JSON.stringify(env["assessment"]))} ref=${norm(refAssess.stdout)}`);
  }
}

// ---------------------------------------------------------------------------
// CLI init (non-interactive): the generated tree must equal the direct
// new-project run's tree.
// ---------------------------------------------------------------------------
{
  const cliRoot = mkdtempSync(join(tmpdir(), "surface-cli-init-"));
  try {
    const args = ["init", "--code", "P99-CLI", "--mode", "Standard", "--execution-path", "development_handoff",
      "--research-mode", "off", "--research-provider", "none", "--research-depth", "standard",
      "--ui-delivery", "not_applicable", "--output", cliRoot, "--handoff", "--target", "demo", "--horizon-days", "14"];
    const cli = runCli(args);
    const refTree = golden.init_tree;
    check("cli init: exit identical", cli.exitCode === golden.init_exit_code, `cli=${cli.exitCode} ref=${golden.init_exit_code}`);
    const treeBytes = (root: string): Record<string, string> => {
      const out: Record<string, string> = {};
      const walk = (d: string) => {
        for (const entry of readdirSync(d)) {
          const full = join(d, entry);
          if (statSync(full).isDirectory()) walk(full);
          else out[full.substring(root.length + 1)] = readFileSync(full).toString("base64");
        }
      };
      if (existsSync(root)) walk(root);
      return out;
    };
    const cliTree = treeBytes(join(cliRoot, "P99-CLI"));
    const sameFiles = JSON.stringify(Object.keys(cliTree).sort()) === JSON.stringify(Object.keys(refTree).sort());
    check("cli init: file set identical", sameFiles,
      `cli=[${Object.keys(cliTree).sort().join(",")}] ref=[${Object.keys(refTree).sort().join(",")}]`);
    const diffs: string[] = [];
    for (const k of Object.keys(refTree)) {
      const a = Buffer.from(cliTree[k] ?? "", "base64").toString("utf8").replace(DATE_RE, "<DATE>");
      const b = Buffer.from(refTree[k] ?? "", "base64").toString("utf8").replace(DATE_RE, "<DATE>");
      if (a !== b) diffs.push(k);
    }
    check("cli init: bytes identical (modulo dates)", sameFiles && diffs.length === 0, `differing: ${diffs.join(", ")}`);
  } finally {
    rmSync(cliRoot, { recursive: true, force: true });
  }
}

// ---------------------------------------------------------------------------
// AXIOM_PWSH is never consulted post-cutover: the CLI has no PowerShell path
// left to point it at, so an unusable value must have zero effect -- status
// runs the in-process engine exactly as if the variable were unset.
// ---------------------------------------------------------------------------
{
  const cliTs = runCli(["status", "--project", "examples/STANDARD-FEATURE"], { env: { AXIOM_PWSH: "/nonexistent/axiom/pwsh" } });
  const refTs = goldenCase("status-text-abspath");
  check("cli ignores AXIOM_PWSH entirely (no rollback path left to use it)", cliTs.exitCode === refTs.exitCode && cliTs.stdout === refTs.stdout,
    `exit=${cliTs.exitCode} ref=${refTs.exitCode}`);
}

// ---------------------------------------------------------------------------
// AXIOM_ROLLBACK_PWSH=1 is inert post-cutover: setting it must change nothing
// -- the CLI still runs the in-process engine and matches the reference.
// ---------------------------------------------------------------------------
{
  const project = "tests/fixtures/generated-project-draft";
  const args = ["validate", "--project", project, "--mode", "Standard", "--gate", "Draft"];
  const ts = runCli(args);
  const withStaleToggle = runCli(args, { env: { AXIOM_ROLLBACK_PWSH: "1" } });
  const ref = goldenCase("validate-text-pass-draft");
  check("cli matches reference regardless of AXIOM_ROLLBACK_PWSH", withStaleToggle.stdout === ref.stdout && withStaleToggle.exitCode === ref.exitCode,
    getGoldenDiffReport(withStaleToggle.stdout, ref.stdout).join(" | "));
  check("AXIOM_ROLLBACK_PWSH=1 produces byte-identical output to it being unset", withStaleToggle.stdout === ts.stdout && withStaleToggle.exitCode === ts.exitCode,
    getGoldenDiffReport(withStaleToggle.stdout, ts.stdout).join(" | "));
}

// ---------------------------------------------------------------------------
// GitHub Action: report-only softens a governance verdict; enforce=true
// propagates it; the embedded validator payload is the reference JSON.
// ---------------------------------------------------------------------------
{
  const failing = resolve("tests/fixtures/invalid-placeholder-release");
  const passing = resolve("tests/fixtures/generated-project-draft");

  const runActionCase = (label: string, project: string, gate: string, enforce: boolean, expectExit: number, refFixture: string) => {
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
        const report = JSON.parse(readFileSync(jsonPath, "utf8")) as Record<string, unknown>;
        const ref = goldenCase(refFixture);
        const norm = (t: string) => jsonCanonical(t.replaceAll(project, "<TREE>"), ["project"]);
        const embedded = norm(JSON.stringify(report["results"]));
        const refResults = norm(JSON.stringify((JSON.parse(ref.stdout) as Record<string, unknown>)["results"]));
        check(`action ${label}: embedded validator results identical to reference`, embedded !== null && embedded === refResults,
          `action=${embedded} ref=${refResults}`);
        check(`action ${label}: action meta present`, typeof (report["action"] as Record<string, unknown>)?.["exit_code"] === "number");
        if (!enforce) {
          check(`action ${label}: report-only note on stdout`, r.stdout.includes("Report-only mode") || expectExit === 0 && !r.stdout.includes("Report-only mode"),
            r.stdout.slice(0, 200));
        }
      }
    } finally {
      rmSync(wd, { recursive: true, force: true });
    }
  };

  runActionCase("failing-report-only", failing, "Release", false, 0, "validate-json-fail-release");
  runActionCase("failing-enforce", failing, "Release", true, 1, "validate-json-fail-release");
  runActionCase("passing-enforce", passing, "Draft", true, 0, "validate-json-pass-draft");
}

console.log(`\nSummary: PASS=${pass} FAIL=${fail}`);
if (fail > 0) process.exitCode = 1;
