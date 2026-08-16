// `run-all-checks`, ported from scripts/run-all-checks.ps1. Orchestrates the
// full framework check suite. Spawns test helpers via pwsh (not yet ported);
// each check name + exit code is reported, with a GITHUB_ACTIONS annotation on
// failure.
import { spawnSync } from "node:child_process";
import { join, resolve } from "node:path";
import { resolvePwsh } from "../probe/pwsh-resolver.js";
export function runAllChecks(repoRoot, testChildScript) {
    const repo = resolve(repoRoot);
    const pwsh = resolvePwsh();
    const out = [];
    const executedChecks = [];
    function invokeCheck(name, args) {
        out.push(`[CHECK] ${name}`);
        const r = spawnSync(pwsh, ["-NoProfile", "-ExecutionPolicy", "Bypass", ...args], { encoding: "utf8" });
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
    out.push(`Running Axiom-PMO framework checks for ${repo}`);
    out.push("");
    const psFile = (rel, args = []) => ["-File", join(repo, rel), ...args];
    if (testChildScript) {
        // The reference resolves the child script to an absolute path (Resolve-Path)
        // before running it; psFile would join() it onto the repo root again and
        // double-prefix an already-absolute path.
        const code = invokeCheck("fault-injection", ["-File", resolve(testChildScript)]);
        if (code !== 0)
            return { output: out.join("\n") + "\n", exitCode: code };
    }
    const checks = [
        ["pmo-doctor", psFile("scripts/pmo-doctor.ps1", ["-RepoPath", repo])],
        ["doctor-markdown", psFile("tests/helpers/doctor-markdown-tests.ps1", ["-RepoPath", repo])],
        ["validation-fixtures", psFile("scripts/run-validation-tests.ps1", ["-RepoPath", repo, "-VerifyGolden"])],
        ["example-golden", psFile("tests/golden/capture-examples.ps1", ["-RepoPath", repo, "-Verify"])],
        ["config-mutation", psFile("tests/helpers/config-mutation-tests.ps1", ["-RepoPath", repo])],
        ["m2-m3-contracts", psFile("tests/helpers/m2-m3-tests.ps1", ["-RepoPath", repo])],
        ["m4-m6-contracts", psFile("tests/helpers/m4-m6-tests.ps1", ["-RepoPath", repo])],
        ["status-lifecycle", psFile("tests/helpers/status-tests.ps1", ["-RepoPath", repo])],
        ["diagnostics-contract", psFile("tests/helpers/diagnostics-contract-tests.ps1", ["-RepoPath", repo])],
        ["line-endings", psFile("tests/helpers/line-ending-tests.ps1", ["-RepoPath", repo])],
        ["handoff-assessment", psFile("tests/helpers/handoff-assessment-tests.ps1", ["-RepoPath", repo])],
        ["visual-proof", psFile("tests/helpers/visual-proof-tests.ps1", ["-RepoPath", repo])],
        ["scope-diff", psFile("tests/helpers/scope-diff-tests.ps1", ["-RepoPath", repo])],
        ["release-evidence", psFile("tests/helpers/release-evidence-tests.ps1", ["-RepoPath", repo])],
        ["execution-contract", psFile("tests/helpers/execution-contract-tests.ps1", ["-RepoPath", repo])],
        ["ci-profile", psFile("tests/helpers/ci-profile-tests.ps1", ["-RepoPath", repo])],
        ["adversarial-review", psFile("tests/helpers/adversarial-review-tests.ps1", ["-RepoPath", repo])],
        ["learning-registry", psFile("tests/helpers/learning-registry-tests.ps1", ["-RepoPath", repo])],
        ["demo-smoke", psFile("tests/helpers/demo-smoke-tests.ps1", ["-RepoPath", repo])],
        ["plugin-package", psFile("tests/helpers/plugin-package-tests.ps1", ["-RepoPath", repo])],
        ["plugin-skills-drift", psFile("scripts/build-plugin-package.ps1", ["-Check"])],
        ["setup-integration", psFile("tests/helpers/setup-integration-tests.ps1", ["-RepoPath", repo])],
        ["hook-advisory", psFile("tests/helpers/hook-advisory-tests.ps1", ["-RepoPath", repo])],
        ["clean-room", psFile("tests/helpers/clean-room-tests.ps1", ["-RepoPath", repo])],
        ["plugin-install", psFile("tests/helpers/plugin-install-spike-tests.ps1", ["-RepoPath", repo])],
        ["lite-example", psFile("scripts/validate-project.ps1", ["-ProjectPath", join(repo, "examples/LITE-BUGFIX"), "-Mode", "Lite", "-Gate", "Scope", "-FailOnWarning"])],
        ["standard-example", psFile("scripts/validate-project.ps1", ["-ProjectPath", join(repo, "examples/STANDARD-FEATURE"), "-Mode", "Standard", "-Gate", "Release", "-FailOnWarning"])],
        ["strict-example", psFile("scripts/validate-project.ps1", ["-ProjectPath", join(repo, "examples/STRICT-HIGH-RISK"), "-Mode", "Strict", "-Gate", "Release", "-FailOnWarning"])],
        ["optional-tracks-example", psFile("scripts/validate-project.ps1", ["-ProjectPath", join(repo, "examples/OPTIONAL-TRACKS"), "-Mode", "Standard", "-Gate", "Design", "-FailOnWarning"])],
        ["e2e-lite", psFile("tests/e2e/lite.ps1", ["-RepoPath", repo])],
        ["e2e-standard", psFile("tests/e2e/standard.ps1", ["-RepoPath", repo])],
        ["e2e-strict", psFile("tests/e2e/strict.ps1", ["-RepoPath", repo])],
        ["e2e-handoff", psFile("tests/e2e/handoff.ps1", ["-RepoPath", repo])],
    ];
    for (const [name, args] of checks) {
        const code = invokeCheck(name, args);
        if (code !== 0)
            return { output: out.join("\n") + "\n", exitCode: code };
    }
    // Node checks (CLI + github-action)
    const nodeProbe = spawnSync("node", ["--version"], { encoding: "utf8" });
    if (nodeProbe.status === 0) {
        const cliCode = invokeCheck("cli", [join(repo, "tests/helpers/cli-tests.mjs")]);
        if (cliCode !== 0)
            return { output: out.join("\n") + "\n", exitCode: cliCode };
        const gaCode = invokeCheck("github-action", [join(repo, "tests/helpers/github-action-tests.mjs")]);
        if (gaCode !== 0)
            return { output: out.join("\n") + "\n", exitCode: gaCode };
    }
    else {
        out.push("");
        out.push("SKIPPED: cli and github-action tests -- Node.js was not found on PATH.");
    }
    for (const required of ["m4-m6-contracts", "status-lifecycle"]) {
        if (!executedChecks.includes(required)) {
            out.push(`Required check was not executed: ${required}`);
            return { output: out.join("\n") + "\n", exitCode: 1 };
        }
    }
    out.push("");
    out.push("All Axiom-PMO framework checks completed.");
    return { output: out.join("\n") + "\n", exitCode: 0 };
}
