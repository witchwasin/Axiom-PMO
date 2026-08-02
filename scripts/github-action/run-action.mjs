#!/usr/bin/env node
// GitHub Action wrapper. Owns CI presentation only -- it invokes the existing
// CLI (which invokes the existing PowerShell validator) and never evaluates a
// rule itself. See docs/reference/diagnostics-contract.md for the JSON shape
// this reads, and docs/guides/github-action.md for the interface this
// implements.
//
//   node run-action.mjs --project <path> [--mode Standard] [--gate Release]
//     [--fail-on-warning true|false] [--working-directory .]
//     [--annotation-mode safe|off] [--enforce true|false]
//     [--json-report-path axiom-report.json] [--md-report-path axiom-report.md]

import { spawnSync } from "node:child_process";
import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { buildReportJson, buildReportMarkdown, buildJobSummary, outcomeForExitCode } from "./render-report.mjs";
import { emitAnnotations } from "./emit-annotations.mjs";

// This file lives at <action_root>/scripts/github-action/run-action.mjs.
// ACTION_ROOT is where the Axiom-PMO framework itself lives -- the same
// checkout whether this runs in Axiom-PMO's own CI or as a consumer's
// `uses: witchwasin/Axiom-PMO@<ref>` step (the Actions runtime checks the
// whole referenced repo out to `github.action_path` and sets that as this
// process's argv[1] location).
const ACTION_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const CLI = join(ACTION_ROOT, "cli/axiom.mjs");

// Exit codes the underlying validator/CLI can produce that represent an
// actual governance verdict -- something report-only mode is allowed to
// soften. Anything else (127 = no PowerShell host, 64 = bad Action input, or
// any other code) is an infrastructure/configuration failure, not a finding,
// and always propagates regardless of --enforce. Silently "passing" a run
// that never actually validated anything would be worse than the noise of
// failing loudly.
const GOVERNANCE_EXIT_CODES = new Set([0, 1, 2]);

// SCOPE-DIFF-003 (invalid scope declaration) and SCOPE-DIFF-004 (git
// base/head range unavailable) are, like a missing PowerShell host,
// infrastructure/configuration failures rather than governance verdicts --
// the comparison never actually ran, so there is no finding for report-only
// to soften. Everything else SCOPE-DIFF can emit (001/002/005) is a real
// governance verdict, subject to --enforce exactly like any other rule.
const SCOPE_DIFF_INFRA_RULE_IDS = new Set(["SCOPE-DIFF-003", "SCOPE-DIFF-004"]);

// A sentinel, not empty strings: validate-project.ps1's own opt-in check is
// `if ($ScopeDiffBase -and $ScopeDiffHead)`, so passing "" would make it
// silently skip the whole check even though the caller explicitly asked for
// it via enable-scope-diff. This value can never resolve as a real git ref,
// so it deterministically routes into the existing SCOPE-DIFF-004
// ("range unavailable") diagnostic with a specific, honest reason instead.
const SCOPE_DIFF_UNRESOLVED_REF = "AXIOM-SCOPE-DIFF-NO-BASE-OR-HEAD-AVAILABLE";

// On a pull_request event, GitHub always sets GITHUB_EVENT_PATH to a JSON
// file with the event payload, which is where the PR's actual base/head SHAs
// live (not the moving branch names). Any failure here (missing env var,
// unreadable file, unexpected shape) is swallowed and reported as "not
// found" -- the caller falls back to an explicit override or the unresolved
// sentinel, never to a guess.
function readPullRequestShasFromEvent() {
  try {
    const eventPath = process.env.GITHUB_EVENT_PATH;
    if (!eventPath) return null;
    const event = JSON.parse(readFileSync(eventPath, "utf8"));
    const base = event?.pull_request?.base?.sha;
    const head = event?.pull_request?.head?.sha;
    if (typeof base === "string" && base && typeof head === "string" && head) {
      return { base, head };
    }
    return null;
  } catch {
    return null;
  }
}

// Precedence: explicit input override > pull_request event context > the
// unresolved sentinel (which surfaces as a clear SCOPE-DIFF-004, not a
// silent skip -- enable-scope-diff being true is itself a request that must
// be honoured with an answer, even a failing one).
function resolveScopeDiffRefs(options) {
  if (options.scopeDiffBase && options.scopeDiffHead) {
    return { base: options.scopeDiffBase, head: options.scopeDiffHead, source: "input-override" };
  }
  const fromEvent = readPullRequestShasFromEvent();
  if (fromEvent) {
    return { base: fromEvent.base, head: fromEvent.head, source: "pull_request-event" };
  }
  return { base: SCOPE_DIFF_UNRESOLVED_REF, head: SCOPE_DIFF_UNRESOLVED_REF, source: "unresolved" };
}

