#!/usr/bin/env node
// Axiom-PMO thin CLI.
//
// This file contains ZERO validation logic and must keep containing zero. The
// PowerShell scripts under scripts/ are the reference implementation; a second
// implementation in JavaScript would drift from them, and the first time the
// two disagreed nobody would know which one was right.
//
// All this does is:
//   1. find a PowerShell host
//   2. map a friendly verb to a script and its arguments
//   3. forward everything else through untouched
//   4. preserve stdout, stderr, and the exit code
//
// Exit codes are the validator's own (see docs/reference/diagnostics-contract.md):
//   0   pass
//   1   at least one FAIL
//   2   -FailOnWarning and at least one blocking WARN
//   127 no PowerShell host found (this file's own failure, not the validator's)

import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, statSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { createInterface } from "node:readline/promises";
import { fileURLToPath } from "node:url";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const EXIT_NO_POWERSHELL = 127;
const EXIT_USAGE = 64;

// Order matters: pwsh (PowerShell 7, the documented minimum for macOS and
// Linux) is preferred over Windows PowerShell 5.1. AXIOM_PWSH overrides both,
// for pinned CI images and unusual installs -- the same variable
// scripts/lib/pwsh-host.ps1 honours, so the CLI and the scripts agree.
//
// M3.5 host-selection contract: the PowerShell helper additionally prefers the
// *current* host, because re-entering the same pwsh/5.1 keeps JSON depth,
// encoding, and regex behaviour stable. That step has no analogue here -- this
// CLI is a Node process, not a PowerShell one, so there is no current host to
// re-enter. What must stay identical (and does) is: AXIOM_PWSH wins, the PATH
// fallback order (pwsh, powershell, powershell.exe) matches, and a missing
// host exits 127.
const HOST_CANDIDATES = ["pwsh", "powershell", "powershell.exe"];

function findPowerShell() {
  const override = process.env.AXIOM_PWSH;
  if (override) {
    // An override is a promise the user made. Check it rather than failing
    // later with an opaque ENOENT from spawn.
    if (isAbsolute(override) && !existsSync(override)) {
      // Same remediation as a missing host: the reader's problem is identical
      // ("nothing here can run PowerShell"), so the answer should be too.
      return {
        error: `AXIOM_PWSH points at a file that does not exist: ${override}\n\n${powerShellMissingMessage()}`,
      };
    }
    return { exe: override };
  }

  for (const candidate of HOST_CANDIDATES) {
    // `-NoProfile -Command $true` is the cheapest thing that proves the binary
    // exists and can execute a command. Checking PATH by hand would have to
    // reimplement PATHEXT resolution on Windows.
    const probe = spawnSync(candidate, ["-NoProfile", "-Command", "$true"], {
      stdio: "ignore",
      shell: false,
    });
    if (!probe.error && probe.status === 0) {
      return { exe: candidate };
    }
  }
  return { error: null };
}

function powerShellMissingMessage() {
  return [
    "PowerShell was not found on PATH.",
    "",
    "Axiom-PMO's validators are PowerShell scripts; this CLI only forwards to them.",
    "",
    "  macOS     brew install --cask powershell",
    "  Linux     https://learn.microsoft.com/powershell/scripting/install/install-ubuntu",
    "  Windows   PowerShell 5.1 ships with the OS; PowerShell 7: winget install Microsoft.PowerShell",
    "",
    "Or point AXIOM_PWSH at an existing PowerShell executable:",
    "",
    "  AXIOM_PWSH=/opt/microsoft/powershell/7/pwsh node cli/axiom.mjs check",
  ].join("\n");
}

// --- argument helpers -------------------------------------------------------

// Extract `--name value` / `--name=value`, leaving everything else in place so
// unrecognised flags reach the PowerShell script untouched.
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

