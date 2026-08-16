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

// Replicates PowerShell's `Format-Table -AutoSize` byte-for-byte (modulo the
// ANSI colour pwsh paints the header with): text columns left-aligned, numeric
// columns right-aligned, each column sized to max(header, longest cell), cells
// joined by a single space, and the trailing blank line the formatting system
// appends after a table block. The estimated-context column is a [double] in
// the reference, so cells print with three decimals (2420.000), never as the
// integer 2420 -- a port that printed integers would show different numbers.
export function formatContextTable(rows: ContextRow[]): string {
  const headers = ["File", "Lines", "Words", "EstimatedContextSize"];
  const cells = rows.map((r) => [r.file, String(r.lines), String(r.words), r.estimatedContextSize.toFixed(3)] as const);
  if (cells.length === 0) {
    return "" + "\n" + "" + "\n" + "Estimated Context Size is an approximation, not a tokenizer measurement." + "\n";
  }
  const widths = headers.map((h, i) => Math.max(h.length, ...cells.map((c) => c[i]!.length)));
  const lines: string[] = [];
  // Format-Table opens the table block with a blank line when output is
  // redirected; the reference's own capture shows it, so the port keeps it.
  lines.push("");
  lines.push(headers.map((h, i) => h.padEnd(widths[i]!)).join(" "));
  // Format-Table's separator row underlines each HEADER (not the column
  // width), left-aligned and padded to the column width.
  lines.push(widths.map((w, i) => "-".repeat(headers[i]!.length).padEnd(w)).join(" "));
  for (const c of cells) {
    lines.push([c[0]!.padEnd(widths[0]!), c[1]!.padStart(widths[1]!), c[2]!.padStart(widths[2]!), c[3]!.padStart(widths[3]!)].join(" "));
  }
  lines.push(""); // Format-Table's trailing blank after the table block
  lines.push(""); // the reference's Write-Host ""
  lines.push("Estimated Context Size is an approximation, not a tokenizer measurement.");
  return lines.join("\n") + "\n";
}
