#!/usr/bin/env node
// Axiom-PMO thin CLI.
//
// This file contains ZERO validation logic and must keep containing zero. The
// TypeScript engine under src/ (compiled to dist/) is the differentially-proven
// engine (Phase 6/7); the PowerShell scripts under scripts/ were the original
// reference implementation the port was proven against and remain on disk for
// now (Phase 9 territory), but this CLI no longer knows how to invoke them --
// Phase 8 (DEC-030/031, master-plan.md) made the Node path unconditional. This
// file only:
//   1. maps a friendly verb to the engine's arguments
//   2. preserves stdout, stderr, and the exit code
//
// No automatic fallback of any kind: a crash in the engine surfaces as a
// visible infrastructure failure (exit 127), never silently retried or masked.
//
// Exit codes follow the diagnostics contract (docs/reference/diagnostics-contract.md):
//   0   pass
//   1   at least one FAIL
//   2   -FailOnWarning and at least one blocking WARN
//   127 in-process engine failure (this file's own failure, not the validator's)

import { existsSync, readFileSync, statSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { createInterface } from "node:readline/promises";
import { fileURLToPath } from "node:url";

// --- the ported TS engine (default path) ------------------------------------
// dist/ is the committed, tsc-compiled form of src/. Importing it here makes
// the default CLI path a thin dispatch over the differentially-proven library
// (master-plan.md's target shape: "cli/axiom.mjs — thin dispatch over dist/").
// These imports are evaluation-free at load time; no rules run until a command
// is dispatched.
import { runValidateEnvelope } from "../dist/probe/validate-chain.js";
import { runPmoStatus } from "../dist/tools/pmo-status.js";
import { runPmoDoctor, formatDoctorText } from "../dist/doctor/pmo-doctor.js";
import { runAssessHandoff } from "../dist/tools/assess-handoff.js";
import { setupClaudeIntegration } from "../dist/tools/setup-claude-integration.js";
import { newProject } from "../dist/tools/new-project.js";
import { exportExecutionContract } from "../dist/tools/export-execution-contract.js";
import { runExecutionCommand } from "../dist/tools/run-execution-command.js";
import { runVerifyExecutionResult, formatVerifyText } from "../dist/exec/verify-execution-result.js";
import { runDemo } from "../dist/tools/demo.js";
import { runAllChecks } from "../dist/tools/run-all-checks.js";
import { buildPluginPackage } from "../dist/tools/build-plugin-package.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const EXIT_NO_POWERSHELL = 127;
const EXIT_USAGE = 64;

// --- argument helpers -------------------------------------------------------

// Extract `--name value` / `--name=value`, leaving everything else in place so
// unrecognised flags reach the PowerShell script untouched (rollback mode).
function takeOption(args, name) {
  const long = `--${name}`;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === long) {
      const value = args[i + 1];
      if (value === undefined || value.startsWith("--")) {
        return { value: undefined, rest: args, missingValue: true };
      }
      return { value, rest: [...args.slice(0, i), ...args.slice(i + 2)] };
    }
    if (args[i].startsWith(`${long}=`)) {
      return { value: args[i].slice(long.length + 1), rest: [...args.slice(0, i), ...args.slice(i + 1)] };
    }
  }
  return { value: undefined, rest: args };
}

function takeFlag(args, name) {
  const long = `--${name}`;
  const index = args.indexOf(long);
  if (index === -1) return { present: false, rest: args };
  return { present: true, rest: [...args.slice(0, index), ...args.slice(index + 1)] };
}

// PowerShell-style `-Name value` / `-Name:value` / `-Switch`. The GitHub
// Action forwards -ScopeDiffBase/-ScopeDiffHead/-ScopeDiffRepoRoot through this
// CLI (they are validate-project.ps1's own parameter names, not CLI verbs), so
// the in-process path has to recognise them; the rollback path forwards them
// untouched regardless.
function takePsOption(args, name) {
  const short = `-${name}`;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === short) {
      const value = args[i + 1];
      if (value === undefined || value.startsWith("-")) {
        return { value: undefined, rest: args, missingValue: true };
      }
      return { value, rest: [...args.slice(0, i), ...args.slice(i + 2)] };
    }
    if (args[i].startsWith(`${short}:`)) {
      return { value: args[i].slice(short.length + 1), rest: [...args.slice(0, i), ...args.slice(i + 1)] };
    }
  }
  return { value: undefined, rest: args };
}

function takePsFlag(args, name) {
  const short = `-${name}`;
  const index = args.indexOf(short);
  if (index === -1) return { present: false, rest: args };
  return { present: true, rest: [...args.slice(0, index), ...args.slice(index + 1)] };
}

function resolveProjectPath(value) {
  const candidate = isAbsolute(value) ? value : resolve(process.cwd(), value);
  if (existsSync(candidate) && statSync(candidate).isDirectory()) return candidate;

  // A project named relative to the repository root is the common case when
  // running from somewhere else in a monorepo.
  const fromRepo = join(REPO_ROOT, value);
  if (existsSync(fromRepo) && statSync(fromRepo).isDirectory()) return fromRepo;

  return null;
}

