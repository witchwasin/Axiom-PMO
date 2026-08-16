// `measure-context`, ported from scripts/measure-context.ps1. Reports line/word/
// estimated-token counts for the framework's context files.

import { readFileSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";

export interface ContextRow {
  file: string;
  lines: number;
  words: number;
  estimatedContextSize: number;
}

export function measureContext(repoRoot: string, files: string[]): ContextRow[] {
  const rows: ContextRow[] = [];
  for (const relative of files) {
    const path = join(repoRoot, relative);
    if (!existsSync(path)) continue;
    const text = readFileSync(path, "utf8");
    const words = text.split(/\s+/).filter((w) => w.length > 0).length;
    rows.push({
      file: relative,
      lines: text.split(/\r?\n/).length,
      words,
      estimatedContextSize: Math.ceil(words * 1.35),
    });
  }
  return rows;
}

export function formatContextTable(rows: ContextRow[]): string {
  const lines: string[] = [];
  lines.push("File                 Lines  Words  EstimatedContextSize");
  lines.push("----                 -----  -----  --------------------");
  for (const r of rows) {
    lines.push(`${r.file.padEnd(20)} ${String(r.lines).padStart(6)} ${String(r.words).padStart(6)} ${String(r.estimatedContextSize).padStart(19)}`);
  }
  lines.push("");
  lines.push("Estimated Context Size is an approximation, not a tokenizer measurement.");
  return lines.join("\n") + "\n";
}
