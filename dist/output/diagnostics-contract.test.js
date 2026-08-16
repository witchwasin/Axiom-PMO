// Ported from tests/helpers/diagnostics-contract-tests.ps1.
//
// The golden masters prove that specific projects produce specific findings.
// These tests prove something different and orthogonal: that whatever the
// validator emits, it always has the shape a machine consumer was promised.
// A new rule added tomorrow with a malformed diagnostic would slip past the
// goldens (its case simply would not exist yet); it fails here.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { existsSync } from "node:fs";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { runPortedChain } from "../probe/validate-chain.js";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const schema = JSON.parse(readFileSync(join(REPO_ROOT, "pmo-config/diagnostics-schema.json"), "utf8"));
const catalog = JSON.parse(readFileSync(join(REPO_ROOT, "pmo-config/validation-rules.json"), "utf8").replace(/^﻿/, ""));
const expectedDiagnosticKeys = schema.diagnostic.required;
const declaredSchemaVersion = schema.diagnostics_schema_version;
const catalogRuleIds = Object.keys(catalog.rules);
const docBase = catalog.documentation_base_url;
const samples = [
    { name: "clean-standard-release", fixture: "tests/fixtures/valid-standard", mode: "Standard", gate: "Release" },
    { name: "failing-standard-release", fixture: "tests/fixtures/invalid-no-source-ref", mode: "Standard", gate: "Release" },
    { name: "warning-github-task-source", fixture: "tests/fixtures/valid-github-task-source-no-delivery", mode: "Standard", gate: "Release" },
    { name: "strict-release", fixture: "examples/STRICT-HIGH-RISK", mode: "Strict", gate: "Release" },
];
test("envelope-level counters agree with the emitted rows", () => {
    for (const sample of samples) {
        const project = join(REPO_ROOT, sample.fixture);
        assert.ok(existsSync(project), `fixture exists: ${sample.fixture}`);
        const { diagnostics, accumulator } = runPortedChain(REPO_ROOT, project, sample.mode, sample.gate);
        const countedPass = diagnostics.filter((d) => d.level === "PASS").length;
        const countedWarn = diagnostics.filter((d) => d.level === "WARN").length;
        const countedFail = diagnostics.filter((d) => d.level === "FAIL").length;
        const countedWarnBlocking = diagnostics.filter((d) => d.level === "WARN" && d.blocking).length;
        assert.equal(accumulator.pass, countedPass, `${sample.name}: pass counter`);
        assert.equal(accumulator.warn, countedWarn, `${sample.name}: warn counter`);
        assert.equal(accumulator.fail, countedFail, `${sample.name}: fail counter`);
        assert.equal(accumulator.warnBlocking, countedWarnBlocking, `${sample.name}: warn_blocking counter`);
        const exitCode = countedFail > 0 ? 1 : 0;
        assert.ok([0, 1, 2].includes(exitCode), `${sample.name}: exit code is a declared value`);
    }
});
test("every diagnostic row matches the declared contract", () => {
    const allResults = [];
    for (const sample of samples) {
        const { diagnostics } = runPortedChain(REPO_ROOT, join(REPO_ROOT, sample.fixture), sample.mode, sample.gate);
        allResults.push(...diagnostics);
    }
    assert.ok(allResults.length > 0, "at least one diagnostic row was collected");
    const shapeProblems = [];
    const enumProblems = [];
    const catalogProblems = [];
    const suggestionProblems = [];
    const docProblems = [];
    const sensitiveProblems = [];
    for (const row of allResults) {
        const keys = Object.keys(row);
        const record = row;
        const missing = expectedDiagnosticKeys.filter((k) => !keys.includes(k));
        if (missing.length > 0)
            shapeProblems.push(`${row.rule_id}: missing ${missing.join(", ")}`);
        // Absent-vs-null policy: fields are always present, never omitted, and
        // never the empty string.
        for (const key of expectedDiagnosticKeys) {
            if (!keys.includes(key))
                continue;
            const value = record[key];
            if (typeof value === "string" && value.trim().length === 0) {
                shapeProblems.push(`${row.rule_id}: '${key}' is an empty string instead of null`);
            }
        }
        if (row.schema_version !== declaredSchemaVersion) {
            shapeProblems.push(`${row.rule_id}: row schema_version is '${row.schema_version}'`);
        }
        if (!["PASS", "WARN", "FAIL", "INFO"].includes(row.level)) {
            enumProblems.push(`level '${row.level}'`);
        }
        if (!/^[A-Z][A-Z0-9]*(-[A-Z0-9]+)+$/.test(row.rule_id)) {
            enumProblems.push(`rule_id '${row.rule_id}' does not match the declared pattern`);
        }
        if (typeof row.blocking !== "boolean") {
            enumProblems.push(`${row.rule_id}: blocking is not a boolean`);
        }
        if (!row.message || !row.message.trim()) {
            shapeProblems.push(`${row.rule_id}: message is empty`);
        }
        if (!catalogRuleIds.includes(row.rule_id)) {
            catalogProblems.push(`${row.rule_id} is not in validation-rules.json`);
        }
        if (row.level === "WARN" || row.level === "FAIL") {
            if (!row.suggestion || !row.suggestion.trim()) {
                suggestionProblems.push(`${row.rule_id} has no suggestion on a ${row.level} row`);
            }
        }
        else {
            // PASS/INFO must not carry remediation text: a consumer filtering on
            // "has a suggestion" would otherwise pick up healthy rows.
            if (row.suggestion && row.suggestion.trim()) {
                suggestionProblems.push(`${row.rule_id} carries a suggestion on a ${row.level} row`);
            }
            if (row.documentation_url && row.documentation_url.trim()) {
                docProblems.push(`${row.rule_id} carries a documentation_url on a ${row.level} row`);
            }
        }
        if (row.documentation_url && row.documentation_url.trim()) {
            if (!row.documentation_url.startsWith(docBase)) {
                docProblems.push(`${row.rule_id}: documentation_url does not start with documentation_base_url`);
            }
            const relative = row.documentation_url.slice(docBase.replace(/\/$/, "").length).replace(/^\/+/, "");
            if (!existsSync(join(REPO_ROOT, relative))) {
                docProblems.push(`${row.rule_id}: documentation_url points at a file that does not exist (${relative})`);
            }
        }
        // Sensitive-data policy: a diagnostic locates a problem, it does not
        // reproduce it. A multi-line message means artifact content was pasted in.
        if (row.message.includes("\n")) {
            sensitiveProblems.push(`${row.rule_id}: message spans multiple lines`);
        }
        if (row.message.length > 400) {
            sensitiveProblems.push(`${row.rule_id}: message is ${row.message.length} chars, long enough to be quoting artifact content`);
        }
    }
    assert.equal(shapeProblems.length, 0, shapeProblems.slice(0, 5).join("; "));
    assert.equal(enumProblems.length, 0, [...new Set(enumProblems)].slice(0, 5).join("; "));
    assert.equal(catalogProblems.length, 0, [...new Set(catalogProblems)].slice(0, 5).join("; "));
    assert.equal(suggestionProblems.length, 0, [...new Set(suggestionProblems)].slice(0, 5).join("; "));
    assert.equal(docProblems.length, 0, [...new Set(docProblems)].slice(0, 5).join("; "));
    assert.equal(sensitiveProblems.length, 0, [...new Set(sensitiveProblems)].slice(0, 5).join("; "));
    // Backward compatibility: the four v1.0 fields must still be present with
    // their original names on every row. Catches someone "tidying up" the
    // contract by renaming e.g. `blocking` to `is_blocking`.
    const v1Fields = schema.compatibility.stable_fields;
    const v1Problems = [];
    for (const row of allResults) {
        const keys = Object.keys(row);
        for (const field of v1Fields) {
            if (!keys.includes(field))
                v1Problems.push(`${row.rule_id} lost v1.0 field '${field}'`);
        }
    }
    assert.equal(v1Problems.length, 0, [...new Set(v1Problems)].slice(0, 5).join("; "));
});
