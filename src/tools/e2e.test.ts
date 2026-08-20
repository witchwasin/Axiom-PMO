// Ported from tests/e2e/lite.ps1, standard.ps1, strict.ps1, handoff.ps1 and
// tests/e2e/lib/fill-project.ps1 (P5.2 / P1.1), adapted for the Node port.
//
// End-to-end: generate a project with the ported generator (newProject),
// fill the REAL generated templates deterministically -- no copying an example
// project over the generator's output -- and walk every gate in order. This is
// what actually exercises the template -> generator -> validator schema
// contract, the exact blind spot that hid the RTM.yaml vs RTM.json mismatch in
// Round 1.
//
// The PS originals spawn scripts/new-project.ps1 and validate-project.ps1 as
// subprocesses; the port calls newProject and runPortedChain in-process, and
// runAssessHandoff for the handoff assessment. Per the established pattern,
// each e2e scenario gets its own fresh tree (§8.6).

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync, existsSync, appendFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { newProject } from "./new-project.js";
import { runAssessHandoff, type AssessmentResult } from "./assess-handoff.js";
import { runPortedChain } from "../probe/validate-chain.js";
import { getSourceSnapshotDigest, getReviewInputDigest } from "../rules/handoff-validator.js";
import { importPmoConfig } from "../config/config-loader.js";
import type { Diagnostic, Gate, Mode } from "../core/types.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

const cfg = importPmoConfig(REPO_ROOT);

function isoDate(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
const TODAY = isoDate(new Date());

// ---- deterministic filler (port of tests/e2e/lib/fill-project.ps1) ---------

// PowerShell -replace is always global; inline (?m) becomes the m flag here.
function rep(text: string, pattern: string, replacement: string, flags = "g"): string {
  return text.replace(new RegExp(pattern, flags), replacement);
}

// Set-Content -Encoding utf8 -NoNewline in pwsh 7 = UTF-8 without BOM, no
// trailing newline.
function psWrite(path: string, content: string): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, content, "utf8");
}