// --- in-process engine execution --------------------------------------------

// A user error (unrecognised option on the default path), not an engine crash.
// Maps to EXIT_USAGE, same as the CLI's other usage errors.
class UsageError extends Error {}

// Runs one step through the in-process TS engine. step.ts() returns
// { output, exitCode } -- the complete stdout and exit code. A throw here is
// an infrastructure failure: it surfaces visibly (exit 127), never masked.
function runTsStep(step) {
  try {
    const r = step.ts();
    return { stdout: r.output, status: r.exitCode };
  } catch (e) {
    if (e instanceof UsageError) {
      return { stdout: "", status: EXIT_USAGE, usageMessage: e.message };
    }
    const msg = e instanceof Error ? e.message : String(e);
    process.stderr.write(`Axiom-PMO internal error: ${msg}\n`);
    process.stderr.write("This is an infrastructure failure, not a governance verdict.\n");
    return { stdout: "", status: EXIT_NO_POWERSHELL };
  }
}

// `validate` through the in-process engine, byte-identical in contract to
// validate-project.ps1: runs the ported chain, optionally the opt-in
// SCOPE-DIFF check, assembles the diagnostic envelope exactly as the
// reference's result-writer does, and renders Text or JSON. Shared with
// demo.ts's own gate step via src/probe/validate-chain.ts's exported
// runValidateEnvelope, rather than duplicating this logic per caller.
function runValidateTs(project, mode, gate, failOnWarning, format, scopeDiff) {
  return runValidateEnvelope(REPO_ROOT, project, mode, gate, failOnWarning, format, scopeDiff);
}

// --- interactive prompting (M7 onboarding) ----------------------------------
//
// Presentation only, by the same rule as the rest of this file: every trigger
// id, question, and mode-resolution decision is read from pmo-config/*.json,
// never written into this script. This file only asks and forwards.
//
// Built on node:readline/promises rather than a raw fs.readSync(0, ...) loop:
// a synchronous fd read is not guaranteed to block on every platform/TTY
// combination (it can return EAGAIN or a short read before input has
// arrived), where readline's event-driven read is the correct, documented
// way to read a line from a controlling terminal.

function isInteractive() {
  return Boolean(process.stdin.isTTY) && Boolean(process.stdout.isTTY);
}

// Numbered menu: prints options, loops until a valid 1..N is entered so a
// stray keystroke can never silently select the wrong path or mode.
async function promptChoice(rl, question, options) {
  for (;;) {
    process.stdout.write(`\n${question}\n`);
    options.forEach((opt, i) => {
      process.stdout.write(`  ${i + 1}. ${opt.label}\n`);
    });
    const raw = (await rl.question("> ")).trim();
    const index = Number.parseInt(raw, 10);
    if (Number.isInteger(index) && index >= 1 && index <= options.length) {
      return options[index - 1].value;
    }
    process.stdout.write(`Please enter a number from 1 to ${options.length}.\n`);
  }
}

async function promptYesNo(rl, question) {
  const raw = (await rl.question(`${question} [y/N] `)).trim();
  return /^y(es)?$/i.test(raw);
}

// pmo-config/*.json ship with a UTF-8 BOM (PowerShell's ConvertFrom-Json
// tolerates it; JSON.parse does not) -- strip it the same way the framework's
// own Python tooling reads these files with encoding="utf-8-sig".
function loadRepoJson(relPath) {
  const raw = readFileSync(join(REPO_ROOT, relPath), "utf8");
  return JSON.parse(raw.charCodeAt(0) === 0xfeff ? raw.slice(1) : raw);
}

// The "Help me decide" path: one question per pmo-config/policy.json
// enums.strict_triggers entry, wording from
// pmo-config/onboarding-questions.json (kept in sync by DOCTOR-013). The
// answer is a DECLARATION, not a detection -- there is no source material at
// init time to detect anything from, so the wording never claims the system
// found something.
async function runHelpMeDecide(rl) {
  const policy = loadRepoJson("pmo-config/policy.json");
  const questions = loadRepoJson("pmo-config/onboarding-questions.json");
  const triggers = policy.enums?.strict_triggers ?? [];

  for (const triggerId of triggers) {
    const entry = questions.questions?.[triggerId];
    const label = entry?.question ?? `Does this work involve: ${triggerId}?`;
    if (await promptYesNo(rl, `\n${label}`)) {
      process.stdout.write(
        `\nYou declared that this work involves: ${triggerId}.\n` +
          "Strict triggers are non-downgradable, so the effective mode is Strict.\n",
      );
      return { mode: "Strict", trigger: triggerId, question: label };
    }
  }
  process.stdout.write("\nNo strict triggers declared. Recommending Standard.\n");
  return { mode: "Standard", trigger: "none", question: null };
}