function resolveProjectPath(value) {
  const candidate = isAbsolute(value) ? value : resolve(process.cwd(), value);
  if (existsSync(candidate) && statSync(candidate).isDirectory()) return candidate;

  // A project named relative to the repository root is the common case when
  // running from somewhere else in a monorepo.
  const fromRepo = join(REPO_ROOT, value);
  if (existsSync(fromRepo) && statSync(fromRepo).isDirectory()) return fromRepo;

  return null;
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

const COMMANDS = {
  demo: {
    summary: "Run the three-minute proof: a broken handoff, then a fixed one",
    build: (args) => ({ script: "scripts/demo.ps1", scriptArgs: ["-RepoPath", REPO_ROOT, ...args] }),
  },

  check: {
    summary: "Run every framework check (doctor, fixtures, mutation, e2e)",
    build: (args) => ({ script: "scripts/run-all-checks.ps1", scriptArgs: ["-RepoPath", REPO_ROOT, ...args] }),
  },

  doctor: {
    summary: "Check framework health: config, skills, rule catalog, permissions",
    build: (args) => ({ script: "scripts/pmo-doctor.ps1", scriptArgs: ["-RepoPath", REPO_ROOT, ...args] }),
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
      "axiom init [--code <PROJECT-CODE>] [--mode Standard] [--execution-path development_handoff] [--research-mode off] [--research-depth standard] [--research-provider none] [--ui-delivery not_applicable] [--handoff] [--target demo] [--horizon-days 14] [--no-interactive]",
    build: (args) => buildInit(args),
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

  const scriptArgs = ["-ProjectPath", projectPath, "-Mode", mode.value ?? "Standard", "-Gate", gate.value ?? "Draft"];
  if (json.present) scriptArgs.push("-Format", "Json");
  if (failOnWarning.present) scriptArgs.push("-FailOnWarning");
  return { script: "scripts/validate-project.ps1", scriptArgs: [...scriptArgs, ...rest] };
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
        script: "scripts/validate-project.ps1",
        scriptArgs: [
          "-ProjectPath", projectPath, "-Mode", resolvedMode, "-Gate", "Handoff",
          ...(json.present ? ["-Format", "Json"] : []),
          ...rest,
        ],
      },
      {
        key: "assessment",
        label: "Readiness assessment",
        script: "scripts/assess-handoff.ps1",
        scriptArgs: [
          "-ProjectPath", projectPath, "-Mode", resolvedMode,
          ...(json.present ? ["-Format", "Json"] : []),
        ],
        // The assessment reports on the gate's findings; it is not a second
        // verdict. The gate's exit code is the one that propagates.
        alwaysRun: true,
        ignoreExitCode: true,
      },
    ],
  };
}

// `export` and `verify` are the two halves of Milestone 5: hand an approved
// work item to an execution workflow, then check what came back. Both forward
// to PowerShell like every other verb -- no verification logic lives here, for
// the same reason stated at the top of this file.
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

  const scriptArgs = ["-ProjectPath", projectPath, "-WorkItemId", workItem.value];
  if (grant.value) scriptArgs.push("-Grant", grant.value);
  if (output.value) scriptArgs.push("-OutputPath", output.value);
  if (format.value) scriptArgs.push("-Format", format.value);
  if (force.present) scriptArgs.push("-Force");
  return { script: "scripts/export-execution-contract.ps1", scriptArgs: [...scriptArgs, ...rest] };
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

  const scriptArgs = ["-ProjectPath", projectPath];
  // takeFlag returns `.present`, not `.value`. Reading `.value` here silently
  // forwarded none of these switches: setup still installed (the default
  // path), so it looked like it worked, and --uninstall quietly reported
  // "already up to date" instead of removing anything.
  if (file.value) { scriptArgs.push("-File", file.value); }
  if (dryRun.present) { scriptArgs.push("-DryRun"); }
  if (uninstall.present) { scriptArgs.push("-Uninstall"); }
  if (force.present) { scriptArgs.push("-Force"); }

  return { script: "scripts/setup-claude-integration.ps1", scriptArgs: [...scriptArgs, ...rest] };
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

  const scriptArgs = ["-ProjectPath", projectPath, "-ResultPath", resultPath];
  if (contract.value) {
    const contractPath = isAbsolute(contract.value) ? contract.value : resolve(process.cwd(), contract.value);
    scriptArgs.push("-ContractPath", contractPath);
  }
  if (json.present) scriptArgs.push("-Format", "Json");
  if (failOnWarning.present) scriptArgs.push("-FailOnWarning");
  if (preflight.present) scriptArgs.push("-Preflight");
  return { script: "scripts/verify-execution-result.ps1", scriptArgs: [...scriptArgs, ...rest] };
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

  const scriptArgs = ["-ProjectPath", projectPath, "-WorkItemId", workItem.value, "-Name", name.value, "-Command", command.value];
  if (cwd.value) scriptArgs.push("-WorkingDirectory", cwd.value);
  return { script: "scripts/run-execution-command.ps1", scriptArgs: [...scriptArgs, ...rest] };
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

  const scriptArgs = ["-ProjectCode", resolvedCode, "-Mode", resolvedMode ?? "Standard"];
  if (resolvedExecutionPath) scriptArgs.push("-ExecutionPath", resolvedExecutionPath);
  if (resolvedResearchMode) scriptArgs.push("-ResearchMode", resolvedResearchMode);
  if (resolvedResearchDepth) scriptArgs.push("-ResearchDepth", resolvedResearchDepth);
  if (resolvedResearchProvider) scriptArgs.push("-ResearchProvider", resolvedResearchProvider);
  if (resolvedUiDelivery) scriptArgs.push("-UiDelivery", resolvedUiDelivery);
  if (strictTrigger) scriptArgs.push("-StrictTrigger", strictTrigger);
  if (modeReason) scriptArgs.push("-ModeReason", modeReason);
  if (modeApprovedBy) scriptArgs.push("-ModeApprovedBy", modeApprovedBy);
  if (output.value) scriptArgs.push("-OutputRoot", output.value);
  if (handoff.present) scriptArgs.push("-IncludeHandoff");
  if (target.value) scriptArgs.push("-Target", target.value);
  if (horizon.value) scriptArgs.push("-HorizonDays", horizon.value);
  return { script: "scripts/new-project.ps1", scriptArgs: [...scriptArgs, ...rest] };
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

  const scriptArgs = ["-ProjectPath", projectPath];
  if (json.present) scriptArgs.push("-Format", "Json");
  return { script: "scripts/pmo-status.ps1", scriptArgs: [...scriptArgs, ...rest] };
}

