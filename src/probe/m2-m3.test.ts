// Ported from tests/helpers/m2-m3-tests.ps1.
//
// Reclassified from tests-disposition.md's "re-derive from golden" bucket
// after reading the file: it mutates project state across a progressive
// sequence (proposed -> scope -> approved -> implemented -> with downstream
// evidence) and asserts on each intermediate state. A golden master is a
// single snapshot and cannot cover a state-transition sequence, so this
// needs a real native port, not a golden re-derivation.

import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, cpSync, rmSync, readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { createHash } from "node:crypto";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { runPortedChain } from "./validate-chain.js";
import type { Diagnostic, Mode, Gate } from "../core/types.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

function copyDir(src: string, dest: string): void {
  for (const entry of readdirSync(src)) {
    if (entry === ".git" || entry === "node_modules" || entry === "dist") continue;
    const s = join(src, entry);
    const d = join(dest, entry);
    if (statSync(s).isDirectory()) { mkdirSync(d, { recursive: true }); copyDir(s, d); }
    else cpSync(s, d);
  }
}

function invoke(repo: string, project: string, mode: Mode, gate: Gate): Diagnostic[] {
  return runPortedChain(repo, project, mode, gate).diagnostics;
}

function assertRule(results: Diagnostic[], rule: string, name: string): void {
  const hit = results.filter((r) => r.rule_id === rule && r.level === "FAIL");
  assert.ok(hit.length > 0, `${name} did not emit expected FAIL ${rule}`);
}

function assertNoRule(results: Diagnostic[], rule: string, name: string): void {
  const hit = results.filter((r) => r.rule_id === rule && r.level === "FAIL");
  assert.equal(hit.length, 0, `${name} unexpectedly emitted FAIL ${rule}`);
}

interface ChangeRequest {
  id: string;
  detected_at: string;
  source: string;
  classification: string;
  summary: string;
  reason: string;
  affected_requirements: string[];
  affected_artifacts: string[];
  scope_impact: boolean;
  acceptance_impact: boolean;
  mode_impact: string;
  status: string;
  owner: string;
  decision_ref: string;
  downstream_validation?: {
    status: string;
    artifacts: Array<{ path: string; sha256: string }>;
    execution_contracts: unknown[];
  };
}

function setChange(project: string, change: ChangeRequest): void {
  const doc = { schema_version: "1.0", changes: [change] };
  writeFileSync(join(project, "CHANGE-REQUESTS.json"), JSON.stringify(doc, null, 2), "utf8");
}