function parseArgs(argv) {
  const options = {
    project: undefined,
    mode: "Standard",
    gate: "Release",
    failOnWarning: true,
    workingDirectory: ".",
    annotationMode: "safe",
    enforce: false,
    jsonReportPath: "axiom-report.json",
    mdReportPath: "axiom-report.md",
    enableScopeDiff: false,
    scopeDiffBase: "",
    scopeDiffHead: "",
  };
  const bool = (v) => v === "true" || v === "1" || v === true;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const next = () => argv[++i];
    switch (arg) {
      case "--project": options.project = next(); break;
      case "--mode": options.mode = next(); break;
      case "--gate": options.gate = next(); break;
      case "--fail-on-warning": options.failOnWarning = bool(next()); break;
      case "--working-directory": options.workingDirectory = next(); break;
      case "--annotation-mode": options.annotationMode = next(); break;
      case "--enforce": options.enforce = bool(next()); break;
      case "--json-report-path": options.jsonReportPath = next(); break;
      case "--md-report-path": options.mdReportPath = next(); break;
      case "--enable-scope-diff": options.enableScopeDiff = bool(next()); break;
      case "--scope-diff-base": options.scopeDiffBase = next(); break;
      case "--scope-diff-head": options.scopeDiffHead = next(); break;
      default:
        process.stderr.write(`run-action.mjs: unrecognised argument ${arg}\n`);
        process.exit(64);
    }
  }
  return options;
}

function writeGithubOutput(entries) {
  const target = process.env.GITHUB_OUTPUT;
  if (!target) return; // Not running under Actions (e.g. local test run).
  const body = Object.entries(entries).map(([k, v]) => `${k}=${v}\n`).join("");
  appendFileSync(target, body);
}

function writeJobSummary(markdown) {
  const target = process.env.GITHUB_STEP_SUMMARY;
  if (!target) return;
  // Always append, never overwrite -- other steps in the same job may also
  // write to the summary, and this Action does not own the whole document.
  appendFileSync(target, `${markdown}\n`);
}

