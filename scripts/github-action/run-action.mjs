#!/usr/bin/env node
// GitHub Action wrapper. Owns CI presentation only -- it invokes the existing
// CLI (which invokes the existing PowerShell validator) and never evaluates a
// rule itself. See docs/reference/diagnostics-contract.md for the JSON shape
// this reads, and 20260729_Fixed_plan/M4_GitHub_Action_implementation_plan.md
// for the interface this implements.
//
//   node run-action.mjs --project <path> [--mode Standard] [--gate Release]
//     [--fail-on-warning true|false] [--working-directory .]
//     [--annotation-mode safe|off] [--enforce true|false]
//     [--json-report-path axiom-report.json] [--md-report-path axiom-report.md]

import { spawnSync } from "node:child_process";
import { appendFileSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
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

function buildParseFailureResult({ project, mode, gate, exitCode, rawStdout }) {
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
        suggestion: rawStdout.length > 0
          ? `Check the workflow run log for the underlying PowerShell error. The first ${Math.min(
              rawStdout.length,
              200,
            )} characters of raw stdout are included in axiom-report.json under action.raw_stdout_preview.`
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
      rawStdout: child.stdout ?? "",
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
    reportJson.action.raw_stdout_preview = (child.stdout ?? "").slice(0, 200);
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

  writeGithubOutput({
    "exit-code": exitCode,
    outcome,
    "json-report": jsonReportPath,
    "markdown-report": mdReportPath,
  });

  process.stdout.write(
    `Axiom-PMO governance report: outcome=${outcome} exit_code=${exitCode} enforce=${options.enforce}\n`,
  );

  // Report-only softens a governance verdict (0/1/2) into a passing step.
  // It never softens an infrastructure failure (127, 64, or anything else) --
  // see GOVERNANCE_EXIT_CODES above for why.
  if (!options.enforce && GOVERNANCE_EXIT_CODES.has(exitCode)) {
    process.exitCode = 0;
    if (exitCode !== 0) {
      process.stdout.write("Report-only mode: findings above did not fail this workflow step. Set enforce: true to change that.\n");
    }
  } else {
    process.exitCode = exitCode;
  }
}

main();
