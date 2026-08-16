// Ported from tests/helpers/visual-proof-tests.ps1 (Milestone 10 conditional
// Visual Proof evidence), adapted for the Node port.
//
// The permanent fixtures deliberately stay free of Visual Proof so they retain
// their compatibility value. Each case below copies the already-valid Strict
// handoff fixture into an exact temporary directory, then adds only the
// optional creative artifact trio. The PNG files are deterministic test-only
// headers: this validator verifies a committed PNG signature/IHDR size and
// identity hash, not rendering provenance or visual quality.
//
// Calls runPortedChain (the in-process equivalent of validate-project.ps1) and
// the ported digest tools in-process rather than spawning scripts, per the
// established pattern.

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  mkdtempSync, mkdirSync, cpSync, rmSync, writeFileSync, readFileSync, existsSync, appendFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { runPortedChain } from "../probe/validate-chain.js";
import { handoffDigest, visualProofDigest } from "./digest-tools.js";
import { importPmoConfig } from "../config/config-loader.js";
import { getArtifactSha256 } from "../digest/artifact-hash.js";
import type { Diagnostic } from "../core/types.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const FIXTURE = join(REPO_ROOT, "tests/fixtures/valid-handoff-strict");

const cfg = importPmoConfig(REPO_ROOT);
const proofPolicy = (cfg.handoffPolicy["visual_proof"] ?? {}) as Record<string, unknown>;

const DIRECTION = [
  "# VISUAL DIRECTION - HANDOFF-DEMO",
  "",
  "## Status",
  "",
  "- stage: selected",
  "- direction_status: selected",
  "- selected_direction: VD-01 Workshop Signal",
  "- direction_decision_ref: DEC-002",
  "",
  "## Selected Direction",
  "",
  "Workshop Signal uses clear scan lanes and high-contrast state markers for the floor tablet.",
].join("\n");

const SYSTEM = [
  "# DESIGN-SYSTEM - HANDOFF-DEMO",
  "",
  "## Status",
  "",
  "- direction_status: selected",
  "- direction_decision_ref: DEC-002",
  "",
  "## Design Tokens - Color",
  "",
  "| Token | Value | Role |",
  "|---|---|---|",
  "| color-ink-900 | #111827 | tablet headings and labels |",
  "| color-signal-500 | #0F766E | confirmed scan state |",
].join("\n");

const SHEET = [
  "<!doctype html>",
  '<html lang="en">',
  '<head><meta charset="utf-8"><style>',
  ":root { --color-ink-900: #111827; --color-signal-500: #0F766E; }",
  "body { color: var(--color-ink-900); }",
  "</style></head>",
  '<body><main id="screen-examples"><h1>Workshop Signal</h1><p>Illustrative tablet sheet.</p></main></body>',
  "</html>",
].join("\n");

function writeUtf8(path: string, text: string): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, text, "utf8");
}

// The validator's deterministic PNG check reads the PNG signature and IHDR
// width/height. These bytes intentionally are not offered as a rendered UI.
function writePngHeader(path: string, width: number, height: number): void {
  mkdirSync(dirname(path), { recursive: true });
  const bytes = Buffer.alloc(24);
  Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]).copy(bytes, 0);
  bytes[8] = 0; bytes[9] = 0; bytes[10] = 0; bytes[11] = 13;
  bytes[12] = 73; bytes[13] = 72; bytes[14] = 68; bytes[15] = 82;
  bytes.writeUInt32BE(width, 16);
  bytes.writeUInt32BE(height, 20);
  writeFileSync(path, bytes);
}

function newTestProject(workRoot: string): string {
  const project = join(workRoot, `project-${Math.random().toString(36).slice(2, 12)}`);
  cpSync(FIXTURE, project, { recursive: true });
  return project;
}

