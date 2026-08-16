// Differential probe for pmo-doctor: compare the TS doctor's rule-level rows
// against the PowerShell reference on the framework's own checkout. The doctor
// is a Text-only self-audit, so comparison is per (rule_id, level) row key.

import { spawnSync } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { runPmoDoctor } from "../doctor/pmo-doctor.js";
import { resolvePwsh } from "./pwsh-resolver.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const PWSH = resolvePwsh();

function runPsDoctor(): Array<{ level: string; rule_id: string }> {
  const r = spawnSync(PWSH, ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/pmo-doctor.ps1", "-RepoPath", REPO_ROOT], { encoding: "utf8" });
  if (r.status !== 0 && r.status !== 1) throw new Error(`ps doctor failed: ${r.stderr}`);
  const rows: Array<{ level: string; rule_id: string }> = [];
  for (const line of (r.stdout ?? "").split("\n")) {
    const m = /^\[(PASS|WARN|FAIL)\]\s+([A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*)\s+(.*)$/.exec(line);
    if (m) rows.push({ level: m[1]!, rule_id: m[2]!, message: m[3]! } as never);
  }
  return rows;
}

const ts = runPmoDoctor(REPO_ROOT);
const ps = runPsDoctor();

// Compare by (rule_id, level) multiset — message text may legitimately differ in
// host path prefix, but rule_id + level must match exactly.
function key(rows: Array<{ level: string; rule_id: string }>): Map<string, number> {
  const m = new Map<string, number>();
  for (const r of rows) {
    const k = `${r.rule_id}:${r.level}`;
    m.set(k, (m.get(k) ?? 0) + 1);
  }
  return m;
}

const tsKey = key(ts.rows);
const psKey = key(ps);

const onlyTs = [...tsKey.entries()].filter(([k, v]) => (psKey.get(k) ?? 0) !== v);
const onlyPs = [...psKey.entries()].filter(([k, v]) => (tsKey.get(k) ?? 0) !== v);

console.log(`TS doctor: PASS=${ts.pass} WARN=${ts.warn} FAIL=${ts.fail} (${ts.rows.length} rows)`);
console.log(`PS doctor: ${ps.length} rows`);

if (onlyTs.length === 0 && onlyPs.length === 0) {
  console.log("\n[PASS] doctor rule-id/level multisets match exactly");
  process.exit(0);
} else {
  console.log("\n[FAIL] doctor mismatch:");
  for (const [k, v] of onlyTs) console.log(`  only TS: ${k} x${v}`);
  for (const [k, v] of onlyPs) console.log(`  only PS: ${k} x${v}`);
  process.exit(1);
}
