// Host-independent normalization for golden-master comparison, ported from
// scripts/lib/golden-normalizer.ps1. Must match its normalization exactly, or
// the differential harness will report false diffs on one platform.
export function getCanonicalGoldenText(text) {
    if (text === null || text === undefined)
        return "";
    let normalized = text;
    // 1. Strip a UTF-8 BOM.
    normalized = normalized.replace(/^﻿/, "");
    // 2. Normalize CRLF/CR to LF.
    normalized = normalized.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
    // 3. Decode \uXXXX escapes to the characters they denote. The negative
    //    lookbehind stops the second backslash of an escaped `\\` pair from being
    //    read as the start of an escape.
    normalized = normalized.replace(/(?<!\\)\\u([0-9a-fA-F]{4})/g, (_m, hex) => String.fromCharCode(parseInt(hex, 16)));
    // 4. Fold a JSON-escaped backslash pair (\\, how a Windows path separator
    //    appears inside a JSON string value) to a forward slash. This is a
    //    literal two-character replace, exactly like golden-normalizer.ps1's
    //    .Replace('\\', '/') -- NOT a per-backslash fold: folding each lone
    //    backslash would turn a Windows JSON value `<REPO_ROOT>\\tests\\x`
    //    into `<REPO_ROOT>//tests//x`, which can never match a POSIX-captured
    //    golden (`<REPO_ROOT>/tests/x`). A lone raw backslash (host text, not
    //    JSON-escaped) is deliberately left alone, matching the reference.
    normalized = normalized.replace(/\\\\/g, "/");
    // 5-6. Per line: drop indentation and collapse the run of spaces after a key's colon.
    const lines = normalized.split("\n");
    const canonicalLines = lines.map((line) => {
        const trimmed = line.trim();
        return trimmed.replace(/^("(?:[^"\\]|\\.)*")\s*:\s+/, "$1: ");
    });
    return canonicalLines.join("\n").trimEnd();
}
export function testGoldenMatch(expected, actual) {
    return getCanonicalGoldenText(expected) === getCanonicalGoldenText(actual);
}
export function getGoldenDiffReport(expected, actual, maxDifferences = 12) {
    const expectedLines = getCanonicalGoldenText(expected).split("\n");
    const actualLines = getCanonicalGoldenText(actual).split("\n");
    const report = [];
    let shown = 0;
    const lineCount = Math.max(expectedLines.length, actualLines.length);
    for (let i = 0; i < lineCount; i++) {
        const expectedLine = i < expectedLines.length ? expectedLines[i] : "<no such line>";
        const actualLine = i < actualLines.length ? actualLines[i] : "<no such line>";
        if (expectedLine === actualLine)
            continue;
        if (shown >= maxDifferences) {
            report.push("      ... further differences not shown");
            break;
        }
        report.push(`      line ${i + 1}:`);
        report.push(`        expected: ${expectedLine}`);
        report.push(`        actual:   ${actualLine}`);
        shown++;
    }
    if (report.length === 0) {
        report.push(`      no differing line found; expected ${expectedLines.length} line(s), actual ${actualLines.length}`);
    }
    return report;
}