// Runs only for whichever of {code, mode, executionPath} the caller did not
// already supply via flags -- flags always win over the interactive prompt,
// never the other way around.
async function runInteractiveInit(rl, existing) {
  const answers = { ...existing };

  process.stdout.write("\nAxiom-PMO project setup\n");

  while (!answers.code) {
    answers.code = (await rl.question("\nProject code (e.g. P02-ABC): ")).trim();
  }

  if (!answers.executionPath) {
    answers.executionPath = await promptChoice(rl, "How will this work be delivered?", [
      {
        value: "development_handoff",
        label:
          "Development Handoff -- prepare requirements, scope, and design for a developer or vendor to build",
      },
      {
        value: "governed_ai_execution",
        label:
          "Governed AI Execution -- an AI execution framework builds it under Axiom-PMO's scope, contract, and evidence checks",
      },
    ]);
  }

  let strictTrigger = "none";
  let modeReason = null;
  let modeApprovedBy = null;

  if (!answers.mode) {
    const choice = await promptChoice(rl, "What level of governance does this work require?", [
      { value: "Lite", label: "Lite -- small, low-risk work, easy to fix if wrong" },
      { value: "Standard", label: "Standard -- normal feature delivery" },
      {
        value: "Strict",
        label: "Strict -- payment, PII, auth, permissions, compliance, or similarly high-risk work",
      },
      { value: "help", label: "Help me decide" },
    ]);
    if (choice === "help") {
      const decided = await runHelpMeDecide(rl);
      answers.mode = decided.mode;
      strictTrigger = decided.trigger;
      if (decided.trigger !== "none") {
        modeReason = `declared at interactive init: ${decided.question}`;
        modeApprovedBy = (await rl.question("\nYour name (recorded as Mode Approved By): ")).trim() || "Unknown";
      }
    } else {
      answers.mode = choice;
    }
  }

  if (!answers.uiDelivery) {
    const hasUi = await promptYesNo(rl, "\nDoes this work have a user-facing UI?");
    answers.uiDelivery = hasUi
      ? await promptChoice(rl, "How will the UI be delivered?", [
          { value: "dev_guided", label: "Developer-guided -- use the governed design and handoff flow" },
          { value: "claude_design", label: "Claude Design -- use the optional governed provider handoff" },
        ])
      : "not_applicable";
  }

  if (!answers.researchMode) {
    answers.researchMode = await promptChoice(rl, "Will this project use governed research before Scope approval?", [
      { value: "off", label: "Off -- no optional research artifacts" },
      { value: "guided", label: "Guided -- Human confirms focus/provider" },
      { value: "auto", label: "Auto -- orchestrate configured provider with truthful fallback" },
    ]);
  }
  if (answers.researchMode !== "off") {
    answers.researchDepth ??= await promptChoice(rl, "Research depth?", [
      { value: "quick", label: "Quick" },
      { value: "standard", label: "Standard" },
      { value: "deep", label: "Deep" },
    ]);
    answers.researchProvider ??= await promptChoice(rl, "Research provider?", [
      { value: "feyman", label: "Feyman (configured local provider)" },
      { value: "web", label: "Governed web research" },
      { value: "auto", label: "Auto provider selection" },
    ]);
  } else {
    answers.researchDepth ??= "standard";
    answers.researchProvider ??= "none";
  }

  const flowSteps =
    answers.executionPath === "governed_ai_execution"
      ? "Source -> Requirements -> Scope -> Design -> Approved Execution Contract -> AI Implementation -> Evidence Verification -> Human Approval"
      : "Source -> Requirements -> Scope -> Design -> Handoff -> Human Approval";

  process.stdout.write("\nYour Axiom-PMO Setup\n\n");
  process.stdout.write(`Execution Path:   ${answers.executionPath}\n`);
  process.stdout.write(`Governance Mode:  ${answers.mode}\n`);
  process.stdout.write(`Research:         ${answers.researchMode} (${answers.researchDepth}, ${answers.researchProvider})\n`);
  process.stdout.write(`UI Delivery:      ${answers.uiDelivery}\n`);
  process.stdout.write(`Expected Flow:    ${flowSteps}\n`);

  if (!(await promptYesNo(rl, "\nCreate this project?"))) {
    return null;
  }

  return { ...answers, strictTrigger, modeReason, modeApprovedBy };
}

// --- commands ---------------------------------------------------------------

// Every command builds a plan shaped { ts: () => ({output, exitCode}) };
// `steps` (handoff) carries one per step. `takePs*` parsing (PowerShell-style
// -Name flags) still matters here even post-cutover: the GitHub Action
// forwards validate-project.ps1's own parameter names through this CLI, so
// the in-process path still has to recognise them.

function buildDemo(args) {
  const tsRest = [...args];
  const plain = takePsFlag(tsRest, "Plain");
  const noPause = takePsFlag(plain.rest, "NoPause");
  const unknownRest = noPause.rest;
  return {
    ts: () => {
      if (unknownRest.length > 0) throw new UsageError(`demo: unrecognised option(s): ${unknownRest.join(" ")}`);
      return runDemo(REPO_ROOT, plain.present, noPause.present);
    },
  };
}