function fillProjectContent(project: string, mode: "Lite" | "Standard" | "Strict", projectCode: string, today: string): void {
  const momId = "MOM-20260710";
  const reqId = "REQ-20260710";

  // --- PROJECT.md ---
  let text = readFileSync(join(project, "PROJECT.md"), "utf8");
  text = rep(text, "> Status: draft.*", "> Status: release-approved");
  text = rep(text, "<PM/PO>", "E2E PM");
  text = rep(text, "<YYYY-MM-DD>", today);
  text = rep(text, "MOM-YYYYMMDD", momId);
  text = rep(text, "REQ-YYYYMMDD", reqId);
  text = rep(text, "<sha256>", "0".repeat(64));
  text = rep(text, "<ISO-8601>", `${today}T09:00:00+07:00`);
  text = rep(text, "> <Who will achieve what outcome by when, measured how\\?>", "> E2E fixture project validates the generator-to-Release path end to end.");
  text = rep(text, "`source/MOM/<file>`", "`source/MOM/mom.md`");
  text = rep(text, "`source/REQ/<file>`", "`source/REQ/req.md`");
  // newProject already substitutes bare "YYYY-MM-DD" with the real date before
  // this filler runs, so only the bracketed placeholder text is left.
  text = rep(text, "<meeting purpose>", "E2E kickoff");
  text = rep(text, "<source note>", "E2E requirement source");
  text = rep(text, "> Task source: file / github", "> Task source: file");
  text = rep(text, "<atomic, testable requirement>", "User can complete the E2E happy path");
  text = rep(text, "<Explicit non-goal>", "Out-of-scope E2E item");
  text = rep(text, "<rule>", "E2E business rule");
  text = rep(text, "<assumption>", "E2E environment is stable");
  text = rep(text, "<how to validate>", "Manual smoke check");
  text = rep(text, "<question>", "None outstanding for the fixture");
  text = rep(text, "<scope/design/test impact>", "none");
  text = rep(text, "<risk>", "E2E fixture risk");
  text = rep(text, "<impact>", "low");
  text = rep(text, "<mitigation>", "None needed for a fixture");
  text = rep(text, "<owner>", "E2E PM");
  text = rep(text, "<approver name>", "E2E Approver");
  // The Design Ready role matrix placeholder entered the template with the M1
  // declaration work; without this the generated Lite/Standard project fails
  // PLACEHOLDER-001 at the Release gate.
  text = rep(text, "<Product Owner / Project Manager / Tech Lead / Solution Architect>", "Product Owner");
  text = rep(text, "^\\| (Scope Approved|Design Ready|Release Approved) \\| pending", "| $1 | approved", "gm");
  // Lite gets no decision-log, so its approval evidence must be a typed ref
  // that resolves without one (H4). Swap the template's DEC-00N approval
  // evidence for an externally-verified ISSUE ref; Standard/Strict keep DEC
  // refs, which their generated decision-log resolves.
  if (mode === "Lite") {
    text = rep(text, "(\\| (?:Scope Approved|Design Ready|Release Approved) \\| approved \\|[^|]*\\|[^|]*\\|[^|]*\\| )DEC-00(\\d) \\|", "$1ISSUE:10$2 |");
  }
  psWrite(join(project, "PROJECT.md"), text);

  // --- DELIVERY.md ---
  let delivery = readFileSync(join(project, "DELIVERY.md"), "utf8");
  delivery = rep(delivery, "- Task source of truth: `file` / `github`", "- Task source of truth: `file`");
  const reviewStage = mode === "Lite" ? "none" : "qa";
  const strictTrigger = mode === "Strict" ? "permission" : "none";
  // M1 changed the generator: DESIGN/FLOW.puml is created only when a UI
  // delivery path is active (default: not_applicable), while DESIGN/BUILD-SPEC.md
  // is always generated for Standard/Strict. Point the design ref at the file
  // that actually exists or REF-001 fails every generated project.
  const designRef = mode === "Lite" ? "not_required" : "DESIGN/BUILD-SPEC.md";
  // Lite work-item evidence must resolve without a decision-log (H4); use a
  // typed ISSUE ref. Standard/Strict use DEC-003 which their decision-log
  // resolves.
  const workItemEvidence = mode === "Lite" ? "ISSUE:123" : "DEC-003";
  const row = `| D-001 | ${mode} | ${strictTrigger} | E2E fixture work item | E2E PM | E2E feature | REQ-001 | ${designRef} | Happy path completes | Happy path | E2E Dev | high | Done | ${reviewStage} | ${workItemEvidence} | e2e |`;
  // Literal (non-regex) replacement text: escape $ for the replacement's own
  // group syntax, exactly as the PS original does.
  const rowLiteral = row.replace(/\$/g, "$$");
  delivery = rep(delivery, "^\\| D-001 \\|.*\\|\\s*$", rowLiteral, "gm");
  psWrite(join(project, "DELIVERY.md"), delivery);

  // --- decision-log.md (generated only for Strict; Standard also needs one
  //     so DEC-### approval/evidence references resolve) ---
  if (mode !== "Lite") {
    psWrite(
      join(project, "decision-log.md"),
      `# Decision Log - ${projectCode}\n\n| ID | Decision | Owner | Date |\n|---|---|---|---|\n| DEC-001 | Scope approved. | E2E PM | ${today} |\n| DEC-002 | Design approved. | E2E PM | ${today} |\n| DEC-003 | Release approved. | E2E PM | ${today} |`,
    );
  }

  // --- RAID-log.md (Strict only, from generator) ---
  if (mode === "Strict") {
    psWrite(
      join(project, "RAID-log.md"),
      `# RAID Log - ${projectCode}\n\n| ID | Type | Description | Owner | Status |\n|---|---|---|---|---|\n| R-001 | risk | E2E fixture risk, already mitigated. | E2E PM | closed |`,
    );
  }

  // --- RELEASE.md (Standard/Strict) ---
  if (mode !== "Lite") {
    let release = readFileSync(join(project, "RELEASE.md"), "utf8");
    release = rep(release, "<Decision ID or MOM>", "DEC-003");
    // H2: Test Summary rows default to "pending" with no evidence; a real
    // release needs a real result, not just an ID the RTM can point at.
    release = rep(release, "\\|\\s*(TEST-\\d{3})\\s*\\|([^|]*)\\|\\s*pending\\s*\\|\\s*\\|\\s*\\|", "| $1 |$2| passed | DEC-003 |");
    const qaRow = `| QA | approved | E2E QA Lead | QA Lead | ${today} | DEC-003 |`;
    release = rep(release, "\\| QA \\| pending \\| <reviewer> \\| QA Lead \\| YYYY-MM-DD \\| <evidence ref> \\|", qaRow);
    if (mode === "Strict") {
      const escapedQa = qaRow.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      release = rep(release, `(${escapedQa})`, `$1\n| Security | approved | E2E Security Lead | Security Reviewer | ${today} | DEC-003 |`);
    }
    release = rep(release, "\\| <rollback trigger> \\| <owner> \\| <numbered rollback steps> \\| <how rollback is verified> \\| <evidence ref> \\|", "| Fixture release blocker | E2E Tech Lead | Revert the E2E change | Fixture no longer shows the change | DEC-003 |");
    release = rep(release, "\\| Release Approved \\| pending \\| <approver name> \\| Product Owner \\| YYYY-MM-DD \\| DEC-001 \\|", `| Release Approved | approved | E2E Approver | Product Owner | ${today} | DEC-003 |`);
    psWrite(join(project, "RELEASE.md"), release);
  }

  // --- RTM.json (Strict only) ---
  if (mode === "Strict") {
    const rtmDoc = {
      schema_version: "1.0",
      project: projectCode,
      traceability: [
        {
          requirement_id: "REQ-001",
          source_ref: `${momId} item-1`,
          design_ref: "DESIGN/BUILD-SPEC.md",
          delivery_ref: "D-001",
          test_ref: "TEST-001",
          evidence_ref: "DEC-003",
          release_ref: "REL-001",
          status: "verified",
        },
      ],
    };
    psWrite(join(project, "RTM.json"), JSON.stringify(rtmDoc));
  }

  // --- DESIGN/WIREFRAME.md (Standard/Strict; only generated when a UI
  //     delivery path is active, which the default is not) ---
  if (mode !== "Lite") {
    const wireframeFile = join(project, "DESIGN/WIREFRAME.md");
    if (existsSync(wireframeFile)) {
      let text2 = readFileSync(wireframeFile, "utf8");
      text2 = rep(text2, "<PROJECT-CODE>", projectCode);
      text2 = rep(text2, "<screen>", "E2E screen");
      text2 = rep(text2, "<Screen Name>", "E2E Screen");
      psWrite(wireframeFile, text2);
    }
  }

  // --- DESIGN/BUILD-SPEC.md (Standard/Strict): the M1 declaration-driven
  //     testability contract makes every generated project require a real Test
  //     Strategy at the Design gate, and the Release gate rejects template
  //     placeholders. Fill the canonical rows and sweep the prose guidance.
  if (mode !== "Lite") {
    const specFile = join(project, "DESIGN/BUILD-SPEC.md");
    if (existsSync(specFile)) {
      let text2 = readFileSync(specFile, "utf8");
      // Table cells first (they carry enum values the prose sweep below would
      // flatten); identical replacements to fillHandoffContent, which runs
      // later for handoff projects and becomes a no-op on already-filled rows.
      text2 = rep(text2, "\\| TD-001 \\| <language / framework / storage> \\| <chosen technology> \\| <alternatives considered> \\| <why chosen> \\| <trade-offs accepted> \\| DEC-001 \\| MOM-YYYYMMDD item-1 \\|", "| TD-001 | runtime | Node.js | Deno, Bun | Industry standard | None | DEC-002 | MOM-20260710 item-1 |");
      text2 = rep(text2, "\\| <rear camera / offline read / file export> \\| <AC-002> \\| <how it is actually served> \\| <DEC-001> \\|", "| Local file read | AC-001 | Same-origin fetch over HTTPS | DEC-002 |");
      text2 = rep(text2, "\\| DC-001 \\| <Part> \\| <quantity_on_hand> \\| <integer> \\| <pieces> \\| <1 per part per location> \\| <>= 0> \\|", "| DC-001 | Record | count | integer | items | 1 per record | >= 0 |");
      text2 = rep(text2, "\\| <Part> \\| <quantity_on_hand> \\| <integer> \\| <pieces> \\| <1 per part per location> \\| <>= 0> \\|", "| DC-001 | Record | count | integer | items | 1 per record | >= 0 |");
      text2 = rep(text2, "\\| ER-001 \\| <Part> \\| <Location> \\| N:1 \\| location_id \\| yes \\| restrict \\|", "| ER-001 | Record | Record | 1:1 | count | no | restrict |");
      text2 = rep(text2, "\\| API-001 \\| <createPart> \\| <name, sku, unit> \\| <201 Created \\+ part_id> \\| <400 invalid_sku, 409 duplicate> \\| no \\| <role> \\|", "| API-001 | createRecord | name, count | 201 Created + id | 400 invalid_input | no | admin |");
      text2 = rep(text2, "\\| TR-001 \\| <draft> \\| <active> \\| <all required fields filled> \\| <deactivate> \\| no \\|", "| TR-001 | draft | active | all required fields filled | deactivate | no |");
      text2 = rep(text2, "\\| <element> \\| <yes / no> \\| <DEC-001 or .not applicable.> \\| <DEC-002 or .retained with the record.> \\|", "| Record identifier | no | not applicable | retained with the record |");
      text2 = rep(text2, "\\| AC-001 \\| <REQ-001> \\| <Given \\.\\.\\., when \\.\\.\\., then \\.\\.\\.> \\| <automated> \\| <seed name> \\| <how to reset> \\|", "| AC-001 | REQ-001 | Given a seeded record, when it is read, then the count is returned | automated | e2e-seed | Regenerate the fixture |");
      text2 = rep(text2, "\\| <area> \\| <REQ-001 or R-001> \\| <unit / integration / system / security / usability> \\| <automated> \\| <environment> \\| <named owner> \\|", "| E2E happy path | REQ-001 | system | automated | local | E2E PM |");
      text2 = rep(text2, "^<[^>\\r\\n]+>[ \\t]*\\r?$", "Specified deterministically by the E2E fixture.", "gm");
      psWrite(specFile, text2);
    }
  }

  // --- source/ (real files so REQ-001's Source Ref and the Others/ folder
  //     both resolve; a TODO here must never block Release). ---
  mkdirSync(join(project, "source/MOM"), { recursive: true });
  mkdirSync(join(project, "source/REQ"), { recursive: true });
  psWrite(join(project, "source/MOM/mom.md"), `# MOM ${today}\n\nTODO: attach recording.`);
  psWrite(join(project, "source/REQ/req.md"), `# REQ notes\n\nSee ${momId} item-1.`);
}

