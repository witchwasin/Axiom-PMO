// Ported from tests/helpers/learning-registry-tests.ps1. Each case runs in an
// isolated repo root so cases cannot see each other's events, and so this
// file never touches the real repository's own .axiom/learning/.

import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, cpSync, rmSync, readFileSync, readdirSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { aggregateDiagnostics, normalizeItemId, normalizeExecutionPath } from "./aggregate-diagnostics.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

function newIsolatedRepoRoot(): string {
  const dir = mkdtempSync(join(tmpdir(), "axiom-learning-"));
  cpSync(join(REPO_ROOT, "pmo-config"), join(dir, "pmo-config"), { recursive: true });
  cpSync(join(REPO_ROOT, "tests/fixtures"), join(dir, "tests/fixtures"), { recursive: true });
  return dir;
}

function readEvents(isolated: string): Record<string, unknown>[] {
  const eventsDir = join(isolated, ".axiom/learning/events");
  if (!existsSync(eventsDir)) return [];
  const events: Record<string, unknown>[] = [];
  for (const f of readdirSync(eventsDir).filter((f) => f.endsWith(".jsonl"))) {
    for (const line of readFileSync(join(eventsDir, f), "utf8").split("\n")) {
      if (line.trim()) events.push(JSON.parse(line));
    }
  }
  return events;
}

