// Regression probe for pmo-doctor: compare the TS doctor's rule-level rows
// against a golden fixture frozen from the PowerShell reference's output on
// the framework's own checkout (Phase 9: the reference no longer exists to
// compare against live, so the fixture stands in for it). The doctor is a
// Text-only self-audit, so comparison is per (rule_id, level) row key.

import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { runPmoDoctor } from "../doctor/pmo-doctor.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const FIXTURE = resolve(REPO_ROOT, "tests/golden/probes/doctor-probe.json");

function loadGoldenDoctor(): Array<{ level: string; rule_id: string }> {
  const data = JSON.parse(readFileSync(FIXTURE, "utf8")) as { rows: Array<{ level: string; rule_id: string }> };
  return data.rows;
}

const ts = runPmoDoctor(REPO_ROOT);
const golden = loadGoldenDoctor();

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
const goldenKey = key(golden);

const onlyTs = [...tsKey.entries()].filter(([k, v]) => (goldenKey.get(k) ?? 0) !== v);
const onlyGolden = [...goldenKey.entries()].filter(([k, v]) => (tsKey.get(k) ?? 0) !== v);

console.log(`TS doctor: PASS=${ts.pass} WARN=${ts.warn} FAIL=${ts.fail} (${ts.rows.length} rows)`);
console.log(`Golden doctor: ${golden.length} rows`);

if (onlyTs.length === 0 && onlyGolden.length === 0) {
  console.log("\n[PASS] doctor rule-id/level multisets match golden fixture exactly");
  process.exit(0);
} else {
  console.log("\n[FAIL] doctor mismatch:");
  for (const [k, v] of onlyTs) console.log(`  only TS: ${k} x${v}`);
  for (const [k, v] of onlyGolden) console.log(`  only golden: ${k} x${v}`);
  process.exit(1);
}
