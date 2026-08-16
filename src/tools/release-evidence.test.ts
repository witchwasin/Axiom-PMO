// Ported from tests/helpers/release-evidence-tests.ps1 (M4 second increment:
// the release-path Test Summary check reconciled against git ground truth,
// TEST-EVIDENCE-003).
//
// When -ReleaseDiffBase/-ReleaseDiffHead are supplied, a passed Test Summary
// row whose FILE: evidence is tracked but was NOT changed within base..head is
// stale -- it cannot be the output of a test run of this release's work.
// Severity mirrors APPROVAL-003 (WARN-blocking at Standard, FAIL at Strict),
// there is no human-vouch escape hatch on this path, and only tracked files
// are in scope (untracked/gitignored evidence is neither passed nor failed).
//
// The PS original exercises validate-project.ps1 as a subprocess over small,
// disposable git repositories built per case. The port calls runPortedChain
// in-process (which runs every other Release-gate rule, so the exit-code
// assertions mean the same thing), then wires the one rule the chain does not
// yet call -- testTestEvidenceGitGroundTruth -- against the same fixture's
// base/head commits.

import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { spawnSync } from "node:child_process";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { runPortedChain } from "../probe/validate-chain.js";
import { createAccumulator } from "../core/context.js";
import { importPmoConfig } from "../config/config-loader.js";
import { getReleaseRegistry, testTestEvidenceGitGroundTruth } from "../rules/rtm-validator.js";
import type { ReferenceTypesConfig } from "../core/reference-resolver.js";
import type { Diagnostic, Mode } from "../core/types.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

const cfg = importPmoConfig(REPO_ROOT);
const referenceTypesConfig = cfg.referenceTypesConfig as unknown as ReferenceTypesConfig;

function git(dir: string, ...args: string[]): { ok: boolean; stdout: string; status: number | null } {
  const r = spawnSync("git", ["-C", dir, ...args], { encoding: "utf8" });
  return { ok: r.status === 0, stdout: (r.stdout ?? "").trim(), status: r.status };
}

function newGitFixture(): string {
  const dir = mkdtempSync(join(tmpdir(), "axiom-release-evidence-"));
  const init = git(dir, "init", "-q", "--initial-branch=main");
  if (!init.ok) git(dir, "init", "-q"); // older git: no --initial-branch
  git(dir, "config", "user.email", "test@axiom-pmo.local");
  git(dir, "config", "user.name", "Axiom Release Evidence Tests");
  return dir;
}

function writeFixtureFile(dir: string, relativePath: string, content = "content"): void {
  const full = join(dir, relativePath);
  mkdirSync(dirname(full), { recursive: true });
  writeFileSync(full, content, "utf8");
}

function newFixtureCommit(dir: string, message: string): string {
  git(dir, "add", "-A");
  git(dir, "commit", "-q", "-m", message);
  return git(dir, "rev-parse", "HEAD").stdout;
}

