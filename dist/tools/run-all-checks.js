// `run-all-checks`, ported from scripts/run-all-checks.ps1. Orchestrates the
// full framework check suite entirely in-process (Phase 9: no PowerShell
// reference left to spawn). The ~20 checks that used to each spawn one
// tests/helpers/*.ps1 file collapse into a single "unit-tests" step running
// the existing Node test suite once, since every one of those files already
// has a direct *.test.ts port (Phase 5 completion) -- confirmed file by file,
// not assumed, before dropping the per-file check names. pmo-doctor and the
// four example-project validations call their ported functions directly, as
// does plugin-skills-drift. validation-fixtures (scripts/run-validation-tests.ps1)
// keeps its own dedicated step: the "implementation-neutral corpus runner"
// master-plan.md's Phase 9 exit criteria says to retain, and meaningfully
// larger and differently-shaped than differential-probe.ts's much smaller
// live-comparison case list (it verifies canonical JSON output byte-for-byte
// against the 156 committed golden masters, not just rule-level parity).
// example-golden (tests/golden/capture-examples.ps1) is dropped entirely per
// that same Phase 9 exit criteria -- its case coverage is carried forward by
// differential-probe.ts and validation-fixtures.ts. cli and github-action
// already spawned node, not pwsh (Phase 8 fix); unchanged here.
import { spawnSync } from "node:child_process";
import { readdirSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import { runPmoDoctor, formatDoctorText } from "../doctor/pmo-doctor.js";
import { runValidateEnvelope } from "../probe/validate-chain.js";
import { runValidationFixtures } from "./validation-fixtures.js";
import { buildPluginPackage } from "./build-plugin-package.js";
function findTestFiles(dir) {
    const out = [];
    for (const entry of readdirSync(dir)) {
        const full = join(dir, entry);
        if (statSync(full).isDirectory())
            out.push(...findTestFiles(full));
        else if (entry.endsWith(".test.js"))
            out.push(full);
    }
    return out;
}
export function runAllChecks(repoRoot, testChildScript) {
    const repo = resolve(repoRoot);
    const out = [];
    const executedChecks = [];
    // Spawns an actual child process (fault-injection, the unit-test run, cli,
    // github-action -- everything that still genuinely needs its own process).
    function invokeCheck(name, exe, args) {
        out.push(`[CHECK] ${name}`);
        const r = spawnSync(exe, args, { encoding: "utf8" });
        // Only re-emit a child's actual output. The reference streams the child's
        // stdout straight through, so a silent child contributes no line; pushing
        // an empty string here would add a blank line the reference does not have.
        if (r.stdout)
            out.push(r.stdout);
        const exitCode = r.status ?? 1;
        if (exitCode !== 0) {
            out.push("");
            out.push(`Check failed: ${name} exit ${exitCode}`);
            if (process.env.GITHUB_ACTIONS === "true")
                out.push(`::error title=Axiom-PMO check failed::${name} exited ${exitCode}`);
            return exitCode;
        }
        executedChecks.push(name);
        out.push(`[PASS] ${name}`);
        return 0;
    }
    // Records the result of an in-process check (no subprocess): pmo-doctor,
    // validation-fixtures, plugin-skills-drift, the example-project gates.
    function recordResult(name, text, exitCode) {
        out.push(`[CHECK] ${name}`);
        if (text)
            out.push(text.trimEnd());
        if (exitCode !== 0) {
            out.push("");
            out.push(`Check failed: ${name} exit ${exitCode}`);
            if (process.env.GITHUB_ACTIONS === "true")
                out.push(`::error title=Axiom-PMO check failed::${name} exited ${exitCode}`);
            return exitCode;
        }
        executedChecks.push(name);
        out.push(`[PASS] ${name}`);
        return 0;
    }
    out.push(`Running Axiom-PMO framework checks for ${repo}`);
    out.push("");
    if (testChildScript) {
        // The reference resolves the child script to an absolute path before
        // running it, so a repo-relative path (as tool-probe.ts and the CLI's
        // -TestChildScript flag both pass) still resolves correctly.
        const code = invokeCheck("fault-injection", process.execPath, [resolve(testChildScript)]);
        if (code !== 0)
            return { output: out.join("\n") + "\n", exitCode: code };
    }
    {
        const result = runPmoDoctor(repo);
        const code = recordResult("pmo-doctor", formatDoctorText(repo, result), result.fail > 0 ? 1 : 0);
        if (code !== 0)
            return { output: out.join("\n") + "\n", exitCode: code };
    }
    {
        const result = runValidationFixtures(repo, true);
        const code = recordResult("validation-fixtures", result.output, result.exitCode);
        if (code !== 0)
            return { output: out.join("\n") + "\n", exitCode: code };
    }
    {
        const files = findTestFiles(join(repo, "dist"));
        const code = invokeCheck("unit-tests", process.execPath, ["--test", ...files]);
        if (code !== 0)
            return { output: out.join("\n") + "\n", exitCode: code };
    }
    {
        const result = buildPluginPackage(repo, true);
        const code = recordResult("plugin-skills-drift", result.output, result.exitCode);
        if (code !== 0)
            return { output: out.join("\n") + "\n", exitCode: code };
    }
    const exampleChecks = [
        ["lite-example", "examples/LITE-BUGFIX", "Lite", "Scope"],
        ["standard-example", "examples/STANDARD-FEATURE", "Standard", "Release"],
        ["strict-example", "examples/STRICT-HIGH-RISK", "Strict", "Release"],
        ["optional-tracks-example", "examples/OPTIONAL-TRACKS", "Standard", "Design"],
    ];
    for (const [name, rel, mode, gate] of exampleChecks) {
        const result = runValidateEnvelope(repo, join(repo, rel), mode, gate, true, "Text");
        const code = recordResult(name, result.output, result.exitCode);
        if (code !== 0)
            return { output: out.join("\n") + "\n", exitCode: code };
    }
    // Node checks (CLI + github-action) -- run via node directly, matching the
    // reference's `& $node.Source ...` (run-all-checks.ps1 lines ~131-138), not
    // via pwsh (Phase 8 fix). Node.js is guaranteed present: this file only
    // ever runs under it, unlike the PS reference which could run without Node
    // on PATH.
    const cliCode = invokeCheck("cli", process.execPath, [join(repo, "tests/helpers/cli-tests.mjs")]);
    if (cliCode !== 0)
        return { output: out.join("\n") + "\n", exitCode: cliCode };
    const gaCode = invokeCheck("github-action", process.execPath, [join(repo, "tests/helpers/github-action-tests.mjs")]);
    if (gaCode !== 0)
        return { output: out.join("\n") + "\n", exitCode: gaCode };
    if (!executedChecks.includes("unit-tests")) {
        out.push("Required check was not executed: unit-tests");
        return { output: out.join("\n") + "\n", exitCode: 1 };
    }
    out.push("");
    out.push("All Axiom-PMO framework checks completed.");
    return { output: out.join("\n") + "\n", exitCode: 0 };
}
