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
import { existsSync, statSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
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
    summary: "Create a new project from the templates",
    usage: "axiom init --code <PROJECT-CODE> [--mode Standard] [--handoff] [--target demo] [--horizon-days 14]",
    build: (args) => buildInit(args),
  },

  export: {
    summary: "Export an approved work item as an execution contract for an agent",
    usage: "axiom export --project <path> --work-item <D-###> [--grant commit,push] [--output <dir>] [--force]",
    build: (args) => buildExport(args),
  },

  verify: {
    summary: "Verify an execution result against its contract and observed git state",
    usage: "axiom verify --project <path> --result <path> [--contract <path>] [--json]",
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

function buildInit(args) {
  let rest = args;
  const code = takeOption(rest, "code");
  rest = code.rest;
  const mode = takeOption(rest, "mode");
  rest = mode.rest;
  const output = takeOption(rest, "output");
  rest = output.rest;
  const target = takeOption(rest, "target");
  rest = target.rest;
  const horizon = takeOption(rest, "horizon-days");
  rest = horizon.rest;
  const handoff = takeFlag(rest, "handoff");
  rest = handoff.rest;

  if (!code.value) {
    return { usageError: "init requires --code <PROJECT-CODE>" };
  }

  const scriptArgs = ["-ProjectCode", code.value, "-Mode", mode.value ?? "Standard"];
  if (output.value) scriptArgs.push("-OutputRoot", output.value);
  if (handoff.present) scriptArgs.push("-IncludeHandoff");
  if (target.value) scriptArgs.push("-Target", target.value);
  if (horizon.value) scriptArgs.push("-HorizonDays", horizon.value);
  return { script: "scripts/new-project.ps1", scriptArgs: [...scriptArgs, ...rest] };
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
    "  node cli/axiom.mjs handoff --project examples/HANDOFF-DEMO --mode Standard",
    "  node cli/axiom.mjs validate --project examples/STANDARD-FEATURE --gate Release --fail-on-warning",
    "  node cli/axiom.mjs init --code P02-ABC --mode Standard --handoff --target demo",
    "",
    "Unrecognised options are forwarded to the underlying PowerShell script.",
    "Exit codes come from the validator: 0 pass, 1 fail, 2 blocking warning.",
  );
  process.stdout.write(lines.join("\n") + "\n");
}

function main() {
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

  const plan = command.build(argv.slice(1));
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
process.exitCode = main();