function buildCheck(args) {
  const tsRest = [...args];
  const child = takePsOption(tsRest, "TestChildScript");
  const unknownRest = child.rest;
  return {
    ts: () => {
      if (unknownRest.length > 0) throw new UsageError(`check: unrecognised option(s): ${unknownRest.join(" ")}`);
      return runAllChecks(REPO_ROOT, child.value ?? "");
    },
  };
}

function buildDoctor(args) {
  return {
    ts: () => {
      if (args.length > 0) throw new UsageError(`doctor: unrecognised option(s): ${args.join(" ")}`);
      const result = runPmoDoctor(REPO_ROOT);
      return { output: formatDoctorText(REPO_ROOT, result) + "\n", exitCode: result.fail > 0 ? 1 : 0 };
    },
  };
}

function buildValidate(args) {
  let rest = args;
  const project = takeOption(rest, "project");
  rest = project.rest;
  const mode = takeOption(rest, "mode");
  rest = mode.rest;
  const gate = takeOption(rest, "gate");
  rest = gate.rest;
  const json = takeFlag(rest, "json");
  rest = json.rest;
  const failOnWarning = takeFlag(rest, "fail-on-warning");
  rest = failOnWarning.rest;

  if (!project.value) {
    return { usageError: "validate requires --project <path>" };
  }
  const projectPath = resolveProjectPath(project.value);
  if (!projectPath) {
    return { usageError: `project directory not found: ${project.value}` };
  }
  const resolvedMode = mode.value ?? "Standard";

  // The GitHub Action forwards validate-project.ps1's own parameters
  // (-ScopeDiffBase/-ScopeDiffHead/-ScopeDiffRepoRoot, and -Release) through
  // this CLI. The rollback path keeps forwarding whatever `rest` still holds,
  // untouched; the in-process path parses the ones it can honour from a copy.
  const tsRest = [...rest];
  const sdBase = takePsOption(tsRest, "ScopeDiffBase");
  const sdHead = takePsOption(sdBase.rest, "ScopeDiffHead");
  const sdRepo = takePsOption(sdHead.rest, "ScopeDiffRepoRoot");
  const release = takePsFlag(sdRepo.rest, "Release");
  const fmt = takePsOption(release.rest, "Format");
  const unknownRest = fmt.rest;
  const resolvedGate = release.present ? "Release" : gate.value ?? "Draft";
  if (fmt.value && fmt.value !== "Json" && fmt.value !== "Text") {
    return { usageError: `validate: -Format must be Json or Text, got '${fmt.value}'` };
  }
  const resolvedFormat = json.present ? "Json" : fmt.value === "Json" ? "Json" : "Text";

  return {
    ts: () => {
      if (unknownRest.length > 0) throw new UsageError(`validate: unrecognised option(s): ${unknownRest.join(" ")}`);
      return runValidateTs(projectPath, resolvedMode, resolvedGate, failOnWarning.present, resolvedFormat, {
        base: sdBase.value,
        head: sdHead.value,
        repoRoot: sdRepo.value,
      });
    },
  };
}

// `handoff` is two runs, not one: the gate proves the contract is complete, the
// assessment turns open findings into per-stage readiness. Running only the
// gate would answer "is this valid" when the question people actually have is
// "can we start, and can we demo".
function buildHandoff(args) {
  let rest = args;
  const project = takeOption(rest, "project");
  rest = project.rest;
  const mode = takeOption(rest, "mode");
  rest = mode.rest;
  const json = takeFlag(rest, "json");
  rest = json.rest;

  if (!project.value) {
    return { usageError: "handoff requires --project <path>" };
  }
  const projectPath = resolveProjectPath(project.value);
  if (!projectPath) {
    return { usageError: `project directory not found: ${project.value}` };
  }
  const resolvedMode = mode.value ?? "Standard";
  const resolvedFormat = json.present ? "Json" : "Text";

  const tsRest = [...rest];
  const sdBase = takePsOption(tsRest, "ScopeDiffBase");
  const sdHead = takePsOption(sdBase.rest, "ScopeDiffHead");
  const sdRepo = takePsOption(sdHead.rest, "ScopeDiffRepoRoot");
  const unknownRest = sdRepo.rest;

  return {
    // --json has to produce one parseable document. Two JSON payloads with
    // human-readable labels between them is not JSON, however useful it looks
    // in a terminal, so the two steps are captured and merged into a single
    // envelope instead of being streamed straight through.
    json: json.present,
    steps: [
      {
        key: "gate",
        label: "Handoff gate",
        ts: () => {
          if (unknownRest.length > 0) throw new UsageError(`handoff: unrecognised option(s): ${unknownRest.join(" ")}`);
          return runValidateTs(projectPath, resolvedMode, "Handoff", false, resolvedFormat, {
            base: sdBase.value,
            head: sdHead.value,
            repoRoot: sdRepo.value,
          });
        },
      },
      {
        key: "assessment",
        label: "Readiness assessment",
        ts: () => runAssessHandoff(REPO_ROOT, projectPath, resolvedMode, resolvedFormat),
        // The assessment reports on the gate's findings; it is not a second
        // verdict. The gate's exit code is the one that propagates.
        alwaysRun: true,
        ignoreExitCode: true,
      },
    ],
  };
}

