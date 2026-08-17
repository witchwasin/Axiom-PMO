// Regression probe for verify-execution-result: build a disposable git
// fixture using the (already differentially-proven, Milestone 5) TS
// export-execution-contract / run-execution-command functions, then compare
// the TS candidate's EXEC-*/AREV-* diagnostic rows against a golden fixture
// frozen from the PowerShell reference's verify-execution-result.ps1 output
// on this exact fixture-construction path (Phase 9: the reference no longer
// exists to compare against live).

import { readFileSync, writeFileSync, mkdirSync, rmSync, mkdtempSync, readdirSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { runVerifyExecutionResult } from "../exec/verify-execution-result.js";
import { exportExecutionContract } from "../tools/export-execution-contract.js";
import { runExecutionCommand } from "../tools/run-execution-command.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const FIXTURE = resolve(REPO_ROOT, "tests/golden/probes/execution-probe.json");
const golden = JSON.parse(readFileSync(FIXTURE, "utf8")) as Record<string, Array<{ level: string; rule_id: string; message: string }>>;

function sha256(buf: Buffer | string): string {
  return createHash("sha256").update(buf).digest("hex").toLowerCase();
}

function git(dir: string, ...args: string[]): { out: string; code: number | null } {
  const r = spawnSync("git", ["-C", dir, ...args], { encoding: "utf8" });
  return { out: r.stdout ?? "", code: r.status };
}

function write(dir: string, rel: string, content: string): void {
  const full = join(dir, rel);
  mkdirSync(dirname(full), { recursive: true });
  writeFileSync(full, content);
}

function commit(dir: string, msg: string): string {
  git(dir, "add", "-A");
  git(dir, "commit", "-q", "-m", msg);
  return git(dir, "rev-parse", "HEAD").out.trim();
}

function newFixture(): string {
  const dir = mkdtempSync(join(tmpdir(), "exec-probe-"));
  git(dir, "init", "-q", "--initial-branch=main");
  git(dir, "config", "user.email", "test@axiom-pmo.local");
  git(dir, "config", "user.name", "Exec Probe");
  git(dir, "config", "core.autocrlf", "false");
  write(dir, "PROJECT.md", "# P99-EXEC\n");
  write(dir, "SCOPE.json", '{"schema_version":"1.0","project":"P99-EXEC","implementation_scope":{"include":["src/payments/**","tests/payments/**"],"exclude":["src/payments/generated/**"]}}');
  write(dir, "DELIVERY.md", "# DELIVERY - P99-EXEC\n\n## Work Items\n\n| ID | Mode | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Status |\n|---|---|---|---|---|---|---|---|---|\n| D-001 | Standard | Checkout flow | REQ-001 | DESIGN/FLOW.puml | Works | unit tests | Dev | To Do |\n");
  write(dir, "src/payments/app.ts", "seed");
  write(dir, "decision-log.md", "# Decision Log\n\n| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |\n|---|---|---|---|---|---|---|---|\n| 2026-07-30 | DEC-100 | Accept local test artifacts for D-001 | accept / require CI | accept | reviewed the artifacts by hand | none | test evidence accepted |\n");
  commit(dir, "base");
  return dir;
}

function exportContract(dir: string, grant: string): void {
  const r = exportExecutionContract(REPO_ROOT, dir, "D-001", null, null, grant, true);
  if (r.exitCode !== 0) throw new Error(`export failed: ${r.output}`);
}

function runRecord(dir: string): void {
  const r = runExecutionCommand(dir, "D-001", "unit tests", "echo ok");
  if (r.exitCode !== 0) throw new Error(`run failed: ${r.output}`);
}

function writeResult(dir: string, contractDigest: string, baseSha: string, headSha: string, runRecordPath: string, recordDigest: string): void {
  write(dir, "decision-log.md", `# Decision Log\n\n| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |\n|---|---|---|---|---|---|---|---|\n| 2026-07-31 | DEC-100 | Accept unit tests evidence for D-001 | accept / require CI | accept | reviewed the artifact by hand. axiom-authority: type=test-evidence-accepted; work_item=D-001; contract=${contractDigest}; test=unit tests; evidence=${recordDigest} | none | test evidence accepted |\n`);
  const result = {
    contract_version: "1.0", work_item_id: "D-001", contract_sha256: contractDigest,
    base_sha: baseSha, head_sha: headSha, execution_status: "completed",
    changed_files: [], test_evidence: [{ type: "runner-exit-record", name: "unit tests", run_record_path: runRecordPath }],
    authority_claims: [{ type: "test-evidence-accepted", actor: "human", claim: "accepted", decision_ref: "DEC-100", test_name: "unit tests", evidence_sha256: recordDigest, evidence_type: "runner-exit-record", work_item_id: "D-001" }],
  };
  write(dir, ".execution/D-001/EXECUTION-RESULT.json", JSON.stringify(result));
}

const EXEC_AREV = /^(EXEC|AREV)-/;
let pass = 0;
let fail = 0;

function compareCase(name: string, dir: string, setup: (d: string) => void): void {
  setup(dir);
  const ref = golden[name] ?? [];
  const cand = runVerifyExecutionResult(REPO_ROOT, dir, join(dir, ".execution/D-001/EXECUTION-RESULT.json"), null, null, false)
    .envelope.results as Array<{ level: string; rule_id: string; message: string }>;
  const candFiltered = cand.filter((r) => EXEC_AREV.test(r.rule_id));

  const refKey = JSON.stringify(ref);
  const candKey = JSON.stringify(candFiltered);
  if (refKey === candKey) {
    pass++;
    console.log(`[PASS] ${name} (${ref.length} rows)`);
  } else {
    fail++;
    console.log(`[FAIL] ${name}`);
    console.log(`  golden (${ref.length}): ${refKey.slice(0, 400)}`);
    console.log(`  cand   (${candFiltered.length}): ${candKey.slice(0, 400)}`);
  }
}

// Case 1: clean run verifies (pass, no EXEC/AREV FAIL)
{
  const dir = newFixture();
  try {
    exportContract(dir, "commit");
    write(dir, "src/payments/app.ts", "implemented");
    write(dir, "tests/payments/app.test.ts", "tested");
    const head = commit(dir, "impl");
    const contractDigest = readFileSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json.sha256"), "utf8").trim();
    const baseSha = git(dir, "rev-parse", "HEAD~1").out.trim();
    runRecord(dir);
    const recordPath = ".execution/D-001/runs/" + (() => {
      // Find the run record filename
      
      return readdirSync(join(dir, ".execution/D-001/runs")).find((f) => f.endsWith(".json") && !f.endsWith(".sha256"))!;
    })();
    const recordDigest = sha256(readFileSync(join(dir, recordPath)));
    writeResult(dir, contractDigest, baseSha, head, recordPath, recordDigest);
    compareCase("clean-run", dir, () => {});
  } finally { rmSync(dir, { recursive: true, force: true }); }
}

// Case 2: out-of-scope change (EXEC-004)
{
  const dir = newFixture();
  try {
    exportContract(dir, "commit");
    write(dir, "src/payments/app.ts", "implemented");
    write(dir, "src/auth/tokens.ts", "wandered");
    const head = commit(dir, "impl");
    const contractDigest = readFileSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json.sha256"), "utf8").trim();
    const baseSha = git(dir, "rev-parse", "HEAD~1").out.trim();
    runRecord(dir);
    const recordPath = ".execution/D-001/runs/" + (() => {
      
      return readdirSync(join(dir, ".execution/D-001/runs")).find((f) => f.endsWith(".json") && !f.endsWith(".sha256"))!;
    })();
    const recordDigest = sha256(readFileSync(join(dir, recordPath)));
    writeResult(dir, contractDigest, baseSha, head, recordPath, recordDigest);
    // Override changed_files to include the out-of-scope path
    const rp = join(dir, ".execution/D-001/EXECUTION-RESULT.json");
    const doc = JSON.parse(readFileSync(rp, "utf8"));
    doc.changed_files = ["src/payments/app.ts", "src/auth/tokens.ts"];
    writeFileSync(rp, JSON.stringify(doc));
    compareCase("out-of-scope", dir, () => {});
  } finally { rmSync(dir, { recursive: true, force: true }); }
}

// Case 3: self-approval (EXEC-007)
{
  const dir = newFixture();
  try {
    exportContract(dir, "commit");
    const contractDigest = readFileSync(join(dir, ".execution/D-001/EXECUTION-CONTRACT.json.sha256"), "utf8").trim();
    const baseSha = git(dir, "rev-parse", "HEAD").out.trim();
    runRecord(dir);
    const recordPath = ".execution/D-001/runs/" + (() => {
      
      return readdirSync(join(dir, ".execution/D-001/runs")).find((f) => f.endsWith(".json") && !f.endsWith(".sha256"))!;
    })();
    const recordDigest = sha256(readFileSync(join(dir, recordPath)));
    writeResult(dir, contractDigest, baseSha, baseSha, recordPath, recordDigest);
    const rp = join(dir, ".execution/D-001/EXECUTION-RESULT.json");
    const doc = JSON.parse(readFileSync(rp, "utf8"));
    doc.authority_claims = [{ type: "release-approval", actor: "agent", claim: "approved" }];
    writeFileSync(rp, JSON.stringify(doc));
    compareCase("self-approval", dir, () => {});
  } finally { rmSync(dir, { recursive: true, force: true }); }
}

console.log(`\nSummary: PASS=${pass} FAIL=${fail}`);
if (fail > 0) process.exitCode = 1;
