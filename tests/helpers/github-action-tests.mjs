#!/usr/bin/env node
// Tests for the GitHub Action wrapper (scripts/github-action/*.mjs).
//
// Two layers, matching the M4 implementation plan's required test list:
//   1. Unit tests on the pure rendering/annotation functions -- no
//      PowerShell needed, run everywhere.
//   2. Integration tests that spawn run-action.mjs against real fixtures --
//      need a PowerShell host, skipped (loudly) when one is not on PATH.
//
//   node tests/helpers/github-action-tests.mjs

import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync, chmodSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { buildAnnotations, __testing as annotationTesting } from "../../scripts/github-action/emit-annotations.mjs";
import { buildReportJson, buildReportMarkdown, outcomeForExitCode } from "../../scripts/github-action/render-report.mjs";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const RUN_ACTION = join(REPO_ROOT, "scripts/github-action/run-action.mjs");

let pass = 0;
let fail = 0;

function assert(name, condition, detail = "") {
  if (condition) {
    pass++;
    console.log(`[PASS] ${name}`);
  } else {
    fail++;
    console.log(`[FAIL] ${name}${detail ? ` -- ${detail}` : ""}`);
  }
}

function hasPowerShell() {
  if (process.env.AXIOM_PWSH) return true;
  for (const candidate of ["pwsh", "powershell", "powershell.exe"]) {
    const probe = spawnSync(candidate, ["-NoProfile", "-Command", "$true"], { stdio: "ignore" });
    if (!probe.error && probe.status === 0) return true;
  }
  return false;
}

const POWERSHELL_AVAILABLE = hasPowerShell();

console.log(`Axiom-PMO GitHub Action Tests: ${REPO_ROOT}`);
console.log(`PowerShell available: ${POWERSHELL_AVAILABLE}`);
console.log("");

// --- Unit tests: emit-annotations.mjs ---------------------------------------

{
  const results = [
    { level: "FAIL", rule_id: "R-1", message: "line one\nline two", artifact: null, item_id: null, field: null, suggestion: null, documentation_url: null },
  ];
  const lines = buildAnnotations(results, { workspace: REPO_ROOT });
  assert("newline in message is escaped to %0A", lines[0].includes("line one%0Aline two"));
  assert("no raw newline reaches the annotation string", !lines[0].includes("\n"));
}

{
  // A message containing `:` and `,` must not corrupt the property list --
  // both characters are structurally significant in `key=value,key=value`.
  const results = [
    { level: "WARN", rule_id: "R-2", message: "m", artifact: null, item_id: "a: b, c", field: null, suggestion: null, documentation_url: null },
  ];
  const lines = buildAnnotations(results, { workspace: REPO_ROOT });
  assert("title property escapes ':' as %3A", lines[0].includes("%3A"));
  assert("title property escapes ',' as %2C", lines[0].includes("%2C"));
}

{
  // null artifact -> no `file=` property, but the annotation still emits.
  const results = [
    { level: "FAIL", rule_id: "R-3", message: "no location", artifact: null, item_id: null, field: null, suggestion: null, documentation_url: null },
  ];
  const lines = buildAnnotations(results, { workspace: REPO_ROOT });
  assert("null artifact produces a locationless annotation", lines.length === 1 && !lines[0].includes("file="));
}

{
  // An artifact path that escapes the workspace (../, or an absolute path
  // from a different machine) must degrade to locationless, not point at an
  // unrelated file or leak the resolved absolute path into `file=`.
  const results = [
    // Deep enough to clear both the project directory *and* the repo root
    // itself, however many parent directories the checkout happens to have.
    { level: "FAIL", rule_id: "R-4", message: "escapes workspace", artifact: "../../../../../../../../etc/passwd", item_id: null, field: null, suggestion: null, documentation_url: null },
  ];
  const lines = buildAnnotations(results, { workspace: REPO_ROOT, projectPath: join(REPO_ROOT, "examples/STANDARD-FEATURE") });
  assert("path escaping the workspace has no file= property", !lines[0].includes("file="));
}