// A valid Standard-mode Release project, mirroring tests/fixtures/valid-standard
// so the positive cases genuinely pass every other rule. RELEASE.md's TEST-001
// row always cites FILE:evidence at evidencePath (project-relative).
// Pass includeEvidenceFile to also create that file on disk. The project's
// declared default mode matters: -Mode Lite cannot downgrade a Standard-default
// project (MODE-001), so testing Lite behavior requires a genuinely
// Lite-default project.
function writeStandardReleaseProject(
  dir: string,
  includeEvidenceFile: boolean,
  evidencePath = "tests/evidence/report.xml",
  defaultMode: "Standard" | "Lite" = "Standard",
): void {
  const projectMd = `# PROJECT - RELEVID

> Status: release-approved
> Default mode: ${defaultMode}
> Task source: file
> Owner: Fixture PM
> Last updated: 2026-07-10

## Task Management

\`\`\`yaml
task_management:
  source_of_truth: delivery_file
  delivery_file: DELIVERY.md
  github_repository:
  rule: DELIVERY.md is master for this fixture
\`\`\`

## Source Snapshot

| Source ID | Version / Date | Last Synced At |
|---|---|---|
| REQ-20260710 | v1 | 2026-07-10T10:00:00+07:00 |

## Scope

### In Scope

| ID | Requirement | Type | Source Ref | Evidence Status | Approval Status |
|---|---|---|---|---|---|
| REQ-001 | User can submit a valid request. | functional | REQ-20260710 row 1 | supported | approved |

## Approvals

| Gate | Approval Status | Approver | Role | Date | Evidence |
|---|---|---|---|---|---|
| Scope Approved | approved | Fixture PO | Product Owner | 2026-07-10 | DEC-001 |
| Design Ready | approved | Fixture PO | Product Owner | 2026-07-10 | DEC-002 |
| Release Approved | approved | Fixture PO | Product Owner | 2026-07-10 | DEC-003 |
`;
  writeFixtureFile(dir, "PROJECT.md", projectMd);

  const deliveryMd = `# DELIVERY - RELEVID

## Delivery Mode

- Mode: ${defaultMode}
- Task source of truth: \`file\`
- Mode owner: Fixture PM
- Current status set: \`To Do\`, \`In Progress\`, \`Review / Test\`, \`Done\`

## Work Items

| ID | Mode | Strict Trigger | Mode Reason | Mode Approved By | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Priority | Status | Review Stage | Evidence Ref | Labels |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| D-001 | ${defaultMode} | none | normal feature | Fixture PM | Request submission | REQ-001 | DESIGN/FLOW.puml | Valid request is accepted | Happy | Fixture Dev | high | Done | qa | DEC-003 | review:qa |
`;
  writeFixtureFile(dir, "DELIVERY.md", deliveryMd);

  const releaseMd = `# RELEASE - RELEVID

## Scope

- D-001

## Test Summary

| ID | Test Area | Result | Evidence | Notes |
|---|---|---|---|---|
| TEST-001 | Happy path | passed | FILE:${evidencePath} | |

## QA / Security Review

| Review Type | Status | Reviewer | Role | Date | Evidence |
|---|---|---|---|---|---|
| QA | approved | Fixture QA Lead | QA Lead | 2026-07-10 | DEC-003 |

## Structured Rollback Plan

| Trigger | Owner | Steps | Verification | Evidence Ref |
|---|---|---|---|---|
| Fixture release blocker | Fixture Lead | Revert the fixture change | Fixture no longer shows change | DEC-003 |
`;
  writeFixtureFile(dir, "RELEASE.md", releaseMd);

  writeFixtureFile(dir, "decision-log.md", `# Decision Log

| ID | Decision | Date |
|---|---|---|
| DEC-001 | Scope approved | 2026-07-10 |
| DEC-002 | Design approved | 2026-07-10 |
| DEC-003 | Release approved | 2026-07-10 |
`);

  writeFixtureFile(dir, "RAID-log.md", `# RAID Log

| ID | Type | Description | Status |
|---|---|---|---|
| R-001 | risk | Normal delivery risk | closed |
`);

  writeFixtureFile(dir, "DESIGN/FLOW.puml", "@startuml\n@enduml");
  writeFixtureFile(dir, "source/REQ-20260710.md", "Requirement source for REQ-001.");

  if (includeEvidenceFile) {
    writeFixtureFile(dir, evidencePath, '<testsuite name="happy" tests="1" failures="0"><testcase name="happy"/></testsuite>');
  }
}

function runReleaseValidate(
  project: string,
  mode: Mode,
  base: string | null,
  head: string | null,
): { diagnostics: Diagnostic[]; exitCode: number } {
  const chain = runPortedChain(REPO_ROOT, project, mode, "Release").diagnostics;
  let diagnostics = chain;
  if (base && head) {
    const releasePath = join(project, "RELEASE.md");
    const releaseText = existsSync(releasePath) ? readFileSync(releasePath, "utf8") : "";
    const registry = getReleaseRegistry(releaseText);
    const acc = createAccumulator();
    testTestEvidenceGitGroundTruth(acc, cfg.validationRules, registry, project, referenceTypesConfig, mode, base, head);
    diagnostics = [...chain, ...acc.messages];
  }
  return {
    diagnostics,
    exitCode: diagnostics.some((d) => d.level === "FAIL") ? 1 : 0,
  };
}

function testEvidenceRows(diagnostics: Diagnostic[], level: "" | "PASS" | "WARN" | "FAIL"): Diagnostic[] {
  return diagnostics.filter((d) => d.rule_id === "TEST-EVIDENCE-003" && (level === "" || d.level === level));
}