// `export` and `verify` are the two halves of Milestone 5: hand an approved
// work item to an execution workflow, then check what came back. No
// verification logic lives here -- the ported engine does all of it.
function buildExport(args) {
  let rest = args;
  const project = takeOption(rest, "project");
  rest = project.rest;
  const workItem = takeOption(rest, "work-item");
  rest = workItem.rest;
  const grant = takeOption(rest, "grant");
  rest = grant.rest;
  const output = takeOption(rest, "output");
  rest = output.rest;
  const format = takeOption(rest, "format");
  rest = format.rest;
  const force = takeFlag(rest, "force");
  rest = force.rest;

  if (!project.value) {
    return { usageError: "export requires --project <path>" };
  }
  if (!workItem.value) {
    return { usageError: "export requires --work-item <D-###>" };
  }
  const projectPath = resolveProjectPath(project.value);
  if (!projectPath) {
    return { usageError: `project directory not found: ${project.value}` };
  }

  const tsRest = [...rest];
  const gitRepo = takePsOption(tsRest, "GitRepoRoot");
  const unknownRest = gitRepo.rest;

  return {
    ts: () => {
      if (unknownRest.length > 0) throw new UsageError(`export: unrecognised option(s): ${unknownRest.join(" ")}`);
      // -Format is accepted by the reference script but unused (kept for
      // continuity); the ported engine ignores it the same way.
      return exportExecutionContract(REPO_ROOT, projectPath, workItem.value, gitRepo.value ?? null, output.value ?? null, grant.value ?? "", force.present);
    },
  };
}

function buildSetup(args) {
  // `axiom setup claude` reads as a subcommand, but the only target that
  // exists is Claude Code, so it is accepted as a positional word rather than
  // modelled as a dispatch table that would have exactly one entry.
  let rest = args;
  if (rest[0] && !rest[0].startsWith("-")) {
    const target = rest[0];
    if (target !== "claude") {
      return { usageError: `unknown setup target '${target}' (only 'claude' is supported)` };
    }
    rest = rest.slice(1);
  }

  const project = takeOption(rest, "project");
  rest = project.rest;
  const file = takeOption(rest, "file");
  rest = file.rest;
  const dryRun = takeFlag(rest, "dry-run");
  rest = dryRun.rest;
  const uninstall = takeFlag(rest, "uninstall");
  rest = uninstall.rest;
  const force = takeFlag(rest, "force");
  rest = force.rest;

  // Defaults to the caller's own directory, and is resolved against cwd rather
  // than the framework root: this command modifies the USER's repository, and
  // resolving a relative path against the framework's checkout would be how it
  // ends up editing the wrong AGENTS.md.
  const projectPath = project.value
    ? (isAbsolute(project.value) ? project.value : resolve(process.cwd(), project.value))
    : process.cwd();

  return {
    ts: () => {
      if (rest.length > 0) throw new UsageError(`setup: unrecognised option(s): ${rest.join(" ")}`);
      return setupClaudeIntegration(projectPath, dryRun.present, uninstall.present, force.present, file.value === "CLAUDE.md" ? "CLAUDE.md" : "AGENTS.md");
    },
  };
}

function buildVerify(args) {
  let rest = args;
  const project = takeOption(rest, "project");
  rest = project.rest;
  const result = takeOption(rest, "result");
  rest = result.rest;
  const contract = takeOption(rest, "contract");
  rest = contract.rest;
  const json = takeFlag(rest, "json");
  rest = json.rest;
  const failOnWarning = takeFlag(rest, "fail-on-warning");
  rest = failOnWarning.rest;
  const preflight = takeFlag(rest, "preflight");
  rest = preflight.rest;

  if (!project.value) {
    return { usageError: "verify requires --project <path>" };
  }
  if (!result.value) {
    return { usageError: "verify requires --result <path to EXECUTION-RESULT.json>" };
  }
  const projectPath = resolveProjectPath(project.value);
  if (!projectPath) {
    return { usageError: `project directory not found: ${project.value}` };
  }

  // The result path is resolved against the caller's cwd rather than the repo
  // root: unlike --project (a governed directory that may sensibly be named
  // relative to the repository), a result is a file the user just produced and
  // is almost always pointing at from where they are standing.
  const resultPath = isAbsolute(result.value) ? result.value : resolve(process.cwd(), result.value);

  const tsRest = [...rest];
  const gitRepo = takePsOption(tsRest, "GitRepoRoot");
  const unknownRest = gitRepo.rest;

  return {
    ts: () => {
      if (unknownRest.length > 0) throw new UsageError(`verify: unrecognised option(s): ${unknownRest.join(" ")}`);
      const contractPath = contract.value
        ? (isAbsolute(contract.value) ? contract.value : resolve(process.cwd(), contract.value))
        : null;
      const v = runVerifyExecutionResult(REPO_ROOT, projectPath, resultPath, gitRepo.value ?? null, contractPath, preflight.present);
      const summary = v.envelope.summary;
      // The ported entrypoint computes the exit code without -FailOnWarning;
      // apply the reference's own exit-code rule on top, exactly as
      // verify-execution-result.ps1 does (and writes into the envelope).
      let exitCode = v.exitCode;
      if (failOnWarning.present && summary.fail === 0 && summary.warn_blocking > 0) exitCode = 2;
      v.envelope.summary.exit_code = exitCode;
      const output = json.present
        ? JSON.stringify(v.envelope, null, 2) + "\n"
        : formatVerifyText(v.envelope, resultPath) + "\n";
      return { output, exitCode };
    },
  };
}

