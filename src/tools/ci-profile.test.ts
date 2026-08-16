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
  assertProfile(["scripts/pmo-doctor.ps1"], "targeted", "doctor", "windows-ps51,windows-ps7");
  assertProfile(["pmo-config/policy.json"], "targeted", "config-mutation", "windows-ps51,windows-ps7");
  assertProfile(["templates/PROJECT.md"], "targeted", "config-mutation", "windows-ps51,windows-ps7");
  assertProfile(["tests/helpers/line-ending-tests.ps1"], "targeted", "validation-fixtures", "windows-ps51,windows-ps7");
  assertProfile(["examples/STANDARD-FEATURE/PROJECT.md"], "targeted", "validation-fixtures", "linux");
  assertProfile([".claude/skills/pmo-governance/SKILL.md"], "targeted", "plugin-drift", "linux");
  assertProfile(["VERSION"], "targeted", "", "linux");
});

test("full: high-risk and runtime surfaces", () => {
  const full = "windows-ps51,windows-ps7,linux,macos";
  assertProfile([".github/workflows/pmo-checks.yml"], "full", "", full);
  assertProfile(["action.yml"], "full", "", full);
  assertProfile(["scripts/lib/golden-normalizer.ps1"], "full", "", full);
  assertProfile(["scripts/run-all-checks.ps1"], "full", "", full);
  assertProfile(["scripts/validate-project.ps1"], "full", "", full);
  assertProfile(["scripts/ci-profile.ps1"], "full", "", full);
  assertProfile(["scripts/run-ci-suite.ps1"], "full", "", full);
  // Node interpreter surfaces (CR-010)
  assertProfile(["src/core/context.ts"], "full", "", full);
  assertProfile(["dist/core/context.js"], "full", "", full);
  assertProfile(["package.json"], "full", "", full);
});

test("union: highest risk wins", () => {
  assertProfile(["docs/a.md", "scripts/lib/x.ps1"], "full", "", "windows-ps51,windows-ps7,linux,macos");
  const mixed = resolveCiProfile(["cli/axiom.mjs", "scripts/pmo-doctor.ps1"]);
  assert.equal(mixed.profile, "targeted");
  assert.equal(mixed.suite, "cli,doctor");
  assert.equal(mixed.hosts, "linux,windows-ps51,windows-ps7");
});

test("run-ci-suite whitelist maps known and rejects unknown", () => {
  const known = resolveCiSuite("/tmp/repo", "line-ending");
  assert.ok("cmd" in known, "known suite resolves");
  const unknown = resolveCiSuite("/tmp/repo", "bogus");
  assert.ok("error" in unknown, "unknown suite rejected");
  const all = resolveCiSuite("/tmp/repo", "all");
  assert.ok("cmd" in all);
});
