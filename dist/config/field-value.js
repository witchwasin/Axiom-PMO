// Field-value placeholder validation, ported from config-loader.ps1
// Test-FieldValue. Shared by workitem-validator and other callers that need
// mode-aware `not_required` handling.
import { testPlaceholderValue } from "./config-loader.js";
export function testFieldValue(fieldName, value, fieldMode, sentinelRules) {
    const trimmed = String(value).trim();
    if (trimmed === "not_required") {
        const rule = sentinelRules?.["not_required"];
        if (rule && rule.allowed_fields?.includes(fieldName) && rule.allowed_modes?.includes(fieldMode)) {
            return false;
        }
        return true;
    }
    return testPlaceholderValue(value);
}