function buildRun(args) {
  let rest = args;
  const project = takeOption(rest, "project");
  rest = project.rest;
  const workItem = takeOption(rest, "work-item");
  rest = workItem.rest;
  const name = takeOption(rest, "name");
  rest = name.rest;
  const command = takeOption(rest, "command");
  rest = command.rest;
  const cwd = takeOption(rest, "cwd");
  rest = cwd.rest;

  if (!project.value) return { usageError: "run requires --project <path>" };
  if (!workItem.value) return { usageError: "run requires --work-item <D-###>" };
  if (!name.value) return { usageError: "run requires --name <test-name>, matching a required_tests entry" };
  if (!command.value) return { usageError: "run requires --command <cmd>" };
  const projectPath = resolveProjectPath(project.value);
  if (!projectPath) return { usageError: `project directory not found: ${project.value}` };

  const tsRest = [...rest];
  const contract = takePsOption(tsRest, "ContractPath");
  const unknownRest = contract.rest;

  return {
    ts: () => {
      if (unknownRest.length > 0) throw new UsageError(`run: unrecognised option(s): ${unknownRest.join(" ")}`);
      return runExecutionCommand(projectPath, workItem.value, name.value, command.value, cwd.value ?? ".", contract.value ?? null);
    },
  };
}

async function buildInit(args) {
  let rest = args;
  const code = takeOption(rest, "code");
  rest = code.rest;
  const mode = takeOption(rest, "mode");
  rest = mode.rest;
  const executionPath = takeOption(rest, "execution-path");
  rest = executionPath.rest;
  const researchMode = takeOption(rest, "research-mode");
  rest = researchMode.rest;
  const researchDepth = takeOption(rest, "research-depth");
  rest = researchDepth.rest;
  const researchProvider = takeOption(rest, "research-provider");
  rest = researchProvider.rest;
  const uiDelivery = takeOption(rest, "ui-delivery");
  rest = uiDelivery.rest;
  const specDepth = takeOption(rest, "spec-depth");
  rest = specDepth.rest;
  const output = takeOption(rest, "output");
  rest = output.rest;
  const target = takeOption(rest, "target");
  rest = target.rest;
  const horizon = takeOption(rest, "horizon-days");
  rest = horizon.rest;
  const handoff = takeFlag(rest, "handoff");
  rest = handoff.rest;
  const noInteractive = takeFlag(rest, "no-interactive");
  rest = noInteractive.rest;

  let resolvedCode = code.value;
  let resolvedMode = mode.value;
  let resolvedExecutionPath = executionPath.value;
  let resolvedResearchMode = researchMode.value;
  let resolvedResearchDepth = researchDepth.value;
  let resolvedResearchProvider = researchProvider.value;
  let resolvedUiDelivery = uiDelivery.value;
  let resolvedSpecDepth = specDepth.value ?? "legacy";
  let strictTrigger;
  let modeReason;
  let modeApprovedBy;

  // Two independent questions (who builds it, how strictly is it governed),
  // asked only for whatever a flag did not already answer, and only on a
  // TTY -- CI, `make demo`, and every scripted caller pass flags and must
  // never block waiting for input that will never arrive.
  const shouldPrompt = isInteractive() && !noInteractive.present && (!resolvedCode || !resolvedMode || !resolvedExecutionPath || !resolvedResearchMode || !resolvedUiDelivery);
  if (shouldPrompt) {
    const rl = createInterface({ input: process.stdin, output: process.stdout });
    let answers;
    try {
      answers = await runInteractiveInit(rl, { code: resolvedCode, mode: resolvedMode, executionPath: resolvedExecutionPath, researchMode: resolvedResearchMode, researchDepth: resolvedResearchDepth, researchProvider: resolvedResearchProvider, uiDelivery: resolvedUiDelivery });
    } finally {
      rl.close();
    }
    if (!answers) {
      return { cancelled: true };
    }
    resolvedCode = answers.code;
    resolvedMode = answers.mode;
    resolvedExecutionPath = answers.executionPath;
    resolvedResearchMode = answers.researchMode;
    resolvedResearchDepth = answers.researchDepth;
    resolvedResearchProvider = answers.researchProvider;
    resolvedUiDelivery = answers.uiDelivery;
    strictTrigger = answers.strictTrigger;
    modeReason = answers.modeReason;
    modeApprovedBy = answers.modeApprovedBy;
  }

  if (!resolvedCode) {
    return { usageError: "init requires --code <PROJECT-CODE>" };
  }

  return {
    ts: () => {
      if (rest.length > 0) throw new UsageError(`init: unrecognised option(s): ${rest.join(" ")}`);
      // Absent flags fall back to new-project.ps1's own parameter defaults so
      // the in-process generator produces the same bytes the reference would.
      return newProject(
        REPO_ROOT, resolvedCode, resolvedMode ?? "Standard", resolvedExecutionPath ?? "development_handoff",
        resolvedResearchMode ?? "off", resolvedResearchDepth ?? "standard", resolvedResearchProvider ?? "none",
        resolvedUiDelivery ?? "not_applicable", strictTrigger ?? "none", modeReason ?? "normal feature",
        modeApprovedBy ?? "PM", output.value ?? "projects", handoff.present, target.value ?? "internal",
        horizon.value ? Number(horizon.value) : 14,
        resolvedSpecDepth,
      );
    },
  };
}

