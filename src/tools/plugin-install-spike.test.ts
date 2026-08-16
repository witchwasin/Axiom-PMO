// Ported from tests/helpers/plugin-install-spike-tests.ps1 (Milestone 6.1
// packaging spike), adapted for the Node port.
//
// The question this answers is narrow and worth stating precisely: does the
// framework still work when its files are NOT in a git checkout, NOT the
// current directory, and NOT writable -- i.e. installed the way a Claude
// Code plugin is installed -- while operating on a user project elsewhere?
//
// Mechanism differs from the PS original by necessity: the PS version spawns
// scripts/*.ps1 as child processes from a simulated install root. The Node
// port's user-facing tools are functions, not scripts, so this calls them
// in-process with repoRoot pointed at the simulated install and projectPath
// pointed at the user project -- proving the same framework-root/
// project-root separation the PS spike proved. Since Phase 7 rewired
// cli/axiom.mjs, the Node CLI cases at the end drive the REAL rewired CLI
// (default in-process path) from the install location: they prove the actual
// product install path runs the compiled dist/ engine with zero PowerShell
// -- and, in the read-only case, from a non-writable install.
//
// The simulated install root deliberately contains a space and a
// dot-directory in its path, matching a real install root
// (~/.claude/plugins/marketplaces/<name>/plugins/<plugin>).

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  mkdtempSync, mkdirSync, cpSync, rmSync, writeFileSync, readFileSync, readdirSync, statSync, existsSync, chmodSync,
} from "node:fs";
import { tmpdir, platform } from "node:os";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { runPmoDoctor, formatDoctorText } from "../doctor/pmo-doctor.js";
import { runPortedChain } from "../probe/validate-chain.js";
import { exportExecutionContract } from "./export-execution-contract.js";
import { runExecutionCommand } from "./run-execution-command.js";
import { runVerifyExecutionResult } from "../exec/verify-execution-result.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

function git(dir: string, ...args: string[]): { ok: boolean; stdout: string } {
  const r = spawnSync("git", ["-C", dir, ...args], { encoding: "utf8" });
  return { ok: r.status === 0, stdout: (r.stdout ?? "").trim() };
}

function newSimulatedPluginInstall(root: string): string {
  // What a plugin install actually carries for the Node-native tools: only
  // pmo-config and templates -- no scripts/, no cli/, since those don't
  // exist as a subprocess boundary for in-process calls. No .git, no tests,
  // no examples: if a tool needs something outside this list, it shows up
  // here as a failure rather than in a user's first install.
  const install = join(root, "marketplaces/axiom pmo/plugins/axiom-pmo");
  mkdirSync(install, { recursive: true });
  // What a plugin install carries for the Node-native tools: pmo-config,
  // templates, and -- since the CLI rewire -- the compiled engine (dist/)
  // plus cli/axiom.mjs itself. scripts/ is carried too: it keeps the
  // rollback path (AXIOM_ROLLBACK_PWSH=1) functional from an install, and it
  // is what the PS original's equivalent spike used.
  for (const dir of ["pmo-config", "templates", "cli", "scripts", "dist"]) {
    cpSync(join(REPO_ROOT, dir), join(install, dir), { recursive: true });
  }
  return install;
}

function newUserProject(root: string): string {
  const project = join(root, "user work/my-app");
  mkdirSync(join(project, "src/payments"), { recursive: true });
  mkdirSync(join(project, "source/MOM"), { recursive: true });

  writeFileSync(
    join(project, "PROJECT.md"),
    "# PROJECT - P90-PLUGIN\n\nTask source: delivery\n\n## Scope\n\n| ID | Requirement | Source Ref | Evidence Status |\n|---|---|---|---|\n| REQ-001 | Card payments are captured. | MOM-20260731 item-1 | supported |",
  );
  writeFileSync(
    join(project, "DELIVERY.md"),
    "# DELIVERY - P90-PLUGIN\n\nTask source: delivery\n\n## Work Items\n\n| ID | Mode | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Status |\n|---|---|---|---|---|---|---|---|---|\n| D-001 | Standard | Capture card payments | REQ-001 | DESIGN/FLOW.puml | Given a valid card, when charged, then a receipt is issued. | unit tests | Dev | To Do |",
  );
  writeFileSync(
    join(project, "SCOPE.json"),
    '{"schema_version":"1.0","project":"P90-PLUGIN","implementation_scope":{"include":["src/payments/**"],"exclude":[]}}',
  );
  writeFileSync(join(project, "source/MOM/MOM-20260731.md"), "# MOM 2026-07-31\n\nitem-1: capture card payments.");
  writeFileSync(join(project, "src/payments/charge.ts"), "export const charge = () => 0;");

  git(project, "init", "-q", "--initial-branch=main");
  git(project, "config", "user.email", "spike@example.invalid");
  git(project, "config", "user.name", "Spike");
  git(project, "config", "core.autocrlf", "false");
  git(project, "add", "-A");
  git(project, "commit", "-q", "-m", "base");
  return project;
}