function setProjectDeclarations(project: string, ui = "dev_guided"): void {
  const path = join(project, "PROJECT.md");
  let text = readFileSync(path, "utf8");
  const declarations = `> Research mode: off\n> Research depth: standard\n> Research provider: none\n> UI delivery: ${ui}\n`;
  text = text.replace(/^(# PROJECT[^\r\n]*\r?\n)/m, `$1\n${declarations}`);
  writeFileSync(path, text, "utf8");
}

test("M2: change control -- proposed harmless patch is auditable but does not block Handoff", () => {
  const workRoot = mkdtempSync(join(tmpdir(), "pmo-m2-m3-"));
  const tempRepo = join(workRoot, "repo");
  try {
    mkdirSync(tempRepo, { recursive: true });
    copyDir(REPO_ROOT, tempRepo);
    const changeProject = join(tempRepo, "examples/HANDOFF-DEMO");

    const baseChange: ChangeRequest = {
      id: "CR-001", detected_at: "2026-08-14T00:00:00Z", source: "implementation", classification: "patch",
      summary: "Small implementation note", reason: "Observed harmless detail", affected_requirements: ["REQ-001"],
      affected_artifacts: ["DESIGN/BUILD-SPEC.md"], scope_impact: false, acceptance_impact: false, mode_impact: "none",
      status: "proposed", owner: "Demo Tech Lead", decision_ref: "",
    };
    setChange(changeProject, baseChange);
    let result = invoke(tempRepo, changeProject, "Standard", "Handoff");
    assertNoRule(result, "CHANGE-003", "proposed harmless patch");

    // Diagnostics identify only the registry entry, never a credential-like
    // string present in the candidate summary.
    baseChange.summary = "Observed sk-THIS-MUST-NOT-LEAK-12345678901234567890 detail";
    baseChange.classification = "scope";
    baseChange.scope_impact = true;
    setChange(changeProject, baseChange);
    result = invoke(tempRepo, changeProject, "Standard", "Handoff");
    assertRule(result, "CHANGE-003", "unresolved scope change");
    assert.ok(
      !result.some((r) => r.message.includes("sk-THIS-MUST-NOT-LEAK")),
      "CHANGE diagnostics leaked sensitive candidate text",
    );

    // A disposed blocking change must cite a real named Human decision.
    baseChange.status = "approved";
    baseChange.decision_ref = "DEC-999";
    setChange(changeProject, baseChange);
    result = invoke(tempRepo, changeProject, "Standard", "Handoff");
    assertRule(result, "CHANGE-002", "approved change without decision");

    // Implemented Scope impact still blocks until downstream contracts are
    // revalidated; this is the non-silent re-export boundary.
    baseChange.decision_ref = "DEC-002";
    baseChange.status = "implemented";
    setChange(changeProject, baseChange);
    result = invoke(tempRepo, changeProject, "Standard", "Handoff");
    assertRule(result, "CHANGE-003", "implemented scope change without downstream evidence");

    const buildSpec = join(changeProject, "DESIGN/BUILD-SPEC.md");
    const buildHash = createHash("sha256").update(readFileSync(buildSpec)).digest("hex").toLowerCase();
    baseChange.downstream_validation = {
      status: "current",
      artifacts: [{ path: "DESIGN/BUILD-SPEC.md", sha256: buildHash }],
      execution_contracts: [],
    };
    setChange(changeProject, baseChange);
    result = invoke(tempRepo, changeProject, "Standard", "Handoff");
    assertNoRule(result, "CHANGE-003", "implemented scope change with current downstream evidence");
  } finally {
    rmSync(workRoot, { recursive: true, force: true });
  }
});

test("M3: explicit UI-path projects require early Test Strategy coverage", () => {
  const workRoot = mkdtempSync(join(tmpdir(), "pmo-m2-m3-"));
  const tempRepo = join(workRoot, "repo");
  try {
    mkdirSync(tempRepo, { recursive: true });
    copyDir(REPO_ROOT, tempRepo);

    const designProject = join(tempRepo, "examples/HANDOFF-DEMO");
    rmSync(join(designProject, "CHANGE-REQUESTS.json"), { force: true });
    setProjectDeclarations(designProject, "dev_guided");

    const buildSpecPath = join(designProject, "DESIGN/BUILD-SPEC.md");
    const originalBuildSpec = readFileSync(buildSpecPath, "utf8");
    const withoutStrategy = originalBuildSpec.replace(/\r?\n### Test Strategy\r?\n[\s\S]*?(?=\r?\n### |(?![\s\S]))/, "");
    writeFileSync(buildSpecPath, withoutStrategy, "utf8");
    let result = invoke(tempRepo, designProject, "Standard", "Design");
    assertRule(result, "TEST-DESIGN-001", "Standard Design without early Test Strategy");

    const strategy = `
### Test Strategy

Status: specified

| Test Area | Requirement / Risk Ref | Level | Execution | Environment | Owner |
|---|---|---|---|---|---|
| Scan lookup | REQ-001 | system | automated | local | Demo Tech Lead |
| Consume stock | REQ-002 | system | automated | local | Demo Tech Lead |
| Receive stock | REQ-003 | system | automated | local | Demo Tech Lead |
| Attach photo | REQ-004 | system | manual | tablet | Demo Tech Lead |
`;
    writeFileSync(buildSpecPath, withoutStrategy.trimEnd() + strategy, "utf8");
    result = invoke(tempRepo, designProject, "Standard", "Design");
    assertNoRule(result, "TEST-DESIGN-001", "complete early Test Strategy");
    assertNoRule(result, "TEST-DESIGN-002", "complete requirement coverage");

    const mutatedStrategy = readFileSync(buildSpecPath, "utf8").replace(
      /\| Attach photo \| REQ-004 \|/,
      "| Attach photo | R-UNKNOWN |",
    );
    writeFileSync(buildSpecPath, mutatedStrategy, "utf8");
    result = invoke(tempRepo, designProject, "Standard", "Design");
    assertRule(result, "TEST-DESIGN-002", "missing scoped requirement coverage");

    // Strict mode keeps the same canonical table but requires a concrete
    // test level for each detailed requirement/risk case.
    const strictProject = designProject;
    const strictBuildSpec = join(strictProject, "DESIGN/BUILD-SPEC.md");
    let strictText = readFileSync(strictBuildSpec, "utf8");
    strictText = strictText.replace(/^> UI delivery: dev_guided\s*$/m, "> UI delivery: not_applicable");
    strictText = strictText + strategy;
    writeFileSync(strictBuildSpec, strictText, "utf8");
    let strictProjectText = readFileSync(join(strictProject, "PROJECT.md"), "utf8");
    strictProjectText = strictProjectText.replace(/^> UI delivery: dev_guided\s*$/m, "> UI delivery: not_applicable");
    writeFileSync(join(strictProject, "PROJECT.md"), strictProjectText, "utf8");
    const strictMutated = readFileSync(strictBuildSpec, "utf8").replace(
      /\| Scan lookup \| REQ-001 \| system \|/,
      "| Scan lookup | REQ-001 | <level> |",
    );
    writeFileSync(strictBuildSpec, strictMutated, "utf8");
    result = invoke(tempRepo, strictProject, "Strict", "Design");
    assertRule(result, "TEST-DESIGN-001", "Strict strategy without concrete test level");

    // Legacy projects with no new declarations stay silent.
    const legacyProject = join(tempRepo, "examples/STANDARD-FEATURE");
    result = invoke(tempRepo, legacyProject, "Standard", "Design");
    assertNoRule(result, "TEST-DESIGN-001", "legacy project compatibility");
    assertNoRule(result, "TEST-DESIGN-002", "legacy project compatibility");
  } finally {
    rmSync(workRoot, { recursive: true, force: true });
  }
});
