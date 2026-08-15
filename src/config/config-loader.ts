// Loads pmo-config/*.json runtime policy, BOM/no-BOM tolerant (CR-019). Throws
// when a required config file is missing — runtime config is the single source
// of truth, there is no silent fallback to hardcoded values. Ported from
// scripts/lib/config-loader.ps1 Import-PmoConfig.

import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import type { Config, ValidationRules } from "../core/context.js";

// Strip exactly one leading U+FEFF when present (not all files have a BOM).
function parseJsonFile(path: string): unknown {
  let raw = readFileSync(path, "utf8");
  if (raw.charCodeAt(0) === 0xfeff) raw = raw.slice(1);
  return JSON.parse(raw);
}

export function importPmoConfig(repoRoot: string): Config {
  const policyPath = join(repoRoot, "pmo-config/policy.json");
  const artifactPolicyPath = join(repoRoot, "pmo-config/artifact-policy.json");
  const referenceTypesPath = join(repoRoot, "pmo-config/reference-types.json");
  const validationRulesPath = join(repoRoot, "pmo-config/validation-rules.json");
  const handoffPolicyPath = join(repoRoot, "pmo-config/handoff-policy.json");
  const orchestrationPolicyPath = join(repoRoot, "pmo-config/orchestration-policy.json");

  for (const p of [
    policyPath,
    artifactPolicyPath,
    referenceTypesPath,
    validationRulesPath,
    handoffPolicyPath,
    orchestrationPolicyPath,
  ]) {
    try {
      readFileSync(p);
    } catch {
      throw new Error(`Missing runtime config: ${p}`);
    }
  }

  const policy = parseJsonFile(policyPath) as Record<string, unknown>;
  const artifactPolicy = parseJsonFile(artifactPolicyPath) as Record<string, unknown>;
  const referenceTypesConfig = parseJsonFile(referenceTypesPath) as Record<string, unknown>;
  const validationRules = parseJsonFile(validationRulesPath) as unknown as ValidationRules;
  const handoffPolicy = parseJsonFile(handoffPolicyPath) as Record<string, unknown>;
  const orchestrationPolicy = parseJsonFile(orchestrationPolicyPath) as Record<string, unknown>;

  return {
    policy,
    policyEnums: (policy["enums"] as Record<string, unknown>) ?? {},
    sentinelRules: (policy["sentinel_rules"] as Record<string, unknown>) ?? {},
    artifactPolicy,
    referenceTypesConfig,
    validationRules,
    handoffPolicy,
    orchestrationPolicy,
  };
}

/** Placeholder detection, ported from Test-PlaceholderValue. */
export function testPlaceholderValue(value: string): boolean {
  const trimmed = value.trim();
  if (trimmed.length === 0) return true;
  if (trimmed === "not_required") return true;
  if (trimmed === "-") return true;
  return /<[^>]+>|TODO|TBD|YYYY-MM-DD|ISO-8601|pending|n\/a/.test(trimmed);
}

/** Date validation (yyyy-MM-dd), ported from Test-DateValue. */
export function testDateValue(value: string): boolean {
  const trimmed = value.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return false;
  const [y, m, d] = trimmed.split("-").map((n) => Number.parseInt(n, 10)) as [
    number,
    number,
    number,
  ];
  const dt = new Date(Date.UTC(y, m - 1, d));
  return (
    dt.getUTCFullYear() === y && dt.getUTCMonth() === m - 1 && dt.getUTCDate() === d
  );
}

/** Placeholder content detection, ported from Test-PlaceholderContent. */
export function testPlaceholderContent(content: string, extension: string): boolean {
  if (extension === ".html") {
    return /{{[^}]+}}|<PLACEHOLDER:[^>]+>|TODO|TBD/.test(content);
  }
  return /<[^>\r\n]+>|TODO|TBD/.test(content);
}

