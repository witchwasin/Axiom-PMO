// Canonical artifact SHA-256 (F8 / CR-018), ported from
// scripts/lib/artifact-hash.ps1. Text files: strict UTF-8 decode, strip one BOM,
// CRLF/CR -> LF, re-encode no-BOM, hash those bytes. Binary: raw bytes.

import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { extname } from "node:path";

const CANONICAL_TEXT_HASH_EXTENSIONS = [
  ".md",
  ".markdown",
  ".json",
  ".puml",
  ".csv",
  ".txt",
  ".yaml",
  ".yml",
  ".html",
  ".htm",
];

export function testCanonicalTextFile(path: string): boolean {
  const extension = extname(path).toLowerCase();
  return CANONICAL_TEXT_HASH_EXTENSIONS.includes(extension);
}

export function getArtifactSha256(path: string): string {
  let bytes: Uint8Array = readFileSync(path);
  if (testCanonicalTextFile(path)) {
    let text: string | null = null;
    try {
      // Strict UTF-8: TextDecoder with fatal:true throws on invalid sequences.
      text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    } catch {
      text = null; // not valid UTF-8: fail safe to byte hashing
    }
    if (text !== null) {
      if (text.length > 0 && text.charCodeAt(0) === 0xfeff) {
        text = text.slice(1);
      }
      text = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
      bytes = new TextEncoder().encode(text);
    }
  }
  return createHash("sha256").update(bytes).digest("hex").toLowerCase();
}
