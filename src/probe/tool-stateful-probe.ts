// Phase 6 -- final-tree differential gate, tool surface (stateful half).
//
// The deterministic tools live in tool-probe.ts. This probe covers the tools
// that WRITE files, using the §8.6 fresh-tree methodology from stateful-probe:
// the candidate operates on its own freshly-created tree, and the probe
// compares the resulting bytes, exit codes, and output against a golden
// fixture frozen from the PowerShell reference (Phase 9: the reference no
// longer exists to compare against live). A nondeterministic field (salt,
// run_id, timestamp, backup stamp) is normalized out of the comparison, never
// skipped -- unchanged from before conversion.

import { readFileSync, writeFileSync, mkdirSync, rmSync, mkdtempSync, existsSync, readdirSync, statSync, cpSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { getCanonicalGoldenText, getGoldenDiffReport } from "../output/canonical-normalizer.js";
import { setupClaudeIntegration } from "../tools/setup-claude-integration.js";
import { newProject } from "../tools/new-project.js";
import { updateSourceSnapshot } from "../tools/update-source-snapshot.js";
import { aggregateDiagnostics } from "../tools/aggregate-diagnostics.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const FIXTURE = resolve(REPO_ROOT, "tests/golden/probes/tool-stateful-probe.json");
const golden = JSON.parse(readFileSync(FIXTURE, "utf8")) as {
  setup_branches: Record<string, { stdout_normalized: string; exitCode: number }>;
  new_project: Record<string, { code: string; stdout_normalized: string; exitCode: number; tree_normalized: Record<string, string> }>;
  update_source_snapshot: { stdout_normalized: string; exitCode: number; project_md_ts_scrubbed: string; project_md_bak: string };
  aggregate_diagnostics: { exitCode: number; registry_canonical: string | null; event_count: number; governed_events_sorted: unknown[] };
  clean_room: { stdout_normalized: string; exitCode: number; changed_files: string[]; agents_md: string };
};

let pass = 0;
let fail = 0;
function check(name: string, ok: boolean, detail = ""): void {
  if (ok) { pass++; console.log(`[PASS] ${name}`); }
  else { fail++; console.log(`[FAIL] ${name}${detail ? " -- " + detail : ""}`); }
}

const DATE_RE = /\d{4}-\d{2}-\d{2}/g;
const TS_RE = /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:\d{2})/g;
const STAMP_RE = /(?<=\.axiom-backup-)\S+/g;

function deepSortKeys(v: unknown): unknown {
  if (Array.isArray(v)) return v.map(deepSortKeys);
  if (v !== null && typeof v === "object") {
    const out: Record<string, unknown> = {};
    for (const k of Object.keys(v as Record<string, unknown>).sort()) out[k] = deepSortKeys((v as Record<string, unknown>)[k]);
    return out;
  }
  return v;
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
    return JSON.stringify(deepSortKeys(dropRec(JSON.parse(text))));
  } catch { return null; }
}

function treeBytes(root: string, excludeSubstrings: string[] = []): Record<string, string> {
  const out: Record<string, string> = {};
  const walk = (d: string) => {
    for (const entry of readdirSync(d)) {
      if (entry === ".git") continue;
      const full = join(d, entry);
      if (statSync(full).isDirectory()) walk(full);
      else {
        const rel = full.substring(root.length + 1).replace(/\\/g, "/");
        if (excludeSubstrings.some((e) => rel.includes(e))) continue;
        out[rel] = readFileSync(full).toString("base64");
      }
    }
  };
  if (existsSync(root)) walk(root);
  return out;
}