export interface OrchestrationDeclarations {
  researchMode: string | null;
  researchDepth: string | null;
  researchProvider: string | null;
  uiDelivery: string | null;
}

/** PROJECT.md optional workflow declarations, ported from Get-ProjectOrchestrationDeclarations. */
export function getProjectOrchestrationDeclarations(projectRoot: string): OrchestrationDeclarations {
  const path = join(projectRoot, "PROJECT.md");
  const text = existsSync(path) ? readFileSync(path, "utf8") : "";

  const values: Record<string, string | null> = {};
  for (const name of ["Research mode", "Research depth", "Research provider", "UI delivery"]) {
    const m = new RegExp(`^\\s*>?\\s*${name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}:\\s*(.+?)\\s*$`, "m").exec(text);
    values[name] = m ? m[1]!.trim() : null;
  }

  return {
    researchMode: values["Research mode"] ?? null,
    researchDepth: values["Research depth"] ?? null,
    researchProvider: values["Research provider"] ?? null,
    uiDelivery: values["UI delivery"] ?? null,
  };
}

/** Joined source-ref regex, ported from Get-PolicySourceRefRegex. */
export function getPolicySourceRefRegex(policyEnums: Record<string, unknown>): string {
  let patterns = (policyEnums["source_ref_patterns"] as string[]) ?? [];
  if (patterns.length === 0) {
    patterns = ["MOM-\\d{8}", "REQ-\\d{8}", "REQ-V\\d+", "TR-\\d{8}", "DEC-\\d{3}", "ISSUE-\\d+", "PR-\\d+", "source_ref"];
  }
  return patterns.join("|");
}

import { addResult } from "../core/result-writer.js";
import type { ResultAccumulator } from "../core/context.js";

/** Orchestration declaration validation (RESEARCH-001 / DPROV-001), ported from
 *  Test-OrchestrationDeclarations. */
export function testOrchestrationDeclarations(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  project: string,
  gate: string,
  orchestrationPolicy: Record<string, unknown>,
): OrchestrationDeclarations {
  const d = getProjectOrchestrationDeclarations(project);

  if (d.researchMode) {
    const research = (orchestrationPolicy["research"] as Record<string, unknown>) ?? {};
    const valid = (research["modes"] as string[]) ?? [];
    if (!valid.includes(d.researchMode)) {
      addResult(acc, catalog, "FAIL", "PROJECT.md Research mode is not recognized", { ruleId: "RESEARCH-001", artifact: "PROJECT.md", field: "Research mode" });
    } else {
      const badDepth = !d.researchDepth || !((research["depths"] as string[]) ?? []).includes(d.researchDepth);
      const badProvider = !d.researchProvider || !((research["providers"] as string[]) ?? []).includes(d.researchProvider);
      if (badDepth || badProvider) {
        addResult(acc, catalog, "FAIL", "PROJECT.md research declarations are incomplete or invalid", { ruleId: "RESEARCH-001", artifact: "PROJECT.md" });
      } else if (d.researchMode === "off" && d.researchProvider !== "none") {
        addResult(acc, catalog, "FAIL", "Research mode off requires Research provider none", { ruleId: "RESEARCH-001", artifact: "PROJECT.md", field: "Research provider" });
      } else if (d.researchMode !== "off" && d.researchProvider === "none") {
        addResult(acc, catalog, "FAIL", "Enabled research requires a provider declaration", { ruleId: "RESEARCH-001", artifact: "PROJECT.md", field: "Research provider" });
      }
    }
  }

  if (d.uiDelivery && !((((orchestrationPolicy["ui_delivery"] as Record<string, unknown>) ?? {})["values"] as string[]) ?? []).includes(d.uiDelivery)) {
    addResult(acc, catalog, "FAIL", "PROJECT.md UI delivery is not recognized", { ruleId: "DPROV-001", artifact: "PROJECT.md", field: "UI delivery" });
  }

  void gate;
  return d;
}
