// Execution path validation (PATH-001 / PATH-002), ported from
// scripts/lib/execution-path-validator.ps1.

import { readFileSync, existsSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { addResult } from "./result-writer.js";
import type { ResultAccumulator, ValidationRules } from "./context.js";
import type { TableRow } from "../markdown/table-parser.js";

export function getProjectExecutionPath(projectRoot: string): string | null {
  const path = join(projectRoot, "PROJECT.md");
  if (!existsSync(path)) return null;
  const text = readFileSync(path, "utf8");
  const m = /^\s*>?\s*Execution path:\s*(.+?)\s*$/m.exec(text);
  return m ? m[1]!.trim() : null;
}

export function testExecutionPath(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  project: string,
  policyEnums: Record<string, unknown>,
  workItems: TableRow[],
): void {
  const declaredRaw = getProjectExecutionPath(project);
  const validPaths = (policyEnums["execution_paths"] as string[]) ?? [];
  let effectivePath = "development_handoff";

  if (!declaredRaw) {
    addResult(acc, catalog, "INFO", "PROJECT.md does not declare an Execution path; defaulting to development_handoff", { ruleId: "PATH-001" });
  } else if (!validPaths.includes(declaredRaw)) {
    addResult(acc, catalog, "WARN", `PROJECT.md Execution path '${declaredRaw}' is not a recognized execution path (${validPaths.join(" / ")})`, { ruleId: "PATH-001" });
  } else {
    effectivePath = declaredRaw;
    addResult(acc, catalog, "PASS", `Execution path declared: ${effectivePath}`, { ruleId: "PATH-001" });
  }

  if (effectivePath !== "development_handoff") return;

  const executionRoot = join(project, ".execution");
  if (!existsSync(executionRoot)) return;

  const doneItemIds = new Set(
    workItems.filter((w) => w["Status"] === "Done").map((w) => w["ID"]),
  );

  for (const workItemId of readdirSync(executionRoot)) {
    const itemDir = join(executionRoot, workItemId);
    const contractPath = join(itemDir, "EXECUTION-CONTRACT.json");
    const resultPath = join(itemDir, "EXECUTION-RESULT.json");

    if (!existsSync(contractPath)) continue;
    if (existsSync(resultPath)) continue;
    if (doneItemIds.has(workItemId)) continue;

    addResult(acc, catalog, "WARN", `This project declares Development Handoff, but an active, unresolved execution package exists for ${workItemId}. Confirm the Execution path declaration is current.`, { ruleId: "PATH-002", itemId: workItemId });
  }
}