// --- execution --------------------------------------------------------------

// Capture a child's stdout instead of inheriting it. Used only in JSON mode,
// where the output has to be parsed and merged rather than streamed.
function captureScript(exe, script, scriptArgs) {
  const scriptPath = join(REPO_ROOT, script);
  if (!existsSync(scriptPath)) {
    return { status: 1, stdout: "", error: `Script not found: ${scriptPath}` };
  }
  const result = spawnSync(exe, ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", scriptPath, ...scriptArgs], {
    encoding: "utf8",
    shell: false,
  });
  if (result.error) {
    return { status: EXIT_NO_POWERSHELL, stdout: "", error: result.error.message };
  }
  // Child stderr is forwarded as-is: swallowing a PowerShell error to keep the
  // JSON clean would hide the reason the JSON is wrong.
  if (result.stderr) process.stderr.write(result.stderr);
  return { status: result.status === null ? 1 : result.status, stdout: result.stdout ?? "" };
}

function runScript(exe, script, scriptArgs) {
  const scriptPath = join(REPO_ROOT, script);
  if (!existsSync(scriptPath)) {
    process.stderr.write(`Script not found: ${scriptPath}\n`);
    return 1;
  }
  // stdio inherit: the child writes straight to the real terminal, so colour,
  // interleaving, and progress all behave as if the script were run directly.
  const result = spawnSync(exe, ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", scriptPath, ...scriptArgs], {
    stdio: "inherit",
    shell: false,
  });
  if (result.error) {
    process.stderr.write(`Failed to run PowerShell: ${result.error.message}\n`);
    return EXIT_NO_POWERSHELL;
  }
  // A child killed by a signal has no exit status. Report it as a failure
  // rather than silently succeeding on `status === null`.
  if (result.status === null) {
    process.stderr.write(`PowerShell terminated by signal ${result.signal}\n`);
    return 1;
  }
  return result.status;
}

function printUsage() {
  const lines = [
    "Axiom-PMO CLI -- a thin wrapper over the PowerShell validators.",
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
    "Unrecognised options are forwarded to the underlying PowerShell script.",
    "Exit codes come from the validator: 0 pass, 1 fail, 2 blocking warning.",
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

  const host = findPowerShell();
  if (!host.exe) {
    process.stderr.write((host.error ?? powerShellMissingMessage()) + "\n");
    return EXIT_NO_POWERSHELL;
  }

  const steps = plan.steps ?? [{ script: plan.script, scriptArgs: plan.scriptArgs }];
  let firstFailure = 0;

  if (plan.json) {
    const envelope = { schema_version: "1.1" };
    for (const step of steps) {
      if (firstFailure !== 0 && !step.alwaysRun) break;
      const result = captureScript(host.exe, step.script, step.scriptArgs);
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
    const code = runScript(host.exe, step.script, step.scriptArgs);
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
