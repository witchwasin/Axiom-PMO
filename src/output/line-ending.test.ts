// Ported from tests/helpers/line-ending-tests.ps1.
//
// Two checks from the original file are retired, not ported: (1) scanning
// scripts/*.ps1 and tests/*.ps1 for multiline-regex patterns unsafe under
// CRLF, and (2) asserting .ps1 source stays ASCII-safe for Windows
// PowerShell 5.1. Both existed only because .ps1 files exist and 5.1 had to
// be supported; PowerShell 5.1 was dropped in Phase 0 and the .ps1 files
// themselves are retired in Phase 9. Once ported, the underlying regex
// -CRLF-safety property is what check 2 below verifies directly against the
// JS/TS regex engine, independent of which file the pattern eventually lives
// in (`tests/e2e/lib/fill-project.ps1` is not yet ported).

import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, cpSync, rmSync, readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { importPmoConfig } from "../config/config-loader.js";
import { getReviewInputDigest, getSourceSnapshotDigest } from "../rules/handoff-validator.js";
import { getCanonicalGoldenText } from "./canonical-normalizer.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

test("the template placeholder pattern matches identically under LF and CRLF", () => {
  // Same pattern as tests/e2e/lib/fill-project.ps1's `(?m)^<[^>\r\n]+>[ \t]*\r?$`.
  // JS `$` in multiline mode anchors immediately before `\n`, same as .NET, so
  // a `\r` immediately before it is not absorbed unless the pattern accounts
  // for it -- the same CRLF hazard applies to the Node port.
  const pattern = /^<[^>\r\n]+>[ \t]*\r?$/m;
  const lfSample = "### Section\n\nStatus: specified\n\n<Languages, frameworks, and versions.>\n";
  const crlfSample = lfSample.replace(/\n/g, "\r\n");

  const lfHits = [...lfSample.matchAll(new RegExp(pattern, "gm"))].length;
  const crlfHits = [...crlfSample.matchAll(new RegExp(pattern, "gm"))].length;

  assert.equal(lfHits, 1, `hits=${lfHits}`);
  assert.equal(crlfHits, lfHits, `lf=${lfHits} crlf=${crlfHits}`);
});

test("digests must not depend on line endings", () => {
  const workRoot = mkdtempSync(join(tmpdir(), "pmo-line-endings-"));
  try {
    const sample = join(workRoot, "HANDOFF-DEMO");
    cpSync(join(REPO_ROOT, "examples/HANDOFF-DEMO"), sample, { recursive: true });

    const cfg = importPmoConfig(REPO_ROOT);
    const projectMdPath = join(sample, "PROJECT.md");

    const lfDigest = getReviewInputDigest(sample, cfg.handoffPolicy as unknown as Record<string, unknown>);
    const lfSnapshot = getSourceSnapshotDigest(readFileSync(projectMdPath, "utf8"));

    const walk = (dir: string): string[] => {
      const out: string[] = [];
      for (const entry of readdirSync(dir)) {
        const full = join(dir, entry);
        const st = statSync(full);
        if (st.isDirectory()) out.push(...walk(full));
        else if (/\.(md|puml|json)$/i.test(entry)) out.push(full);
      }
      return out;
    };
    for (const file of walk(sample)) {
      const text = readFileSync(file, "utf8");
      const crlf = text.replace(/\r\n/g, "\n").replace(/\n/g, "\r\n");
      writeFileSync(file, crlf, "utf8");
    }

    const crlfDigest = getReviewInputDigest(sample, cfg.handoffPolicy as unknown as Record<string, unknown>);
    const crlfSnapshot = getSourceSnapshotDigest(readFileSync(projectMdPath, "utf8"));

    assert.equal(lfDigest, crlfDigest, `lf=${lfDigest?.slice(0, 12)} crlf=${crlfDigest?.slice(0, 12)}`);
    assert.equal(lfSnapshot, crlfSnapshot, `lf=${lfSnapshot?.slice(0, 12)} crlf=${crlfSnapshot?.slice(0, 12)}`);
  } finally {
    rmSync(workRoot, { recursive: true, force: true });
  }
});

test("golden comparison ignores the line ending", () => {
  const goldenSample = '{\n  "level": "FAIL",\n  "rule_id": "HANDOFF-004"\n}\nEXIT_CODE=1';
  const crlfSample = goldenSample.replace(/\n/g, "\r\n");
  assert.equal(getCanonicalGoldenText(goldenSample), getCanonicalGoldenText(crlfSample));
});
