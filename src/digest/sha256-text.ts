// SHA-256 of a UTF-8 string (hex, lowercase), ported from handoff-validator.ps1
// Get-Sha256Hex. Used for combined digests in design-provider and handoff.

import { createHash } from "node:crypto";

export function getSha256Hex(text: string): string {
  return createHash("sha256").update(text, "utf8").digest("hex").toLowerCase();
}
