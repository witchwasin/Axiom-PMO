// Result accumulator (Add-Result equivalent) + exit-code computation + Text/JSON
// output, ported from scripts/lib/result-writer.ps1. Order of calls is the order
// of output; field order in each JSON row mirrors the PowerShell `[ordered]`
// object exactly.
import { DIAGNOSTICS_SCHEMA_VERSION } from "./types.js";
function nullIfBlank(value) {
    if (value === null || value === undefined || value.trim() === "")
        return null;
    return value;
}
function resolveRuleCatalogEntry(catalog, ruleId) {
    if (!catalog?.rules)
        return null;
    const entry = catalog.rules[ruleId];
    if (!entry)
        return null;
    return entry;
}
function resolveSuggestion(catalog, ruleId) {
    const entry = resolveRuleCatalogEntry(catalog, ruleId);
    if (!entry?.suggestion || entry.suggestion.trim() === "")
        return null;
    return entry.suggestion;
}
function resolveDocumentationUrl(catalog, ruleId) {
    const entry = resolveRuleCatalogEntry(catalog, ruleId);
    if (!entry?.documentation)
        return null;
    const base = catalog?.documentation_base_url;
    if (!base || base.trim() === "")
        return entry.documentation;
    return base.replace(/\/+$/, "") + "/" + entry.documentation.replace(/^\/+/, "");
}
/**
 * Appends one diagnostic row and updates the accumulator counters. `catalog` is
 * optional here because some callers (pmo-doctor) hold a different rule registry;
 * a null catalog means no suggestion/documentation_url lookup.
 */
export function addResult(acc, catalog, level, message, opts = {}) {
    const ruleId = opts.ruleId ?? "GENERAL-001";
    const blocking = opts.blocking ?? true;
    let suggestion = opts.suggestion ?? null;
    if ((suggestion === null || suggestion.trim() === "") && (level === "WARN" || level === "FAIL")) {
        suggestion = resolveSuggestion(catalog, ruleId);
    }
    let documentationUrl = opts.documentationUrl ?? null;
    if ((documentationUrl === null || documentationUrl.trim() === "") &&
        (level === "WARN" || level === "FAIL")) {
        documentationUrl = resolveDocumentationUrl(catalog, ruleId);
    }
    const row = {
        schema_version: DIAGNOSTICS_SCHEMA_VERSION,
        level,
        rule_id: ruleId,
        message,
        blocking,
        artifact: nullIfBlank(opts.artifact ?? null),
        item_id: nullIfBlank(opts.itemId ?? null),
        field: nullIfBlank(opts.field ?? null),
        suggestion: nullIfBlank(suggestion),
        documentation_url: nullIfBlank(documentationUrl),
    };
    acc.messages.push(row);
    if (level === "PASS")
        acc.pass++;
    else if (level === "WARN") {
        acc.warn++;
        if (blocking)
            acc.warnBlocking++;
    }
    else if (level === "FAIL")
        acc.fail++;
}
export function getExitCode(fail, warnBlocking, failOnWarning) {
    if (fail > 0)
        return 1;
    if (failOnWarning && warnBlocking > 0)
        return 2;
    return 0;
}
export function writeValidationOutput(format, envelope, project, requestedMode, effectiveMode, gate) {
    if (format === "Json") {
        return JSON.stringify(envelope, null, 2);
    }
    const lines = [];
    lines.push(`Axiom-PMO Project Validation: ${project}`);
    lines.push(`Requested Mode: ${requestedMode}`);
    lines.push(`Detected Project Mode: ${effectiveMode}`);
    lines.push(`Effective Mode: ${effectiveMode}`);
    lines.push(`Gate=${gate}`);
    lines.push("");
    for (const row of envelope.results) {
        const tag = row.level === "WARN" && !row.blocking ? " (non-blocking)" : "";
        lines.push(`[${row.level}] ${row.rule_id} ${row.message}${tag}`);
        if (row.level === "WARN" || row.level === "FAIL") {
            const location = [];
            if (row.artifact)
                location.push(row.artifact);
            if (row.item_id)
                location.push(row.item_id);
            if (row.field)
                location.push(`field: ${row.field}`);
            if (location.length > 0)
                lines.push(`        where: ${location.join(" / ")}`);
            if (row.suggestion)
                lines.push(`        fix:   ${row.suggestion}`);
            if (row.documentation_url)
                lines.push(`        docs:  ${row.documentation_url}`);
        }
    }
    const s = envelope.summary;
    lines.push("");
    lines.push(`Summary: PASS=${s.pass} WARN=${s.warn} (${s.warn_blocking} blocking) FAIL=${s.fail}`);
    return lines.join("\n");
}
