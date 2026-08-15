// Owner policy helpers (generic-owner detection + severity map), ported from
// handoff-validator.ps1 Test-GenericOwner / Get-HandoffPolicySeverity. Shared
// by APPROVAL-005 and HANDOFF-003.
import { testPlaceholderValue } from "../config/config-loader.js";
export function testGenericOwner(value, ownerPolicy) {
    const trimmed = String(value).trim();
    if (trimmed.length === 0)
        return true;
    const tokens = ownerPolicy["generic_tokens"] ?? [];
    for (const token of tokens) {
        if (trimmed.toLowerCase() === String(token).trim().toLowerCase())
            return true;
    }
    return testPlaceholderValue(trimmed);
}
export function getHandoffPolicySeverity(severityMap, mode, defaultValue = "fail") {
    let value = defaultValue;
    if (severityMap) {
        const prop = severityMap[mode];
        if (prop !== undefined)
            value = String(prop);
    }
    if (value === "warn")
        return "WARN";
    return "FAIL";
}
