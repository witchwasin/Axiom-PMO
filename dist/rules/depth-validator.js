// Specification depth validation (WS2-WS9), gated by `Spec depth: full`.
// Validates SRS completeness (SRS-001..004), Technology Decisions (ARCH-001),
// Entity Relationships (DATA-003, DATA-004), Test Cases & Coverage (TEST-CASE-001..003, TEST-COVERAGE-001..002),
// Data Flow & Journeys (DATAFLOW-001..002, JOURNEY-001..002), and OpenAPI Contract (API-001, API-002).
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { getTableRowsAfterHeading } from "../markdown/table-parser.js";
import { testPlaceholderValue } from "../config/config-loader.js";
import { resolveReference } from "../core/reference-resolver.js";
import { getHeadingPattern, getSectionBody } from "./handoff-validator.js";
import { addResult } from "../core/result-writer.js";
const MANDATORY_STRICT_NFR_CATEGORIES = [
    "performance",
    "security",
    "reliability",
];
const TEST_CASE_COLUMNS = [
    "Case ID",
    "Category",
    "Target Type",
    "Target ID",
    "Description",
    "Preconditions",
    "Input / Action",
    "Expected Result",
    "Pass Criteria",
    "Strict Trigger",
    "Source Ref",
    "Evidence Status",
];
export function testSpecificationDepth(acc, catalog, ctx, projectText, mode, gate, projectReqIds, decisionIds, sourceRefRegex) {
    const isFullDepth = /^\s*>?\s*Spec depth:\s*full\s*$/im.test(projectText);
    if (!isFullDepth)
        return;
    if (gate === "Draft" || gate === "Scope")
        return;
    const depthPolicy = ctx.depthPolicy ?? {};
    const policyEnums = ctx.policy?.["enums"] ?? {};
    // 1. SRS Validation (SRS-001..004)
    const nfrIds = testSrsArtifact(acc, catalog, ctx, mode, gate, depthPolicy, policyEnums, sourceRefRegex);
    // 2. BUILD-SPEC Extended Tables (ARCH-001, DATA-003, DATA-004)
    const { constraintIds, operationIds, transitionIds } = testBuildSpecDepth(acc, catalog, ctx, mode, gate, decisionIds, sourceRefRegex);
    // 3. Data Flow & Journeys (DATAFLOW-001, DATAFLOW-002, JOURNEY-001, JOURNEY-002)
    const journeyStepIds = testDataFlowAndJourneys(acc, catalog, ctx, mode, gate, depthPolicy, projectReqIds, operationIds);
    // 4. Test Cases & Coverage Matrix (TEST-CASE-001..003, TEST-COVERAGE-001..002)
    testTestCasesAndCoverage(acc, catalog, ctx, mode, gate, depthPolicy, policyEnums, sourceRefRegex, projectReqIds, nfrIds, constraintIds, operationIds, transitionIds, journeyStepIds);
    // 5. OpenAPI Contract Scanner (API-001, API-002)
    testOpenApiContract(acc, catalog, ctx, mode, gate, operationIds);
}
function testSrsArtifact(acc, catalog, ctx, mode, gate, depthPolicy, policyEnums, sourceRefRegex) {
    const nfrIds = [];
    const srsPath = join(ctx.project, "DESIGN/SRS.md");
    if (!existsSync(srsPath)) {
        if (mode !== "Lite" && (gate === "Design" || gate === "Handoff" || gate === "Release")) {
            addResult(acc, catalog, "FAIL", "DESIGN/SRS.md is required under Spec depth: full but was not found", {
                ruleId: "SRS-001",
                artifact: "DESIGN/SRS.md",
            });
        }
        return nfrIds;
    }
    const text = readFileSync(srsPath, "utf8");
    const srsSections = depthPolicy["srs_sections"] ?? [];
    const sectionProblems = [];
    for (const section of srsSections) {
        const heading = String(section["heading"]);
        const requiredModes = section["required_modes"] ?? [];
        if (!requiredModes.includes(mode))
            continue;
        const body = getSectionBody(text, heading, 3);
        if (body === null) {
            sectionProblems.push(`'${heading}' is missing`);
            continue;
        }
        const statusMatch = /^\s*Status\s*:\s*(\S+)\s*$/im.exec(body);
        const status = statusMatch ? statusMatch[1].trim().toLowerCase() : null;
        if (!status) {
            sectionProblems.push(`'${heading}' does not declare a Status: line`);
            continue;
        }
        if (status === "not_required") {
            const allowNotReq = section["allow_not_required"] === true;
            if (!allowNotReq) {
                sectionProblems.push(`'${heading}' is marked not_required but policy does not allow waiving it`);
                continue;
            }
            const rm = /^\s*Rationale\s*:\s*(.+)$/im.exec(body);
            const rationale = rm ? rm[1].trim() : "";
            if (rationale.length === 0 || testPlaceholderValue(rationale)) {
                sectionProblems.push(`'${heading}' is marked not_required without a Rationale:`);
            }
            else if (rationale.split(/\s+/).length < 4) {
                sectionProblems.push(`'${heading}' has a Rationale: shorter than 4 words`);
            }
            continue;
        }
        if (status === "specified") {
            const contentLines = body.split(/\r?\n/).filter((l) => {
                const t = l.trim();
                return t.length > 0 && !/^\s*Status\s*:/i.test(t);
            });
            if (contentLines.length === 0) {
                sectionProblems.push(`'${heading}' is marked specified but has no content`);
                continue;
            }
            if (section["table"] === true) {
                const rows = getTableRowsAfterHeading(text, getHeadingPattern(heading, 3));
                if (rows.length === 0) {
                    sectionProblems.push(`'${heading}' is marked specified but its table has no rows`);
                }
            }
        }
    }
    if (sectionProblems.length > 0) {
        for (const p of sectionProblems) {
            addResult(acc, catalog, "FAIL", `SRS section ${p}`, {
                ruleId: "SRS-001",
                artifact: "DESIGN/SRS.md",
            });
        }
    }
    else {
        addResult(acc, catalog, "PASS", `DESIGN/SRS.md declares every section required for ${mode} mode`, {
            ruleId: "SRS-001",
        });
    }
    // NFR Table Validation (SRS-002, SRS-003, SRS-004)
    const nfrRows = getTableRowsAfterHeading(text, getHeadingPattern("Non-Functional Requirements", 3));
    for (const row of nfrRows) {
        const id = (row["ID"] ?? "").trim();
        if (id)
            nfrIds.push(id);
    }
    testSrsNfrTable(acc, catalog, text, mode, policyEnums, sourceRefRegex);
    return nfrIds;
}
function testSrsNfrTable(acc, catalog, text, mode, policyEnums, sourceRefRegex) {
    const nfrRows = getTableRowsAfterHeading(text, getHeadingPattern("Non-Functional Requirements", 3));
    if (nfrRows.length === 0)
        return;
    const incompleteNfrs = [];
    const invalidSources = [];
    const invalidStatuses = [];
    const validEvidence = policyEnums["evidence_statuses"] ?? [];
    const declaredCategories = new Set();
    for (const row of nfrRows) {
        const id = (row["ID"] ?? "").trim();
        const category = (row["Category"] ?? "").trim().toLowerCase();
        const target = (row["Target"] ?? "").trim();
        const method = (row["Measurement Method"] ?? "").trim();
        const sourceRef = (row["Source Ref"] ?? "").trim();
        const evidenceStatus = (row["Evidence Status"] ?? "").trim().toLowerCase();
        if (category)
            declaredCategories.add(category);
        if (!id || !category || !target || !method || testPlaceholderValue(target) || testPlaceholderValue(method)) {
            incompleteNfrs.push(id || "unknown");
        }
        if (!sourceRef || !new RegExp(sourceRefRegex).test(sourceRef)) {
            invalidSources.push(id || "unknown");
        }
        if (!evidenceStatus || !validEvidence.includes(evidenceStatus)) {
            invalidStatuses.push(id || "unknown");
        }
    }
    // SRS-002
    if (incompleteNfrs.length > 0) {
        addResult(acc, catalog, "FAIL", `NFR rows missing target or measurement method: ${incompleteNfrs.join(", ")}`, {
            ruleId: "SRS-002",
            artifact: "DESIGN/SRS.md",
            field: "Non-Functional Requirements",
        });
    }
    else {
        addResult(acc, catalog, "PASS", "Non-Functional Requirements table has target and measurement method for all rows", {
            ruleId: "SRS-002",
        });
    }
    // SRS-003
    if (invalidSources.length > 0 || invalidStatuses.length > 0) {
        const problems = [];
        if (invalidSources.length > 0)
            problems.push(`invalid source_ref in ${invalidSources.join(", ")}`);
        if (invalidStatuses.length > 0)
            problems.push(`invalid evidence_status in ${invalidStatuses.join(", ")}`);
        addResult(acc, catalog, "FAIL", `NFR rows with invalid metadata: ${problems.join("; ")}`, {
            ruleId: "SRS-003",
            artifact: "DESIGN/SRS.md",
            field: "Non-Functional Requirements",
        });
    }
    else {
        addResult(acc, catalog, "PASS", "Non-Functional Requirements rows include valid source references and evidence status", {
            ruleId: "SRS-003",
        });
    }
    // SRS-004
    if (mode === "Strict") {
        const missingCategories = MANDATORY_STRICT_NFR_CATEGORIES.filter((c) => !declaredCategories.has(c));
        if (missingCategories.length > 0) {
            addResult(acc, catalog, "FAIL", `Strict mode requires NFRs covering mandatory categories, missing: ${missingCategories.join(", ")}`, {
                ruleId: "SRS-004",
                artifact: "DESIGN/SRS.md",
                field: "Category",
            });
        }
        else {
            addResult(acc, catalog, "PASS", "Strict mode declares NFRs covering mandatory categories", {
                ruleId: "SRS-004",
            });
        }
    }
}
function testBuildSpecDepth(acc, catalog, ctx, mode, gate, decisionIds, sourceRefRegex) {
    const constraintIds = [];
    const operationIds = [];
    const transitionIds = [];
    const specPath = join(ctx.project, "DESIGN/BUILD-SPEC.md");
    if (!existsSync(specPath))
        return { constraintIds, operationIds, transitionIds };
    const text = readFileSync(specPath, "utf8");
    // Collect IDs from tables
    const dmRows = getTableRowsAfterHeading(text, getHeadingPattern("Data Model", 3));
    for (const r of dmRows) {
        const cid = (r["Constraint ID"] ?? "").trim();
        if (cid)
            constraintIds.push(cid);
    }
    const apiRows = getTableRowsAfterHeading(text, getHeadingPattern("API or Command Contract", 3));
    for (const r of apiRows) {
        const opId = (r["Operation ID"] ?? "").trim();
        if (opId)
            operationIds.push(opId);
    }
    const smRows = getTableRowsAfterHeading(text, getHeadingPattern("State Machine and Transition Guards", 3));
    for (const r of smRows) {
        const tid = (r["Transition ID"] ?? "").trim();
        if (tid)
            transitionIds.push(tid);
    }
    // ARCH-001: Technology Decisions
    const tdRows = getTableRowsAfterHeading(text, getHeadingPattern("Technology Decisions", 3));
    if (mode === "Strict" && tdRows.length === 0) {
        addResult(acc, catalog, "FAIL", "Technology Decisions table is required for Strict mode but has no rows", {
            ruleId: "ARCH-001",
            artifact: "DESIGN/BUILD-SPEC.md",
            field: "Technology Decisions",
        });
    }
    else if (tdRows.length > 0) {
        const badDecisions = [];
        for (const row of tdRows) {
            const id = (row["Decision ID"] ?? "").trim();
            const area = (row["Area"] ?? "").trim();
            const chosen = (row["Chosen"] ?? "").trim();
            const decRef = (row["Decision Ref"] ?? "").trim();
            const srcRef = (row["Source Ref"] ?? "").trim();
            let valid = Boolean(id && area && chosen && !testPlaceholderValue(chosen));
            if (decRef) {
                const hasDec = decisionIds ? decisionIds.includes(decRef) : /^DEC-\d+$/i.test(decRef);
                if (!hasDec)
                    valid = false;
            }
            else {
                valid = false;
            }
            if (srcRef && !new RegExp(sourceRefRegex).test(srcRef))
                valid = false;
            if (!valid)
                badDecisions.push(id || "unknown");
        }
        if (badDecisions.length > 0) {
            addResult(acc, catalog, "FAIL", `Technology Decisions rows incomplete or citing unresolved decisions: ${badDecisions.join(", ")}`, {
                ruleId: "ARCH-001",
                artifact: "DESIGN/BUILD-SPEC.md",
                field: "Technology Decisions",
            });
        }
        else {
            addResult(acc, catalog, "PASS", "Technology Decisions table is complete with resolvable decision and source references", {
                ruleId: "ARCH-001",
            });
        }
    }
    // DATA-003 & DATA-004: Entity Relationships vs Data Model
    const erRows = getTableRowsAfterHeading(text, getHeadingPattern("Entity Relationships", 3));
    if (erRows.length > 0) {
        const knownEntities = new Set();
        const entityAttributes = new Map();
        for (const r of dmRows) {
            const entity = (r["Entity"] ?? "").trim().toLowerCase();
            const attr = (r["Attribute"] ?? "").trim().toLowerCase();
            if (entity) {
                knownEntities.add(entity);
                if (!entityAttributes.has(entity))
                    entityAttributes.set(entity, new Set());
                if (attr)
                    entityAttributes.get(entity).add(attr);
            }
        }
        const missingEntities = [];
        const missingFkFields = [];
        for (const r of erRows) {
            const id = (r["Relationship ID"] ?? "").trim();
            const fromEntity = (r["From Entity"] ?? "").trim().toLowerCase();
            const toEntity = (r["To Entity"] ?? "").trim().toLowerCase();
            const fkField = (r["FK Field"] ?? "").trim().toLowerCase();
            if (fromEntity && !knownEntities.has(fromEntity)) {
                missingEntities.push(`${id} (From: ${fromEntity})`);
            }
            if (toEntity && !knownEntities.has(toEntity)) {
                missingEntities.push(`${id} (To: ${toEntity})`);
            }
            if (fromEntity && fkField && fkField !== "none" && fkField !== "n/a") {
                const attrs = entityAttributes.get(fromEntity);
                if (attrs && !attrs.has(fkField)) {
                    missingFkFields.push(`${id} (${fromEntity}.${fkField})`);
                }
            }
        }
        if (missingEntities.length > 0) {
            addResult(acc, catalog, "FAIL", `Entity Relationships cite entities not declared in Data Model: ${missingEntities.join(", ")}`, {
                ruleId: "DATA-003",
                artifact: "DESIGN/BUILD-SPEC.md",
                field: "Entity Relationships",
            });
        }
        else {
            addResult(acc, catalog, "PASS", "Entity Relationships entities match Data Model declarations", {
                ruleId: "DATA-003",
            });
        }
        if (missingFkFields.length > 0) {
            addResult(acc, catalog, "FAIL", `Entity Relationships FK fields not found in Data Model entity attributes: ${missingFkFields.join(", ")}`, {
                ruleId: "DATA-004",
                artifact: "DESIGN/BUILD-SPEC.md",
                field: "FK Field",
            });
        }
        else {
            addResult(acc, catalog, "PASS", "Entity Relationships FK fields exist in Data Model entity attributes", {
                ruleId: "DATA-004",
            });
        }
    }
    return { constraintIds, operationIds, transitionIds };
}
function testDataFlowAndJourneys(acc, catalog, ctx, mode, gate, depthPolicy, projectReqIds, operationIds) {
    const journeyStepIds = [];
    const dataflowPath = join(ctx.project, "DESIGN/DATA-FLOW.md");
    const hasDataFlow = existsSync(dataflowPath);
    if (!hasDataFlow) {
        if (mode === "Strict" && (gate === "Design" || gate === "Handoff" || gate === "Release")) {
            addResult(acc, catalog, "FAIL", "DESIGN/DATA-FLOW.md is required for Strict mode under Spec depth: full", {
                ruleId: "DATAFLOW-001",
                artifact: "DESIGN/DATA-FLOW.md",
            });
        }
        return journeyStepIds;
    }
    const text = readFileSync(dataflowPath, "utf8");
    const dataflowSections = depthPolicy["dataflow_sections"] ?? [];
    const sectionProblems = [];
    for (const section of dataflowSections) {
        const heading = String(section["heading"]);
        const requiredModes = section["required_modes"] ?? [];
        if (!requiredModes.includes(mode))
            continue;
        const body = getSectionBody(text, heading, 2);
        if (body === null) {
            sectionProblems.push(`'${heading}' is missing`);
            continue;
        }
        const statusMatch = /^\s*Status\s*:\s*(\S+)\s*$/im.exec(body);
        const status = statusMatch ? statusMatch[1].trim().toLowerCase() : null;
        if (!status) {
            sectionProblems.push(`'${heading}' does not declare a Status: line`);
            continue;
        }
    }
    if (sectionProblems.length > 0) {
        for (const p of sectionProblems) {
            addResult(acc, catalog, "FAIL", `DATA-FLOW section ${p}`, {
                ruleId: "DATAFLOW-001",
                artifact: "DESIGN/DATA-FLOW.md",
            });
        }
    }
    else {
        addResult(acc, catalog, "PASS", `DESIGN/DATA-FLOW.md declares required sections for ${mode} mode`, {
            ruleId: "DATAFLOW-001",
        });
    }
    // DATAFLOW-002 & JOURNEY-001..002: End-to-End Journeys Table
    const journeyRows = getTableRowsAfterHeading(text, getHeadingPattern("End-to-End Journeys", 2));
    if (journeyRows.length === 0) {
        if (mode !== "Lite" && (gate === "Design" || gate === "Handoff" || gate === "Release")) {
            addResult(acc, catalog, "FAIL", "End-to-End Journeys table in DESIGN/DATA-FLOW.md has no journey steps", {
                ruleId: "JOURNEY-001",
                artifact: "DESIGN/DATA-FLOW.md",
                field: "End-to-End Journeys",
            });
        }
    }
    else {
        addResult(acc, catalog, "PASS", "End-to-End Journeys table declares journey steps", {
            ruleId: "JOURNEY-001",
        });
        const unresolvableRefs = [];
        const validTargets = new Set([...projectReqIds, ...operationIds]);
        for (const r of journeyRows) {
            const stepId = (r["Step ID"] ?? "").trim();
            const specRef = (r["Spec Element Ref"] ?? "").trim();
            if (stepId)
                journeyStepIds.push(stepId);
            if (specRef && validTargets.size > 0) {
                const refs = specRef.split(/[,;\s]+/).map((s) => s.trim()).filter(Boolean);
                for (const ref of refs) {
                    if (!validTargets.has(ref)) {
                        unresolvableRefs.push(`${stepId} -> ${ref}`);
                    }
                }
            }
        }
        if (unresolvableRefs.length > 0) {
            addResult(acc, catalog, "FAIL", `Journey steps cite unresolvable spec elements: ${unresolvableRefs.join(", ")}`, {
                ruleId: "JOURNEY-002",
                artifact: "DESIGN/DATA-FLOW.md",
                field: "Spec Element Ref",
            });
        }
        else {
            addResult(acc, catalog, "PASS", "All journey step spec element references resolve to declared requirements or operations", {
                ruleId: "JOURNEY-002",
            });
        }
        addResult(acc, catalog, "PASS", "DESIGN/DATA-FLOW.md End-to-End Journeys structure is valid", {
            ruleId: "DATAFLOW-002",
        });
    }
    return journeyStepIds;
}
function testTestCasesAndCoverage(acc, catalog, ctx, mode, gate, depthPolicy, policyEnums, sourceRefRegex, projectReqIds, nfrIds, constraintIds, operationIds, transitionIds, journeyStepIds) {
    const testCasesPath = join(ctx.project, "TESTS/TEST-CASES.md");
    const hasTestCases = existsSync(testCasesPath);
    if (!hasTestCases) {
        if (mode !== "Lite" && (gate === "Design" || gate === "Handoff" || gate === "Release")) {
            addResult(acc, catalog, "FAIL", "TESTS/TEST-CASES.md is required under Spec depth: full but was not found", {
                ruleId: "TEST-CASE-001",
                artifact: "TESTS/TEST-CASES.md",
            });
        }
        return;
    }
    const text = readFileSync(testCasesPath, "utf8");
    const caseRows = getTableRowsAfterHeading(text, getHeadingPattern("Test Cases Inventory", 2));
    if (caseRows.length === 0) {
        addResult(acc, catalog, "FAIL", "TESTS/TEST-CASES.md Test Cases Inventory table has no rows", {
            ruleId: "TEST-CASE-001",
            artifact: "TESTS/TEST-CASES.md",
            field: "Test Cases Inventory",
        });
        return;
    }
    // 1. TEST-CASE-001: Column Completeness & Placeholders
    const incompleteCases = [];
    for (const r of caseRows) {
        const id = (r["Case ID"] ?? "").trim();
        const desc = (r["Description"] ?? "").trim();
        const exp = (r["Expected Result"] ?? "").trim();
        const pass = (r["Pass Criteria"] ?? "").trim();
        if (!id || !desc || !exp || !pass || testPlaceholderValue(desc) || testPlaceholderValue(exp) || testPlaceholderValue(pass)) {
            incompleteCases.push(id || "unknown");
        }
    }
    if (incompleteCases.length > 0) {
        addResult(acc, catalog, "FAIL", `Test cases missing description, expected result, or pass criteria: ${incompleteCases.join(", ")}`, {
            ruleId: "TEST-CASE-001",
            artifact: "TESTS/TEST-CASES.md",
            field: "Test Cases Inventory",
        });
    }
    else {
        addResult(acc, catalog, "PASS", "TESTS/TEST-CASES.md test cases declare complete criteria and parameters", {
            ruleId: "TEST-CASE-001",
        });
    }
    // 2. TEST-CASE-002: ID Uniqueness & Valid Categories
    const allowedCategories = new Set((depthPolicy["test_categories"] ?? [
        "happy", "happy_path", "negative", "boundary", "security", "concurrency", "recovery",
    ]).map((c) => c.toLowerCase()));
    allowedCategories.add("happy_path");
    const seenIds = new Set();
    const duplicateIds = [];
    const invalidCategoryCases = [];
    const coveredReqIds = new Set();
    for (const r of caseRows) {
        const id = (r["Case ID"] ?? "").trim();
        const cat = (r["Category"] ?? "").trim().toLowerCase();
        const targetId = (r["Target ID"] ?? "").trim();
        if (id) {
            if (seenIds.has(id))
                duplicateIds.push(id);
            seenIds.add(id);
        }
        if (!cat || !allowedCategories.has(cat)) {
            invalidCategoryCases.push(`${id || "unknown"}: '${cat}'`);
        }
        if (targetId && projectReqIds.includes(targetId)) {
            coveredReqIds.add(targetId);
        }
    }
    if (duplicateIds.length > 0 || invalidCategoryCases.length > 0) {
        const problems = [];
        if (duplicateIds.length > 0)
            problems.push(`duplicate Case IDs: ${duplicateIds.join(", ")}`);
        if (invalidCategoryCases.length > 0)
            problems.push(`invalid Category in: ${invalidCategoryCases.join(", ")}`);
        addResult(acc, catalog, "FAIL", `Test case definition errors: ${problems.join("; ")}`, {
            ruleId: "TEST-CASE-002",
            artifact: "TESTS/TEST-CASES.md",
            field: "Category",
        });
    }
    else {
        addResult(acc, catalog, "PASS", "Test cases have unique IDs and valid categories", {
            ruleId: "TEST-CASE-002",
        });
    }
    // 3. TEST-CASE-003: Traceability & Evidence Status
    const validEvidence = policyEnums["evidence_statuses"] ?? [];
    const invalidMetadata = [];
    for (const r of caseRows) {
        const id = (r["Case ID"] ?? "").trim();
        const srcRef = (r["Source Ref"] ?? "").trim();
        const evStatus = (r["Evidence Status"] ?? "").trim().toLowerCase();
        const srcOk = Boolean(srcRef && new RegExp(sourceRefRegex).test(srcRef));
        const evOk = Boolean(evStatus && validEvidence.includes(evStatus));
        if (!srcOk || !evOk) {
            invalidMetadata.push(id || "unknown");
        }
    }
    if (invalidMetadata.length > 0) {
        addResult(acc, catalog, "FAIL", `Test cases with invalid source_ref or evidence_status: ${invalidMetadata.join(", ")}`, {
            ruleId: "TEST-CASE-003",
            artifact: "TESTS/TEST-CASES.md",
            field: "Source Ref",
        });
    }
    else {
        addResult(acc, catalog, "PASS", "Test cases carry valid source references and evidence status", {
            ruleId: "TEST-CASE-003",
        });
    }
    // 4. TEST-COVERAGE-001: Derived Test Volume Math
    const minRequiredCases = mode === "Strict" ? Math.max(projectReqIds.length * 2, 4) : Math.max(projectReqIds.length, 1);
    if (caseRows.length < minRequiredCases) {
        addResult(acc, catalog, "FAIL", `Test case count (${caseRows.length}) is below required minimum (${minRequiredCases}) for ${mode} mode`, {
            ruleId: "TEST-COVERAGE-001",
            artifact: "TESTS/TEST-CASES.md",
            field: "Derived Target Cases",
        });
    }
    else {
        addResult(acc, catalog, "PASS", `Test case count (${caseRows.length}) satisfies derived minimum (${minRequiredCases}) for ${mode} mode`, {
            ruleId: "TEST-COVERAGE-001",
        });
    }
    // 5. TEST-COVERAGE-002: Scoped Requirements Coverage
    const uncoveredReqs = projectReqIds.filter((id) => !coveredReqIds.has(id));
    if (uncoveredReqs.length > 0) {
        addResult(acc, catalog, "FAIL", `Scoped requirements missing test case coverage: ${uncoveredReqs.join(", ")}`, {
            ruleId: "TEST-COVERAGE-002",
            artifact: "TESTS/TEST-CASES.md",
            field: "Target ID",
        });
    }
    else {
        addResult(acc, catalog, "PASS", "All scoped requirements have corresponding test cases", {
            ruleId: "TEST-COVERAGE-002",
        });
    }
}
function testOpenApiContract(acc, catalog, ctx, mode, gate, operationIds) {
    const openApiPath = join(ctx.project, "DESIGN/API/openapi.yaml");
    if (!existsSync(openApiPath))
        return;
    const yamlText = readFileSync(openApiPath, "utf8");
    // API-001: Version Header
    const versionMatch = /^\s*openapi\s*:\s*["']?(\d+\.\d+\.\d+)["']?\s*$/m.exec(yamlText);
    if (!versionMatch) {
        addResult(acc, catalog, "FAIL", "DESIGN/API/openapi.yaml is missing valid openapi: 3.x version header", {
            ruleId: "API-001",
            artifact: "DESIGN/API/openapi.yaml",
            field: "openapi",
        });
    }
    else {
        addResult(acc, catalog, "PASS", `DESIGN/API/openapi.yaml declares OpenAPI ${versionMatch[1]}`, {
            ruleId: "API-001",
        });
    }
    // API-002: Zero-Dependency OperationId Scanner
    const declaredOps = new Set();
    const opMatches = yamlText.matchAll(/^\s*operationId\s*:\s*["']?([a-zA-Z0-9_-]+)["']?\s*$/gm);
    for (const m of opMatches) {
        if (m[1])
            declaredOps.add(m[1].trim());
    }
    if (operationIds.length > 0 && declaredOps.size > 0) {
        const missingOps = operationIds.filter((id) => !declaredOps.has(id));
        if (missingOps.length > 0) {
            addResult(acc, catalog, "FAIL", `OpenAPI spec missing operationIds declared in BUILD-SPEC: ${missingOps.join(", ")}`, {
                ruleId: "API-002",
                artifact: "DESIGN/API/openapi.yaml",
                field: "operationId",
            });
        }
        else {
            addResult(acc, catalog, "PASS", "OpenAPI spec operationIds correspond to declared BUILD-SPEC operations", {
                ruleId: "API-002",
            });
        }
    }
}
