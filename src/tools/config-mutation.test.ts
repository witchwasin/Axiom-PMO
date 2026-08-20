// Config-mutation tests, ported from tests/helpers/config-mutation-tests.ps1.
// CR-003: proves each load-bearing policy key drives the Node implementation.
// Each mutation changes one knob and asserts the SPECIFIC rule fires.

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, statSync, copyFileSync, rmSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { runPortedChain } from "../probe/validate-chain.js";
import { runPmoDoctor } from "../doctor/pmo-doctor.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

function copyDir(src: string, dest: string): void {
  for (const entry of readdirSync(src)) {
    if (entry === ".git") continue;
    const s = join(src, entry);
    const d = join(dest, entry);
    if (statSync(s).isDirectory()) { mkdirSync(d, { recursive: true }); copyDir(s, d); }
    else copyFileSync(s, d);
  }
}

function writeJson(path: string, doc: unknown): void {
  writeFileSync(path, JSON.stringify(doc, null, 2) + "\n", "utf8");
}

function readJson(path: string): Record<string, unknown> {
  let raw = readFileSync(path, "utf8");
  if (raw.charCodeAt(0) === 0xfeff) raw = raw.slice(1);
  return JSON.parse(raw);
}

test("config mutation proves JSON runtime config is the source of truth", () => {
  const workRoot = mkdtempSync(join(tmpdir(), "pmo-config-mutation-"));
  const tempRepo = join(workRoot, "repo");
  try {
    mkdirSync(tempRepo, { recursive: true });
    copyDir(REPO_ROOT, tempRepo);

    const validate = (project: string, mode: "Lite" | "Standard" | "Strict", gate: "Draft" | "Scope" | "Design" | "Handoff" | "Release") =>
      runPortedChain(tempRepo, join(tempRepo, project), mode, gate).diagnostics;

    // 1. policy enum mutation → ENUM-001
    const policyPath = join(tempRepo, "pmo-config/policy.json");
    let policy = readJson(policyPath);
    (policy["enums"] as Record<string, unknown>)["statuses"] = ((policy["enums"] as Record<string, unknown>)["statuses"] as string[]).filter((s) => s !== "Done");
    writeJson(policyPath, policy);
    let diags = validate("tests/fixtures/valid-standard", "Standard", "Release");
    assert.ok(diags.some((d) => d.rule_id === "ENUM-001" && d.level === "FAIL"), "policy enum mutation fires ENUM-001");

    // 2. skill manifest mutation → DOCTOR-001
    const manifestPath = join(tempRepo, "pmo-config/skill-manifest.json");
    const manifest = readJson(manifestPath);
    manifest["active_skills"] = (manifest["active_skills"] as Array<Record<string, unknown>>).filter((s) => s["id"] !== "pmo-intake");
    writeJson(manifestPath, manifest);
    let doctor = runPmoDoctor(tempRepo);
    assert.ok(doctor.rows.some((r) => r.rule_id === "DOCTOR-001" && r.level === "FAIL"), "skill manifest mutation fires DOCTOR-001");

    // 3. artifact-policy mutation → STRUCT-001
    copyFileSync(join(REPO_ROOT, "pmo-config/policy.json"), policyPath);
    const artifactPolicyPath = join(tempRepo, "pmo-config/artifact-policy.json");
    const artifactPolicy = readJson(artifactPolicyPath);
    const matrix = (artifactPolicy["artifact_matrix"] as Record<string, unknown>)["Standard"] as Record<string, unknown>;
    matrix["Release"] = [...(matrix["Release"] as string[]), "RTM.json"];
    writeJson(artifactPolicyPath, artifactPolicy);
    diags = validate("tests/fixtures/valid-standard", "Standard", "Release");
    assert.ok(diags.some((d) => d.rule_id === "STRUCT-001" && d.level === "FAIL"), "artifact-policy mutation fires STRUCT-001");

    // 4. orchestration-policy enum mutation → RESEARCH-001
    copyFileSync(join(REPO_ROOT, "pmo-config/artifact-policy.json"), artifactPolicyPath);
    const orchestrationPath = join(tempRepo, "pmo-config/orchestration-policy.json");
    const orchestration = readJson(orchestrationPath);
    (orchestration["research"] as Record<string, unknown>)["modes"] = ((orchestration["research"] as Record<string, unknown>)["modes"] as string[]).filter((m) => m !== "off");
    writeJson(orchestrationPath, orchestration);

    const liteProject = join(tempRepo, "examples/LITE-BUGFIX/PROJECT.md");
    let projectText = readFileSync(liteProject, "utf8");
    if (projectText.charCodeAt(0) === 0xfeff) projectText = projectText.slice(1); // strip BOM like PS Get-Content -Raw
    const declarations = "> Research mode: off\n> Research depth: standard\n> Research provider: none\n> UI delivery: not_applicable\n";
    projectText = projectText.replace(/^(# PROJECT[^\r\n]*\r?\n)/m, `$1\n${declarations}`);
    writeFileSync(liteProject, projectText, "utf8");
    diags = validate("examples/LITE-BUGFIX", "Lite", "Scope");
    assert.ok(diags.some((d) => d.rule_id === "RESEARCH-001" && d.level === "FAIL"), "orchestration enum mutation fires RESEARCH-001");

    // 5. externalization.internal_default_human_review flip
    copyFileSync(join(REPO_ROOT, "pmo-config/orchestration-policy.json"), orchestrationPath);
    const extPath = join(tempRepo, "examples/OPTIONAL-TRACKS/EXTERNALIZATION.json");
    const extDoc = readJson(extPath);
    (extDoc["entries"] as Array<Record<string, unknown>>)[0]!["classification"] = "Internal";
    (extDoc["entries"] as Array<Record<string, unknown>>)[0]!["human_review_required"] = false;
    (extDoc["entries"] as Array<Record<string, unknown>>)[0]!["reviewer"] = "";
    (extDoc["entries"] as Array<Record<string, unknown>>)[0]!["decision_ref"] = "";
    writeJson(extPath, extDoc);

    let extDiags = validate("examples/OPTIONAL-TRACKS", "Standard", "Scope");
    assert.equal(extDiags.filter((d) => d.rule_id === "EXT-002" && d.level === "FAIL").length, 0, "internal proceeds under false default");

    let orch = readJson(orchestrationPath);
    (orch["externalization"] as Record<string, unknown>)["internal_default_human_review"] = true;
    writeJson(orchestrationPath, orch);
    extDiags = validate("examples/OPTIONAL-TRACKS", "Standard", "Scope");
    assert.ok(extDiags.filter((d) => d.rule_id === "EXT-002" && d.level === "FAIL").length >= 1, "flipping to true requires Human evidence");

    // 6. research_statuses mutation → RESEARCH-006
    const provPath = join(tempRepo, "examples/OPTIONAL-TRACKS/RESEARCH/PROVENANCE.json");
    const provDoc = readJson(provPath);
    provDoc["research_status"] = "stopped";
    provDoc["stop_reason"] = "Provider unavailable and no fallback configured";
    provDoc["next_action"] = "Human decides whether to defer research or proceed without it";
    writeJson(provPath, provDoc);
    orch = readJson(orchestrationPath);
    (orch["research"] as Record<string, unknown>)["research_statuses"] = ((orch["research"] as Record<string, unknown>)["research_statuses"] as string[]).filter((s) => s !== "stopped");
    writeJson(orchestrationPath, orch);
    diags = validate("examples/OPTIONAL-TRACKS", "Standard", "Scope");
    assert.ok(diags.some((d) => d.rule_id === "RESEARCH-006" && d.level === "FAIL"), "research_statuses mutation fires RESEARCH-006");

    // 7. schema_version mutation → DOCTOR-006
    copyFileSync(join(REPO_ROOT, "pmo-config/orchestration-policy.json"), orchestrationPath);
    policy = readJson(policyPath);
    policy["schema_version"] = "2.0";
    writeJson(policyPath, policy);
    doctor = runPmoDoctor(tempRepo);
    assert.ok(doctor.rows.some((r) => r.rule_id === "DOCTOR-006" && r.level === "FAIL"), "schema_version mutation fires DOCTOR-006");

    // 8. rule catalog mutation → DOCTOR-007
    const rulesPath = join(tempRepo, "pmo-config/validation-rules.json");
    let rules = readJson(rulesPath);
    delete (rules["rules"] as Record<string, unknown>)["REF-001"];
    writeJson(rulesPath, rules);
    doctor = runPmoDoctor(tempRepo);
    assert.ok(doctor.rows.some((r) => r.rule_id === "DOCTOR-007" && r.level === "FAIL"), "rule catalog mutation fires DOCTOR-007");

    // 9. handoff owner-token mutation → HANDOFF-003
    copyFileSync(join(REPO_ROOT, "pmo-config/validation-rules.json"), rulesPath);
    copyFileSync(join(REPO_ROOT, "pmo-config/policy.json"), policyPath);
    const handoffPath = join(tempRepo, "pmo-config/handoff-policy.json");
    let handoff = readJson(handoffPath);
    ((handoff["owner_policy"] as Record<string, unknown>)["generic_tokens"] as string[]).push("R. Silva");
    writeJson(handoffPath, handoff);
    diags = validate("examples/HANDOFF-DEMO", "Standard", "Handoff");
    assert.ok(diags.some((d) => d.rule_id === "HANDOFF-003" && d.level === "FAIL"), "owner-token mutation fires HANDOFF-003");

    // 10. handoff review-lens mutation → HANDOFF-010
    copyFileSync(join(REPO_ROOT, "pmo-config/handoff-policy.json"), handoffPath);
    handoff = readJson(handoffPath);
    (handoff["semantic_review"] as Record<string, unknown>)["lenses"] = [
      ...((handoff["semantic_review"] as Record<string, unknown>)["lenses"] as Array<Record<string, unknown>>),
      { id: "mutation_test_lens", title: "Added by the config mutation test" },
    ];
    writeJson(handoffPath, handoff);
    diags = validate("examples/HANDOFF-DEMO", "Standard", "Handoff");
    assert.ok(diags.some((d) => d.rule_id === "HANDOFF-010" && d.level === "FAIL"), "review-lens mutation fires HANDOFF-010");

    // 11. experimental rule with blocking severity → DOCTOR-014
    copyFileSync(join(REPO_ROOT, "pmo-config/handoff-policy.json"), handoffPath);
    rules = readJson(rulesPath);
    ((rules["rules"] as Record<string, unknown>)["STRUCT-001"] as Record<string, unknown>)["lifecycle"] = "experimental";
    writeJson(rulesPath, rules);
    doctor = runPmoDoctor(tempRepo);
    assert.ok(doctor.rows.some((r) => r.rule_id === "DOCTOR-014" && r.level === "FAIL"), "experimental blocking rule fires DOCTOR-014");

    // 12. build_spec section heading mutation → DOCTOR-015
    copyFileSync(join(REPO_ROOT, "pmo-config/validation-rules.json"), rulesPath);
    handoff = readJson(handoffPath);
    const sections = ((handoff["build_spec"] as Record<string, unknown>)["sections"] as Array<Record<string, unknown>>);
    sections[0]!["heading"] = "Mutated Technology Stack Heading";
    writeJson(handoffPath, handoff);
    doctor = runPmoDoctor(tempRepo);
    assert.ok(doctor.rows.some((r) => r.rule_id === "DOCTOR-015" && r.level === "FAIL"), "build_spec section heading mutation fires DOCTOR-015");
  } finally {
    rmSync(workRoot, { recursive: true, force: true });
  }
});