function buildPackage(args) {
  let rest = args;
  const write = takeFlag(rest, "write");
  rest = write.rest;
  const check = takeFlag(rest, "check");
  rest = check.rest;

  return {
    ts: () => {
      if (rest.length > 0) throw new UsageError(`package: unrecognised option(s): ${rest.join(" ")}`);
      const isCheck = check.present || !write.present;
      const res = buildPluginPackage(REPO_ROOT, isCheck);
      return { output: res.output, exitCode: res.exitCode };
    },
  };
}

function buildStatus(args) {
  let rest = args;
  const project = takeOption(rest, "project");
  rest = project.rest;
  const json = takeFlag(rest, "json");
  rest = json.rest;

  if (!project.value) {
    return { usageError: "status requires --project <path>" };
  }
  const projectPath = resolveProjectPath(project.value);
  if (!projectPath) {
    return { usageError: `project directory not found: ${project.value}` };
  }

  const tsRest = [...rest];
  const fmt = takePsOption(tsRest, "Format");
  const unknownRest = fmt.rest;
  if (fmt.value && fmt.value !== "Json" && fmt.value !== "Text") {
    return { usageError: `status: -Format must be Json or Text, got '${fmt.value}'` };
  }
  const resolvedFormat = json.present ? "Json" : fmt.value === "Json" ? "Json" : "Text";

  return {
    ts: () => {
      if (unknownRest.length > 0) throw new UsageError(`status: unrecognised option(s): ${unknownRest.join(" ")}`);
      return runPmoStatus(REPO_ROOT, projectPath, resolvedFormat);
    },
  };
}

const COMMANDS = {
  demo: {
    summary: "Run the three-minute proof: a broken handoff, then a fixed one",
    build: (args) => buildDemo(args),
  },

  check: {
    summary: "Run every framework check (doctor, fixtures, mutation, e2e)",
    build: (args) => buildCheck(args),
  },

  doctor: {
    summary: "Check framework health: config, skills, rule catalog, permissions",
    build: (args) => buildDoctor(args),
  },

  validate: {
    summary: "Validate a project at a gate",
    usage: "axiom validate --project <path> [--mode Standard] [--gate Release] [--json] [--fail-on-warning]",
    build: (args) => buildValidate(args),
  },

  handoff: {
    summary: "Run the Handoff gate, then report readiness by stage",
    usage: "axiom handoff --project <path> [--mode Standard] [--json]",
    build: (args) => buildHandoff(args),
  },

  init: {
    summary: "Create a new project from the templates (interactive on a TTY)",
    usage:
      "axiom init [--code <PROJECT-CODE>] [--mode Standard] [--execution-path development_handoff] [--research-mode off] [--research-depth standard] [--research-provider none] [--ui-delivery not_applicable] [--spec-depth legacy|full] [--handoff] [--target demo] [--horizon-days 14] [--no-interactive]",
    build: (args) => buildInit(args),
  },

  package: {
    summary: "Package or check the skills/ mirror from .claude/skills/",
    usage: "axiom package [--write] [--check]",
    build: (args) => buildPackage(args),
  },

  status: {
    summary: "Show a project's execution path, governance mode, and next required action",
    usage: "axiom status --project <path> [--json]",
    build: (args) => buildStatus(args),
  },

  export: {
    summary: "Export an approved work item as an execution contract for an agent",
    usage: "axiom export --project <path> --work-item <D-###> [--grant commit,push] [--output <dir>] [--force]",
    build: (args) => buildExport(args),
  },

  setup: {
    summary: "Add, preview, or remove the Axiom-PMO block in a repository's AGENTS.md",
    usage: "axiom setup claude --project <path> [--dry-run] [--uninstall] [--force] [--file AGENTS.md|CLAUDE.md]",
    build: (args) => buildSetup(args),
  },

  verify: {
    summary: "Verify an execution result against its contract and observed git state",
    usage: "axiom verify --project <path> --result <path> [--contract <path>] [--json] [--preflight]",
    build: (args) => buildVerify(args),
  },

  run: {
    summary: "Run a command for real and seal a verifiable runner-exit-record",
    usage: "axiom run --project <path> --work-item <D-###> --name <test-name> --command <cmd> [--cwd <dir>]",
    build: (args) => buildRun(args),
  },
};