test("no artifact content or free text reaches an event", () => {
  const isolated = newIsolatedRepoRoot();
  try {
    aggregateDiagnostics(isolated, join(isolated, "tests/fixtures/invalid-mode-downgrade-workitem"), "Standard", "Release", false, "Json");
    const eventsDir = join(isolated, ".axiom/learning/events");
    const files = existsSync(eventsDir) ? readdirSync(eventsDir).filter((f) => f.endsWith(".jsonl")) : [];
    assert.ok(files.length > 0, "at least one event file was written");

    const allText = files.map((f) => readFileSync(join(eventsDir, f), "utf8")).join("\n");
    // Anchor every privacy assertion on non-empty text: without it they pass
    // vacuously if the aggregator throws before writing anything.
    const haveEvents = allText.trim().length > 0;
    assert.ok(haveEvents && !allText.includes('"message"'), "no event carries a 'message' key");
    assert.ok(haveEvents && !allText.includes('"suggestion"'), "no event carries a 'suggestion' key");
    assert.ok(
      haveEvents && (!/\.md"/.test(allText) || /"artifact":"(PROJECT|DELIVERY|HANDOFF|RELEASE|RAID-log|decision-log)\.md"/.test(allText)),
      "no event carries a raw markdown/source path outside the governed allowlist",
    );
  } finally {
    rmSync(isolated, { recursive: true, force: true });
  }
});

test("an unlisted artifact is bucketed to 'other', not retained", () => {
  const isolated = newIsolatedRepoRoot();
  const governed = [
    "PROJECT.md", "DELIVERY.md", "HANDOFF.md", "RELEASE.md", "RAID-log.md", "decision-log.md",
    "SCOPE.json", "RTM.json", "HANDOFF-REVIEW.json", "EXECUTION-CONTRACT.json",
    "EXECUTION-RESULT.json", "EXECUTION-REVIEW.json", "DESIGN/BUILD-SPEC.md", "DESIGN/FLOW.puml",
    "DESIGN/WIREFRAME.md", "other",
  ];
  try {
    aggregateDiagnostics(isolated, join(isolated, "tests/fixtures/invalid-mode-downgrade-workitem"), "Standard", "Release", false, "Json");
    const events = readEvents(isolated);
    const unlisted = events.filter((e) => e["artifact"] && !governed.includes(String(e["artifact"])));
    assert.equal(unlisted.length, 0, `saw: ${unlisted.map((e) => e["artifact"]).join(", ")}`);
  } finally {
    rmSync(isolated, { recursive: true, force: true });
  }
});

test("rebuild is byte-for-byte identical (generated_at excepted)", () => {
  const isolated = newIsolatedRepoRoot();
  try {
    const r1 = aggregateDiagnostics(isolated, join(isolated, "tests/fixtures/invalid-mode-downgrade-workitem"), "Standard", "Release", false, "Json");
    const registryPath = join(isolated, ".axiom/learning/FAILURE-PATTERNS.json");
    rmSync(registryPath, { force: true });
    const r2 = aggregateDiagnostics(isolated, null, "Standard", "Release", true, "Json");

    const strip = (r: typeof r1) => {
      const clone = JSON.parse(JSON.stringify(r.registry)) as Record<string, unknown>;
      delete clone["generated_at"];
      return JSON.stringify(clone);
    };
    assert.equal(strip(r1), strip(r2), "rebuilt registry matches the original (generated_at aside)");
  } finally {
    rmSync(isolated, { recursive: true, force: true });
  }
});

test("twenty reruns of one unfixed defect do not cross the candidate threshold", () => {
  const isolated = newIsolatedRepoRoot();
  try {
    for (let i = 0; i < 20; i++) {
      aggregateDiagnostics(isolated, join(isolated, "tests/fixtures/invalid-mode-downgrade-workitem"), "Standard", "Release", false, "Json");
    }
    const candidatesDir = join(isolated, ".axiom/learning/candidates");
    const candidateCount = existsSync(candidatesDir) ? readdirSync(candidatesDir).filter((f) => f.endsWith(".json")).length : 0;
    assert.equal(candidateCount, 0, "20 reruns against ONE project/commit produce zero improvement candidates");

    const registry = JSON.parse(readFileSync(join(isolated, ".axiom/learning/FAILURE-PATTERNS.json"), "utf8")) as {
      clusters: Array<{ rule_id: string; count: number; distinct_projects: number }>;
    };
    const modeCluster = registry.clusters.find((c) => c.rule_id === "MODE-001");
    assert.ok(modeCluster, "MODE-001 cluster exists");
    assert.equal(modeCluster!.count, 20);
    assert.equal(modeCluster!.distinct_projects, 1, "MODE-001 cluster recorded 20 events but only 1 distinct project");
  } finally {
    rmSync(isolated, { recursive: true, force: true });
  }
});

test(".gitignore excludes .axiom/learning/events/", () => {
  const gitignore = readFileSync(join(REPO_ROOT, ".gitignore"), "utf8");
  assert.ok(gitignore.includes(".axiom/learning/events/"));
});

test("an alphabetic, potentially sensitive item_id is not retained", () => {
  const policy = JSON.parse(readFileSync(join(REPO_ROOT, "pmo-config/learning-policy.json"), "utf8")) as {
    item_id_allowed_patterns: string[];
    execution_path_allowed_values: string[];
  };

  assert.equal(normalizeItemId("D-123", policy.item_id_allowed_patterns), "D-#", "'D-123' (allowlisted shape) normalizes to 'D-#'");
  assert.equal(
    normalizeItemId("ACME-fraud-case", policy.item_id_allowed_patterns),
    "other",
    "'ACME-fraud-case' (no digits, not an allowlisted shape) is bucketed to 'other', not retained",
  );
  assert.equal(normalizeItemId("patient-HIV", policy.item_id_allowed_patterns), "other", "'patient-HIV' is bucketed to 'other', not retained");
  assert.equal(
    normalizeItemId("D-123-extra", policy.item_id_allowed_patterns),
    "other",
    "a governed shape with extra trailing text ('D-123-extra') is bucketed to 'other', not partially matched",
  );

  assert.equal(
    normalizeExecutionPath("development_handoff", policy.execution_path_allowed_values),
    "development_handoff",
    "'development_handoff' (valid enum) is retained",
  );
  assert.equal(
    normalizeExecutionPath("customer-acme-secret-migration", policy.execution_path_allowed_values),
    "unknown",
    "a malformed execution_path value is normalized to 'unknown', not retained raw",
  );
});