function fillHandoffContent(project: string, mode: "Lite" | "Standard" | "Strict", projectCode: string, today: string): void {
  let text = readFileSync(join(project, "HANDOFF.md"), "utf8");

  text = rep(text, "- Handoff Owner: <Name \\(Role\\)>", "- Handoff Owner: E2E Delivery Lead");
  text = rep(text, "- Named Integrator: <Name \\(Role\\)>", "- Named Integrator: E2E Senior Engineer");

  text = rep(text, "\\| <what it is> \\| <D-001> \\| <why it matters to the target milestone> \\| <Name> \\|", "| E2E feature | D-001 | Proves the generated project reaches the Handoff gate | E2E Dev |");
  text = rep(text, "\\| <what it is> \\| <deferred / do-not-build> \\| <why> \\| <DEC-001> \\|", "| Second E2E feature | deferred | Out of this fixture slice | DEC-002 |");
  text = rep(text, "\\| <constraint> \\| <technical / commercial / legal / operational> \\| <MOM-20260101 item 3> \\|", "| Fixture must validate offline | technical | MOM-20260710 item-1 |");
  text = rep(text, "\\| 1 \\| <D-001> \\| none \\| <Name> \\| <shared prerequisite> \\|", "| 1 | D-001 | none | E2E Dev | Only work item in the fixture |");
  text = rep(text, "^\\| 2 \\| <D-002> \\| <D-001> \\| <Name> \\| <consumer> \\|\\r?\\n", "", "gm");
  text = rep(text, "\\| <dev / demo / pilot> \\| <device, OS, browser and version> \\| <how it is served: localhost, HTTPS via proxy, packaged app> \\| <DEC-001> \\|", "| demo | Desktop Chrome 126 | Served over HTTPS from the fixture host | DEC-002 |");
  text = rep(text, "\\| Demo Date \\| <YYYY-MM-DD> \\|", `| Demo Date | ${today} |`);
  text = rep(text, "\\| Demo Device \\| <the actual hardware it runs on> \\|", "| Demo Device | Fixture desktop, Chrome 126 |");
  text = rep(text, "\\| Integrator \\| <Name> \\|", "| Integrator | E2E Senior Engineer |");
  text = rep(text, "\\| Capacity \\| <person-days available before the date> \\|", "| Capacity | 1 person-day |");
  text = rep(text, "\\| Reset Path \\| <how to return to a clean demo state, and how long it takes> \\|", "| Reset Path | Regenerate the fixture project; takes under a minute |");
  text = rep(text, "\\| Degraded Path \\| <what is shown if the primary path fails live> \\|", "| Degraded Path | Show the recorded validator output instead |");
  text = rep(text, "\\| <criterion> \\| <how it is verified> \\| <Name> \\|", "| Handoff gate passes | scripts/validate-project.ps1 -Gate Handoff | E2E Dev |");
  text = rep(text, "\\| OA-001 \\| <what is unresolved> \\| <Name> \\| <before_demo> \\| <open> \\|", "| OA-001 | Confirm the fixture host is reachable | E2E Delivery Lead | before_demo | open |");
  text = rep(text, "<nothing / list>", "nothing");
  psWrite(join(project, "HANDOFF.md"), text);

  if (mode !== "Lite") {
    const specFile = join(project, "DESIGN/BUILD-SPEC.md");
    let text2 = readFileSync(specFile, "utf8");

    // Tables first: their cells carry enum values the generic sweep below
    // would flatten into prose.
    text2 = rep(text2, "\\| TD-001 \\| <language / framework / storage> \\| <chosen technology> \\| <alternatives considered> \\| <why chosen> \\| <trade-offs accepted> \\| DEC-001 \\| MOM-YYYYMMDD item-1 \\|", "| TD-001 | runtime | Node.js | Deno, Bun | Industry standard | None | DEC-002 | MOM-20260710 item-1 |");
    text2 = rep(text2, "\\| <rear camera / offline read / file export> \\| <AC-002> \\| <how it is actually served> \\| <DEC-001> \\|", "| Local file read | AC-001 | Same-origin fetch over HTTPS | DEC-002 |");
    text2 = rep(text2, "\\| DC-001 \\| <Part> \\| <quantity_on_hand> \\| <integer> \\| <pieces> \\| <1 per part per location> \\| <>= 0> \\|", "| DC-001 | Record | count | integer | items | 1 per record | >= 0 |");
    text2 = rep(text2, "\\| <Part> \\| <quantity_on_hand> \\| <integer> \\| <pieces> \\| <1 per part per location> \\| <>= 0> \\|", "| DC-001 | Record | count | integer | items | 1 per record | >= 0 |");
    text2 = rep(text2, "\\| ER-001 \\| <Part> \\| <Location> \\| N:1 \\| location_id \\| yes \\| restrict \\|", "| ER-001 | Record | Record | 1:1 | count | no | restrict |");
    text2 = rep(text2, "\\| API-001 \\| <createPart> \\| <name, sku, unit> \\| <201 Created \\+ part_id> \\| <400 invalid_sku, 409 duplicate> \\| no \\| <role> \\|", "| API-001 | createRecord | name, count | 201 Created + id | 400 invalid_input | no | admin |");
    text2 = rep(text2, "\\| TR-001 \\| <draft> \\| <active> \\| <all required fields filled> \\| <deactivate> \\| no \\|", "| TR-001 | draft | active | all required fields filled | deactivate | no |");
    text2 = rep(text2, "\\| <element> \\| <yes / no> \\| <DEC-001 or .not applicable.> \\| <DEC-002 or .retained with the record.> \\|", "| Record identifier | no | not applicable | retained with the record |");
    text2 = rep(text2, "\\| AC-001 \\| <REQ-001> \\| <Given \\.\\.\\., when \\.\\.\\., then \\.\\.\\.> \\| <automated> \\| <seed name> \\| <how to reset> \\|", "| AC-001 | REQ-001 | Given a seeded record, when it is read, then the count is returned | automated | e2e-seed | Regenerate the fixture |");

    // Everything else in this template is prose guidance in angle brackets.
    // One deterministic sentence keeps the section non-empty and
    // placeholder-free. The trailing \r? is load-bearing for CRLF checkouts
    // (see the PS original's comment); retained here for parity.
    text2 = rep(text2, "^<[^>\\r\\n]+>[ \\t]*\\r?$", "Specified deterministically by the E2E fixture.", "gm");
    psWrite(specFile, text2);
  }

  // Both digests, computed after every other artifact is final -- exactly what
  // a real reviewer does with scripts/handoff-digest.ps1. Computing them
  // earlier would record a review of files this function is about to rewrite.
  const lensIds = [
    "value_and_scope_slice", "capability_lifecycle", "data_cardinality_and_units",
    "state_transitions_and_rollback", "concurrency_and_idempotency", "dependencies_and_build_order",
    "ownership_and_capacity", "acceptance_seed_reachability", "automated_manual_test_split",
    "privacy_and_data_classification", "environment_and_device_constraints",
    "demo_startup_reset_and_recovery",
  ];
  const review = {
    schema_version: "1.0",
    project_code: projectCode,
    reviewed_at: today,
    reviewer_kind: "ai",
    reviewer: "e2e fixture",
    handoff_target: "demo",
    source_snapshot: {
      source_ids: ["MOM-20260710", "REQ-20260710"],
      digest: getSourceSnapshotDigest(readFileSync(join(project, "PROJECT.md"), "utf8")),
    },
    review_inputs: { digest: getReviewInputDigest(project, cfg.handoffPolicy) },
    lenses: lensIds.map((lens) => ({ lens, status: "reviewed" })),
    findings: [],
    recommendation: {
      ready_to_start_development: true,
      ready_to_demo: true,
      notes: "E2E fixture: no findings raised.",
    },
  };
  psWrite(join(project, "HANDOFF-REVIEW.json"), JSON.stringify(review));
}

