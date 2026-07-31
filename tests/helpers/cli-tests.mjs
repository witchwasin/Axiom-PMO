#!/usr/bin/env node
// Tests for cli/axiom.mjs.
//
// The CLI's entire job is to forward faithfully, so that is what is tested:
// exit codes survive, arguments reach the script, PowerShell absence is
// reported rather than swallowed, and no validation logic has crept into the
// JavaScript.
//
//   node tests/helpers/cli-tests.mjs

import { spawnSync } from "node:child_process";
import { readFileSync, existsSync, mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const CLI = join(REPO_ROOT, "cli/axiom.mjs");

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

function runCli(args, env = {}) {
  const result = spawnSync(process.execPath, [CLI, ...args], {
    cwd: REPO_ROOT,
    encoding: "utf8",
    env: { ...process.env, ...env },
  });
  return {
    status: result.status,
    stdout: result.stdout ?? "",
    stderr: result.stderr ?? "",
  };
}

// Is a PowerShell host reachable? Several assertions only mean something when
// one is; the rest run everywhere.
function hasPowerShell() {
  if (process.env.AXIOM_PWSH) return true;
  for (const candidate of ["pwsh", "powershell", "powershell.exe"]) {
    const probe = spawnSync(candidate, ["-NoProfile", "-Command", "$true"], { stdio: "ignore" });
    if (!probe.error && probe.status === 0) return true;
  }
  return false;
}

const POWERSHELL_AVAILABLE = hasPowerShell();

console.log(`Axiom-PMO CLI Tests: ${REPO_ROOT}`);
console.log(`PowerShell available: ${POWERSHELL_AVAILABLE}`);
console.log("");

// --- Behaviour that does not need PowerShell --------------------------------

{
  const help = runCli(["--help"]);
  assert("--help exits 0", help.status === 0, `exit=${help.status}`);
  assert("--help lists every command",
    ["demo", "check", "doctor", "validate", "handoff", "init"].every((c) => help.stdout.includes(c)));
  assert("no arguments prints usage", runCli([]).status === 0);
}

{
  const unknown = runCli(["definitely-not-a-command"]);
  assert("unknown command exits 64", unknown.status === 64, `exit=${unknown.status}`);
  assert("unknown command explains itself on stderr", unknown.stderr.includes("Unknown command"));
}

{
  const noProject = runCli(["handoff"]);
  assert("handoff without --project exits 64", noProject.status === 64, `exit=${noProject.status}`);
  assert("handoff without --project shows its usage line", noProject.stderr.includes("--project"));

  const badProject = runCli(["validate", "--project", "does/not/exist"]);
  assert("validate with a missing project exits 64", badProject.status === 64, `exit=${badProject.status}`);
  assert("validate names the missing directory", badProject.stderr.includes("does/not/exist"));
}

{
  // Reported, not swallowed. A CLI that silently skipped validation when
  // PowerShell was absent would be worse than one that refuses to run.
  //
  // The unreachable-host case is exercised through AXIOM_PWSH because it is
  // the only technique that works on every platform. Emptying PATH hides
  // PowerShell on POSIX but NOT on Windows: CreateProcess searches the system
  // directory regardless of PATH, so powershell.exe is still found and the
  // assertion would be testing the harness rather than the CLI.
  const badOverride = runCli(["doctor"], { AXIOM_PWSH: "/nonexistent/pwsh" });
  assert("an unreachable PowerShell exits 127", badOverride.status === 127, `exit=${badOverride.status}`);
  assert("an unreachable PowerShell names what was wrong", badOverride.stderr.includes("/nonexistent/pwsh"));
  assert("an unreachable PowerShell names the remediation",
    badOverride.stderr.includes("aka.ms") || badOverride.stderr.includes("install"));
  assert("an unreachable PowerShell mentions the AXIOM_PWSH escape hatch",
    badOverride.stderr.includes("AXIOM_PWSH"));

  if (process.platform === "win32") {
    console.log("[SKIP] empty-PATH host discovery -- CreateProcess finds powershell.exe in the system directory whatever PATH says");
  } else {
    const noHost = runCli(["doctor"], { PATH: "/nonexistent-path-for-test", AXIOM_PWSH: "" });
    assert("no PowerShell on PATH exits 127", noHost.status === 127, `exit=${noHost.status}`);
    assert("no PowerShell on PATH names the remediation",
      noHost.stderr.includes("aka.ms") || noHost.stderr.includes("install"));
  }
}

{
  // The load-bearing constraint of this whole file.
  const source = readFileSync(CLI, "utf8");
  const forbidden = [
    ["validation-rules.json", "reads the rule catalog"],
    ["PROJECT.md", "parses project artifacts"],
    ["HANDOFF-REVIEW", "parses the semantic review"],
    ["evidence_status", "knows about evidence semantics"],
  ];
  for (const [needle, why] of forbidden) {
    assert(`CLI does not reimplement validation (${why})`, !source.includes(needle),
      `found "${needle}" in cli/axiom.mjs`);
  }
  assert("CLI resolves the repo root from its own location, not the cwd",
    source.includes("import.meta.url"));
}

{
  // Path handling is where a "works on my machine" CLI usually breaks. Assert
  // the pieces that differ across platforms rather than claiming the whole
  // thing is verified on Windows from a macOS run.
  const source = readFileSync(CLI, "utf8");
  assert("CLI builds paths with node:path rather than string concatenation",
    source.includes('from "node:path"') && !source.includes('REPO_ROOT + "/'));
  assert("CLI spawns without a shell, so paths with spaces survive",
    source.includes("shell: false"));
  assert("CLI probes powershell.exe as well as pwsh",
    source.includes("powershell.exe"));
}

// --- Behaviour that needs PowerShell ----------------------------------------

if (!POWERSHELL_AVAILABLE) {
  console.log("");
  console.log("SKIPPED: exit-code propagation tests require a PowerShell host.");
  console.log("         Install pwsh or set AXIOM_PWSH to run them.");
} else {
  const cases = [
    { name: "a passing project propagates 0", args: ["validate", "--project", "examples/STANDARD-FEATURE", "--gate", "Release", "--fail-on-warning"], expected: 0 },
    { name: "a failing project propagates 1", args: ["validate", "--project", "tests/fixtures/invalid-no-source-ref", "--gate", "Release"], expected: 1 },
    { name: "a blocking warning propagates 2", args: ["validate", "--project", "tests/fixtures/invalid-source-snapshot-no-sync", "--gate", "Scope", "--fail-on-warning"], expected: 2 },
    { name: "a passing handoff propagates 0", args: ["handoff", "--project", "examples/HANDOFF-DEMO", "--mode", "Standard"], expected: 0 },
    { name: "a failing handoff propagates 1", args: ["handoff", "--project", "demo/broken-project", "--mode", "Standard"], expected: 1 },
  ];
  for (const testCase of cases) {
    const result = runCli(testCase.args);
    assert(testCase.name, result.status === testCase.expected,
      `exit=${result.status} expected=${testCase.expected}`);
  }

  {
    const jsonRun = runCli(["validate", "--project", "examples/STANDARD-FEATURE", "--gate", "Release", "--json"]);
    let parsed = null;
    try { parsed = JSON.parse(jsonRun.stdout); } catch { parsed = null; }
    assert("--json produces parseable diagnostics", parsed !== null);
    assert("--json output carries the diagnostics schema version", parsed?.schema_version === "1.1",
      `got ${parsed?.schema_version}`);
  }

  {
    // The assessment must still run when the gate failed -- that is how a team
    // learns *which* stage is blocked rather than just that something is.
    const broken = runCli(["handoff", "--project", "demo/broken-project", "--mode", "Standard"]);
    assert("handoff runs the assessment even when the gate fails",
      broken.stdout.includes("Readiness assessment"));
    assert("handoff still reports the gate's failure as its exit code", broken.status === 1,
      `exit=${broken.status}`);
  }

  {
    // handoff runs two JSON-producing steps. Streaming both with labels between
    // them advertises --json and delivers something no parser accepts, so the
    // two are merged into one envelope.
    const jsonRun = runCli(["handoff", "--project", "examples/HANDOFF-DEMO", "--mode", "Standard", "--json"]);
    let parsed = null;
    try { parsed = JSON.parse(jsonRun.stdout); } catch { parsed = null; }
    assert("handoff --json emits exactly one parseable document", parsed !== null,
      `stdout began: ${JSON.stringify(jsonRun.stdout.slice(0, 60))}`);
    assert("handoff --json envelope carries both steps",
      parsed !== null && parsed.gate !== undefined && parsed.assessment !== undefined);
    assert("handoff --json envelope is versioned", parsed?.schema_version === "1.1");
    assert("handoff --json keeps the gate's diagnostics intact",
      Array.isArray(parsed?.gate?.results) && parsed.gate.results.length > 0);
    assert("handoff --json keeps the assessment's stage verdicts intact",
      parsed?.assessment?.verdicts?.["Ready to Demo"] === false,
      `got ${JSON.stringify(parsed?.assessment?.verdicts?.["Ready to Demo"])}`);
    assert("handoff --json prints no labels into the JSON stream",
      !jsonRun.stdout.includes("--- "));

    const brokenJson = runCli(["handoff", "--project", "demo/broken-project", "--mode", "Standard", "--json"]);
    let brokenParsed = null;
    try { brokenParsed = JSON.parse(brokenJson.stdout); } catch { brokenParsed = null; }
    assert("handoff --json stays parseable when the gate fails", brokenParsed !== null);
    assert("handoff --json still propagates the failing exit code", brokenJson.status === 1,
      `exit=${brokenJson.status}`);
  }

  {
    // `axiom setup claude` is the only CLI verb that writes to a file outside
    // this repository, so its argument forwarding is tested end to end rather
    // than by inspection. Reading `.value` off takeFlag (which returns
    // `.present`) forwarded none of these switches while still looking like it
    // worked -- setup installed via the default path, and --uninstall reported
    // "already up to date" instead of removing anything.
    const sandbox = mkdtempSync(join(tmpdir(), "axiom-cli-setup-"));
    try {
      const project = join(sandbox, "repo");
      mkdirSync(project, { recursive: true });
      const original = "# Their Project\n\nTheir own rules.\n";
      const agents = join(project, "AGENTS.md");
      writeFileSync(agents, original);

      const dry = runCli(["setup", "claude", "--project", project, "--dry-run"]);
      assert("setup --dry-run exits cleanly", dry.status === 0, `exit=${dry.status}`);
      assert("setup --dry-run reaches the script as a dry run",
        /Dry run/i.test(dry.stdout), dry.stdout.slice(0, 300));
      assert("setup --dry-run writes nothing", readFileSync(agents, "utf8") === original);

      const install = runCli(["setup", "claude", "--project", project]);
      assert("setup adds the block", install.status === 0 && /AXIOM-PMO:BEGIN/.test(readFileSync(agents, "utf8")),
        install.stdout.slice(0, 300));

      const again = runCli(["setup", "claude", "--project", project]);
      assert("setup is idempotent through the CLI", /already up to date/i.test(again.stdout),
        again.stdout.slice(0, 300));

      const remove = runCli(["setup", "claude", "--project", project, "--uninstall"]);
      assert("setup --uninstall actually removes", remove.status === 0 && /Removed/i.test(remove.stdout),
        remove.stdout.slice(0, 300));
      assert("…and restores the file byte-for-byte", readFileSync(agents, "utf8") === original,
        JSON.stringify(readFileSync(agents, "utf8")));

      const bad = runCli(["setup", "fnord", "--project", project]);
      assert("an unknown setup target is refused", bad.status !== 0 && /unknown setup target/i.test(bad.stdout + bad.stderr),
        `exit=${bad.status}`);
    } finally {
      rmSync(sandbox, { recursive: true, force: true });
    }
  }

  {
    const relative = runCli(["validate", "--project", "examples/LITE-BUGFIX", "--mode", "Lite", "--gate", "Scope"]);
    assert("a repo-relative --project path resolves", relative.status === 0, `exit=${relative.status}`);

    const absolute = runCli(["validate", "--project", join(REPO_ROOT, "examples/LITE-BUGFIX"), "--mode", "Lite", "--gate", "Scope"]);
    assert("an absolute --project path resolves", absolute.status === 0, `exit=${absolute.status}`);
  }
}

console.log("");
console.log(`Summary: PASS=${pass} FAIL=${fail}`);
process.exit(fail > 0 ? 1 : 0);
