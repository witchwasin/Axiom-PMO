// Loads pmo-config/*.json runtime policy, BOM/no-BOM tolerant (CR-019). Throws
// when a required config file is missing — runtime config is the single source
// of truth, there is no silent fallback to hardcoded values. Ported from
// scripts/lib/config-loader.ps1 Import-PmoConfig.

import { readFileSync } from "node:fs";
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
