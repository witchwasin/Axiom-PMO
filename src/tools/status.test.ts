// status lifecycle test, ported from tests/helpers/status-tests.ps1. Mutates a
// temp copy of OPTIONAL-TRACKS to assert status reports DECLARED lifecycle
// (research/ui-delivery/provider-review/open-changes), not mere file existence.

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, writeFileSync, mkdirSync, existsSync, rmSync, mkdtempSync, readdirSync, statSync, copyFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { runPmoStatus, type StatusResult } from "./pmo-status.js";

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

test("status reports declared lifecycle through state transitions", () => {
  const workRoot = mkdtempSync(join(tmpdir(), "pmo-status-"));
  const tempRepo = join(workRoot, "repo");
  try {
    mkdirSync(tempRepo, { recursive: true });
    copyDir(REPO_ROOT, tempRepo);
    const active = join(tempRepo, "examples/OPTIONAL-TRACKS");
    const status = () => JSON.parse(runPmoStatus(tempRepo, active, "Json").output) as StatusResult;

    // 1. baseline
    let s = status();
    assert.equal(s.research_state, "complete");
    assert.equal(s.ui_delivery_state, "accepted");
    assert.equal(s.provider_review_state, "current");
    assert.equal(s.open_governed_changes, 0);
    assert.ok(/Handoff/.test(s.next_action ?? ""));

    // 2. stale provider review
    const reviewPath = join(active, "DESIGN/CLAUDE-DESIGN/REVIEW.json");
    const reviewDoc = JSON.parse(readFileSync(reviewPath, "utf8"));
    reviewDoc.preflight.manifest_digest = "0".repeat(64);
    writeFileSync(reviewPath, JSON.stringify(reviewDoc, null, 2));
    s = status();
    assert.equal(s.provider_review_state, "stale");
    copyFileSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/REVIEW.json"), reviewPath);

    // 3. missing provider review
    rmSync(reviewPath, { force: true });
    s = status();
    assert.equal(s.provider_review_state, "missing");
    assert.equal(s.ui_delivery_state, "preparing");
    copyFileSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/REVIEW.json"), reviewPath);

    // 4. stopped research
    const provPath = join(active, "RESEARCH/PROVENANCE.json");
    const provDoc = JSON.parse(readFileSync(provPath, "utf8"));
    provDoc.research_status = "stopped";
    provDoc.stop_reason = "Research provider unavailable and no fallback configured";
    provDoc.next_action = "Human decides whether to defer research or proceed without it";
    writeFileSync(provPath, JSON.stringify(provDoc, null, 2));
    s = status();
    assert.equal(s.research_state, "stopped");
    assert.ok(/stopped/.test(s.next_action ?? ""));
    copyFileSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/RESEARCH/PROVENANCE.json"), provPath);

    // 5. approved-but-unimplemented change counted
    const crPath = join(active, "CHANGE-REQUESTS.json");
    const crDoc = JSON.parse(readFileSync(crPath, "utf8"));
    crDoc.changes[0].status = "approved";
    writeFileSync(crPath, JSON.stringify(crDoc, null, 2));
    s = status();
    assert.equal(s.open_governed_changes, 1);
    assert.ok(/change/.test(s.next_action ?? ""));
    copyFileSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/CHANGE-REQUESTS.json"), crPath);

    // 6. text status reports lifecycle + next action
    const text = runPmoStatus(tempRepo, active, "Text").output;
    assert.ok(/Research:\s+guided \(standard, feyman\) - complete/.test(text));
    assert.ok(/UI Delivery:\s+claude_design - accepted/.test(text));
    assert.ok(/Next action:/.test(text));
  } finally {
    rmSync(workRoot, { recursive: true, force: true });
  }
});
