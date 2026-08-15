// Generic markdown table parsing, ported from scripts/lib/markdown-table-parser.ps1.
// Finds the first pipe-table after a heading and turns it into row objects.

export type TableRow = Record<string, string>;

// PowerShell inline flags `(?i)` / `(?m)` / `(?s)` are not valid in JS RegExp;
// strip a leading `(?flags)` group and pass them as constructor flags.
function toRegExp(pattern: string): RegExp {
  const m = /^\(\?([a-z]+)\)/.exec(pattern);
  if (m) return new RegExp(pattern.slice(m[0].length), m[1]);
  return new RegExp(pattern);
}

export function getTableRowsAfterHeading(text: string, headingPattern: string): TableRow[] {
  const rx = toRegExp(headingPattern);
  const lines = text.split(/\r?\n/);
  let start = -1;
  for (let i = 0; i < lines.length; i++) {
    if (rx.test(lines[i]!)) {
      start = i;
      break;
    }
  }
  if (start < 0) return [];

  const tableLines: string[] = [];
  for (let i = start + 1; i < lines.length; i++) {
    const line = lines[i]!;
    if (line.trim().length === 0) {
      if (tableLines.length === 0) continue;
      break;
    }
    if (/^\s*#/.test(line)) break;
    if (/^\s*\|/.test(line)) {
      tableLines.push(line);
      continue;
    }
    if (tableLines.length > 0) break;
  }
  if (tableLines.length < 2) return [];

  const headerParts = tableLines[0]!.split("|");
  const headers: string[] = [];
  for (let i = 1; i < headerParts.length - 1; i++) {
    headers.push(headerParts[i]!.trim());
  }

  const rows: TableRow[] = [];
  for (const line of tableLines.slice(2)) {
    const cellParts = line.split("|");
    const cells: string[] = [];
    for (let i = 1; i < cellParts.length - 1; i++) {
      cells.push(cellParts[i]!.trim());
    }
    if (cells.length === 0) continue;
    const row: TableRow = {};
    for (let i = 0; i < headers.length; i++) {
      row[headers[i]!] = i < cells.length ? cells[i]! : "";
    }
    rows.push(row);
  }
  return rows;
}

export function getTableLinesAfterHeading(text: string, headingPattern: string): string[] {
  const rx = toRegExp(headingPattern);
  const lines = text.split(/\r?\n/);
  let start = -1;
  for (let i = 0; i < lines.length; i++) {
    if (rx.test(lines[i]!)) {
      start = i;
      break;
    }
  }
  if (start < 0) return [];

  const tableLines: string[] = [];
  for (let i = start + 1; i < lines.length; i++) {
    const line = lines[i]!;
    if (line.trim().length === 0) {
      if (tableLines.length === 0) continue;
      break;
    }
    if (/^\s*#/.test(line)) break;
    if (/^\s*\|/.test(line)) {
      tableLines.push(line);
      continue;
    }
    if (tableLines.length > 0) break;
  }
  return tableLines;
}

export function getIdsFromRows(rows: TableRow[]): string[] {
  return rows.filter((r) => r["ID"]).map((r) => r["ID"]!.trim());
}

export function splitReferenceValues(value: string): string[] {
  if (!value) return [];
  return value
    .split(",")
    .map((v) => v.trim())
    .filter((v) => v.length > 0);
}
