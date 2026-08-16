// `run-ci-suite`, ported from scripts/run-ci-suite.ps1. Closed whitelist that
// maps a named suite to one script; an unknown suite is an error, never a no-op.

const SUITE_MAP: Record<string, { kind: "ps" | "node"; target: string; args: string[] }> = {
  doctor: { kind: "ps", target: "scripts/pmo-doctor.ps1", args: [] },
  hygiene: { kind: "ps", target: "scripts/check-public-hygiene.ps1", args: [] },
  golden: { kind: "ps", target: "tests/golden/capture-examples.ps1", args: ["-Verify"] },
  "validation-fixtures": { kind: "ps", target: "scripts/run-validation-tests.ps1", args: ["-VerifyGolden"] },
  "config-mutation": { kind: "ps", target: "tests/helpers/config-mutation-tests.ps1", args: [] },
  "line-ending": { kind: "ps", target: "tests/helpers/line-ending-tests.ps1", args: [] },
  "plugin-drift": { kind: "ps", target: "scripts/build-plugin-package.ps1", args: ["-Check"] },
  cli: { kind: "node", target: "tests/helpers/cli-tests.mjs", args: [] },
  "github-action": { kind: "node", target: "tests/helpers/github-action-tests.mjs", args: [] },
  all: { kind: "ps", target: "scripts/run-all-checks.ps1", args: [] },
};

export function resolveCiSuite(repo: string, suite: string): { cmd: string; args: string[] } | { error: string } {
  if (!(suite in SUITE_MAP)) {
    return { error: `[FAIL] CI-SUITE-001 Unknown suite '${suite}'. Expected one of: ${Object.keys(SUITE_MAP).sort().join(", ")}.` };
  }
  const entry = SUITE_MAP[suite]!;
  if (entry.kind === "node") {
    return { cmd: "node", args: [entry.target] };
  }
  return { cmd: "pwsh", args: ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", entry.target, "-RepoPath", repo, ...entry.args] };
}
