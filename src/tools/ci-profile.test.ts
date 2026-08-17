// Node-native regression test for ci-profile + run-ci-suite, ported from
// tests/helpers/ci-profile-tests.ps1. Exercises the classifier directly (no
// subprocess) plus the run-ci-suite whitelist.

import { test } from "node:test";
import assert from "node:assert/strict";
import { resolveCiProfile } from "./ci-profile.js";
import { resolveCiSuite } from "./run-ci-suite.js";

function assertProfile(paths: string[], profile: string, suite: string, hosts: string): void {
  const r = resolveCiProfile(paths);
  assert.equal(r.profile, profile, `profile for ${paths.join(",")}`);
  assert.equal(r.suite, suite, `suite for ${paths.join(",")}`);
  assert.equal(r.hosts, hosts, `hosts for ${paths.join(",")}`);
}

test("fast: docs and top-level markdown", () => {
  assertProfile(["docs/architecture/foo.md"], "fast", "", "linux");
  assertProfile(["README.md"], "fast", "", "linux");
  assertProfile([], "fast", "", "linux");
});

test("targeted: known code areas", () => {
  assertProfile(["cli/axiom.mjs"], "targeted", "cli", "linux");
  assertProfile(["tests/helpers/cli-tests.mjs"], "targeted", "cli", "linux");
  assertProfile(["hooks/scope-advisory.sh"], "targeted", "plugin-drift", "linux");
  assertProfile(["pmo-config/policy.json"], "targeted", "config-mutation", "windows-ps51,windows-ps7");
  assertProfile(["templates/PROJECT.md"], "targeted", "config-mutation", "windows-ps51,windows-ps7");
  assertProfile(["tests/fixtures/invalid-broken-link/PROJECT.md"], "targeted", "validation-fixtures", "windows-ps51,windows-ps7");
  assertProfile(["examples/STANDARD-FEATURE/PROJECT.md"], "targeted", "validation-fixtures", "linux");
  assertProfile([".claude/skills/pmo-governance/SKILL.md"], "targeted", "plugin-drift", "linux");
  assertProfile(["VERSION"], "targeted", "", "linux");
});

test("full: high-risk and runtime surfaces", () => {
  const full = "windows-ps51,windows-ps7,linux,macos";
  assertProfile([".github/workflows/pmo-checks.yml"], "full", "", full);
  assertProfile(["action.yml"], "full", "", full);
  // Phase 9: the PowerShell reference is deleted; the ports live under src/
  // and dist/ and classify as full through the interpreter branch below.
  assertProfile(["src/output/canonical-normalizer.ts"], "full", "", full);
  assertProfile(["src/tools/run-all-checks.ts"], "full", "", full);
  assertProfile(["src/exec/execution-contract-validator.ts"], "full", "", full);
  assertProfile(["src/tools/ci-profile.ts"], "full", "", full);
  assertProfile(["src/tools/run-ci-suite.ts"], "full", "", full);
  // Node interpreter surfaces (CR-010)
  assertProfile(["src/core/context.ts"], "full", "", full);
  assertProfile(["dist/core/context.js"], "full", "", full);
  assertProfile(["package.json"], "full", "", full);
});

test("union: highest risk wins", () => {
  assertProfile(["docs/a.md", "src/output/canonical-normalizer.ts"], "full", "", "windows-ps51,windows-ps7,linux,macos");
  const mixed = resolveCiProfile(["cli/axiom.mjs", "src/doctor/pmo-doctor.ts"]);
  assert.equal(mixed.profile, "full");
  assert.equal(mixed.suite, "");
  assert.equal(mixed.hosts, "windows-ps51,windows-ps7,linux,macos");
});

test("run-ci-suite whitelist maps known and rejects unknown", () => {
  const known = resolveCiSuite("/tmp/repo", "line-ending");
  assert.ok("cmd" in known, "known suite resolves");
  const unknown = resolveCiSuite("/tmp/repo", "bogus");
  assert.ok("error" in unknown, "unknown suite rejected");
  const all = resolveCiSuite("/tmp/repo", "all");
  assert.ok("cmd" in all);
});
