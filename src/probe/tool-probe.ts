// Phase 6 -- final-tree differential gate, tool surface (deterministic half).
//
// The validator-surface report (differential-probe, execution-probe, marker-*,
// doctor-probe, stateful-probe, setup-probe) proves rule-level parity. This
// probe closes the gap the old report's "Remaining" section listed: the
// orchestrators/tools in src/tools/ that were ported in Phase 5 but never
// differentially exercised against their own PowerShell entrypoint.
//
// Same discipline as differential-probe: direct candidate (the ported TS
// function, in-process) compared against a golden fixture frozen from the
// direct reference (pwsh -File the real script) on identical fixtures
// (Phase 9: the reference no longer exists to compare against live). Outputs
// are compared canonically (golden normalizer), or as parsed JSON when the
// two sides legitimately emit JSON (key order is not a contract for a JSON
// consumer), or byte-for-byte where the reference itself is deterministic.

import { readFileSync, writeFileSync, mkdirSync, rmSync, mkdtempSync, cpSync, existsSync, readdirSync, statSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { getCanonicalGoldenText, getGoldenDiffReport } from "../output/canonical-normalizer.js";

import { runPmoStatus } from "../tools/pmo-status.js";
import { runAssessHandoff } from "../tools/assess-handoff.js";
import { resolveCiProfile } from "../tools/ci-profile.js";
import { measureContext, formatContextTable } from "../tools/measure-context.js";
import { hookScopeAdvisory } from "../tools/hook-scope-advisory.js";
import { checkPublicHygiene } from "../tools/check-public-hygiene.js";
import { buildPluginPackage } from "../tools/build-plugin-package.js";
import { runDemo } from "../tools/demo.js";
import { runAllChecks } from "../tools/run-all-checks.js";
import { resolveCiSuite } from "../tools/run-ci-suite.js";
import { preparePublicRelease } from "../tools/prepare-public-release.js";
import { designProviderDigest, handoffDigest, visualProofDigest } from "../tools/digest-tools.js";
import { updateSourceSnapshot } from "../tools/update-source-snapshot.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const FIXTURE = resolve(REPO_ROOT, "tests/golden/probes/tool-probe.json");

// The fixture was captured on the machine that ran the capture; any
// REPO_ROOT-rooted absolute path it embeds (validate-project.ps1 and
// friends print the resolved project path in their own banners) was baked
// in as a "<REPO_ROOT>" token rather than that machine's literal checkout
// path -- otherwise this probe would only pass on the exact machine that
// captured it, and would leak that machine's local path into a committed
// file besides (caught by this repo's own check-public-hygiene
// LOCAL-PATH-002 rule). Substituted back to this machine's real REPO_ROOT
// at load time. A handful of run-ci-suite cases also carry a "<LOCAL_PATH>"
// token in place of the capture machine's resolved pwsh host executable;
// that token is never substituted back because the probe's own comparison
// for those cases already discards the first (host executable) token
// before comparing, so what it says has never mattered.
const REPO_TOKEN = "<REPO_ROOT>";
function detokenize(s: string): string {
  return s.split(REPO_TOKEN).join(REPO_ROOT);
}

interface PsRun { stdout: string; stderr: string; exitCode: number; }
interface GoldenCase { stdout?: string; stdout_normalized?: string; exitCode?: number; ref_is_empty?: boolean; }
const rawGolden = JSON.parse(readFileSync(FIXTURE, "utf8")) as { cases: Record<string, GoldenCase> };
const golden = {
  cases: Object.fromEntries(Object.entries(rawGolden.cases).map(([k, v]) => [k, {
    ...v,
    stdout: v.stdout !== undefined ? detokenize(v.stdout) : undefined,
    stdout_normalized: v.stdout_normalized !== undefined ? detokenize(v.stdout_normalized) : undefined,
  }])),
};

function goldenCase(key: string): PsRun {
  const c = golden.cases[key];
  if (!c || c.stdout === undefined) throw new Error(`no golden fixture case: ${key}`);
  return { stdout: c.stdout, stderr: "", exitCode: c.exitCode ?? 1 };
}
// For cases whose comparison text was normalized (temp-dir path replaced with
// <TREE>) at capture time -- the candidate's own output must be normalized
// the same way before comparing against these.
function goldenNormalized(key: string): { stdout_normalized: string; exitCode: number } {
  const c = golden.cases[key];
  if (!c || c.stdout_normalized === undefined) throw new Error(`no golden normalized case: ${key}`);
  return { stdout_normalized: c.stdout_normalized, exitCode: c.exitCode ?? 1 };
}

let pass = 0;
let fail = 0;
function check(name: string, ok: boolean, detail = ""): void {
  if (ok) { pass++; console.log(`[PASS] ${name}`); }
  else { fail++; console.log(`[FAIL] ${name}${detail ? " -- " + detail : ""}`); }
}

function deepSortKeys(v: unknown): unknown {
  if (Array.isArray(v)) return v.map(deepSortKeys);
  if (v !== null && typeof v === "object") {
    const out: Record<string, unknown> = {};
    for (const k of Object.keys(v as Record<string, unknown>).sort()) out[k] = deepSortKeys((v as Record<string, unknown>)[k]);
    return out;
  }
  return v;
}

function jsonCanonical(text: string): string | null {
  try { return JSON.stringify(deepSortKeys(JSON.parse(text))); } catch { return null; }
}

function compareOutputs(name: string, ref: PsRun, cand: { output: string; exitCode: number }): void {
  const refCanon = getCanonicalGoldenText(ref.stdout);
  const candCanon = getCanonicalGoldenText(cand.output);
  const same = refCanon === candCanon;
  const exitSame = (ref.exitCode ?? 1) === (cand.exitCode ?? 1);
  check(`${name}: output`, same, same ? "" : getGoldenDiffReport(refCanon, candCanon).join(" | "));
  check(`${name}: exit`, exitSame, `reference=${ref.exitCode} candidate=${cand.exitCode}`);
}

// ---------------------------------------------------------------------------
// ci-profile: pure classifier, JSON on stdout, no I/O.
// ---------------------------------------------------------------------------
{
  // -File array binding only ever binds the FIRST value of a -ChangedPaths
  // list (later values fall through to -Profile's ValidateSet and error), so
  // multi-path cases go through -ChangedPathsPath (one path per line), exactly
  // the reference's own documented alternative. Single-path cases use the
  // named parameter directly.
  const ciCases: Array<{ label: string; key: string; paths: string[] }> = [
    { label: "mixed", key: "ci-mixed", paths: ["src/core/context.ts", "docs/foo.md", "tests/a.test.ts"] },
    { label: "high-risk validator", key: "ci-high-risk-validator", paths: ["src/tools/run-all-checks.ts"] },
    { label: "empty (default fast)", key: "ci-empty", paths: [] },
    { label: "cli + example", key: "ci-cli-example", paths: ["cli/axiom.mjs", "examples/x"] },
    { label: "windows backslash path", key: "ci-windows-backslash", paths: ["src\\core\\context.ts"] },
  ];
  for (const c of ciCases) {
    const ref = goldenCase(c.key);
    const cand = resolveCiProfile(c.paths);
    const candJson = JSON.stringify(cand);
    const refJson = jsonCanonical(ref.stdout);
    check(`ci-profile ${c.label}: JSON matches`, refJson === jsonCanonical(candJson), `ref=${refJson} cand=${jsonCanonical(candJson)}`);
    check(`ci-profile ${c.label}: exit 0`, ref.exitCode === 0, `exit ${ref.exitCode}`);
  }
}

// ---------------------------------------------------------------------------
// pmo-status: read-only report; JSON deep-equal + Text canonical.
// ---------------------------------------------------------------------------
{
  const fixtures = [
    { label: "standard", key: "status-standard-json", path: join(REPO_ROOT, "examples/STANDARD-FEATURE") },
    { label: "strict-escalation", key: "status-strict-escalation-json", path: join(REPO_ROOT, "examples/STRICT-HIGH-RISK") },
    { label: "handoff-demo", key: "status-handoff-demo-json", path: join(REPO_ROOT, "examples/HANDOFF-DEMO") },
  ];
  for (const f of fixtures) {
    const ref = goldenCase(f.key);
    const cand = runPmoStatus(REPO_ROOT, f.path, "Json");
    const refCanon = jsonCanonical(ref.stdout);
    const candCanon = jsonCanonical(cand.output);
    check(`pmo-status ${f.label} json: equal`, refCanon === candCanon && refCanon !== null,
      refCanon === candCanon ? "" : `ref=${refCanon} cand=${candCanon}`);
    check(`pmo-status ${f.label} json: exit`, (ref.exitCode ?? 1) === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
  }
  // Text format on one fixture (canonical, path-normalized already since both
  // sides print the same absolute fixture path).
  {
    const path = join(REPO_ROOT, "examples/HANDOFF-DEMO");
    const ref = goldenCase("status-handoff-demo-text");
    const cand = runPmoStatus(REPO_ROOT, path, "Text");
    const refCanon = getCanonicalGoldenText(ref.stdout);
    const candCanon = getCanonicalGoldenText(cand.output);
    check("pmo-status handoff-demo text: equal", refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
    check("pmo-status handoff-demo text: exit", (ref.exitCode ?? 1) === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
  }
  // A directory that exists but has no PROJECT.md: the reference treats it as
  // a real project whose STRUCT-001 finding is the "next required" answer.
  {
    const dir = mkdtempSync(join(tmpdir(), "tool-probe-status-"));
    try {
      const ref = goldenNormalized("status-empty-dir-json");
      const cand = runPmoStatus(REPO_ROOT, dir, "Json");
      const refCanon = jsonCanonical(ref.stdout_normalized);
      const candCanon = jsonCanonical(cand.output.replaceAll(dir, "<TREE>"));
      check("pmo-status empty-dir json: equal", refCanon === candCanon && refCanon !== null,
        refCanon === candCanon ? "" : `ref=${refCanon} cand=${candCanon}`);
      check("pmo-status empty-dir json: exit", ref.exitCode === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  }
}

// ---------------------------------------------------------------------------
// assess-handoff: gate + review + score. JSON deep-equal + Text canonical.
// ---------------------------------------------------------------------------
{
  const cases = [
    { label: "handoff-demo json", key: "assess-handoff-demo-json", path: join(REPO_ROOT, "examples/HANDOFF-DEMO"), format: "Json" as const },
    { label: "valid-handoff-strict json", key: "assess-valid-handoff-strict-json", path: join(REPO_ROOT, "tests/fixtures/valid-handoff-strict"), format: "Json" as const },
    { label: "invalid-handoff-missing text", key: "assess-invalid-handoff-missing-text", path: join(REPO_ROOT, "tests/fixtures/invalid-handoff-missing"), format: "Text" as const },
  ];
  for (const c of cases) {
    const ref = goldenCase(c.key);
    const cand = runAssessHandoff(REPO_ROOT, c.path, "Standard", c.format);
    if (c.format === "Json") {
      const refCanon = jsonCanonical(ref.stdout);
      const candCanon = jsonCanonical(cand.output);
      check(`assess-handoff ${c.label}: equal`, refCanon === candCanon && refCanon !== null,
        refCanon === candCanon ? "" : `ref=${refCanon} cand=${candCanon}`);
    } else {
      const refCanon = getCanonicalGoldenText(ref.stdout);
      const candCanon = getCanonicalGoldenText(cand.output);
      check(`assess-handoff ${c.label}: equal`, refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
    }
    check(`assess-handoff ${c.label}: exit`, (ref.exitCode ?? 1) === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
  }
}

// ---------------------------------------------------------------------------
// digest tools: deterministic hash reports; exact byte comparison.
// ---------------------------------------------------------------------------
{
  const vp = join(REPO_ROOT, "examples/DESIGN-SYSTEM-DEMO");
  {
    const ref = goldenCase("visual-proof-digest");
    const cand = visualProofDigest(REPO_ROOT, vp);
    check("visual-proof-digest: output", getCanonicalGoldenText(ref.stdout) === getCanonicalGoldenText(cand.output),
      getGoldenDiffReport(getCanonicalGoldenText(ref.stdout), getCanonicalGoldenText(cand.output)).join(" | "));
    check("visual-proof-digest: exit", ref.exitCode === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
  }
  const hd = join(REPO_ROOT, "examples/HANDOFF-DEMO");
  for (const which of ["Both", "Source", "ReviewInputs"] as const) {
    const ref = goldenCase(`handoff-digest-${which}`);
    const cand = handoffDigest(REPO_ROOT, hd, which);
    check(`handoff-digest ${which}: output`, getCanonicalGoldenText(ref.stdout) === getCanonicalGoldenText(cand.output),
      getGoldenDiffReport(getCanonicalGoldenText(ref.stdout), getCanonicalGoldenText(cand.output)).join(" | "));
    check(`handoff-digest ${which}: exit`, ref.exitCode === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
  }
  const dp = join(REPO_ROOT, "examples/OPTIONAL-TRACKS");
  {
    const ref = goldenCase("design-provider-digest");
    const cand = designProviderDigest(REPO_ROOT, dp);
    check("design-provider-digest: output", getCanonicalGoldenText(ref.stdout) === getCanonicalGoldenText(cand.output),
      getGoldenDiffReport(getCanonicalGoldenText(ref.stdout), getCanonicalGoldenText(cand.output)).join(" | "));
    check("design-provider-digest: exit", ref.exitCode === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
  }
}

// ---------------------------------------------------------------------------
// measure-context: Format-Table output; ANSI stripped on the reference side,
// then byte-for-byte against the port's Format-Table replica.
// ---------------------------------------------------------------------------
{
  const defaultFiles = ["AGENTS.md", "CLAUDE.md", "CONTEXT-ROUTER.md", "pmo-config/context-map.json", "pmo-config/policy.json"];
  {
    const ref = goldenCase("measure-context-default");
    const cand = formatContextTable(measureContext(REPO_ROOT, defaultFiles));
    check("measure-context default files: output", ref.stdout === cand, getGoldenDiffReport(getCanonicalGoldenText(ref.stdout), getCanonicalGoldenText(cand)).join(" | "));
    check("measure-context default files: exit", ref.exitCode === 0, `exit ${ref.exitCode}`);
  }
  {
    const ref = goldenCase("measure-context-single");
    const cand = formatContextTable(measureContext(REPO_ROOT, ["AGENTS.md"]));
    check("measure-context single file: output", ref.stdout === cand, getGoldenDiffReport(getCanonicalGoldenText(ref.stdout), getCanonicalGoldenText(cand)).join(" | "));
  }
}

// ---------------------------------------------------------------------------
// hook-scope-advisory: report-only advisory; JSON bytes or silence.
// ---------------------------------------------------------------------------
function advisoryProject(optIn: boolean): { dir: string; payload: string } {
  const dir = mkdtempSync(join(tmpdir(), "tool-probe-advisory-"));
  mkdirSync(join(dir, "src/payments"), { recursive: true });
  writeFileSync(join(dir, "PROJECT.md"), "# P-ADV\n");
  writeFileSync(join(dir, "SCOPE.json"), JSON.stringify({
    schema_version: "1.0",
    project: "P-ADV",
    implementation_scope: { include: ["src/payments/**"], exclude: [] },
  }));
  if (optIn) {
    mkdirSync(join(dir, ".axiom"), { recursive: true });
    writeFileSync(join(dir, ".axiom/hooks.json"), JSON.stringify({ scope_advisory: true }));
  }
  const payload = JSON.stringify({ cwd: dir, tool_input: { file_path: "src/reporting/export.ts" } });
  return { dir, payload };
}
{
  const { dir, payload } = advisoryProject(true);
  try {
    const ref = goldenNormalized("hook-advisory-out-of-scope");
    const cand = hookScopeAdvisory(dir, payload);
    const candN = cand.output.replaceAll(dir, "<TREE>");
    check("hook-advisory out-of-scope: output", getCanonicalGoldenText(ref.stdout_normalized) === getCanonicalGoldenText(candN),
      getGoldenDiffReport(getCanonicalGoldenText(ref.stdout_normalized), getCanonicalGoldenText(candN)).join(" | "));
    check("hook-advisory out-of-scope: exit", ref.exitCode === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
  } finally { rmSync(dir, { recursive: true, force: true }); }
}
{
  const dir = mkdtempSync(join(tmpdir(), "tool-probe-advisory-"));
  try {
    mkdirSync(join(dir, "src/payments"), { recursive: true });
    writeFileSync(join(dir, "PROJECT.md"), "# P-ADV\n");
    writeFileSync(join(dir, "SCOPE.json"), JSON.stringify({
      schema_version: "1.0", project: "P-ADV",
      implementation_scope: { include: ["src/payments/**"], exclude: [] },
    }));
    mkdirSync(join(dir, ".axiom"), { recursive: true });
    writeFileSync(join(dir, ".axiom/hooks.json"), JSON.stringify({ scope_advisory: true }));
    const payload = JSON.stringify({ cwd: dir, tool_input: { file_path: "src/payments/charge.ts" } });
    const ref = golden.cases["hook-advisory-in-scope-silent"]!;
    const cand = hookScopeAdvisory(dir, payload);
    check("hook-advisory in-scope: silent on both sides", ref.ref_is_empty === true && cand.output === "", `ref_is_empty=${ref.ref_is_empty} cand=[${cand.output}]`);
  } finally { rmSync(dir, { recursive: true, force: true }); }
}
{
  const { dir, payload } = advisoryProject(false);
  try {
    const ref = golden.cases["hook-advisory-no-opt-in-silent"]!;
    const cand = hookScopeAdvisory(dir, payload);
    check("hook-advisory no-opt-in: silent on both sides", ref.ref_is_empty === true && cand.output === "", `ref_is_empty=${ref.ref_is_empty} cand=[${cand.output}]`);
  } finally { rmSync(dir, { recursive: true, force: true }); }
}

// ---------------------------------------------------------------------------
// check-public-hygiene: scans tracked files of the framework repo itself.
// ---------------------------------------------------------------------------
{
  const ref = goldenCase("check-public-hygiene");
  const cand = checkPublicHygiene(REPO_ROOT);
  const refCanon = getCanonicalGoldenText(ref.stdout);
  const candCanon = getCanonicalGoldenText(cand.output);
  check("check-public-hygiene: output", refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
  check("check-public-hygiene: exit", ref.exitCode === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
}

// ---------------------------------------------------------------------------
// build-plugin-package: -Check against the real repo, plus a drifted mirror
// and a fresh generate, both on a temp copy (the script resolves its roots
// from $PSScriptRoot/.. so the copy carries its own .claude/skills + skills).
// ---------------------------------------------------------------------------
{
  const ref = goldenCase("build-plugin-package-check-synced");
  const cand = buildPluginPackage(REPO_ROOT, true);
  const refCanon = getCanonicalGoldenText(ref.stdout);
  const candCanon = getCanonicalGoldenText(cand.output);
  check("build-plugin-package -Check (synced): output", refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
  check("build-plugin-package -Check (synced): exit", ref.exitCode === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
}
function pluginTree(desync: boolean): string {
  const dir = mkdtempSync(join(tmpdir(), "tool-probe-plugin-"));
  cpSync(join(REPO_ROOT, ".claude/skills"), join(dir, ".claude/skills"), { recursive: true });
  cpSync(join(REPO_ROOT, ".claude/skills"), join(dir, "skills"), { recursive: true });
  if (desync) {
    // Modify one mirrored file so the mirror no longer matches the source.
    const srcRoot = join(REPO_ROOT, ".claude/skills");
    const walk = (d: string): string | null => {
      for (const e of ["SKILL.md", "skill.md", "skill.yml"]) {
        if (existsSync(join(d, e))) return join(d, e);
      }
      const entries = ["pmo-intake", "pmo-scope", "pmo-release"].map((s) => join(d, s)).filter((p) => existsSync(p));
      for (const sub of entries) {
        const found = walk(sub);
        if (found) return found;
      }
      return null;
    };
    const srcFile = walk(srcRoot);
    if (!srcFile) throw new Error("no SKILL.md found under .claude/skills");
    const rel = srcFile.substring(srcRoot.length);
    writeFileSync(join(dir, "skills", rel), readFileSync(srcFile, "utf8") + "\n# drifted\n");
  }
  return dir;
}
function treeSnapshot(root: string, sub: string): Record<string, string> {
  const out: Record<string, string> = {};
  const base = join(root, sub);
  const walk = (d: string) => {
    for (const entry of readdirSync(d)) {
      const full = join(d, entry);
      if (statSync(full).isDirectory()) walk(full);
      else out[full.substring(base.length).replace(/^[/\\]/, "")] = readFileSync(full).toString("base64");
    }
  };
  if (existsSync(base)) walk(base);
  return out;
}
{
  const dir = pluginTree(true);
  try {
    const refCopy = goldenNormalized("build-plugin-package-check-drifted");
    const cand = buildPluginPackage(dir, true);
    const refCanon = getCanonicalGoldenText(refCopy.stdout_normalized);
    const candCanon = getCanonicalGoldenText(cand.output.replaceAll(dir, "<TREE>"));
    check("build-plugin-package -Check (drifted): output", refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
    check("build-plugin-package -Check (drifted): exit", refCopy.exitCode === cand.exitCode, `ref=${refCopy.exitCode} cand=${cand.exitCode}`);
  } finally { rmSync(dir, { recursive: true, force: true }); }
}
{
  const dir = pluginTree(false);
  try {
    rmSync(join(dir, "skills"), { recursive: true, force: true });
    const ref = goldenNormalized("build-plugin-package-generate");
    const cand = buildPluginPackage(dir, false);
    const refCanon = getCanonicalGoldenText(ref.stdout_normalized);
    const candCanon = getCanonicalGoldenText(cand.output.replaceAll(dir, "<TREE>"));
    check("build-plugin-package generate: output", refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
    check("build-plugin-package generate: exit", ref.exitCode === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
    const refSnap = treeSnapshot(dir, "skills");
    const candSnap = treeSnapshot(dir, "skills");
    const sameFiles = JSON.stringify(Object.keys(refSnap).sort()) === JSON.stringify(Object.keys(candSnap).sort());
    const sameBytes = Object.keys(refSnap).every((k) => refSnap[k] === candSnap[k]);
    check("build-plugin-package generate: file set identical", sameFiles);
    check("build-plugin-package generate: bytes identical", sameBytes);
  } finally { rmSync(dir, { recursive: true, force: true }); }
}

// ---------------------------------------------------------------------------
// update-source-snapshot: -DryRun (timestamp modulo).
// ---------------------------------------------------------------------------
{
  const dir = mkdtempSync(join(tmpdir(), "tool-probe-snapshot-"));
  try {
    mkdirSync(join(dir, "source/REQ"), { recursive: true });
    writeFileSync(join(dir, "source/REQ/REQ-0001.md"), "# REQ-0001\n");
    writeFileSync(join(dir, "PROJECT.md"), [
      "# P99-SNAP",
      "",
      "## Source Snapshot",
      "",
      "| Source ID | Version / Date | SHA256 | Last Synced At |",
      "|---|---|---|---|",
      "| REQ-0001 | v1 | deadbeef | 2026-01-01T00:00:00Z |",
      "",
      "## Other",
      "x",
      "",
    ].join("\n"));
    const ref = goldenNormalized("update-source-snapshot-dryrun");
    const cand = updateSourceSnapshot(dir, true);
    const norm = (s: string) => getCanonicalGoldenText(s).replaceAll(dir, "<TREE>").replace(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:\d{2})/g, "<TS>");
    const refN = norm(ref.stdout_normalized);
    const candN = norm(cand.output);
    check("update-source-snapshot -DryRun: output", refN === candN, getGoldenDiffReport(refN, candN).join(" | "));
    check("update-source-snapshot -DryRun: exit", ref.exitCode === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
  } finally { rmSync(dir, { recursive: true, force: true }); }
}

// ---------------------------------------------------------------------------
// prepare-public-release: non-destructive readiness, on the repo itself.
// ---------------------------------------------------------------------------
{
  const ref = goldenCase("prepare-public-release");
  const cand = preparePublicRelease(REPO_ROOT, false);
  // The "Working tree" section reports live `git status --porcelain`, and the
  // Verdict section's dirty-tree note depends on it -- inherently as
  // non-reproducible as a timestamp during active development, so both are
  // normalized out rather than compared byte-for-byte like the rest of the
  // report.
  const normTree = (s: string) => s
    .replace(/== Working tree ==\n[\s\S]*?(?=\n==)/, "== Working tree ==\n<LIVE_STATUS>")
    .replace(/\n\s*note: Working tree has uncommitted changes.*$/m, "");
  const refCanon = getCanonicalGoldenText(normTree(ref.stdout));
  const candCanon = getCanonicalGoldenText(normTree(cand.output));
  check("prepare-public-release: output", refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
  check("prepare-public-release: exit", ref.exitCode === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
}

// ---------------------------------------------------------------------------
// run-ci-suite: -ResolveOnly mapping (host prefix normalized) + unknown suite.
// ---------------------------------------------------------------------------
{
  // "golden" is intentionally absent: tests/golden/capture-examples.ps1 was
  // retired with the reference (Phase 9), its coverage carried by
  // differential-probe.ts and validation-fixtures.ts.
  const suites = ["doctor", "hygiene", "validation-fixtures", "config-mutation", "line-ending", "plugin-drift", "cli", "github-action", "all"];
  for (const suite of suites) {
    const ref = goldenCase(`run-ci-suite-${suite}`);
    const cand = resolveCiSuite(REPO_ROOT, suite);
    if ("error" in cand) {
      check(`run-ci-suite ${suite}: no error from candidate`, false, cand.error);
      continue;
    }
    // The reference prints the resolved host executable (absolute path or
    // `node`) and an ABSOLUTE script target; the candidate's contract is
    // command + args with a repo-relative target. Compare from the first
    // option onward, prefixing repo-relative targets so both sides name the
    // same absolute script, with the repo root normalized out.
    // The reference prints an absolute target for PowerShell suites (its
    // suiteMap joins $repo in) but leaves node-suite targets relative.
    const absify = (a: string) =>
      cand.cmd === "pwsh" && (a.startsWith("scripts/") || a.startsWith("tests/") || a.startsWith("cli/") || a.startsWith("src/"))
        ? `<REPO>/${a}`
        : a;
    const candLine = cand.args.map(absify).join(" ").replaceAll(REPO_ROOT, "<REPO>");
    const refLine = ref.stdout.trim().replace(/^\S+\s+/, "").replaceAll(REPO_ROOT, "<REPO>");
    check(`run-ci-suite ${suite}: resolve line`, refLine === candLine, `ref=[${refLine}] cand=[${candLine}]`);
  }
  {
    const ref = goldenCase("run-ci-suite-bogus");
    const cand = resolveCiSuite(REPO_ROOT, "bogus");
    const refCanon = getCanonicalGoldenText(ref.stdout);
    check("run-ci-suite unknown suite: message", "error" in cand && refCanon === getCanonicalGoldenText(cand.error + "\n"), `ref=[${refCanon}] cand=${"error" in cand ? cand.error : "no error"}`);
    check("run-ci-suite unknown suite: exit 1", ref.exitCode === 1, `exit ${ref.exitCode}`);
  }
}

// ---------------------------------------------------------------------------
// demo: full transcript, -Plain -NoPause. Both sides spawn the same child
// validators, so this doubles as a Text-report parity check.
// ---------------------------------------------------------------------------
{
  const ref = goldenCase("demo");
  const cand = runDemo(REPO_ROOT, true, true);
  const refCanon = getCanonicalGoldenText(ref.stdout);
  const candCanon = getCanonicalGoldenText(cand.output);
  check("demo: output", refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
  check("demo: exit", ref.exitCode === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
}

// ---------------------------------------------------------------------------
// run-all-checks: fault-injection path. Both sides stop at the first failing
// child with identical framing (the full-pass framing is the same code path
// with zero-length child output, covered by the checks below it).
// ---------------------------------------------------------------------------
{
  const ref = goldenCase("run-all-checks-fault-injection");
  const cand = runAllChecks(REPO_ROOT, "tests/helpers/exit-1.mjs");
  const refCanon = getCanonicalGoldenText(ref.stdout);
  const candCanon = getCanonicalGoldenText(cand.output);
  check("run-all-checks fault-injection: output", refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
  check("run-all-checks fault-injection: exit 1", ref.exitCode === cand.exitCode && cand.exitCode === 1, `ref=${ref.exitCode} cand=${cand.exitCode}`);
}

// ---------------------------------------------------------------------------
// CLI: the wrapper forwards to the same scripts, so the compatibility case is
// CLI-vs-direct-script parity (the wrapper must add nothing and drop nothing).
// ---------------------------------------------------------------------------
function runCli(args: string[], opts: { cwd?: string } = {}): { stdout: string; stderr: string; exitCode: number } {
  const r = spawnSync(process.execPath, [join(REPO_ROOT, "cli/axiom.mjs"), ...args], {
    encoding: "utf8",
    cwd: opts.cwd ?? REPO_ROOT,
    env: { ...process.env },
  });
  return { stdout: r.stdout ?? "", stderr: r.stderr ?? "", exitCode: r.status ?? 1 };
}
{
  const hd = join(REPO_ROOT, "examples/HANDOFF-DEMO");
  const cli = runCli(["status", "--project", hd, "--json"]);
  const direct = goldenCase("status-handoff-demo-json");
  check("cli status --json: output equals direct script", getCanonicalGoldenText(cli.stdout) === getCanonicalGoldenText(direct.stdout),
    getGoldenDiffReport(getCanonicalGoldenText(cli.stdout), getCanonicalGoldenText(direct.stdout)).join(" | "));
  check("cli status --json: exit equals direct", cli.exitCode === direct.exitCode, `cli=${cli.exitCode} direct=${direct.exitCode}`);

  const sf = join(REPO_ROOT, "examples/STANDARD-FEATURE");
  const cliV = runCli(["validate", "--project", sf, "--gate", "Release", "--json"]);
  const directV = goldenCase("validate-standard-feature-release-json");
  check("cli validate --json: output equals direct script", getCanonicalGoldenText(cliV.stdout) === getCanonicalGoldenText(directV.stdout),
    getGoldenDiffReport(getCanonicalGoldenText(cliV.stdout), getCanonicalGoldenText(directV.stdout)).join(" | "));
  check("cli validate --json: exit equals direct", cliV.exitCode === directV.exitCode, `cli=${cliV.exitCode} direct=${directV.exitCode}`);

  const cliH = runCli(["handoff", "--project", hd, "--json"]);
  const gateDirect = goldenCase("validate-handoff-demo-handoff-json");
  const assessDirect = goldenCase("assess-handoff-demo-json");
  let envelope: Record<string, unknown> | null = null;
  try { envelope = JSON.parse(cliH.stdout); } catch {}
  check("cli handoff --json: envelope parses", envelope !== null);
  if (envelope) {
    check("cli handoff --json: gate payload equals direct", jsonCanonical(JSON.stringify(envelope["gate"])) === jsonCanonical(gateDirect.stdout),
      `envelope gate vs direct: ${jsonCanonical(JSON.stringify(envelope["gate"]))} != ${jsonCanonical(gateDirect.stdout)}`);
    check("cli handoff --json: assessment payload equals direct", jsonCanonical(JSON.stringify(envelope["assessment"])) === jsonCanonical(assessDirect.stdout),
      `envelope assessment vs direct: ${jsonCanonical(JSON.stringify(envelope["assessment"]))} != ${jsonCanonical(assessDirect.stdout)}`);
    check("cli handoff --json: exit is the gate's exit", cliH.exitCode === gateDirect.exitCode, `cli=${cliH.exitCode} gate=${gateDirect.exitCode}`);
  }

  const unknown = runCli(["bogus"]);
  check("cli unknown command: exit 64", unknown.exitCode === 64, `exit ${unknown.exitCode}`);
  check("cli unknown command: stderr names it", unknown.stderr.includes("Unknown command: bogus"), `stderr=[${unknown.stderr.slice(0, 80)}]`);

  const missing = runCli(["status", "--project", "/nonexistent/xyz"]);
  check("cli missing project: exit 64", missing.exitCode === 64, `exit ${missing.exitCode}`);
  check("cli missing project: stderr names it", missing.stderr.includes("project directory not found: /nonexistent/xyz"), `stderr=[${missing.stderr.slice(0, 80)}]`);
}

// ---------------------------------------------------------------------------
// GitHub Action wrapper: report JSON/MD contract against the direct validator
// JSON, report-only softening, and enforce escalation.
// ---------------------------------------------------------------------------
{
  const runAction = (args: string[], cwd: string): { stdout: string; stderr: string; exitCode: number } => {
    const r = spawnSync(process.execPath, [join(REPO_ROOT, "scripts/github-action/run-action.mjs"), ...args], {
      encoding: "utf8",
      cwd,
      env: { ...process.env, GITHUB_OUTPUT: "", GITHUB_STEP_SUMMARY: "" },
    });
    return { stdout: r.stdout ?? "", stderr: r.stderr ?? "", exitCode: r.status ?? 1 };
  };
  const wd = mkdtempSync(join(tmpdir(), "tool-probe-action-"));
  try {
    const sf = join(REPO_ROOT, "examples/STANDARD-FEATURE");
    const jsonPath = join(wd, "axiom-report.json");
    const mdPath = join(wd, "axiom-report.md");
    const r = runAction(["--project", sf, "--gate", "Release", "--json-report-path", jsonPath, "--md-report-path", mdPath], wd);
    const direct = goldenCase("validate-standard-feature-release-json");
    check("action pass fixture: exit 0", r.exitCode === 0, `exit ${r.exitCode}`);
    let report: Record<string, unknown> | null = null;
    try { report = JSON.parse(readFileSync(jsonPath, "utf8")); } catch {}
    check("action pass fixture: report JSON written", report !== null);
    if (report && direct.exitCode === 0) {
      const directEnvelope = JSON.parse(direct.stdout) as Record<string, unknown>;
      const dSummary = deepSortKeys(directEnvelope["summary"]);
      const rSummary = deepSortKeys((report["summary"] as Record<string, unknown>) ?? {});
      check("action pass fixture: report summary equals validator", JSON.stringify(rSummary) === JSON.stringify(dSummary),
        `report=${JSON.stringify(rSummary)} validator=${JSON.stringify(dSummary)}`);
      check("action pass fixture: report carries configured project", String(report["project"]) === sf, `project=${report["project"]}`);
      check("action pass fixture: markdown report written", existsSync(mdPath) && (readFileSync(mdPath, "utf8").length > 0));
    }

    // Report-only softens a governance FAIL into a passing step...
    const bad = join(REPO_ROOT, "tests/fixtures/invalid-rtm-broken-release-ref");
    const badJson = join(wd, "bad-report.json");
    const badMd = join(wd, "bad-report.md");
    const rBad = runAction(["--project", bad, "--json-report-path", badJson, "--md-report-path", badMd], wd);
    check("action failing fixture report-only: exit 0", rBad.exitCode === 0, `exit ${rBad.exitCode}`);
    let badReport: Record<string, unknown> | null = null;
    try { badReport = JSON.parse(readFileSync(badJson, "utf8")); } catch {}
    const failCount = (badReport?.["summary"] as Record<string, unknown> | undefined)?.["fail"] ?? -1;
    check("action failing fixture report-only: report still shows FAIL", (badReport !== null) && (failCount as number) > 0, `fail=${failCount}`);
    // ...and --enforce makes the same run fail the step.
    const rEnforce = runAction(["--project", bad, "--enforce", "true", "--json-report-path", join(wd, "bad-report2.json"), "--md-report-path", join(wd, "bad-report2.md")], wd);
    check("action failing fixture enforce: exit 1", rEnforce.exitCode === 1, `exit ${rEnforce.exitCode}`);
  } finally { rmSync(wd, { recursive: true, force: true }); }
}

// ---------------------------------------------------------------------------
// Documented skips (each has a reason; none is an unexplained gap):
//  - capture-plugin-load-evidence: drives the real `claude` CLI, which mutates
//    ~/.claude (install/uninstall of the axiom-pmo plugin). Both sides drive
//    the same external binary, so the differential value is the wrapper's
//    transcript handling, covered by unit tests; running it here would modify
//    the user's machine outside the project tree. Skipped.
// ---------------------------------------------------------------------------
console.log("  [SKIP] capture-plugin-load-evidence: live claude CLI mutates ~/.claude; both sides drive the same external binary (documented in the Phase 6 report)");

console.log(`\nSummary: PASS=${pass} FAIL=${fail}`);
if (fail > 0) process.exitCode = 1;