{
  const results = [
    { level: "FAIL", rule_id: "R-5", message: "in workspace", artifact: "HANDOFF.md", item_id: null, field: null, suggestion: null, documentation_url: null },
  ];
  const workspace = REPO_ROOT;
  const projectPath = join(REPO_ROOT, "demo/broken-project");
  const lines = buildAnnotations(results, { workspace, projectPath });
  assert("in-workspace artifact resolves to a workspace-relative file=", lines[0].includes("file=demo/broken-project/HANDOFF.md"));
  assert("workspace-relative path is never absolute", !lines[0].includes(REPO_ROOT));
}

{
  // SCOPE-DIFF-* rows are the one documented exception: `artifact` is
  // repo-root-relative (a real git-diff path), not project-relative like
  // every other rule -- see emit-annotations.mjs's safeWorkspacePath
  // comment. Resolving it against projectPath the way every other rule's
  // artifact is resolved either doubles the project prefix (this case: the
  // changed file happens to sit inside the project folder) or points at a
  // nonexistent file (the next case: it does not) -- a real bug caught by
  // inspecting an actual annotation GitHub rendered from this repository's
  // own dogfood CI run, not by local testing alone.
  const workspace = REPO_ROOT;
  const projectPath = join(REPO_ROOT, "demo/scope-diff-dogfood-fail");
  const results = [
    { level: "FAIL", rule_id: "SCOPE-DIFF-001", message: "out of scope", artifact: "demo/scope-diff-dogfood-fail/README.md", item_id: null, field: null, suggestion: null, documentation_url: null },
  ];
  const lines = buildAnnotations(results, { workspace, projectPath });
  assert(
    "SCOPE-DIFF artifact resolves against the workspace, not doubled under the project path",
    lines[0].includes("file=demo/scope-diff-dogfood-fail/README.md") && !lines[0].includes("scope-diff-dogfood-fail/demo/scope-diff-dogfood-fail"),
    lines[0],
  );
}

{
  // The documented common case: the changed file lives entirely outside the
  // project's own folder (project governs projects/P02-X/, the code it
  // approves lives in src/**). A project-relative resolution would produce
  // a path nested under the project directory that does not correspond to
  // any real file at all.
  const workspace = REPO_ROOT;
  const projectPath = join(REPO_ROOT, "examples/STANDARD-FEATURE");
  const results = [
    { level: "FAIL", rule_id: "SCOPE-DIFF-001", message: "out of scope", artifact: "src/payments/checkout.ts", item_id: null, field: null, suggestion: null, documentation_url: null },
  ];
  const lines = buildAnnotations(results, { workspace, projectPath });
  assert(
    "SCOPE-DIFF artifact outside the project folder still resolves to its real workspace-relative path",
    lines[0].includes("file=src/payments/checkout.ts"),
    lines[0],
  );
}

{
  // Non-SCOPE-DIFF rule ids must be completely unaffected -- the exception
  // is keyed on rule_id prefix, never a default.
  assert("isRepoRootRelativeRule is scoped to SCOPE-DIFF-*", annotationTesting.isRepoRootRelativeRule("SCOPE-DIFF-004") === true);
  assert("isRepoRootRelativeRule does not match unrelated rule ids", annotationTesting.isRepoRootRelativeRule("HANDOFF-004") === false);
}

{
  const results = Array.from({ length: 15 }, (_, i) => ({
    level: "FAIL", rule_id: `R-${i}`, message: "m", artifact: null, item_id: null, field: null, suggestion: null, documentation_url: null,
  }));
  const lines = buildAnnotations(results, { workspace: REPO_ROOT });
  const errorLines = lines.filter((l) => l.startsWith("::error"));
  const noticeLines = lines.filter((l) => l.startsWith("::notice"));
  assert("annotation cap stops at 10 per level", errorLines.length === 10, `got ${errorLines.length}`);
  assert("suppressed count is reported as a notice", noticeLines.length === 1 && noticeLines[0].includes("5 further error"));
}

{
  const results = [{ level: "PASS", rule_id: "R-6", message: "m", artifact: null, item_id: null, field: null, suggestion: null, documentation_url: null }];
  assert("PASS rows never become annotations", buildAnnotations(results, { workspace: REPO_ROOT }).length === 0);
}