function listFiles(dir: string): string[] {
  const out: string[] = [];
  const walk = (d: string) => {
    for (const entry of readdirSync(d)) {
      const full = join(d, entry);
      if (statSync(full).isDirectory()) walk(full);
      else out.push(full);
    }
  };
  walk(dir);
  return out.sort();
}

test("plugin install spike: framework-root vs project-root separation", () => {
  const root = mkdtempSync(join(tmpdir(), "axiom-spike-"));
  try {
    const install = newSimulatedPluginInstall(root);
    const project = newUserProject(root);

    assert.ok(!existsSync(join(install, ".git")), "install root is not a git repository");
    assert.ok(install.includes(" "), "install root path contains a space (Windows quoting exercised)");

    // ---- pmo-doctor is a maintainer tool and does not survive a plugin
    // install -- it must fail cleanly with FRAMEWORK-001, not a raw exception.
    const doctorResult = runPmoDoctor(install);
    const doctorText = formatDoctorText(install, doctorResult);
    assert.ok(doctorResult.fail > 0, "pmo-doctor is a maintainer tool and does not survive a plugin install");
    assert.ok(doctorText.includes("FRAMEWORK-001"), "...and fails with a FRAMEWORK-001 diagnostic, not a raw exception");
    assert.ok(
      doctorText.includes("validate") || doctorText.includes("axiom.mjs"),
      "...and the diagnostic redirects to the user-facing command",
    );

    // ---- framework root vs project root, kept distinct.
    let diagnostics = runPortedChain(install, project, "Standard", "Scope").diagnostics;
    assert.ok(diagnostics.length > 0, "validate-project runs against a project outside the install root");

    // ---- does validation write into the framework install?
    const before = listFiles(install);
    runPortedChain(install, project, "Standard", "Handoff");
    const after = listFiles(install);
    assert.deepEqual(after, before, "validation writes no new file into the install root");

    // ---- are templates readable from the install?
    assert.ok(existsSync(join(install, "templates/PROJECT.md")), "templates are present in the install and readable");

    // ---- the M5 loop end to end from a plugin install.
    const exportResult = exportExecutionContract(install, project, "D-001", null, null, "commit", false);
    const contractPath = join(project, ".execution/D-001/EXECUTION-CONTRACT.json");
    assert.ok(existsSync(contractPath), `axiom export writes the contract into the USER's repo: ${exportResult.output ?? ""}`);
    assert.ok(existsSync(contractPath + ".sha256"), "the contract sidecar is written alongside it");

    const runResult = runExecutionCommand(project, "D-001", "unit tests", "echo ok");
    assert.equal(runResult.exitCode, 0, `axiom run executes a real child process: ${runResult.output}`);

    const missingResultPath = join(project, ".execution/D-001/EXECUTION-RESULT.json");
    const verifyMissing = runVerifyExecutionResult(install, project, missingResultPath, null, null, false);
    const missingVerdict = String((verifyMissing.envelope["execution_verification"] as Record<string, unknown>)["verdict"]);
    assert.ok(
      /missing|EXEC-/i.test(missingVerdict) || verifyMissing.exitCode !== 0,
      `verify refuses a missing result cleanly rather than crashing: verdict=${missingVerdict}`,
    );

    // ---- does a REAL result verify from the install root?
    const runsDir = join(project, ".execution/D-001/runs");
    const recordName = readdirSync(runsDir).find((f) => !f.endsWith(".sha256"))!;
    const recordPath = join(runsDir, recordName);
    const recordDigest = createHash("sha256").update(readFileSync(recordPath)).digest("hex").toLowerCase();
    const contractDigest = readFileSync(contractPath + ".sha256", "utf8").trim();
    const head = git(project, "rev-parse", "HEAD").stdout;
    const contract = JSON.parse(readFileSync(contractPath, "utf8"));

    const token = `axiom-authority: type=test-evidence-accepted; work_item=D-001; contract=${contractDigest}; test=unit tests; evidence=${recordDigest}`;
    writeFileSync(
      join(project, "decision-log.md"),
      `# Decision Log - P90-PLUGIN\n\n| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |\n|---|---|---|---|---|---|---|---|\n| 2026-07-31 | DEC-100 | Accept unit test evidence for D-001 | accept / require CI | accept | reviewed the run record by hand. ${token} | none | accepted |`,
    );

    const resultDoc = {
      contract_version: "1.0", work_item_id: "D-001", contract_sha256: contractDigest,
      base_sha: contract.base_sha, head_sha: head, execution_status: "completed", changed_files: [],
      test_evidence: [{ type: "runner-exit-record", name: "unit tests", run_record_path: `.execution/D-001/runs/${recordName}` }],
      authority_claims: [{
        type: "test-evidence-accepted", actor: "human", claim: "accepted", decision_ref: "DEC-100",
        test_name: "unit tests", evidence_sha256: recordDigest, evidence_type: "runner-exit-record", work_item_id: "D-001",
      }],
    };
    const resultPath = join(project, ".execution/D-001/EXECUTION-RESULT.json");
    writeFileSync(resultPath, JSON.stringify(resultDoc, null, 2));

    const realVerify = runVerifyExecutionResult(install, project, resultPath, null, null, false);
    const realVerdict = String((realVerify.envelope["execution_verification"] as Record<string, unknown>)["verdict"]);
    assert.equal(realVerdict, "pass", `a complete execution result verifies to a pass from the install root: ${JSON.stringify(realVerify.envelope["execution_verification"]).slice(0, 600)}`);

    // ---- does the REWIRED Node CLI resolve the same way? (Phase 7: the CLI
    // runs the compiled dist/ engine in-process from its own install
    // location; AXIOM_ROLLBACK_PWSH is forced unset so this exercises the
    // default path, the one a plugin install would use.)
    const cli = spawnSync(process.execPath, [join(install, "cli/axiom.mjs"), "validate", "--project", project, "--mode", "Standard"], {
      encoding: "utf8", cwd: root, env: { ...process.env, AXIOM_ROLLBACK_PWSH: "" },
    });
    if (cli.error) {
      // Node itself unavailable in this environment is a legitimate skip,
      // matching the PS original's behavior when `node` is missing.
    } else {
      const cliText = (cli.stdout ?? "") + (cli.stderr ?? "");
      // This fixture is a real project with real Draft findings, so a
      // verdict of 0 or 1 is correct -- what must NOT happen is an infra
      // failure (127) or a usage error (64). The point is the rewired CLI
      // resolved its engine from the install and produced a real report.
      assert.ok(
        cli.status === 0 || cli.status === 1,
        `the rewired CLI runs a real validation from the install (not an infra/usage failure): exit=${cli.status} ${cliText.slice(0, 400)}`,
      );
      assert.ok(
        /Summary: PASS=\d+/.test(cliText) || cliText.includes("P90-PLUGIN"),
        `the rewired CLI resolves the framework from its own install location: exit=${cli.status} ${cliText.slice(0, 400)}`,
      );
    }

    // ---- does the REWIRED Node CLI still work from a read-only install?
    // (§5.3: same simulated install, filesystem made read-only, run through
    // the real rewired CLI end to end.) Skipped on Windows, where ACL
    // semantics differ from chmod (matches the PS original).
    if (platform() !== "win32") {
      chmodSync(install, 0o555);
      for (const f of listFiles(install)) chmodSync(f, 0o444);
      try {
        const cliRo = spawnSync(process.execPath, [join(install, "cli/axiom.mjs"), "validate", "--project", project, "--mode", "Standard"], {
          encoding: "utf8", cwd: root, env: { ...process.env, AXIOM_ROLLBACK_PWSH: "" },
        });
        const cliRoText = (cliRo.stdout ?? "") + (cliRo.stderr ?? "");
        assert.ok(cliRo.status === 0 || cliRo.status === 1, `the rewired CLI validates from a read-only install (not an infra/usage failure): exit=${cliRo.status} ${cliRoText.slice(0, 400)}`);
        assert.ok(/Summary: PASS=\d+/.test(cliRoText), `...and produces a real validation report: ${cliRoText.slice(0, 300)}`);
      } finally {
        chmodSync(install, 0o755);
        for (const f of listFiles(install)) chmodSync(f, 0o644);
      }
    }

    // ---- does a read-only install still work? Last, since it changes
    // permissions on the tree the earlier cases used. Skipped on Windows,
    // where ACL semantics differ from chmod (matches the PS original).
    if (platform() !== "win32") {
      chmodSync(install, 0o555);
      for (const f of listFiles(install)) chmodSync(f, 0o444);
      try {
        diagnostics = runPortedChain(install, project, "Standard", "Scope").diagnostics;
        assert.ok(diagnostics.length > 0, "the user-facing validator runs from a read-only install root");
      } finally {
        chmodSync(install, 0o755);
        for (const f of listFiles(install)) chmodSync(f, 0o644);
      }
    }
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