// ---- gate walking -----------------------------------------------------------

// The PS originals validate with -FailOnWarning: any WARN or FAIL fails the
// gate.
function assertGatesPass(project: string, mode: Mode, gates: Gate[], label: string): void {
  for (const gate of gates) {
    const diags = runPortedChain(REPO_ROOT, project, mode, gate).diagnostics;
    const problems = diags.filter((d) => d.level === "FAIL" || d.level === "WARN");
    assert.equal(
      problems.length, 0,
      `${label} failed validation at Gate=${gate}: ${problems.slice(0, 6).map((p) => `${p.rule_id}: ${p.message}`).join(" | ")}`,
    );
  }
}

function generate(projectCode: string, mode: "Lite" | "Standard" | "Strict", workRoot: string, includeHandoff: boolean): string {
  const gen = newProject(
    REPO_ROOT, projectCode, mode, "development_handoff", "off", "standard", "none", "not_applicable",
    "none", "normal feature", "PM", workRoot, includeHandoff, "demo", 21,
  );
  assert.equal(gen.exitCode, 0, `${mode} E2E: new-project failed with exit ${gen.exitCode}`);
  return join(workRoot, projectCode);
}

test("Lite E2E: generate -> fill -> Draft/Scope/Release", () => {
  const sandbox = mkdtempSync(join(tmpdir(), "pmo-e2e-"));
  try {
    // Thai directory name + a space, deliberately: the generator/validator must
    // work on real-world paths, not just ASCII no-space temp dirs.
    const thaiLite = String.fromCharCode(0x0e44, 0x0e25, 0x0e17, 0x0e4c);
    const workRoot = join(sandbox, `pmo e2e ${thaiLite} ${Math.random().toString(36).slice(2, 10)}`);
    mkdirSync(workRoot, { recursive: true });

    const project = generate("LITE-E2E", "Lite", workRoot, false);
    fillProjectContent(project, "Lite", "LITE-E2E", TODAY);

    assertGatesPass(project, "Lite", ["Draft", "Scope", "Release"], "Lite E2E");

    assert.ok(!existsSync(join(project, "RELEASE.md")), "Lite E2E generated RELEASE.md unexpectedly");
    assert.ok(!existsSync(join(project, "RTM.yaml")), "Lite E2E generated RTM.yaml unexpectedly");
  } finally {
    rmSync(sandbox, { recursive: true, force: true });
  }
});