// --- execution --------------------------------------------------------------

function printUsage() {
  const lines = [
    "Axiom-PMO CLI -- runs the ported TypeScript engine in-process.",
    "",
    "Usage: node cli/axiom.mjs <command> [options]",
    "",
    "Commands:",
  ];
  const width = Math.max(...Object.keys(COMMANDS).map((name) => name.length));
  for (const [name, command] of Object.entries(COMMANDS)) {
    lines.push(`  ${name.padEnd(width)}  ${command.summary}`);
  }
  lines.push(
    "",
    "Examples:",
    "  node cli/axiom.mjs demo",
    "  node cli/axiom.mjs init                     interactive on a TTY: asks delivery path, then governance mode",
    "  node cli/axiom.mjs init --code P02-ABC --mode Standard --handoff --target demo",
    "  node cli/axiom.mjs status --project examples/HANDOFF-DEMO",
    "  node cli/axiom.mjs handoff --project examples/HANDOFF-DEMO --mode Standard",
    "  node cli/axiom.mjs validate --project examples/STANDARD-FEATURE --gate Release --fail-on-warning",
    "  node cli/axiom.mjs setup claude --project . --dry-run",
    "",
    "Exit codes: 0 pass, 1 fail, 2 blocking warning, 127 infrastructure failure.",
  );
  process.stdout.write(lines.join("\n") + "\n");
}

async function main() {
  const argv = process.argv.slice(2);

  if (argv.length === 0 || argv[0] === "--help" || argv[0] === "-h" || argv[0] === "help") {
    printUsage();
    return 0;
  }

  const commandName = argv[0];
  const command = COMMANDS[commandName];
  if (!command) {
    process.stderr.write(`Unknown command: ${commandName}\n\n`);
    printUsage();
    return EXIT_USAGE;
  }

  const plan = await command.build(argv.slice(1));
  if (plan.cancelled) {
    process.stdout.write("Cancelled.\n");
    return 0;
  }
  if (plan.usageError) {
    process.stderr.write(`${plan.usageError}\n`);
    if (command.usage) process.stderr.write(`\n  ${command.usage}\n`);
    return EXIT_USAGE;
  }

  const steps = plan.steps ?? [{ ts: plan.ts }];
  let firstFailure = 0;

  if (plan.json) {
    const envelope = { schema_version: "1.1" };
    for (const step of steps) {
      if (firstFailure !== 0 && !step.alwaysRun) break;
      const result = runTsStep(step);
      if (result.usageMessage) {
        process.stderr.write(`${result.usageMessage}\n`);
        return EXIT_USAGE;
      }
      if (result.error) process.stderr.write(`${result.error}\n`);
      try {
        envelope[step.key] = JSON.parse(result.stdout);
      } catch {
        // Surface the unparseable output rather than dropping it: a consumer
        // needs to see that a step produced something unexpected.
        envelope[step.key] = { parse_error: true, raw: result.stdout };
        if (firstFailure === 0) firstFailure = 1;
      }
      if (!step.ignoreExitCode && result.status !== 0 && firstFailure === 0) {
        firstFailure = result.status;
      }
    }
    process.stdout.write(JSON.stringify(envelope, null, 2) + "\n");
    return firstFailure;
  }

  for (const step of steps) {
    if (firstFailure !== 0 && !step.alwaysRun) break;
    if (step.label && steps.length > 1) {
      process.stdout.write(`\n--- ${step.label} ---\n`);
    }
    const result = runTsStep(step);
    if (result.usageMessage) {
      process.stderr.write(`${result.usageMessage}\n`);
      return EXIT_USAGE;
    }
    if (result.stdout) process.stdout.write(result.stdout);
    const code = result.status;
    if (!step.ignoreExitCode && code !== 0 && firstFailure === 0) {
      firstFailure = code;
    }
  }
  return firstFailure;
}

// process.exitCode, not process.exit().
//
// stdout is a pipe when this CLI is used the way a CI job uses it, and writes
// to a pipe are asynchronous in Node. Calling process.exit() tears the process
// down before the buffer drains, which silently truncated the JSON envelope at
// 8 KB -- the output looked fine in a terminal (a TTY flushes synchronously)
// and failed to parse under `| jq`. Setting exitCode lets Node exit naturally
// once stdout has flushed.
process.exitCode = await main();
