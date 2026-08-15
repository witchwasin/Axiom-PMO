// Effective mode resolution, ported from scripts/lib/mode-resolver.ps1.
// CLI -Mode may upgrade but never silently downgrade a project's enforcement.

import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { getTableRowsAfterHeading, type TableRow } from "../markdown/table-parser.js";
import { addResult } from "./result-writer.js";
import type { ResultAccumulator, ValidationRules } from "./context.js";
import type { Mode } from "./types.js";

const MODE_RANK: Record<Mode, number> = { Lite: 1, Standard: 2, Strict: 3 };

export function getProjectDefaultMode(projectRoot: string): string | null {
  const path = join(projectRoot, "PROJECT.md");
  if (!existsSync(path)) return null;
  const text = readFileSync(path, "utf8");
  const m = /^\s*>?\s*Default mode:\s*(.+?)\s*$/m.exec(text);
  return m ? m[1]!.trim() : null;
}

export interface DeliveryModeSignals {
  highestMode: Mode | null;
  hasStrictTrigger: boolean;
  strictTriggerItem: string | null;
}

export function getDeliveryModeSignals(projectRoot: string): DeliveryModeSignals {
  const result: DeliveryModeSignals = { highestMode: null, hasStrictTrigger: false, strictTriggerItem: null };
  const path = join(projectRoot, "DELIVERY.md");
  if (!existsSync(path)) return result;
  const text = readFileSync(path, "utf8");
  const rows = getTableRowsAfterHeading(text, "^##\\s+Work Items");
  let highest = 0;
  for (const row of rows) {
    const mode = row["Mode"];
    if (mode && MODE_RANK[mode as Mode] !== undefined && MODE_RANK[mode as Mode]! > highest) {
      highest = MODE_RANK[mode as Mode]!;
    }
    const strict = row["Strict Trigger"];
    if (strict && strict !== "none" && !result.hasStrictTrigger) {
      result.hasStrictTrigger = true;
      result.strictTriggerItem = row["ID"] ?? null;
    }
  }
  if (highest > 0) {
    result.highestMode = (Object.entries(MODE_RANK).find(([, r]) => r === highest)?.[0] as Mode) ?? null;
  }
  return result;
}

export function resolveEffectiveMode(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  project: string,
  requestedMode: Mode,
  gate: string,
): Mode {
  const projectDefaultModeRaw = getProjectDefaultMode(project);
  if (projectDefaultModeRaw && MODE_RANK[projectDefaultModeRaw as Mode] === undefined) {
    addResult(acc, catalog, "WARN", `PROJECT.md Default mode '${projectDefaultModeRaw}' is not a recognized mode (Lite/Standard/Strict)`, { ruleId: "MODE-002" });
  }
  const deliverySignals = getDeliveryModeSignals(project);
  let effectiveMode = requestedMode;
  const effectiveReasons: string[] = [];
  if (projectDefaultModeRaw && MODE_RANK[projectDefaultModeRaw as Mode] !== undefined && MODE_RANK[projectDefaultModeRaw as Mode]! > MODE_RANK[effectiveMode]!) {
    effectiveMode = projectDefaultModeRaw as Mode;
    effectiveReasons.push(`PROJECT.md Default mode is ${projectDefaultModeRaw}`);
  }
  if (deliverySignals.highestMode && MODE_RANK[deliverySignals.highestMode]! > MODE_RANK[effectiveMode]!) {
    effectiveMode = deliverySignals.highestMode;
    effectiveReasons.push(`highest work item mode is ${deliverySignals.highestMode}`);
  }
  if (deliverySignals.hasStrictTrigger && MODE_RANK["Strict"]! > MODE_RANK[effectiveMode]!) {
    effectiveMode = "Strict";
    effectiveReasons.push(`work item ${deliverySignals.strictTriggerItem} has a strict trigger`);
  }

  if (MODE_RANK[effectiveMode]! > MODE_RANK[requestedMode]!) {
    const modeLevel = gate === "Release" ? "FAIL" : "WARN";
    addResult(acc, catalog, modeLevel, `Requested mode ${requestedMode} cannot be used; effective mode is ${effectiveMode} (${effectiveReasons.join("; ")})`, { ruleId: "MODE-001" });
    if (deliverySignals.hasStrictTrigger && effectiveMode === "Strict") {
      addResult(acc, catalog, "INFO", `Strict escalation triggered by work item ${deliverySignals.strictTriggerItem}`, { ruleId: "MODE-003" });
    }
  } else {
    addResult(acc, catalog, "PASS", `Effective mode (${effectiveMode}) matches requested mode (${requestedMode})`, { ruleId: "MODE-001" });
  }

  return effectiveMode;
}

// Re-export for callers that need the rank or row type.
export type { TableRow };