{
  const results = [{ level: "FAIL", rule_id: "R-7", message: "m", artifact: null, item_id: null, field: null, suggestion: null, documentation_url: null }];
  assert("annotation-mode off suppresses everything", buildAnnotations(results, { workspace: REPO_ROOT, mode: "off" }).length === 0);
}

{
  const long = "x".repeat(1000);
  const clamped = annotationTesting.clamp(long);
  assert("long field is clamped", clamped.length === annotationTesting.MAX_FIELD_CHARS, `got ${clamped.length}`);
}

// --- Unit tests: render-report.mjs -------------------------------------------

{
  assert("exit 0 -> success", outcomeForExitCode(0) === "success");
  assert("exit 1 -> failure", outcomeForExitCode(1) === "failure");
  assert("exit 2 -> warning", outcomeForExitCode(2) === "warning");
  assert("exit 127 -> runtime-missing", outcomeForExitCode(127) === "runtime-missing");
  assert("unmapped exit code falls back to failure", outcomeForExitCode(64) === "failure");
}

{
  const validatorResult = {
    schema_version: "1.1", project: "examples/STANDARD-FEATURE", requested_mode: "Standard",
    effective_mode: "Standard", gate: "Release", summary: { pass: 1, warn: 0, warn_blocking: 0, fail: 0, exit_code: 0 }, results: [],
  };
  const meta = { outcome: "success", exitCode: 0, enforce: false, failOnWarning: true, annotationMode: "safe", generatedAt: "2026-07-29T00:00:00.000Z" };
  const reportJson = buildReportJson(validatorResult, meta);
  assert("report JSON preserves every original validator field", Object.keys(validatorResult).every((k) => JSON.stringify(reportJson[k]) === JSON.stringify(validatorResult[k])));
  assert("report JSON adds a namespaced action block without renaming anything", reportJson.action.outcome === "success" && reportJson.action.exit_code === 0);
  const md = buildReportMarkdown(validatorResult, meta);
  assert("markdown report names the outcome", md.includes("SUCCESS"));
  assert("markdown report says no findings when clean", md.includes("No FAIL or WARN diagnostics."));
}

// --- Integration tests: run-action.mjs against real fixtures -----------------

function runAction(args, env = {}) {
  const outDir = mkdtempSync(join(tmpdir(), "axiom-action-test-"));
  const jsonPath = join(outDir, "axiom-report.json");
  const mdPath = join(outDir, "axiom-report.md");
  const result = spawnSync(process.execPath, [
    RUN_ACTION, ...args, "--json-report-path", jsonPath, "--md-report-path", mdPath,
  ], {
    cwd: REPO_ROOT,
    encoding: "utf8",
    env: { ...process.env, ...env },
  });
  return { status: result.status, stdout: result.stdout ?? "", stderr: result.stderr ?? "", jsonPath, mdPath, outDir };
}

function cleanup(outDir) {
  try { rmSync(outDir, { recursive: true, force: true }); } catch { /* best effort */ }
}

// A small disposable git repository for SCOPE-DIFF Action-layer tests --
// the PowerShell-level matching/precedence/rename cases already have their
// own thorough fixture-based suite in scope-diff-tests.ps1; this exists
// only to exercise the Action wrapper's own responsibilities (ref
// resolution, report-only vs enforce, output plumbing) against something
// real rather than mocked.
function git(dir, args) {
  const result = spawnSync("git", ["-C", dir, ...args], { encoding: "utf8" });
  return result.stdout.trim();
}

function createScopeDiffFixture() {
  const dir = mkdtempSync(join(tmpdir(), "axiom-scope-diff-action-"));
  spawnSync("git", ["-C", dir, "init", "-q", "--initial-branch=main"]);
  spawnSync("git", ["-C", dir, "config", "user.email", "test@axiom-pmo.local"]);
  spawnSync("git", ["-C", dir, "config", "user.name", "Axiom Scope Diff Action Tests"]);

  mkdirSync(join(dir, "src", "payments"), { recursive: true });
  writeFileSync(join(dir, "src", "payments", "foo.ts"), "a");
  writeFileSync(
    join(dir, "SCOPE.json"),
    JSON.stringify({
      schema_version: "1.0",
      project: "T",
      implementation_scope: { include: ["src/payments/**"], exclude: [] },
    }),
  );
  spawnSync("git", ["-C", dir, "add", "-A"]);
  spawnSync("git", ["-C", dir, "commit", "-q", "-m", "base"]);
  const base = git(dir, ["rev-parse", "HEAD"]);

  // A violation by default -- most of the tests below want one; the
  // clean-scope test overwrites this before committing instead.
  writeFileSync(join(dir, "src", "auth-out-of-scope.ts"), "new");
  spawnSync("git", ["-C", dir, "add", "-A"]);
  spawnSync("git", ["-C", dir, "commit", "-q", "-m", "violation"]);
  const head = git(dir, ["rev-parse", "HEAD"]);

  return { dir, base, head };
}

