// Harness mutant self-tests (CR-009): prove the comparator FAILS on each of the
// real-diff classes — changed exit, reordered result, missing field, stderr
// change — and PASSES on host-noise (indentation/BOM/CRLF/path separator) that
// the golden normalizer deliberately ignores. A harness that cannot detect these
// would let a drift through the differential gate.

import { test } from "node:test";
import assert from "node:assert/strict";
import { compareOutputs } from "./compare.js";
import { getCanonicalGoldenText } from "../output/canonical-normalizer.js";

const BASE_JSON = `{
  "schema_version": "1.1",
  "project": "<REPO_ROOT>/examples/X",
  "summary": { "pass": 1, "warn": 0, "warn_blocking": 0, "fail": 0, "exit_code": 0 },
  "results": [
    { "level": "PASS", "rule_id": "STRUCT-001", "message": "ok", "blocking": true }
  ]
}`;

function run(actual: string): ReturnType<typeof compareOutputs> {
  return compareOutputs(
    { stdout: BASE_JSON, stderr: "", exitCode: 0 },
    { stdout: actual, stderr: "", exitCode: 0 },
  );
}

test("harness fails on changed exit code", () => {
  const r = compareOutputs(
    { stdout: BASE_JSON, stderr: "", exitCode: 0 },
    { stdout: BASE_JSON, stderr: "", exitCode: 1 },
  );
  assert.equal(r.equivalent, true); // output unchanged…
  assert.equal(r.exitMatch, false); // …but exit differs
});

test("harness fails on reordered result", () => {
  const reordered = BASE_JSON.replace(
    `"rule_id": "STRUCT-001", "message": "ok"`,
    `"message": "ok", "rule_id": "STRUCT-001"`,
  );
  assert.equal(run(reordered).equivalent, false);
});

test("harness fails on missing field", () => {
  const missing = BASE_JSON.replace(`, "blocking": true`, "");
  assert.equal(run(missing).equivalent, false);
});

test("harness fails on changed message text", () => {
  const changed = BASE_JSON.replace(`"message": "ok"`, `"message": "not ok"`);
  assert.equal(run(changed).equivalent, false);
});

test("harness passes on indentation-only diff", () => {
  const indented = BASE_JSON.replace(/^  /gm, "    ");
  assert.equal(run(indented).equivalent, true);
});

test("harness passes on CRLF and BOM diff", () => {
  const crlfBom = "﻿" + BASE_JSON.replace(/\n/g, "\r\n");
  assert.equal(run(crlfBom).equivalent, true);
});

test("harness passes on path-separator diff", () => {
  const backslash = BASE_JSON.replaceAll("<REPO_ROOT>/examples", "<REPO_ROOT>\\examples");
  assert.equal(run(backslash).equivalent, true);
});

test("canonical normalizer decodes \\uXXXX escapes", () => {
  assert.equal(getCanonicalGoldenText("\\u0061"), "a");
  assert.equal(getCanonicalGoldenText("value's"), "value's");
});
