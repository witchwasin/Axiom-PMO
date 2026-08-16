// Smoke test for the three-minute demo, ported from tests/helpers/demo-smoke-tests.ps1.
// Runs the demo (via pwsh reference) and asserts its own claims against output.

import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { resolvePwsh } from "../probe/pwsh-resolver.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

test("demo runs and its claims match output", () => {
  const pwsh = resolvePwsh();
  const started = Date.now();
  const r = spawnSync(pwsh, ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", resolve(REPO_ROOT, "scripts/demo.ps1"), "-RepoPath", REPO_ROOT, "-NoPause", "-Plain"], { encoding: "utf8" });
  const elapsed = (Date.now() - started) / 1000;
  const text = (r.stdout ?? "") + (r.stderr ?? "");

  assert.equal(r.status, 0, "demo exits 0");
  assert.ok(elapsed < 180, "demo completes well inside three minutes");

  for (const rule of ["HANDOFF-003", "HANDOFF-004", "HANDOFF-007", "HANDOFF-011", "HANDOFF-012"]) {
    assert.ok(new RegExp(`\\[FAIL\\]\\s+${rule}`).test(text), `demo shows a real ${rule} failure`);
  }

  assert.ok(/Summary: PASS=\d+ WARN=0 \(0 blocking\) FAIL=0/.test(text), "demo shows fixed project passing");
  assert.ok(/Ready to Start Development/.test(text), "demo shows stage verdicts");
  assert.ok(/READY TO BUILD, NOT READY TO DEMO/.test(text), "demo shows build-ready but demo-blocked");
  assert.ok(/not an approval/.test(text), "demo states score is not approval");
  assert.ok(!/\.gif|\.cast\b/.test(text), "demo does not claim a recording asset");
  assert.ok(/^\s+fix:/m.test(text), "demo includes a fix line");
  assert.ok(/^\s+docs:\s+https:\/\//m.test(text), "demo includes a docs link");
  assert.ok(/^\s+where:/m.test(text), "demo locates findings by artifact");
});