// ---------------------------------------------------------------------------
// setup-claude-integration: output + exit parity across the operational
// branches (file bytes already proven by setup-probe.ts), against a golden
// fixture frozen from the PS reference. Preconditions that used to be built
// via the PS reference (so both sides started from byte-identical trees) are
// now built with the TS install itself -- setup-probe.ts already proved TS
// install output is byte-identical to the reference's.
// ---------------------------------------------------------------------------
  const normSetup = (s: string, root: string) =>
    getCanonicalGoldenText(s).replaceAll(root, "<TREE>").replace(STAMP_RE, "<STAMP>");
  const agentsSeed = (d: string) => writeFileSync(join(d, "AGENTS.md"), "# User rules\n\nBe careful.\n");
  const tsInstall = (d: string) => setupClaudeIntegration(d, false, false, false, "AGENTS.md");

  interface Branch {
    label: string;
    prepare: (d: string) => void;
    tsRun: (d: string) => { output: string; exitCode: number };
  }
  const branches: Branch[] = [
    {
      label: "install-fresh",
      prepare: agentsSeed,
      tsRun: (d) => setupClaudeIntegration(d, false, false, false, "AGENTS.md"),
    },
    {
      label: "reinstall-unchanged",
      prepare: (d) => { agentsSeed(d); tsInstall(d); },
      tsRun: (d) => setupClaudeIntegration(d, false, false, false, "AGENTS.md"),
    },
    {
      label: "dry-run",
      prepare: agentsSeed,
      tsRun: (d) => setupClaudeIntegration(d, true, false, false, "AGENTS.md"),
    },
    {
      label: "uninstall",
      prepare: (d) => { agentsSeed(d); tsInstall(d); },
      tsRun: (d) => setupClaudeIntegration(d, false, true, false, "AGENTS.md"),
    },
    {
      label: "uninstall-no-file",
      prepare: (d) => { agentsSeed(d); rmSync(join(d, "AGENTS.md"), { force: true }); },
      tsRun: (d) => setupClaudeIntegration(d, false, true, false, "AGENTS.md"),
    },
    {
      label: "blocked-hand-edited-uninstall",
      prepare: (d) => {
        agentsSeed(d);
        tsInstall(d);
        const p = join(d, "AGENTS.md");
        writeFileSync(p, readFileSync(p, "utf8").replace("You may not approve", "You CAN approve"));
      },
      tsRun: (d) => setupClaudeIntegration(d, false, true, false, "AGENTS.md"),
    },
  ];

  for (const b of branches) {
    const tsDir = mkdtempSync(join(tmpdir(), "tool-stateful-setup-"));
    try {
      b.prepare(tsDir);
      const ref = golden.setup_branches[b.label];
      if (!ref) throw new Error(`no golden fixture for setup branch: ${b.label}`);
      const cand = b.tsRun(tsDir);
      const candN = normSetup(cand.output, tsDir);
      check(`setup ${b.label}: output`, ref.stdout_normalized === candN, ref.stdout_normalized === candN ? "" : getGoldenDiffReport(ref.stdout_normalized, candN).join(" | "));
      check(`setup ${b.label}: exit`, ref.exitCode === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
    } finally {
      rmSync(tsDir, { recursive: true, force: true });
    }
  }

// ---------------------------------------------------------------------------
// new-project: generated tree bytes + stdout + exit across three modes.
// ---------------------------------------------------------------------------
{
  const configs = [
    {
      label: "standard+handoff",
      args: { mode: "Standard" as const, executionPath: "development_handoff", researchMode: "off", researchDepth: "standard", researchProvider: "none", uiDelivery: "not_applicable", strictTrigger: "none", modeReason: "normal feature", modeApprovedBy: "PM", includeHandoff: true, target: "demo", horizonDays: 14 },
    },
    {
      label: "strict+claude-design",
      args: { mode: "Strict" as const, executionPath: "governed_ai_execution", researchMode: "guided", researchDepth: "deep", researchProvider: "feyman", uiDelivery: "claude_design", strictTrigger: "payment-processing", modeReason: "declared at interactive init: does this involve payment processing?", modeApprovedBy: "Alice Chen", includeHandoff: false, target: "internal", horizonDays: 14 },
    },
    {
      label: "lite",
      args: { mode: "Lite" as const, executionPath: "development_handoff", researchMode: "off", researchDepth: "standard", researchProvider: "none", uiDelivery: "not_applicable", strictTrigger: "none", modeReason: "normal feature", modeApprovedBy: "PM", includeHandoff: false, target: "internal", horizonDays: 14 },
    },
  ];
  for (const c of configs) {
    const tsRoot = mkdtempSync(join(tmpdir(), "tool-stateful-np-"));
    try {
      const code = "P99-" + c.label.slice(0, 3).toUpperCase();
      const ref = golden.new_project[c.label];
      if (!ref) throw new Error(`no golden fixture for new-project config: ${c.label}`);

      const cand = newProject(REPO_ROOT, code, c.args.mode, c.args.executionPath, c.args.researchMode, c.args.researchDepth,
        c.args.researchProvider, c.args.uiDelivery, c.args.strictTrigger, c.args.modeReason, c.args.modeApprovedBy,
        tsRoot, c.args.includeHandoff, c.args.target, c.args.horizonDays);

      const norm = (s: string, root: string) =>
        getCanonicalGoldenText(s).replaceAll(root, "<TREE>").replace(join(root, code), "<TREE>").replace(DATE_RE, "<DATE>");
      const candN = norm(cand.output, tsRoot);
      check(`new-project ${c.label}: stdout`, ref.stdout_normalized === candN, ref.stdout_normalized === candN ? "" : getGoldenDiffReport(ref.stdout_normalized, candN).join(" | "));
      check(`new-project ${c.label}: exit`, ref.exitCode === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);

      const tsTree = treeBytes(join(tsRoot, code));
      const normBytes = (t: Record<string, string>) => {
        const out: Record<string, string> = {};
        for (const [k, v] of Object.entries(t)) {
          // decode + normalize date tokens + re-encode
          let text = Buffer.from(v, "base64").toString("utf8");
          if (text.includes("\u0000") || /[^\x09\x0a\x0d\x20-\x7e\xc0-\xff]/.test(text.replace(/[\x80-\xff]/g, ""))) {
            out[k] = v; // binary — compare raw
          } else {
            out[k] = Buffer.from(text.replace(DATE_RE, "<DATE>")).toString("base64");
          }
        }
        return out;
      };
      const psN = ref.tree_normalized;
      const tsN = normBytes(tsTree);
      const sameFiles = JSON.stringify(Object.keys(psN).sort()) === JSON.stringify(Object.keys(tsN).sort());
      check(`new-project ${c.label}: file set identical`, sameFiles,
        `ps=[${Object.keys(psN).sort().join(",")}] ts=[${Object.keys(tsN).sort().join(",")}]`);
      const diffs: string[] = [];
      for (const k of Object.keys(psN)) {
        if (psN[k] !== tsN[k]) diffs.push(k);
      }
      check(`new-project ${c.label}: bytes identical (modulo dates)`, sameFiles && diffs.length === 0,
        `differing files: ${diffs.join(", ")}`);
    } finally {
      rmSync(tsRoot, { recursive: true, force: true });
    }
  }
}

// ---------------------------------------------------------------------------
// update-source-snapshot: write mode. Resulting PROJECT.md + backup + output.
// ---------------------------------------------------------------------------
{
  const fixture = (root: string) => {
    mkdirSync(join(root, "source/REQ"), { recursive: true });
    mkdirSync(join(root, "source/MOM"), { recursive: true });
    writeFileSync(join(root, "source/REQ/REQ-0001.md"), "# REQ-0001\n");
    writeFileSync(join(root, "source/MOM/MOM-20260101.md"), "# MOM\n");
    writeFileSync(join(root, "PROJECT.md"), [
      "# P99-SNAP", "",
      "## Source Snapshot", "",
      "| Source ID | Version / Date | SHA256 | Last Synced At |",
      "|---|---|---|---|",
      "| REQ-0001 | v1 | deadbeef | 2026-01-01T00:00:00Z |",
      "",
      "## Other",
      "x", "",
    ].join("\n"));
  };
  const tsDir = mkdtempSync(join(tmpdir(), "tool-stateful-uss-"));
  try {
    fixture(tsDir);
    const ref = golden.update_source_snapshot;
    const cand = updateSourceSnapshot(tsDir, false);
    const norm = (s: string, root: string) => getCanonicalGoldenText(s).replaceAll(root, "<TREE>").replace(TS_RE, "<TS>");
    const candOutN = norm(cand.output, tsDir);
    check("update-source-snapshot write: output", ref.stdout_normalized === candOutN,
      getGoldenDiffReport(ref.stdout_normalized, candOutN).join(" | "));
    check("update-source-snapshot write: exit", ref.exitCode === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
    const tsProj = readFileSync(join(tsDir, "PROJECT.md"), "utf8").replace(TS_RE, "<TS>");
    check("update-source-snapshot write: PROJECT.md identical (modulo timestamp)", ref.project_md_ts_scrubbed === tsProj,
      getGoldenDiffReport(ref.project_md_ts_scrubbed, tsProj).join(" | "));
    const tsBak = readFileSync(join(tsDir, "PROJECT.md.bak"), "utf8");
    check("update-source-snapshot write: backup is the pre-image on both sides", ref.project_md_bak === tsBak);
  } finally {
    rmSync(tsDir, { recursive: true, force: true });
  }
}

// ---------------------------------------------------------------------------
// aggregate-diagnostics: failure-pattern registry + immutable event files.
// Two fresh clones of the committed tree (same HEAD), each carrying an
// identical fixture project (own git repo, fixed commit date, so commit_hash
// matches across sides). Salt, run_id, recorded_at and absolute paths are the
// only nondeterministic fields and are normalized out.
// ---------------------------------------------------------------------------
{
  const clone = (name: string): string => {
    const dir = mkdtempSync(join(tmpdir(), `tool-stateful-${name}-`));
    const r = spawnSync("git", ["clone", "-q", REPO_ROOT, join(dir, "framework")], { encoding: "utf8" });
    if (r.status !== 0) throw new Error(`git clone failed: ${r.stderr}`);
    return join(dir, "framework");
  };
  const fixtureRepo = (): string => {
    const dir = mkdtempSync(join(tmpdir(), "tool-stateful-aggregate-fixture-"));
    const env = { ...process.env, GIT_AUTHOR_DATE: "2026-01-01T00:00:00+00:00", GIT_COMMITTER_DATE: "2026-01-01T00:00:00+00:00" };
    const git = (...args: string[]) => spawnSync("git", ["-C", dir, ...args], { encoding: "utf8", env });
    writeFileSync(join(dir, "PROJECT.md"), [
      "# P99-AGG", "",
      "Status: draft", "",
      "> Execution path: development_handoff", "",
      "## Source Snapshot", "",
      "| Source ID | Version / Date | SHA256 | Last Synced At |",
      "|---|---|---|---|",
      "| REQ-0001 | v1 | deadbeef | 2026-01-01T00:00:00Z |",
      "",
    ].join("\n") + "\n");
    writeFileSync(join(dir, "DELIVERY.md"), [
      "# DELIVERY - P99-AGG", "",
      "## Work Items", "",
      "| ID | Mode | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Status |",
      "|---|---|---|---|---|---|---|---|---|",
      "| D-001 | Standard | Checkout | REQ-0001 | DESIGN/FLOW.puml | Works | unit tests | Dev Team | To Do |",
      "",
    ].join("\n") + "\n");
    git("init", "-q", "--initial-branch=main");
    git("config", "user.email", "agg@axiom-pmo.local");
    git("config", "user.name", "Agg Probe");
    git("add", "-A");
    git("commit", "-q", "-m", "base");
    return dir;
  };
  const B = clone("aggregate-ts");
  const fixture = fixtureRepo();
  try {
    const fixB = join(B, "fixture");
    cpSync(fixture, fixB, { recursive: true });

    const ref = golden.aggregate_diagnostics;
    const cand = aggregateDiagnostics(B, fixB, "Standard", "Draft", false, "Json");
    check("aggregate-diagnostics: exit", ref.exitCode === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);

    const candCanon = jsonCanonical(cand.output, ["generated_at", "first_seen", "last_seen"]);
    check("aggregate-diagnostics: registry identical (modulo timestamps)", ref.registry_canonical === candCanon && ref.registry_canonical !== null,
      ref.registry_canonical === candCanon ? "" : `ref=${ref.registry_canonical} cand=${candCanon}`);

    // Event files: identical governed fields, same count, and the same
    // commit_hash (the fixture repo's fixed-date commit) on both sides.
    const eventsOf = (root: string) => {
      const dir = join(root, ".axiom/learning/events");
      if (!existsSync(dir)) return [] as Array<Record<string, unknown>>;
      const events: Array<Record<string, unknown>> = [];
      for (const f of readdirSync(dir).filter((f) => f.endsWith(".jsonl")).sort()) {
        for (const line of readFileSync(join(dir, f), "utf8").split("\n")) {
          if (line.trim()) events.push(JSON.parse(line));
        }
      }
      return events;
    };
    const evB = eventsOf(B);
    check("aggregate-diagnostics: event counts equal", ref.event_count === evB.length, `ps=${ref.event_count} ts=${evB.length}`);
    const governed = (e: Record<string, unknown>) => deepSortKeys({
      rule_id: e["rule_id"], level: e["level"], blocking: e["blocking"], mode: e["mode"], gate: e["gate"],
      execution_path: e["execution_path"], artifact: e["artifact"], item_id: e["item_id"], commit_hash: e["commit_hash"],
    });
    const keysB = evB.map(governed).sort((x, y) => JSON.stringify(x).localeCompare(JSON.stringify(y)));
    check("aggregate-diagnostics: event governed fields identical", JSON.stringify(ref.governed_events_sorted) === JSON.stringify(keysB),
      `ps=${JSON.stringify(ref.governed_events_sorted)} ts=${JSON.stringify(keysB)}`);
  } finally {
    rmSync(B, { recursive: true, force: true });
    rmSync(fixture, { recursive: true, force: true });
  }
}

// ---------------------------------------------------------------------------
// clean-room compatibility: installing into a repository that already belongs
// to somebody touches nothing but AGENTS.md, on both sides, and the resulting
// file bytes are identical.
// ---------------------------------------------------------------------------
{
  const foreignFiles: Record<string, string> = {
    "README.md": "# Their app\n\nTheir product.\n",
    ".claude/skills/their-skill/SKILL.md": "---\nname: their-skill\ndescription: A skill the team wrote.\n---\n\n# their-skill\n",
    ".claude/settings.json": '{ "permissions": { "allow": ["Bash(npm test:*)"], "env": { "THEIR_VAR": "1" } } }',
    "AGENTS.md": "# AGENTS\n\nTheir agent rules.\n",
  };
  const build = (root: string) => {
    for (const [rel, content] of Object.entries(foreignFiles)) {
      const full = join(root, rel);
      mkdirSync(dirname(full), { recursive: true });
      writeFileSync(full, content);
    }
  };
  const tsDir = mkdtempSync(join(tmpdir(), "tool-stateful-cr-"));
  try {
    build(tsDir);
    const beforeTs = treeBytes(tsDir, [".axiom-backup-"]);
    const ref = golden.clean_room;
    const cand = setupClaudeIntegration(tsDir, false, false, false, "AGENTS.md");
    const norm = (s: string, root: string) => getCanonicalGoldenText(s).replaceAll(root, "<TREE>").replace(STAMP_RE, "<STAMP>");
    const candOutN = norm(cand.output, tsDir);
    check("clean-room install: output", ref.stdout_normalized === candOutN,
      getGoldenDiffReport(ref.stdout_normalized, candOutN).join(" | "));
    check("clean-room install: exit", ref.exitCode === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
    const afterTs = treeBytes(tsDir, [".axiom-backup-"]);
    const changedTs = Object.keys(afterTs).filter((k) => !beforeTs[k] || beforeTs[k] !== afterTs[k]);
    check("clean-room: PS touches only AGENTS.md", JSON.stringify(ref.changed_files) === JSON.stringify(["AGENTS.md"]), `changed: ${ref.changed_files.join(",")}`);
    check("clean-room: TS touches only AGENTS.md", JSON.stringify(changedTs.sort()) === JSON.stringify(["AGENTS.md"]), `changed: ${changedTs.join(",")}`);
    const tsAgents = readFileSync(join(tsDir, "AGENTS.md"), "utf8");
    check("clean-room: resulting AGENTS.md bytes identical", ref.agents_md === tsAgents, `${ref.agents_md.length} vs ${tsAgents.length}`);
  } finally {
    rmSync(tsDir, { recursive: true, force: true });
  }
}

console.log(`\nSummary: PASS=${pass} FAIL=${fail}`);
if (fail > 0) process.exitCode = 1;