test("release evidence: opt-in -- no refs supplied", () => {
  const dir = newGitFixture();
  try {
    writeStandardReleaseProject(dir, true);
    newFixtureCommit(dir, "base");

    const r = runReleaseValidate(dir, "Standard", null, null);
    assert.equal(testEvidenceRows(r.diagnostics, "").length, 0, "opt-in: no TEST-EVIDENCE-003 rows when refs are omitted");
    assert.equal(r.exitCode, 0, `opt-in: project still passes at Standard Release (exit ${r.exitCode})`);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("release evidence: fresh evidence inside the verified range", () => {
  const dir = newGitFixture();
  try {
    writeStandardReleaseProject(dir, false);
    const base = newFixtureCommit(dir, "base");
    // The release's work: the evidence file is produced and committed within
    // the range, alongside the code change it proves.
    writeFixtureFile(dir, "tests/evidence/report.xml", '<testsuite name="happy" tests="1" failures="0"><testcase name="happy"/></testsuite>');
    writeFixtureFile(dir, "src/feature.ts", "export const ok = true;");
    const head = newFixtureCommit(dir, "change");

    const r = runReleaseValidate(dir, "Standard", base, head);
    assert.equal(testEvidenceRows(r.diagnostics, "PASS").length, 1, "fresh-in-range: TEST-EVIDENCE-003 PASS row present");
    assert.equal(
      testEvidenceRows(r.diagnostics, "WARN").length + testEvidenceRows(r.diagnostics, "FAIL").length, 0,
      "fresh-in-range: no TEST-EVIDENCE-003 WARN/FAIL row",
    );
    assert.equal(r.exitCode, 0, `fresh-in-range: overall exit 0 (exit ${r.exitCode})`);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("release evidence: stale evidence is WARN-blocking at Standard", () => {
  const dir = newGitFixture();
  try {
    writeStandardReleaseProject(dir, true);
    const base = newFixtureCommit(dir, "base");
    // The release's work changes code, but the evidence report is an old file.
    writeFixtureFile(dir, "src/feature.ts", "export const ok = true;");
    const head = newFixtureCommit(dir, "change");

    const r = runReleaseValidate(dir, "Standard", base, head);
    const warns = testEvidenceRows(r.diagnostics, "WARN");
    assert.equal(warns.length, 1, "stale-standard: TEST-EVIDENCE-003 WARN row present");
    assert.equal(warns[0]!.blocking, true, "stale-standard: WARN is blocking (mirrors APPROVAL-003)");
    assert.match(warns[0]!.message, /tests\/evidence\/report\.xml/, "stale-standard: message names the evidence path");
    assert.match(
      warns[0]!.message, /not changed within the release's verified commit range/,
      "stale-standard: message names the git-ground-truth defect",
    );
    assert.equal(r.exitCode, 0, `stale-standard: WARN-block alone does not fail the run (exit ${r.exitCode})`);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("release evidence: the same stale evidence fails at Strict", () => {
  const dir = newGitFixture();
  try {
    writeStandardReleaseProject(dir, true);
    const base = newFixtureCommit(dir, "base");
    writeFixtureFile(dir, "src/feature.ts", "export const ok = true;");
    const head = newFixtureCommit(dir, "change");

    const r = runReleaseValidate(dir, "Strict", base, head);
    const fails = testEvidenceRows(r.diagnostics, "FAIL");
    assert.equal(fails.length, 1, "stale-strict: TEST-EVIDENCE-003 FAIL row present");
    assert.match(fails[0]!.message, /not changed within the release's verified commit range/, "stale-strict: message names the git-ground-truth defect");
    assert.equal(r.exitCode, 1, `stale-strict: overall exit 1 (exit ${r.exitCode})`);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("release evidence: tracked evidence modified in the working tree (uncommitted)", () => {
  const dir = newGitFixture();
  try {
    writeStandardReleaseProject(dir, true);
    const base = newFixtureCommit(dir, "base");
    writeFixtureFile(dir, "src/feature.ts", "export const ok = true;");
    const head = newFixtureCommit(dir, "change");
    // The report is touched after the fact, never committed.
    writeFixtureFile(dir, "tests/evidence/report.xml", '<testsuite name="forged" tests="99" failures="0"/>');

    const r = runReleaseValidate(dir, "Standard", base, head);
    const warns = testEvidenceRows(r.diagnostics, "WARN");
    assert.equal(warns.length, 1, "uncommitted: TEST-EVIDENCE-003 WARN row present");
    assert.match(warns[0]!.message, /uncommitted changes/, "uncommitted: message names the uncommitted state");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("release evidence: evidence staged but never committed (retro-added after head)", () => {
  const dir = newGitFixture();
  try {
    writeStandardReleaseProject(dir, false);
    const base = newFixtureCommit(dir, "base");
    writeFixtureFile(dir, "src/feature.ts", "export const ok = true;");
    const head = newFixtureCommit(dir, "change");
    // Added to the index after the head commit: tracked (visible to
    // ls-files) but not part of base..head.
    writeFixtureFile(dir, "tests/evidence/report.xml", '<testsuite name="happy" tests="1" failures="0"/>');
    git(dir, "add", "tests/evidence/report.xml");

    const r = runReleaseValidate(dir, "Standard", base, head);
    const warns = testEvidenceRows(r.diagnostics, "WARN");
    assert.equal(warns.length, 1, "retro-added: TEST-EVIDENCE-003 WARN row present");
    assert.match(warns[0]!.message, /uncommitted changes/, "retro-added: message names the uncommitted state");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("release evidence: untracked evidence is out of scope entirely", () => {
  const dir = newGitFixture();
  try {
    writeStandardReleaseProject(dir, false);
    const base = newFixtureCommit(dir, "base");
    writeFixtureFile(dir, "src/feature.ts", "export const ok = true;");
    const head = newFixtureCommit(dir, "change");
    // A brand-new file that git never saw: a legitimately gitignored CI report
    // directory behaves exactly this way. Must be neither passed nor failed by
    // the git check -- same as before this check existed.
    writeFixtureFile(dir, "tests/evidence/report.xml", '<testsuite name="happy" tests="1" failures="0"/>');

    const r = runReleaseValidate(dir, "Standard", base, head);
    assert.equal(
      testEvidenceRows(r.diagnostics, "WARN").length + testEvidenceRows(r.diagnostics, "FAIL").length, 0,
      "untracked: no TEST-EVIDENCE-003 WARN/FAIL row (out of scope)",
    );
    assert.equal(r.exitCode, 0, `untracked: overall exit 0 (evidence still resolves on disk) (exit ${r.exitCode})`);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("release evidence: project inside a subdirectory of the repo (Action shape)", () => {
  const dir = newGitFixture();
  try {
    // The GitHub Action runs the framework from the consumer checkout, where
    // the project is a subdirectory of the repository. Evidence paths are
    // project-relative; git diff names repo-root-relative paths; the bridge
    // must hold.
    writeStandardReleaseProject(join(dir, "project"), true);
    const base = newFixtureCommit(dir, "base");
    writeFixtureFile(dir, "project/src/feature.ts", "export const ok = true;");
    const head = newFixtureCommit(dir, "change");

    const r = runReleaseValidate(join(dir, "project"), "Standard", base, head);
    const warns = testEvidenceRows(r.diagnostics, "WARN");
    assert.equal(warns.length, 1, "subdir: stale evidence caught across the repo-root boundary");
    assert.match(warns[0]!.message, /project\/tests\/evidence\/report\.xml/, "subdir: message names the repo-root-relative evidence path");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("release evidence: Lite is exempt, same as APPROVAL-003", () => {
  const dir = newGitFixture();
  try {
    // A genuinely Lite-default project: -Mode Lite cannot downgrade a
    // Standard-default one (MODE-001), so the exemption is only reachable
    // when the project itself is Lite.
    writeStandardReleaseProject(dir, true, "tests/evidence/report.xml", "Lite");
    const base = newFixtureCommit(dir, "base");
    writeFixtureFile(dir, "src/feature.ts", "export const ok = true;");
    const head = newFixtureCommit(dir, "change");

    const r = runReleaseValidate(dir, "Lite", base, head);
    assert.equal(testEvidenceRows(r.diagnostics, "").length, 0, "lite: no TEST-EVIDENCE-003 row of any level");
    assert.equal(r.exitCode, 0, `lite: project still passes at Lite Release (exit ${r.exitCode})`);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("release evidence: unresolvable base commit always fails (mirrors SCOPE-DIFF-004)", () => {
  const dir = newGitFixture();
  try {
    writeStandardReleaseProject(dir, true);
    const base = newFixtureCommit(dir, "base");

    const r = runReleaseValidate(dir, "Standard", "0000000000000000000000000000000000000000", base);
    const fails = testEvidenceRows(r.diagnostics, "FAIL");
    assert.equal(fails.length, 1, "bad base: TEST-EVIDENCE-003 FAIL row present");
    assert.match(fails[0]!.message, /fetch-depth/, "bad base: message mentions fetch-depth guidance");
    assert.equal(r.exitCode, 1, `bad base: overall exit 1 (exit ${r.exitCode})`);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
