// Ported from tests/helpers/handoff-assessment-tests.ps1.
//
// The point of the assessment is that it does NOT collapse readiness into one
// boolean, and that the score cannot be inflated past what the evidence
// supports. Both properties are easy to lose in a refactor and neither is
// covered by the fixture suite, which only checks rule ids and exit codes.

import { test } from "node:test";
import assert from "node:assert/strict";
import { resolve, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { runAssessHandoff, type AssessmentResult } from "./assess-handoff.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

function assess(fixture: string, mode = "Standard"): AssessmentResult {
  const { output } = runAssessHandoff(REPO_ROOT, join(REPO_ROOT, fixture), mode, "Json");
  return JSON.parse(output) as AssessmentResult;
}

test("build readiness and demo readiness are separate", () => {
  const demo = assess("examples/HANDOFF-DEMO");
  assert.equal(demo.verdicts["Contract Valid"], true, `verdict=${demo.verdict}`);
  assert.equal(demo.verdicts["Ready to Start Development"], true, `verdict=${demo.verdict}`);
  assert.equal(demo.verdicts["Ready to Demo"], false, `verdict=${demo.verdict}`);
  assert.equal(demo.verdict, "READY TO BUILD, NOT READY TO DEMO", `got '${demo.verdict}'`);
  assert.ok(
    (demo.score.awarded as number) < (demo.score.total as number),
    `score=${demo.score.awarded}/${demo.score.total}`,
  );
  assert.ok(!(demo.semantic_review as Record<string, unknown>)["is_approval"], "the review is never reported as an approval");

  assert.equal(
    ((demo.semantic_review as Record<string, unknown>)["open_blockers"] as Array<Record<string, unknown>>).filter(
      (b) => b["origin"] === "review_finding",
    ).length > 0,
    true,
    "open actions and review findings are distinguishable by origin",
  );
  assert.equal(
    ((demo.semantic_review as Record<string, unknown>)["open_blockers"] as Array<Record<string, unknown>>).filter(
      (b) => b["finding_id"] === "OA-002",
    ).length,
    0,
    "OA-002 is already represented by finding HF-005",
  );
  assert.ok(String(demo.score["disclaimer"] ?? "").trim().length > 0, "disclaimer is empty");
  assert.ok(String(demo.score["disclaimer"]).includes("not an approval"));
});

test("readiness is unknown, not true, when nobody has reviewed", () => {
  const noReviewStages = assess("tests/fixtures/invalid-handoff-review-missing");
  assert.equal(
    noReviewStages.verdicts["Ready to Start Development"],
    null,
    `got '${noReviewStages.verdicts["Ready to Start Development"]}'`,
  );
  assert.ok(
    noReviewStages.verdict_reasons["Ready to Start Development"]?.includes("unknown"),
    `got '${noReviewStages.verdict_reasons["Ready to Start Development"]}'`,
  );
  assert.equal(noReviewStages.verdicts["Contract Valid"], true);

  const staleStages = assess("tests/fixtures/invalid-handoff-review-stale");
  const rtsd = staleStages.verdicts["Ready to Start Development"];
  assert.ok(rtsd === null || rtsd === false, "stale review: readiness is unknown rather than inherited");
});

test("a reviewed artifact changing is staleness too, not just the sources", () => {
  const staleInputs = assess("tests/fixtures/invalid-handoff-review-stale-inputs");
  assert.ok((staleInputs.semantic_review as Record<string, unknown>)["stale"], "editing BUILD-SPEC after review marks the review stale");
  assert.ok(
    String((staleInputs.semantic_review as Record<string, unknown>)["stale_reason"]).includes("artifact"),
    `got '${(staleInputs.semantic_review as Record<string, unknown>)["stale_reason"]}'`,
  );
});

test("open actions in HANDOFF.md block stages, not only review findings", () => {
  const openAction = assess("tests/fixtures/valid-handoff-action-blocks-demo");
  assert.equal(openAction.verdicts["Contract Valid"], true);
  assert.equal(openAction.verdicts["Ready to Demo"], false, `got '${openAction.verdicts["Ready to Demo"]}'`);
  assert.equal(openAction.verdicts["Ready to Start Development"], true);
  assert.ok(
    (
      (openAction.semantic_review as Record<string, unknown>)["open_blockers"] as Array<Record<string, unknown>>
    ).filter((b) => b["origin"] === "open_action").length > 0,
    "the blocking open action is named in the output",
  );

  assert.ok(
    (openAction.score.awarded as number) < (openAction.score.total as number),
    `score=${openAction.score.awarded}/${openAction.score.total} with Ready to Demo = ${openAction.verdicts["Ready to Demo"]}`,
  );
  assert.ok(
    openAction.verdicts["Ready to Demo"] === false && (openAction.score.awarded as number) < 100,
    "a project that blocks its own demo never scores full marks",
  );
  const dims = openAction.score["dimensions"] as Array<Record<string, unknown>>;
  const sourceScope = dims.find((d) => d["id"] === "source_scope_integrity");
  assert.ok(sourceScope && sourceScope["awarded"] === sourceScope["points"], "a non_blocking action costs nothing");
});

test("score caps reflect review absence, staleness, and blocking severity", () => {
  const noReview = assess("tests/fixtures/invalid-handoff-review-missing");
  assert.ok((noReview.score.awarded as number) <= 70, `score=${noReview.score.awarded}`);
  assert.ok(
    (noReview.score["caps_applied"] as Array<Record<string, unknown>>).some((c) => c["id"] === "review_absent_or_stale"),
  );
  assert.equal(noReview.verdict, "CONTRACT VALID, NOT REVIEWED", `got '${noReview.verdict}'`);

  const staleReview = assess("tests/fixtures/invalid-handoff-review-stale");
  assert.ok((staleReview.semantic_review as Record<string, unknown>)["stale"]);
  assert.ok((staleReview.score.awarded as number) <= 70, `score=${staleReview.score.awarded}`);

  const blockedBuild = assess("tests/fixtures/invalid-handoff-open-before-build-critical");
  assert.ok((blockedBuild.score.awarded as number) <= 49, `score=${blockedBuild.score.awarded}`);
  assert.equal(blockedBuild.verdicts["Ready to Start Development"], false);
  assert.ok(
    (blockedBuild.score["caps_applied"] as Array<Record<string, unknown>>).some(
      (c) => c["id"] === "open_before_build_critical",
    ),
  );
});

test("a deterministic FAIL is always BLOCKED, whatever the score says", () => {
  const deterministic = assess("tests/fixtures/invalid-handoff-sequence-inverted");
  assert.equal(deterministic.verdict, "BLOCKED", `got '${deterministic.verdict}'`);
  assert.equal(deterministic.verdicts["Contract Valid"], false);
  assert.equal(
    Object.values(deterministic.verdicts).filter((v) => v !== false).length,
    0,
    "every stage verdict is an explicit false, never unknown",
  );

  const ownerGap = assess("tests/fixtures/invalid-handoff-workitem-generic-owner");
  assert.ok(
    (ownerGap.score["caps_applied"] as Array<Record<string, unknown>>).some((c) => c["id"] === "missing_owner_or_sequence"),
  );
});

test("a clean Lite handoff reports honestly rather than perfectly", () => {
  const lite = assess("tests/fixtures/valid-handoff-lite", "Lite");
  assert.equal(lite.verdicts["Contract Valid"], true, `verdict=${lite.verdict}`);
  assert.ok((lite.score.awarded as number) <= 70, `score=${lite.score.awarded}`);
});
