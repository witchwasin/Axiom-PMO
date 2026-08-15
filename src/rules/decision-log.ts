// Decision-log helpers shared by approval, change-control, and handoff
// validators. Ported from approval-validator.ps1 Get-DecisionIds and
// handoff-validator.ps1 Get-DecisionDecider.

import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { getTableRowsAfterHeading } from "../markdown/table-parser.js";

export function getDecisionIds(project: string): string[] {
  const path = join(project, "decision-log.md");
  if (!existsSync(path)) return [];
  const text = readFileSync(path, "utf8");
  const ids = text.match(/DEC-\d{3}/g) ?? [];
  return [...new Set(ids)].sort();
}

export function getDecisionDecider(project: string, decisionId: string): string | null {
  const path = join(project, "decision-log.md");
  if (!existsSync(path)) return null;

  const raw = readFileSync(path, "utf8");
  let rows = getTableRowsAfterHeading(raw, "^#\\s+Decision Log");
  if (rows.length === 0) {
    rows = getTableRowsAfterHeading(raw, "^##?\\s+");
  }
  for (const row of rows) {
    if (String(row["ID"] ?? "").trim() !== decisionId) continue;
    for (const column of ["Decided By", "Owner", "Approved By", "Decider"]) {
      const value = row[column];
      if (value && value.trim() !== "") return value.trim();
    }
    return "";
  }
  return null;
}