function addVisualProofArtifacts(project: string): void {
  const design = join(project, "DESIGN");
  writeUtf8(join(design, "VISUAL-DIRECTION.md"), DIRECTION + "\n");
  writeUtf8(join(design, "DESIGN-SYSTEM.md"), SYSTEM + "\n");
  writeUtf8(join(design, "DESIGN-SYSTEM.html"), SHEET + "\n");

  const decisionPath = join(project, "decision-log.md");
  const existingRaw = readFileSync(decisionPath, "utf8");
  const existing = existingRaw.replace(/[\r\n]+$/, "");
  const decision = "| DEC-007 | Named human reviewed the committed Visual Proof evidence. | The review records local artifact identity only. | REQ-20260714 row 1 | 2026-08-11 | Morgan Chen |";
  writeUtf8(decisionPath, existing + "\n" + decision + "\n");

  for (const capture of (proofPolicy["captures"] as Array<Record<string, unknown>>) ?? []) {
    writePngHeader(join(project, String(capture["path"])), Number(capture["min_width"]), Number(capture["min_height"]));
  }

  // This existing Strict fixture carries a semantic handoff review whose input
  // digest includes decision-log.md. Adding DEC-007 is intentional, so reseal
  // that separate review against its actual input set before testing Visual
  // Proof. VISUAL-REVIEW.json is deliberately not part of that digest.
  const handoffReviewPath = join(project, "HANDOFF-REVIEW.json");
  const handoffReview = JSON.parse(readFileSync(handoffReviewPath, "utf8")) as Record<string, unknown>;
  const reviewInputs = handoffReview["review_inputs"] as Record<string, unknown>;
  reviewInputs["digest"] = handoffDigest(REPO_ROOT, project, "ReviewInputs").output.trim();
  writeUtf8(handoffReviewPath, JSON.stringify(handoffReview) + "\n");
}

function newVisualProofReview(project: string): void {
  const captures = ((proofPolicy["captures"] as Array<Record<string, unknown>>) ?? []).map((capture) => {
    const relative = String(capture["path"]);
    return {
      id: String(capture["id"]),
      path: relative,
      sha256: getArtifactSha256(join(project, relative)),
      viewport: {
        width: Number(capture["min_viewport_width"]),
        height: Number(capture["min_viewport_height"]),
      },
      captured_at: "2026-08-11T10:00:00Z",
      capture_method: "local_browser_screenshot",
    };
  });
  const rubric = ((proofPolicy["rubric"] as Array<Record<string, unknown>>) ?? []).map((item) => ({
    id: String(item["id"]),
    status: "reviewed",
    notes: "Named human reviewed this rubric item against the selected direction.",
  }));
  const review = {
    schema_version: String(proofPolicy["schema_version"]),
    project_code: "HANDOFF-DEMO",
    reviewed_at: "2026-08-11",
    reviewer_kind: "human",
    reviewer: "Morgan Chen, Product Design Lead",
    decision_ref: "DEC-007",
    visual_direction: {
      selected_direction: "VD-01 Workshop Signal",
      decision_ref: "DEC-002",
    },
    review_inputs: { digest: visualProofDigest(REPO_ROOT, project).output.trim() },
    captures,
    rubric,
    findings: [],
    recommendation: {
      status: "accepted",
      notes: "Named human reviewed the committed captures. This is candidate evidence, not approval.",
    },
  };
  writeUtf8(join(project, String(proofPolicy["artifact"])), JSON.stringify(review) + "\n");
}

function newVisualProofProject(workRoot: string): string {
  const project = newTestProject(workRoot);
  addVisualProofArtifacts(project);
  newVisualProofReview(project);
  return project;
}

function readReview(project: string): Record<string, any> {
  return JSON.parse(readFileSync(join(project, String(proofPolicy["artifact"])), "utf8")) as Record<string, any>;
}

function writeReview(project: string, review: Record<string, any>): void {
  writeUtf8(join(project, String(proofPolicy["artifact"])), JSON.stringify(review) + "\n");
}

function ruleHits(diagnostics: Diagnostic[], ruleId: string, level = ""): Diagnostic[] {
  return diagnostics.filter((d) => d.rule_id === ruleId && (level === "" || d.level === level));
}

function chainFailed(diagnostics: Diagnostic[]): boolean {
  return diagnostics.some((d) => d.level === "FAIL");
}

function failureSummary(diagnostics: Diagnostic[]): string {
  const hits = diagnostics.filter((d) => d.level === "FAIL");
  if (hits.length === 0) return "none";
  return hits.slice(0, 4).map((d) => `${d.rule_id}: ${d.message}`).join(" | ");
}

test("visual proof: policy requires human reviewer attestation only", () => {
  const reviewerKinds = ((proofPolicy["reviewer_kinds"] as string[]) ?? []).map(String);
  assert.ok(
    reviewerKinds.length === 1 && reviewerKinds[0] === "human",
    `Visual Proof policy requires human reviewer attestation only (reviewer_kinds=${reviewerKinds.join(", ")})`,
  );
});

