// `run-ci-suite`, ported from scripts/run-ci-suite.ps1. Closed whitelist that
// maps a named suite to one script; an unknown suite is an error, never a no-op.
// repoPath mirrors scripts/run-ci-suite.ps1's suiteMap: the reference only
// passes -RepoPath where its own table declares it. plugin-drift notably does
// NOT declare it -- scripts/build-plugin-package.ps1 takes only -Check, and a
// stray -RepoPath would make the resolved command line fail when executed.
const SUITE_MAP = {
    doctor: { kind: "ps", target: "scripts/pmo-doctor.ps1", args: [], repoPath: true },
    hygiene: { kind: "ps", target: "scripts/check-public-hygiene.ps1", args: [], repoPath: true },
    golden: { kind: "ps", target: "tests/golden/capture-examples.ps1", args: ["-Verify"], repoPath: true },
    "validation-fixtures": { kind: "ps", target: "scripts/run-validation-tests.ps1", args: ["-VerifyGolden"], repoPath: true },
    "config-mutation": { kind: "ps", target: "tests/helpers/config-mutation-tests.ps1", args: [], repoPath: true },
    "line-ending": { kind: "ps", target: "tests/helpers/line-ending-tests.ps1", args: [], repoPath: true },
    "plugin-drift": { kind: "ps", target: "scripts/build-plugin-package.ps1", args: ["-Check"], repoPath: false },
    cli: { kind: "node", target: "tests/helpers/cli-tests.mjs", args: [], repoPath: false },
    "github-action": { kind: "node", target: "tests/helpers/github-action-tests.mjs", args: [], repoPath: false },
    all: { kind: "ps", target: "scripts/run-all-checks.ps1", args: [], repoPath: true },
};
export function resolveCiSuite(repo, suite) {
    if (!(suite in SUITE_MAP)) {
        return { error: `[FAIL] CI-SUITE-001 Unknown suite '${suite}'. Expected one of: ${Object.keys(SUITE_MAP).sort().join(", ")}.` };
    }
    const entry = SUITE_MAP[suite];
    if (entry.kind === "node") {
        return { cmd: "node", args: [entry.target] };
    }
    const args = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", entry.target];
    if (entry.repoPath)
        args.push("-RepoPath", repo);
    args.push(...entry.args);
    return { cmd: "pwsh", args };
}