// Deliberately takes a length, never the stdout string itself -- a function
// that never receives the raw content cannot leak it, by construction. If the
// validator's stdout is malformed because of a corrupted PowerShell profile,
// a broken wrapper, or a misconfigured dependency, that stdout can contain
// anything: a token, a connection string, a local path, output the user never
// intended to publish. axiom-report.json is uploaded as a workflow artifact
// by default, so nothing beyond "did this happen, and how much text was
// there" belongs in it. The actual content stays in the workflow run log
// (private to the same audience that could already read this step's log),
// which is where a human debugging the underlying host should look anyway.
function buildParseFailureResult({ project, mode, gate, exitCode, stdoutLength }) {
  return {
    schema_version: "1.1",
    project,
    requested_mode: mode,
    effective_mode: mode,
    gate,
    summary: { pass: 0, warn: 0, warn_blocking: 0, fail: 1, exit_code: exitCode },
    results: [
      {
        schema_version: "1.1",
        level: "FAIL",
        rule_id: "ACTION-PARSE-ERROR",
        message: "The validator did not produce parseable JSON output. The run cannot be scored.",
        blocking: true,
        artifact: null,
        item_id: null,
        field: null,
        suggestion: stdoutLength > 0
          ? "Check the workflow run log for the underlying PowerShell error. The raw output is not copied into this report -- it may contain secrets or other content that should not be persisted in an uploaded artifact."
          : "The validator produced no stdout at all. Check the workflow run log above this annotation for the underlying error (commonly a missing PowerShell host or a bad Action input).",
        documentation_url: null,
      },
    ],
  };
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  if (!options.project) {
    process.stderr.write("run-action.mjs: --project is required\n");
    process.exit(64);
  }

  const workingDirectory = isAbsolute(options.workingDirectory)
    ? options.workingDirectory
    : resolve(process.cwd(), options.workingDirectory);

  const cliArgs = [
    "validate",
    "--project", options.project,
    "--mode", options.mode,
    "--gate", options.gate,
    "--json",
  ];
  if (options.failOnWarning) cliArgs.push("--fail-on-warning");

  let scopeDiffRefs = null;
  if (options.enableScopeDiff) {
    scopeDiffRefs = resolveScopeDiffRefs(options);
    // PowerShell parameter syntax (-Name), not this file's own --kebab-case
    // argv convention: cli/axiom.mjs's `validate` command forwards any
    // argument it does not itself recognise straight through, unmodified, to
    // scripts/validate-project.ps1's own command line (see buildValidate in
    // cli/axiom.mjs) -- these three have to already be in the form
    // validate-project.ps1 itself expects.
    cliArgs.push(
      "-ScopeDiffBase", scopeDiffRefs.base,
      "-ScopeDiffHead", scopeDiffRefs.head,
      // The consumer's own checkout (workingDirectory), not wherever this
      // Action's own files happen to be checked out -- see validate-project.ps1's
      // -ScopeDiffRepoRoot comment for why those are two different things
      // when running as a GitHub Action.
      "-ScopeDiffRepoRoot", workingDirectory,
    );
  }

  const child = spawnSync(process.execPath, [CLI, ...cliArgs], {
    cwd: workingDirectory,
    encoding: "utf8",
  });

  if (child.error) {
    process.stderr.write(`run-action.mjs: failed to launch node/cli: ${child.error.message}\n`);
    process.exitCode = 127;
    return;
  }
  // Forward stderr as-is: swallowing a PowerShell error to keep output clean
  // would hide the reason a report came back empty or malformed.
  if (child.stderr) process.stderr.write(child.stderr);

  const exitCode = child.status === null ? 1 : child.status;

  let validatorResult;
  let parseOk = true;
  try {
    validatorResult = JSON.parse(child.stdout);
  } catch {
    parseOk = false;
    validatorResult = buildParseFailureResult({
      project: options.project,
      mode: options.mode,
      gate: options.gate,
      exitCode,
      stdoutLength: (child.stdout ?? "").length,
    });
  }

  const outcome = parseOk ? outcomeForExitCode(exitCode) : "failure";
  const meta = {
    outcome,
    exitCode,
    enforce: options.enforce,
    failOnWarning: options.failOnWarning,
    annotationMode: options.annotationMode,
    generatedAt: new Date().toISOString(),
  };

  // The validator resolves --project to an absolute filesystem path and
  // echoes it back in its own JSON. That is fine for a local terminal, but a
  // report/Job Summary meant for a pull request should not print the CI
  // runner's absolute directory layout -- show what the user configured
  // instead. This only changes the display value used for reports; nothing
  // that reaches emit-annotations.mjs (which already resolves paths
  // relative to the workspace on its own) is affected.
  validatorResult = { ...validatorResult, project: options.project };

  const reportJson = buildReportJson(validatorResult, meta);
  if (!parseOk) {
    // Safe metadata only -- see buildParseFailureResult's comment above for
    // why the raw content itself never reaches this object.
    reportJson.action.parse_error = true;
    reportJson.action.stdout_present = (child.stdout ?? "").length > 0;
    reportJson.action.stdout_length = (child.stdout ?? "").length;
  }
  const reportMarkdown = buildReportMarkdown(validatorResult, meta);
  const jobSummary = buildJobSummary(validatorResult, meta);

  const jsonReportPath = isAbsolute(options.jsonReportPath)
    ? options.jsonReportPath
    : resolve(workingDirectory, options.jsonReportPath);
  const mdReportPath = isAbsolute(options.mdReportPath)
    ? options.mdReportPath
    : resolve(workingDirectory, options.mdReportPath);

  mkdirSync(dirname(jsonReportPath), { recursive: true });
  mkdirSync(dirname(mdReportPath), { recursive: true });
  writeFileSync(jsonReportPath, `${JSON.stringify(reportJson, null, 2)}\n`, "utf8");
  writeFileSync(mdReportPath, `${reportMarkdown}\n`, "utf8");

  writeJobSummary(jobSummary);

  const resolvedProjectPath = isAbsolute(options.project)
    ? options.project
    : resolve(workingDirectory, options.project);
  emitAnnotations(validatorResult.results ?? [], {
    workspace: workingDirectory,
    projectPath: resolvedProjectPath,
    mode: options.annotationMode,
  });

  const scopeDiffVerdict = validatorResult.scope_diff?.verdict ?? "";

  writeGithubOutput({
    "exit-code": exitCode,
    outcome,
    "json-report": jsonReportPath,
    "markdown-report": mdReportPath,
    "scope-diff-verdict": scopeDiffVerdict,
  });

  const scopeDiffNote = options.enableScopeDiff ? ` scope_diff=${scopeDiffVerdict || "(none)"}` : "";
  process.stdout.write(
    `Axiom-PMO governance report: outcome=${outcome} exit_code=${exitCode} enforce=${options.enforce}${scopeDiffNote}\n`,
  );

  // A SCOPE-DIFF-003/004 row means the scope comparison itself could not run
  // (invalid declaration, or the git range was unavailable) -- an
  // infrastructure/configuration problem, not a governance verdict, so
  // report-only must not be able to hide it either. Checked independently of
  // the aggregate exit code, which mixes scope-diff in with every other rule
  // this validator run evaluated.
  const hasScopeDiffInfraFailure = (validatorResult.results ?? []).some(
    (row) => SCOPE_DIFF_INFRA_RULE_IDS.has(row.rule_id),
  );

  // Report-only softens a governance verdict (0/1/2) into a passing step.
  // It never softens an infrastructure failure (127, 64, a SCOPE-DIFF-003/004
  // row, or anything else) -- see GOVERNANCE_EXIT_CODES above for why.
  if (!options.enforce && !hasScopeDiffInfraFailure && GOVERNANCE_EXIT_CODES.has(exitCode)) {
    process.exitCode = 0;
    if (exitCode !== 0) {
      process.stdout.write("Report-only mode: findings above did not fail this workflow step. Set enforce: true to change that.\n");
    }
  } else {
    process.exitCode = exitCode;
    if (hasScopeDiffInfraFailure && !options.enforce) {
      process.stdout.write("Scope-diff could not run (see SCOPE-DIFF-003/004 above) -- this fails the step even in report-only mode, the same way a missing PowerShell host would.\n");
    }
  }
}

main();