test("visual proof: legacy and complete-active behavior", () => {
  const workRoot = mkdtempSync(join(tmpdir(), "axiom-visual-proof-"));
  try {
    // The unchanged valid handoff fixture proves the check is genuinely
    // conditional and does not retroactively require new artifacts.
    const legacy = newTestProject(workRoot);
    const legacyRun = runPortedChain(REPO_ROOT, legacy, "Strict", "Handoff").diagnostics;
    assert.ok(!chainFailed(legacyRun), `legacy handoff without the visual trio still passes (${failureSummary(legacyRun)})`);
    assert.equal(ruleHits(legacyRun, "VPROOF-001").length, 0, "legacy handoff does not activate Visual Proof");

    const valid = newVisualProofProject(workRoot);
    const validRun = runPortedChain(REPO_ROOT, valid, "Strict", "Handoff").diagnostics;
    assert.ok(!chainFailed(validRun), `complete active Visual Proof passes the Handoff gate (${failureSummary(validRun)})`);
    assert.equal(ruleHits(validRun, "VPROOF-001", "PASS").length, 1, "complete active Visual Proof reports evidence completeness");
    assert.equal(ruleHits(validRun, "VPROOF-002", "PASS").length, 1, "complete active Visual Proof reports current digest");
  } finally {
    rmSync(workRoot, { recursive: true, force: true });
  }
});

test("visual proof: failure cases", () => {
  const workRoot = mkdtempSync(join(tmpdir(), "axiom-visual-proof-"));
  try {
    // Active Visual Proof without a manifest.
    const missingReview = newVisualProofProject(workRoot);
    rmSync(join(missingReview, String(proofPolicy["artifact"])), { force: true });
    let run = runPortedChain(REPO_ROOT, missingReview, "Strict", "Handoff").diagnostics;
    assert.ok(ruleHits(run, "VPROOF-001", "FAIL").length > 0, "active Visual Proof without a manifest fails VPROOF-001");

    // A reviewed visual input changed after capture.
    const stale = newVisualProofProject(workRoot);
    appendFileSync(join(stale, "DESIGN/DESIGN-SYSTEM.html"), "<!-- reviewed sheet changed after capture -->");
    run = runPortedChain(REPO_ROOT, stale, "Strict", "Handoff").diagnostics;
    assert.equal(ruleHits(run, "VPROOF-002", "FAIL").length, 1, "changing a reviewed visual input fails VPROOF-002");

    // A committed capture changed without resealing its recorded hash.
    const badHash = newVisualProofProject(workRoot);
    const desktop = (proofPolicy["captures"] as Array<Record<string, unknown>>).find((c) => String(c["id"]) === "desktop")!;
    appendFileSync(join(badHash, String(desktop["path"])), "tampered");
    run = runPortedChain(REPO_ROOT, badHash, "Strict", "Handoff").diagnostics;
    const hashHits = ruleHits(run, "VPROOF-001", "FAIL").filter((d) => /sha256/.test(d.message));
    assert.equal(hashHits.length, 1, "changing a committed capture without resealing its hash fails VPROOF-001");

    // The capture manifest path must bind to the policy's committed local path.
    const wrongPath = newVisualProofProject(workRoot);
    const wrongPathReview = readReview(wrongPath);
    const wrongPathDesktop = wrongPathReview["captures"].find((c: Record<string, unknown>) => c["id"] === "desktop");
    wrongPathDesktop["path"] = "DESIGN/VISUAL-PROOF/another-desktop.png";
    writeReview(wrongPath, wrongPathReview);
    run = runPortedChain(REPO_ROOT, wrongPath, "Strict", "Handoff").diagnostics;
    const pathHits = ruleHits(run, "VPROOF-001", "FAIL").filter((d) => /path is not the required local path/.test(d.message));
    assert.equal(pathHits.length, 1, "capture manifest path must bind to the policy's committed local path");

    // An AI reviewer attestation cannot satisfy named-human Visual Proof.
    const aiReviewer = newVisualProofProject(workRoot);
    const aiReview = readReview(aiReviewer);
    aiReview["reviewer_kind"] = "ai";
    writeReview(aiReviewer, aiReview);
    run = runPortedChain(REPO_ROOT, aiReviewer, "Strict", "Handoff").diagnostics;
    const aiHits = ruleHits(run, "VPROOF-001", "FAIL").filter((d) => /reviewer_kind/.test(d.message));
    assert.equal(aiHits.length, 1, "AI reviewer attestation cannot satisfy named-human Visual Proof");

    // The decision declaration requires a named human owner.
    const unnamed = newVisualProofProject(workRoot);
    const decisionPath = join(unnamed, "decision-log.md");
    const logRaw = readFileSync(decisionPath, "utf8");
    writeUtf8(decisionPath, logRaw.replace("| Morgan Chen |", "| Team |"));
    run = runPortedChain(REPO_ROOT, unnamed, "Strict", "Handoff").diagnostics;
    const authorityHits = ruleHits(run, "VPROOF-001", "FAIL").filter((d) => /decision owner/.test(d.message));
    assert.equal(authorityHits.length, 1, "Visual Proof decision declaration requires a named human owner");
  } finally {
    rmSync(workRoot, { recursive: true, force: true });
  }
});