test("Standard E2E: generate -> fill -> Draft/Scope/Design/Release", () => {
  const sandbox = mkdtempSync(join(tmpdir(), "pmo-e2e-"));
  try {
    // Path with spaces, deliberately: real project paths are rarely space-free.
    const workRoot = join(sandbox, `pmo e2e standard fixture ${Math.random().toString(36).slice(2, 10)}`);
    mkdirSync(workRoot, { recursive: true });

    const project = generate("STANDARD-E2E", "Standard", workRoot, false);
    // Real generated templates, filled in deterministically -- no copying an
    // example project over the generator's own output.
    fillProjectContent(project, "Standard", "STANDARD-E2E", TODAY);

    assertGatesPass(project, "Standard", ["Draft", "Scope", "Design", "Release"], "Standard E2E");
  } finally {
    rmSync(sandbox, { recursive: true, force: true });
  }
});

test("Strict E2E: generate -> fill -> Draft/Scope/Design/Release", () => {
  const sandbox = mkdtempSync(join(tmpdir(), "pmo-e2e-"));
  try {
    const workRoot = join(sandbox, `pmo e2e strict ${Math.random().toString(36).slice(2, 10)}`);
    mkdirSync(workRoot, { recursive: true });

    const project = generate("STRICT-E2E", "Strict", workRoot, false);
    // Real generated templates (including the generator's own RTM.json),
    // filled in deterministically -- no copying an example project's RTM.json
    // over the generator's output. This is the exact blind spot that hid the
    // RTM.yaml vs RTM.json schema mismatch in Round 1.
    fillProjectContent(project, "Strict", "STRICT-E2E", TODAY);

    assertGatesPass(project, "Strict", ["Draft", "Scope", "Design", "Release"], "Strict E2E");
  } finally {
    rmSync(sandbox, { recursive: true, force: true });
  }
});

