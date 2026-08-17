// `run-ci-suite`, ported from scripts/run-ci-suite.ps1. Closed whitelist that
// maps a named suite to one executable invocation; an unknown suite is an
// error, never a no-op. Phase 9: the PowerShell reference is deleted, so every
// suite resolves to the same Node executor (dist/tools/run-ci-suite-cli.js)
// that actually runs it -- the resolver exists so a caller (tool-probe, the
// targeted-profile dispatch) can resolve a suite to a command without
// executing it, the same contract the reference's suiteMap provided.
//
// "golden" (tests/golden/capture-examples.ps1) is intentionally NOT a valid
// suite, matching run-ci-suite-cli.ts: its coverage is carried forward by
// differential-probe.ts and validation-fixtures.ts.
const SUITES = ["all", "cli", "config-mutation", "doctor", "github-action", "hygiene", "line-ending", "plugin-drift", "validation-fixtures"];

export function resolveCiSuite(repo: string, suite: string): { cmd: string; args: string[] } | { error: string } {
  if (!SUITES.includes(suite)) {
    return { error: `[FAIL] CI-SUITE-001 Unknown suite '${suite}'. Expected one of: ${[...SUITES].sort().join(", ")}.` };
  }
  return { cmd: "node", args: ["dist/tools/run-ci-suite-cli.js", "-Suite", suite, "-RepoPath", repo] };
}
