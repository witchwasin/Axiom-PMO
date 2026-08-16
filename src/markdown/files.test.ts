// Ported from tests/helpers/doctor-markdown-tests.ps1.

import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { getMarkdownFiles, readMarkdownText, testMarkdownLocalLinkPath } from "./files.js";
import { runPmoDoctor, formatDoctorText } from "../doctor/pmo-doctor.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

test("markdown discovery, encoding, and local-link handling", () => {
  const workRoot = mkdtempSync(join(tmpdir(), "pmo-doctor-markdown-"));
  try {
    const nested = join(workRoot, "nested");
    mkdirSync(nested, { recursive: true });

    // Thai text via UTF-8, matching the PS test's code-point construction.
    const thaiText = String.fromCharCode(
      0x0e2b, 0x0e31, 0x0e27, 0x0e02, 0x0e49, 0x0e2d, 0x0e20, 0x0e32, 0x0e29, 0x0e32, 0x0e44, 0x0e17, 0x0e22,
    );
    const thaiMarkdown = join(nested, "thai.md");
    writeFileSync(thaiMarkdown, `${thaiText}\n\n[missing](missing.md)`, "utf8");

    // Payload deliberately resembles the byte sequence that made a real PPTX
    // look like a Markdown link to Windows PowerShell 5.1. Discovery must
    // ignore it solely because it is not a Markdown file.
    const binaryPath = join(workRoot, "deck.pptx");
    writeFileSync(binaryPath, Buffer.from("PK\0\0[slide](\x11bad:path)\0compressed", "latin1"));

    const markdownFiles = getMarkdownFiles(workRoot);
    assert.equal(markdownFiles.length, 1, "discovery returns only Markdown files");
    assert.equal(markdownFiles[0], thaiMarkdown);
    assert.equal(
      markdownFiles.filter((f) => f.toLowerCase().endsWith(".pptx")).length,
      0,
      "PPTX payload is excluded from Markdown discovery",
    );

    const markdownText = readMarkdownText(thaiMarkdown);
    assert.ok(markdownText.includes(thaiText), "UTF-8 Thai Markdown survives reading");

    const invalidTarget = "bad\x01path.md";
    const invalidResult = testMarkdownLocalLinkPath(nested, invalidTarget);
    assert.equal(invalidResult.validPath, false, "illegal local-link path is rejected without throwing");

    const missingResult = testMarkdownLocalLinkPath(nested, "missing.md");
    assert.equal(missingResult.validPath, true);
    assert.equal(missingResult.exists, false, "valid missing local-link path remains reportable");

    const spaceDirectory = join(nested, "space dir");
    mkdirSync(spaceDirectory, { recursive: true });
    const encodedResult = testMarkdownLocalLinkPath(nested, "space%20dir");
    assert.equal(encodedResult.validPath, true);
    assert.equal(encodedResult.exists, true, "percent-encoded Markdown path resolves on disk");
  } finally {
    rmSync(workRoot, { recursive: true, force: true });
  }
});

test("doctor reports an invalid Markdown link target without throwing", () => {
  const integrationMarkdown = join(REPO_ROOT, `doctor-invalid-link-${Date.now()}-${Math.random().toString(16).slice(2)}.md`);
  const invalidMarkdownTarget = "bad\x01path.md";
  try {
    writeFileSync(integrationMarkdown, `[invalid](${invalidMarkdownTarget})`, "utf8");

    const result = runPmoDoctor(REPO_ROOT);
    const text = formatDoctorText(REPO_ROOT, result);
    const integrationName = integrationMarkdown.split("/").pop()!;

    assert.equal(result.fail, 0, "doctor reports an invalid Markdown target without failing");
    assert.ok(
      text.includes(`${integrationName} line 1 -> invalid local link target`),
      "doctor reports the specific broken-link message",
    );
    assert.ok(!text.includes("Illegal characters in path"), "doctor emits no illegal-path exception");
  } finally {
    rmSync(integrationMarkdown, { force: true });
  }
});