test("Handoff E2E: generate with scaffolding -> fill -> all gates -> assess -> staleness", () => {
  const sandbox = mkdtempSync(join(tmpdir(), "pmo-e2e-"));
  try {
    const workRoot = join(sandbox, `pmo e2e handoff ${Math.random().toString(36).slice(2, 10)}`);
    mkdirSync(workRoot, { recursive: true });

    const project = generate("HANDOFF-E2E", "Standard", workRoot, true);

    for (const artifact of ["HANDOFF.md", "DESIGN/BUILD-SPEC.md", "HANDOFF-REVIEW.json"]) {
      assert.ok(existsSync(join(project, artifact)), `Handoff E2E: -IncludeHandoff did not create ${artifact}`);
    }

    // An unfilled scaffold must not pass. This is the guard against a generator
    // that quietly produces something that looks reviewed.
    const scaffoldDiags = runPortedChain(REPO_ROOT, project, "Standard", "Handoff").diagnostics;
    assert.ok(
      scaffoldDiags.some((d) => d.level === "FAIL"),
      "Handoff E2E: a freshly generated, unfilled scaffold passed the Handoff gate",
    );

    fillProjectContent(project, "Standard", "HANDOFF-E2E", TODAY);
    fillHandoffContent(project, "Standard", "HANDOFF-E2E", TODAY);

    // Draft -> Scope -> Design -> Handoff -> Release, in order.
    assertGatesPass(project, "Standard", ["Draft", "Scope", "Design", "Handoff", "Release"], "Handoff E2E");

    // The assessment must run on the same project and report stage verdicts.
    const assessment = runAssessHandoff(REPO_ROOT, project, "Standard", "Json");
    assert.equal(assessment.exitCode, 0, `Handoff E2E: assess-handoff failed`);
    const parsed = JSON.parse(assessment.output) as AssessmentResult;
    assert.ok(parsed.verdicts["Contract Valid"], "Handoff E2E: assessment did not report a valid contract");
    assert.ok(parsed.verdicts["Ready to Start Development"], "Handoff E2E: assessment did not report the project as ready to start development");

    // Editing a reviewed artifact must invalidate the review even though the
    // sources are untouched. This is the path a single-digest design misses.
    const specFile = join(project, "DESIGN/BUILD-SPEC.md");
    appendFileSync(specFile, "\nAdded after the review was recorded.");
    const inputStaleDiags = runPortedChain(REPO_ROOT, project, "Standard", "Handoff").diagnostics;
    const inputStaleHits = inputStaleDiags.filter((d) => d.rule_id === "HANDOFF-010" && d.field === "review_inputs.digest");
    assert.ok(inputStaleHits.length > 0, "Handoff E2E: editing a reviewed artifact did not mark the review stale");

    // Staleness is the property most likely to silently stop working: the
    // digest has to actually change when the sources do.
    const projectFile = join(project, "PROJECT.md");
    const before = getSourceSnapshotDigest(readFileSync(projectFile, "utf8"));
    const mutated = readFileSync(projectFile, "utf8").replace("MOM-20260710", "MOM-20260901");
    writeFileSync(projectFile, mutated, "utf8");
    const after = getSourceSnapshotDigest(readFileSync(projectFile, "utf8"));
    assert.notEqual(before, after, "Handoff E2E: the source snapshot digest did not change when the sources changed");

    const staleDiags = runPortedChain(REPO_ROOT, project, "Standard", "Handoff").diagnostics;
    const staleHits = staleDiags.filter((d) => d.rule_id === "HANDOFF-010" && /stale/.test(d.message));
    assert.ok(staleHits.length > 0, "Handoff E2E: a review recorded against changed sources was not reported as stale");
  } finally {
    rmSync(sandbox, { recursive: true, force: true });
  }
});
