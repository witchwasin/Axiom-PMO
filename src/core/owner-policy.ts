// Owner policy helpers (generic-owner detection + severity map), ported from
// handoff-validator.ps1 Test-GenericOwner / Get-HandoffPolicySeverity. Shared
// by APPROVAL-005 and HANDOFF-003.

import { testPlaceholderValue } from "../config/config-loader.js";

export function testGenericOwner(value: string, ownerPolicy: Record<string, unknown>): boolean {
  const trimmed = String(value).trim();
  if (trimmed.length === 0) return true;
  const tokens = (ownerPolicy["generic_tokens"] as string[]) ?? [];
  for (const token of tokens) {
    if (trimmed.toLowerCase() === String(token).trim().toLowerCase()) return true;
  }
  return testPlaceholderValue(trimmed);
}

export function getHandoffPolicySeverity(
  severityMap: Record<string, unknown> | null | undefined,
  mode: string,
  defaultValue = "fail",
): "WARN" | "FAIL" {
  let value = defaultValue;
  if (severityMap) {
    const prop = severityMap[mode];
    if (prop !== undefined) value = String(prop);
  }
  if (value === "warn") return "WARN";
  return "FAIL";
}