function cleanupFixture(fixture) {
  try { rmSync(fixture.dir, { recursive: true, force: true }); } catch { /* best effort */ }
}

if (POWERSHELL_AVAILABLE) {
  {
    const r = runAction(["--project", "examples/STANDARD-FEATURE", "--mode", "Standard", "--gate", "Release"]);
    assert("passing Release gate: wrapper exits 0", r.status === 0, `status=${r.status}`);
    assert("passing gate: json report exists", existsSync(r.jsonPath));
    assert("passing gate: md report exists", existsSync(r.mdPath));
    const json = JSON.parse(readFileSync(r.jsonPath, "utf8"));
    assert("passing gate: outcome is success", json.action.outcome === "success");
    assert("passing gate: project field is the relative input, not an absolute runner path", json.project === "examples/STANDARD-FEATURE" && !json.project.includes(REPO_ROOT));
    cleanup(r.outDir);
  }

  {
    const r = runAction(["--project", "demo/broken-project", "--mode", "Standard", "--gate", "Handoff"]);
    assert("failing Handoff gate, report-only (default): wrapper still exits 0", r.status === 0, `status=${r.status}`);
    const json = JSON.parse(readFileSync(r.jsonPath, "utf8"));
    assert("failing gate, report-only: real outcome is still failure in the report", json.action.outcome === "failure" && json.action.exit_code === 1);
    assert("failing gate: report files exist even though validation failed", existsSync(r.jsonPath) && existsSync(r.mdPath));
    assert("failing gate: FAIL annotations reach stdout", r.stdout.includes("::error"));
    cleanup(r.outDir);
  }

  {
    const r = runAction(["--project", "demo/broken-project", "--mode", "Standard", "--gate", "Handoff", "--enforce", "true"]);
    assert("failing Handoff gate, enforce=true: wrapper exits 1", r.status === 1, `status=${r.status}`);
    cleanup(r.outDir);
  }

  {
    const project = "tests/fixtures/invalid-github-action-warn-only-blocking";
    const rSoft = runAction(["--project", project, "--mode", "Standard", "--gate", "Handoff", "--fail-on-warning", "true"]);
    assert("blocking warning, report-only: wrapper exits 0", rSoft.status === 0, `status=${rSoft.status}`);
    const jsonSoft = JSON.parse(readFileSync(rSoft.jsonPath, "utf8"));
    assert("blocking warning, report-only: real outcome recorded as warning, not silently success", jsonSoft.action.outcome === "warning" && jsonSoft.action.exit_code === 2);
    cleanup(rSoft.outDir);

    const rEnforced = runAction(["--project", project, "--mode", "Standard", "--gate", "Handoff", "--fail-on-warning", "true", "--enforce", "true"]);
    assert("blocking warning, enforce=true: wrapper exits 2", rEnforced.status === 2, `status=${rEnforced.status}`);
    cleanup(rEnforced.outDir);

    const rNoFailOnWarning = runAction(["--project", project, "--mode", "Standard", "--gate", "Handoff", "--fail-on-warning", "false", "--enforce", "true"]);
    assert("blocking warning demoted by fail-on-warning=false: wrapper exits 0", rNoFailOnWarning.status === 0, `status=${rNoFailOnWarning.status}`);
    cleanup(rNoFailOnWarning.outDir);
  }

  {
    // A missing PowerShell host is an infrastructure failure, not a
    // governance verdict -- report-only must not swallow it.
    const r = runAction(["--project", "examples/STANDARD-FEATURE"], { AXIOM_PWSH: "/nonexistent/pwsh" });
    assert("missing PowerShell: wrapper exits 127 even in report-only mode", r.status === 127, `status=${r.status}`);
    const json = JSON.parse(readFileSync(r.jsonPath, "utf8"));
    assert("missing PowerShell: report still gets written with a FAIL row", json.results.some((row) => row.rule_id === "ACTION-PARSE-ERROR"));
    cleanup(r.outDir);
  }

  {
    // Simulate a PowerShell host that runs but emits garbage instead of JSON
    // (e.g. a corrupted profile writing to stdout). The wrapper must still
    // produce a useful, non-crashing failure report rather than throwing --
    // and, per Independent AI Reviewer's privacy review, must never copy that garbage into any
    // persisted output. A malformed-stdout scenario is exactly the case where
    // the garbage could be a leaked token, connection string, or local path
    // from a corrupted profile/wrapper/dependency -- so the "garbage" here is
    // a fake secret marker, not an arbitrary string, and this test asserts
    // the marker reaches nowhere it could be uploaded as an artifact.
    //
    // AXIOM_PWSH is spawned directly by axiom.mjs -- not through a shell --
    // so the shim has to be something the OS can execute on its own: a
    // shebang script on POSIX, a .cmd file on Windows (Node's child_process
    // auto-wraps .cmd/.bat through cmd.exe on win32; a bare extensionless
    // "shebang" file is not executable there at all).
    const SECRET_MARKER = "ghp_FAKE_SECRET_FOR_TEST";
    const GARBAGE = `not json at all: token=${SECRET_MARKER}`;
    const shimDir = mkdtempSync(join(tmpdir(), "axiom-fake-pwsh-"));
    let wrapperPath;
    if (process.platform === "win32") {
      wrapperPath = join(shimDir, "fake-pwsh.cmd");
      writeFileSync(wrapperPath, `@echo off\r\necho ${GARBAGE}\r\n`);
    } else {
      wrapperPath = join(shimDir, "fake-pwsh");
      writeFileSync(wrapperPath, `#!/bin/sh\nprintf '%s' '${GARBAGE}'\n`);
      chmodSync(wrapperPath, 0o755);
    }

    // Exercise the real Job Summary path too (normally a no-op in this test
    // harness, since GITHUB_STEP_SUMMARY is unset outside real Actions runs).
    const jobSummaryPath = join(shimDir, "job-summary.md");
    writeFileSync(jobSummaryPath, "");

    const r = runAction(["--project", "examples/STANDARD-FEATURE"], {
      AXIOM_PWSH: wrapperPath,
      GITHUB_STEP_SUMMARY: jobSummaryPath,
    });
    assert("malformed JSON from validator: wrapper does not crash", r.status !== null);
    assert("malformed JSON: report files still exist", existsSync(r.jsonPath) && existsSync(r.mdPath));
    const jsonText = readFileSync(r.jsonPath, "utf8");
    const mdText = readFileSync(r.mdPath, "utf8");
    const jobSummaryText = readFileSync(jobSummaryPath, "utf8");
    const json = JSON.parse(jsonText);
    assert("malformed JSON: synthetic FAIL row is present", json.results.some((row) => row.rule_id === "ACTION-PARSE-ERROR"));

    // Independent AI Reviewer's blocking privacy finding: no raw stdout content in any persisted
    // surface, ever -- confirmed via the field never existing, and via a
    // direct secret-marker scan of every artifact this Action writes.
    assert("malformed JSON: no raw_stdout_preview field exists at all", json.action.raw_stdout_preview === undefined);
    assert("malformed JSON: action.parse_error is true", json.action.parse_error === true);
    assert("malformed JSON: action.stdout_present is a boolean", typeof json.action.stdout_present === "boolean");
    assert("malformed JSON: action.stdout_length is a number", typeof json.action.stdout_length === "number");
    assert("secret marker does not appear in the JSON report", !jsonText.includes(SECRET_MARKER));
    assert("secret marker does not appear in the Markdown report", !mdText.includes(SECRET_MARKER));
    assert("secret marker does not appear in stdout (annotations)", !r.stdout.includes(SECRET_MARKER));
    assert("secret marker does not appear in the Job Summary", !jobSummaryText.includes(SECRET_MARKER));

    cleanup(r.outDir);
    rmSync(shimDir, { recursive: true, force: true });
  }

  {
    const r = runAction(["--project", "examples/STANDARD-FEATURE", "--annotation-mode", "off"]);
    assert("annotation-mode off: no workflow-command lines on stdout", !r.stdout.includes("::error") && !r.stdout.includes("::warning"));
    cleanup(r.outDir);
  }

  {
    // Privacy/redaction: nothing in the annotations or reports should leak
    // this machine's absolute filesystem path.
    const r = runAction(["--project", "demo/broken-project", "--mode", "Standard", "--gate", "Handoff"]);
    assert("no absolute local path in stdout annotations", !r.stdout.includes(REPO_ROOT));
    const md = readFileSync(r.mdPath, "utf8");
    assert("no absolute local path in the markdown report", !md.includes(REPO_ROOT));
    cleanup(r.outDir);
  }

  // --- SCOPE-DIFF: Action-layer behavior (ref resolution, report-only vs
  // enforce, output plumbing). The matching/precedence/rename logic itself
  // is covered exhaustively in tests/helpers/scope-diff-tests.ps1; these
  // tests exist only for what the Action wrapper is responsible for.
  {
    const fixture = createScopeDiffFixture();
    const r = runAction([
      "--project", fixture.dir, "--mode", "Standard", "--gate", "Draft",
      "--working-directory", fixture.dir,
      "--enable-scope-diff", "true", "--scope-diff-base", fixture.base, "--scope-diff-head", fixture.head,
    ]);
    assert("scope-diff violation, report-only: wrapper exits 0", r.status === 0, `status=${r.status}`);
    const json = JSON.parse(readFileSync(r.jsonPath, "utf8"));
    assert("scope-diff violation, report-only: real verdict still recorded as fail", json.scope_diff?.verdict === "fail");
    assert("scope-diff violation, report-only: offending path listed", json.scope_diff?.changed_out_of_scope?.includes("src/auth-out-of-scope.ts"));
    const md = readFileSync(r.mdPath, "utf8");
    assert("scope-diff violation: Markdown report has a Scope-diff section", md.includes("## Scope-diff"));
    cleanup(r.outDir);
    cleanupFixture(fixture);
  }

  {
    const fixture = createScopeDiffFixture();
    const r = runAction([
      "--project", fixture.dir, "--mode", "Standard", "--gate", "Draft",
      "--working-directory", fixture.dir,
      "--enable-scope-diff", "true", "--scope-diff-base", fixture.base, "--scope-diff-head", fixture.head,
      "--enforce", "true",
    ]);
    assert("scope-diff violation, enforce=true: wrapper exits 1", r.status === 1, `status=${r.status}`);
    cleanup(r.outDir);
    cleanupFixture(fixture);
  }

  {
    // Same repo, but diff base==head (no violation possible) -- enforce must
    // not false-positive.
    const fixture = createScopeDiffFixture();
    const r = runAction([
      "--project", fixture.dir, "--mode", "Standard", "--gate", "Draft",
      "--working-directory", fixture.dir,
      "--enable-scope-diff", "true", "--scope-diff-base", fixture.base, "--scope-diff-head", fixture.base,
      "--enforce", "true",
    ]);
    const json = JSON.parse(readFileSync(r.jsonPath, "utf8"));
    assert("scope-diff clean (empty diff), enforce=true: verdict pass", json.scope_diff?.verdict === "pass");
    cleanup(r.outDir);
    cleanupFixture(fixture);
  }

  {
    // No explicit refs and no GITHUB_EVENT_PATH -- enable-scope-diff must
    // still fail loudly (SCOPE-DIFF-004), and report-only must not be able
    // to hide it, the same way a missing PowerShell host can't be hidden.
    const fixture = createScopeDiffFixture();
    const r = runAction(
      ["--project", fixture.dir, "--mode", "Standard", "--gate", "Draft", "--working-directory", fixture.dir, "--enable-scope-diff", "true"],
      { GITHUB_EVENT_PATH: "" },
    );
    assert("scope-diff enabled with no resolvable refs: wrapper exits non-zero even in report-only mode", r.status !== 0, `status=${r.status}`);
    const json = JSON.parse(readFileSync(r.jsonPath, "utf8"));
    assert("unresolved refs: SCOPE-DIFF-004 row present", json.results.some((row) => row.rule_id === "SCOPE-DIFF-004"));
    cleanup(r.outDir);
    cleanupFixture(fixture);
  }

  {
    // pull_request event context is used when no explicit override is given.
    const fixture = createScopeDiffFixture();
    const eventPath = join(fixture.dir, "event.json");
    writeFileSync(eventPath, JSON.stringify({ pull_request: { base: { sha: fixture.base }, head: { sha: fixture.head } } }));
    const r = runAction(
      ["--project", fixture.dir, "--mode", "Standard", "--gate", "Draft", "--working-directory", fixture.dir, "--enable-scope-diff", "true"],
      { GITHUB_EVENT_PATH: eventPath },
    );
    const json = JSON.parse(readFileSync(r.jsonPath, "utf8"));
    assert("PR-event ref auto-detection: base/head match the event payload", json.scope_diff?.base_sha === fixture.base && json.scope_diff?.head_sha === fixture.head);
    assert("PR-event ref auto-detection: real verdict computed (not unresolved)", json.scope_diff?.verdict === "fail");
    cleanup(r.outDir);
    cleanupFixture(fixture);
  }

  {
    // An explicit override wins over the PR event context, even when they
    // disagree.
    const fixture = createScopeDiffFixture();
    const eventPath = join(fixture.dir, "event.json");
    writeFileSync(eventPath, JSON.stringify({ pull_request: { base: { sha: "0000000000000000000000000000000000000000" }, head: { sha: "1111111111111111111111111111111111111111" } } }));
    const r = runAction(
      [
        "--project", fixture.dir, "--mode", "Standard", "--gate", "Draft", "--working-directory", fixture.dir,
        "--enable-scope-diff", "true", "--scope-diff-base", fixture.base, "--scope-diff-head", fixture.base,
      ],
      { GITHUB_EVENT_PATH: eventPath },
    );
    const json = JSON.parse(readFileSync(r.jsonPath, "utf8"));
    assert("explicit override wins over PR event", json.scope_diff?.base_sha === fixture.base && json.scope_diff?.head_sha === fixture.base);
    assert("explicit override: valid refs resolve (event's fake SHAs were not used)", json.scope_diff?.verdict === "pass");
    cleanup(r.outDir);
    cleanupFixture(fixture);
  }

  {
    // GITHUB_OUTPUT plumbing for the new scope-diff-verdict output.
    const fixture = createScopeDiffFixture();
    const outputFile = join(fixture.dir, "github_output");
    writeFileSync(outputFile, "");
    runAction(
      [
        "--project", fixture.dir, "--mode", "Standard", "--gate", "Draft", "--working-directory", fixture.dir,
        "--enable-scope-diff", "true", "--scope-diff-base", fixture.base, "--scope-diff-head", fixture.head,
      ],
      { GITHUB_OUTPUT: outputFile },
    );
    const outputText = readFileSync(outputFile, "utf8");
    assert("GITHUB_OUTPUT includes scope-diff-verdict=fail", outputText.includes("scope-diff-verdict=fail"));
    cleanupFixture(fixture);
  }

  {
    // Opt-in at the Action layer too: not passing enable-scope-diff leaves
    // the report exactly as plain M4 always produced it.
    const fixture = createScopeDiffFixture();
    const r = runAction(["--project", fixture.dir, "--mode", "Standard", "--gate", "Draft", "--working-directory", fixture.dir]);
    const json = JSON.parse(readFileSync(r.jsonPath, "utf8"));
    assert("scope-diff not enabled: no scope_diff key in the report", !("scope_diff" in json));
    assert("scope-diff not enabled: no SCOPE-DIFF rows", !json.results.some((row) => row.rule_id.startsWith("SCOPE-DIFF")));
    cleanup(r.outDir);
    cleanupFixture(fixture);
  }
} else {
  console.log("");
  console.log("SKIPPED: run-action.mjs integration tests -- no PowerShell host on PATH.");
  console.log("         Unit tests above still ran; they do not need PowerShell.");
}

console.log("");
console.log(`Axiom-PMO GitHub Action Tests: ${pass} passed, ${fail} failed`);
if (fail > 0) process.exitCode = 1;
