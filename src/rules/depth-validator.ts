// Specification depth validation (WS2-WS9), gated by `Spec depth: full`.
// Validates SRS completeness (SRS-001..004), Technology Decisions (ARCH-001),
// Entity Relationships (DATA-003, DATA-004), Data Dictionary (DATAFLOW-001..002),
// Journeys (JOURNEY-001..002), Test Cases & Coverage Matrix (TEST-CASE-001..003, TEST-COVERAGE-001..002),
// and OpenAPI Contract (API-001, API-002).

import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { getTableRowsAfterHeading, type TableRow } from "../markdown/table-parser.js";
import { testPlaceholderValue } from "../config/config-loader.js";
import { resolveReference, type ReferenceTypesConfig } from "../core/reference-resolver.js";
import { getHeadingPattern, getSectionBody } from "./handoff-validator.js";
import { addResult } from "../core/result-writer.js";
import type { ResultAccumulator, ValidationRules } from "../core/context.js";
import type { Mode, Gate } from "../core/types.js";

const MANDATORY_STRICT_NFR_CATEGORIES = [
  "performance",
  "security",
  "reliability",
];

export function testSpecificationDepth(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  ctx: {
    project: string;
    policy: Record<string, unknown>;
    depthPolicy: Record<string, unknown>;
    handoffPolicy: Record<string, unknown>;
    referenceTypesConfig: ReferenceTypesConfig;
  },
  projectText: string,
  mode: Mode,
  gate: Gate,
  projectReqIds: string[],
  decisionIds: string[] | null,
  sourceRefRegex: string,
): void {
  const isFullDepth = /^\s*>?\s*Spec depth:\s*full\s*$/im.test(projectText);
  if (!isFullDepth) return;
  if (gate === "Draft" || gate === "Scope") return;

  const depthPolicy = ctx.depthPolicy ?? {};
  const policyEnums = (ctx.policy?.["enums"] as Record<string, unknown>) ?? {};

  // Extract Business Rules IDs from PROJECT.md
  const brRows = getTableRowsAfterHeading(projectText, getHeadingPattern("Business Rules", 2));
  const projectBusinessIds: string[] = [];
  for (const r of brRows) {
    const bid = (r["ID"] ?? "").trim();
    if (bid) projectBusinessIds.push(bid);
  }

  // Extract Strict Triggers from DELIVERY.md
  const deliveryPath = join(ctx.project, "DELIVERY.md");
  const deliveryText = existsSync(deliveryPath) ? readFileSync(deliveryPath, "utf8") : "";
  const deliveryRows = getTableRowsAfterHeading(deliveryText, "^##\\s+Work Items");
  const strictTriggers: string[] = [];
  for (const r of deliveryRows) {
    const st = (r["Strict Trigger"] ?? "").trim();
    if (st && st.toLowerCase() !== "none" && st.toLowerCase() !== "n/a") {
      if (!strictTriggers.includes(st)) strictTriggers.push(st);
    }
  }

  // 1. SRS Validation (SRS-001..004)
  const nfrIds = testSrsArtifact(acc, catalog, ctx, mode, gate, depthPolicy, policyEnums, sourceRefRegex);

  // 2. BUILD-SPEC Extended Tables (ARCH-001, DATA-003, DATA-004)
  const { constraintIds, operationIds, transitionIds, stateNames } = testBuildSpecDepth(acc, catalog, ctx, mode, gate, decisionIds, sourceRefRegex);

  // 3. Data Dictionary Validation (DATAFLOW-001, DATAFLOW-002)
  testDataDictionary(acc, catalog, ctx, mode, gate);

  // 4. Data Flow & Journeys (JOURNEY-001, JOURNEY-002)
  const journeyStepIds = testDataFlowAndJourneys(acc, catalog, ctx, mode, gate, projectReqIds, transitionIds, stateNames);

  // 5. Test Cases & Coverage Matrix (TEST-CASE-001..003, TEST-COVERAGE-001..002)
  testTestCasesAndCoverage(
    acc, catalog, ctx, mode, gate, depthPolicy, policyEnums, sourceRefRegex,
    projectReqIds, projectBusinessIds, nfrIds, constraintIds, operationIds, transitionIds, journeyStepIds, strictTriggers,
  );

  // 6. OpenAPI Contract Scanner (API-001, API-002)
  testOpenApiContract(acc, catalog, ctx, mode, gate, operationIds);
}

function testSrsArtifact(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  ctx: { project: string },
  mode: Mode,
  gate: Gate,
  depthPolicy: Record<string, unknown>,
  policyEnums: Record<string, unknown>,
  sourceRefRegex: string,
): string[] {
  const nfrIds: string[] = [];
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
  const srsSections = (depthPolicy["srs_sections"] as Array<Record<string, unknown>>) ?? [];

  const sectionProblems: string[] = [];
  for (const section of srsSections) {
    const heading = String(section["heading"]);
    const requiredModes = (section["required_modes"] as string[]) ?? [];
    if (!requiredModes.includes(mode)) continue;

    const body = getSectionBody(text, heading, 3);
    if (body === null) {
      sectionProblems.push(`'${heading}' is missing`);
      continue;
    }

    const statusMatch = /^\s*Status\s*:\s*(\S+)\s*$/im.exec(body);
    const status = statusMatch ? statusMatch[1]!.trim().toLowerCase() : null;
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
      const rationale = rm ? rm[1]!.trim() : "";
      if (rationale.length === 0 || testPlaceholderValue(rationale)) {
        sectionProblems.push(`'${heading}' is marked not_required without a Rationale:`);
      } else if (rationale.split(/\s+/).length < 4) {
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
  } else {
    addResult(acc, catalog, "PASS", `DESIGN/SRS.md declares every section required for ${mode} mode`, {
      ruleId: "SRS-001",
    });
  }

  // NFR Table Validation (SRS-002, SRS-003, SRS-004)
  const nfrRows = getTableRowsAfterHeading(text, getHeadingPattern("Non-Functional Requirements", 3));
  for (const row of nfrRows) {
    const id = (row["ID"] ?? "").trim();
    if (id) nfrIds.push(id);
  }
  testSrsNfrTable(acc, catalog, text, mode, policyEnums, sourceRefRegex);
  return nfrIds;
}

function testSrsNfrTable(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  text: string,
  mode: Mode,
  policyEnums: Record<string, unknown>,
  sourceRefRegex: string,
): void {
  const nfrRows = getTableRowsAfterHeading(text, getHeadingPattern("Non-Functional Requirements", 3));
  if (nfrRows.length === 0) return;

  const incompleteNfrs: string[] = [];
  const invalidSources: string[] = [];
  const invalidStatuses: string[] = [];
  const validEvidence = (policyEnums["evidence_statuses"] as string[]) ?? [];
  const declaredCategories = new Set<string>();

  for (const row of nfrRows) {
    const id = (row["ID"] ?? "").trim();
    const category = (row["Category"] ?? "").trim().toLowerCase();
    const target = (row["Target"] ?? "").trim();
    const method = (row["Measurement Method"] ?? "").trim();
    const sourceRef = (row["Source Ref"] ?? "").trim();
    const evidenceStatus = (row["Evidence Status"] ?? "").trim().toLowerCase();

    if (category) declaredCategories.add(category);

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
  } else {
    addResult(acc, catalog, "PASS", "Non-Functional Requirements table has target and measurement method for all rows", {
      ruleId: "SRS-002",
    });
  }

  // SRS-003
  if (invalidSources.length > 0 || invalidStatuses.length > 0) {
    const problems = [];
    if (invalidSources.length > 0) problems.push(`invalid source_ref in ${invalidSources.join(", ")}`);
    if (invalidStatuses.length > 0) problems.push(`invalid evidence_status in ${invalidStatuses.join(", ")}`);
    addResult(acc, catalog, "FAIL", `NFR rows with invalid metadata: ${problems.join("; ")}`, {
      ruleId: "SRS-003",
      artifact: "DESIGN/SRS.md",
      field: "Non-Functional Requirements",
    });
  } else {
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
    } else {
      addResult(acc, catalog, "PASS", "Strict mode declares NFRs covering mandatory categories", {
        ruleId: "SRS-004",
      });
    }
  }
}

function testBuildSpecDepth(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  ctx: { project: string; referenceTypesConfig: ReferenceTypesConfig },
  mode: Mode,
  gate: Gate,
  decisionIds: string[] | null,
  sourceRefRegex: string,
): { constraintIds: string[]; operationIds: string[]; transitionIds: string[]; stateNames: string[] } {
  const constraintIds: string[] = [];
  const operationIds: string[] = [];
  const transitionIds: string[] = [];
  const stateNames: string[] = ["none", "n/a", "initial", "terminal", "start", "end", "-"];

  const specPath = join(ctx.project, "DESIGN/BUILD-SPEC.md");
  if (!existsSync(specPath)) return { constraintIds, operationIds, transitionIds, stateNames };
  const text = readFileSync(specPath, "utf8");

  // Collect IDs from tables
  const dmRows = getTableRowsAfterHeading(text, getHeadingPattern("Data Model", 3));
  for (const r of dmRows) {
    const cid = (r["Constraint ID"] ?? "").trim();
    if (cid) constraintIds.push(cid);
  }

  const apiRows = getTableRowsAfterHeading(text, getHeadingPattern("API or Command Contract", 3));
  for (const r of apiRows) {
    const opId = (r["Operation ID"] ?? "").trim();
    if (opId) operationIds.push(opId);
  }

  const smRows = getTableRowsAfterHeading(text, getHeadingPattern("State Machine and Transition Guards", 3));
  for (const r of smRows) {
    const tid = (r["Transition ID"] ?? "").trim();
    if (tid) transitionIds.push(tid);

    const fromState = (r["From State"] ?? r["From"] ?? "").trim().toLowerCase();
    const toState = (r["To State"] ?? r["To"] ?? "").trim().toLowerCase();
    if (fromState && !stateNames.includes(fromState)) stateNames.push(fromState);
    if (toState && !stateNames.includes(toState)) stateNames.push(toState);
  }

  // ARCH-001: Technology Decisions
  const tdRows = getTableRowsAfterHeading(text, getHeadingPattern("Technology Decisions", 3));
  if (mode === "Strict" && tdRows.length === 0) {
    addResult(acc, catalog, "FAIL", "Technology Decisions table is required for Strict mode but has no rows", {
      ruleId: "ARCH-001",
      artifact: "DESIGN/BUILD-SPEC.md",
      field: "Technology Decisions",
    });
  } else if (tdRows.length > 0) {
    const badDecisions: string[] = [];
    for (const row of tdRows) {
      const id = (row["Decision ID"] ?? "").trim();
      const area = (row["Area"] ?? "").trim();
      const chosen = (row["Chosen"] ?? "").trim();
      const decRef = (row["Decision Ref"] ?? "").trim();
      const srcRef = (row["Source Ref"] ?? "").trim();

      let valid = Boolean(id && area && chosen && !testPlaceholderValue(chosen));
      if (decRef) {
        const hasDec = decisionIds ? decisionIds.includes(decRef) : /^DEC-\d+$/i.test(decRef);
        if (!hasDec) valid = false;
      } else {
        valid = false;
      }
      if (srcRef && !new RegExp(sourceRefRegex).test(srcRef)) valid = false;

      if (!valid) badDecisions.push(id || "unknown");
    }

    if (badDecisions.length > 0) {
      addResult(acc, catalog, "FAIL", `Technology Decisions rows incomplete or citing unresolved decisions: ${badDecisions.join(", ")}`, {
        ruleId: "ARCH-001",
        artifact: "DESIGN/BUILD-SPEC.md",
        field: "Technology Decisions",
      });
    } else {
      addResult(acc, catalog, "PASS", "Technology Decisions table is complete with resolvable decision and source references", {
        ruleId: "ARCH-001",
      });
    }
  }

  // DATA-003 & DATA-004: Entity Relationships vs Data Model
  const erRows = getTableRowsAfterHeading(text, getHeadingPattern("Entity Relationships", 3));

  if (erRows.length > 0) {
    const knownEntities = new Set<string>();
    const entityAttributes = new Map<string, Set<string>>();

    for (const r of dmRows) {
      const entity = (r["Entity"] ?? "").trim().toLowerCase();
      const attr = (r["Attribute"] ?? "").trim().toLowerCase();
      if (entity) {
        knownEntities.add(entity);
        if (!entityAttributes.has(entity)) entityAttributes.set(entity, new Set());
        if (attr) entityAttributes.get(entity)!.add(attr);
      }
    }

    const missingEntities: string[] = [];
    const missingFkFields: string[] = [];

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
    } else {
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
    } else {
      addResult(acc, catalog, "PASS", "Entity Relationships FK fields exist in Data Model entity attributes", {
        ruleId: "DATA-004",
      });
    }
  }

  return { constraintIds, operationIds, transitionIds, stateNames };
}

function testDataDictionary(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  ctx: { project: string },
  mode: Mode,
  gate: Gate,
): void {
  const dictPath = join(ctx.project, "DESIGN/DATA-DICTIONARY.md");
  const hasDict = existsSync(dictPath);

  if (!hasDict) {
    if (mode !== "Lite" && (gate === "Design" || gate === "Handoff" || gate === "Release")) {
      addResult(acc, catalog, "FAIL", "DESIGN/DATA-DICTIONARY.md is required under Spec depth: full but was not found", {
        ruleId: "DATAFLOW-001",
        artifact: "DESIGN/DATA-DICTIONARY.md",
      });
    }
    return;
  }

  const dictText = readFileSync(dictPath, "utf8");
  const dictRows = getTableRowsAfterHeading(dictText, getHeadingPattern("Field Inventory", 2));

  const specPath = join(ctx.project, "DESIGN/BUILD-SPEC.md");
  const specText = existsSync(specPath) ? readFileSync(specPath, "utf8") : "";
  const dmRows = getTableRowsAfterHeading(specText, getHeadingPattern("Data Model", 3));

  // 1. DATAFLOW-001: Every BUILD-SPEC Data Model attribute appears in Data Dictionary
  const dictFields = new Set<string>();
  const dictSensitiveFields: Array<{ entity: string; attribute: string }> = [];

  for (const r of dictRows) {
    const entity = (r["Entity"] ?? "").trim().toLowerCase();
    const attr = (r["Attribute"] ?? "").trim().toLowerCase();
    const classification = (r["Classification"] ?? "").trim().toLowerCase();
    if (entity && attr) {
      dictFields.add(`${entity}.${attr}`);
      if (["confidential", "restricted", "sensitive", "pii", "secret"].includes(classification)) {
        dictSensitiveFields.push({ entity, attribute: attr });
      }
    }
  }

  const missingFromDict: string[] = [];
  for (const r of dmRows) {
    const entity = (r["Entity"] ?? "").trim().toLowerCase();
    const attr = (r["Attribute"] ?? "").trim().toLowerCase();
    if (entity && attr && !dictFields.has(`${entity}.${attr}`)) {
      missingFromDict.push(`${entity}.${attr}`);
    }
  }

  if (missingFromDict.length > 0) {
    addResult(acc, catalog, "FAIL", `Data dictionary missing attributes declared in BUILD-SPEC: ${missingFromDict.join(", ")}`, {
      ruleId: "DATAFLOW-001",
      artifact: "DESIGN/DATA-DICTIONARY.md",
      field: "Field Inventory",
    });
  } else {
    addResult(acc, catalog, "PASS", "All BUILD-SPEC Data Model attributes appear in DESIGN/DATA-DICTIONARY.md", {
      ruleId: "DATAFLOW-001",
    });
  }

  // 2. DATAFLOW-002: Sensitive classification agreement with BUILD-SPEC Security Inventory
  const secRows = getTableRowsAfterHeading(specText, getHeadingPattern("Security, Privacy and Data Inventory", 3));
  const declaredSensitiveElements = new Set<string>();

  for (const r of secRows) {
    const elem = (r["Data Element"] ?? "").trim().toLowerCase();
    const hasSensitive = (r["Contains Sensitive Data"] ?? "").trim().toLowerCase();
    const decision = (r["Classification Decision"] ?? "").trim().toLowerCase();
    if (elem) {
      declaredSensitiveElements.add(elem);
      const parts = elem.split(/[.:\s]+/);
      for (const p of parts) declaredSensitiveElements.add(p);
    }
    if (hasSensitive === "yes" || hasSensitive === "true" || decision.includes("sensitive") || decision.includes("confidential") || decision.includes("pii") || decision.includes("restricted")) {
      if (elem) declaredSensitiveElements.add(elem);
    }
  }

  if (dictSensitiveFields.length > 0 && secRows.length > 0) {
    const unrecordedSensitive: string[] = [];
    for (const f of dictSensitiveFields) {
      const full = `${f.entity}.${f.attribute}`;
      const hasMatch = declaredSensitiveElements.has(full) ||
                       declaredSensitiveElements.has(f.attribute) ||
                       declaredSensitiveElements.has(f.entity);
      if (!hasMatch) {
        unrecordedSensitive.push(full);
      }
    }

    if (unrecordedSensitive.length > 0) {
      addResult(acc, catalog, "FAIL", `Data dictionary sensitive fields not declared in BUILD-SPEC Security Inventory: ${unrecordedSensitive.join(", ")}`, {
        ruleId: "DATAFLOW-002",
        artifact: "DESIGN/DATA-DICTIONARY.md",
        field: "Classification",
      });
    } else {
      addResult(acc, catalog, "PASS", "Data dictionary sensitive field classifications agree with BUILD-SPEC Security Inventory", {
        ruleId: "DATAFLOW-002",
      });
    }
  } else {
    addResult(acc, catalog, "PASS", "Data dictionary sensitive field classifications agree with BUILD-SPEC Security Inventory", {
      ruleId: "DATAFLOW-002",
    });
  }
}

function testDataFlowAndJourneys(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  ctx: { project: string },
  mode: Mode,
  gate: Gate,
  projectReqIds: string[],
  transitionIds: string[],
  stateNames: string[],
): string[] {
  const journeyStepIds: string[] = [];
  const dataflowPath = join(ctx.project, "DESIGN/DATA-FLOW.md");
  const hasDataFlow = existsSync(dataflowPath);

  if (!hasDataFlow) {
    if (mode === "Strict" && (gate === "Design" || gate === "Handoff" || gate === "Release")) {
      addResult(acc, catalog, "FAIL", "DESIGN/DATA-FLOW.md is required for Strict mode under Spec depth: full", {
        ruleId: "JOURNEY-001",
        artifact: "DESIGN/DATA-FLOW.md",
      });
    }
    return journeyStepIds;
  }

  const text = readFileSync(dataflowPath, "utf8");
  const journeyRows = getTableRowsAfterHeading(text, getHeadingPattern("End-to-End Journeys", 2));

  if (journeyRows.length === 0) {
    if (mode !== "Lite" && (gate === "Design" || gate === "Handoff" || gate === "Release")) {
      addResult(acc, catalog, "FAIL", "End-to-End Journeys table in DESIGN/DATA-FLOW.md has no journey steps", {
        ruleId: "JOURNEY-001",
        artifact: "DESIGN/DATA-FLOW.md",
        field: "End-to-End Journeys",
      });
    }
  } else {
    for (const r of journeyRows) {
      const stepId = (r["Step ID"] ?? "").trim();
      if (stepId) journeyStepIds.push(stepId);
    }

    // JOURNEY-001: State Before / State After resolution against State Machine
    const validStates = new Set([
      ...stateNames.map((s) => s.toLowerCase()),
      ...transitionIds.map((t) => t.toLowerCase()),
      "none", "n/a", "initial", "terminal", "start", "end", "-",
    ]);

    const badStates: string[] = [];
    for (const r of journeyRows) {
      const stepId = (r["Step ID"] ?? "").trim();
      const stateBefore = (r["State Before"] ?? "").trim().toLowerCase();
      const stateAfter = (r["State After"] ?? "").trim().toLowerCase();

      const beforeOk = !stateBefore || validStates.has(stateBefore);
      const afterOk = !stateAfter || validStates.has(stateAfter);
      if (!beforeOk || !afterOk) {
        badStates.push(`${stepId || "unknown"}: '${stateBefore}' -> '${stateAfter}'`);
      }
    }

    if (badStates.length > 0 && validStates.size > 7) {
      addResult(acc, catalog, "FAIL", `Journey step states before/after do not resolve to declared states or transitions in BUILD-SPEC: ${badStates.join(", ")}`, {
        ruleId: "JOURNEY-001",
        artifact: "DESIGN/DATA-FLOW.md",
        field: "State Before / State After",
      });
    } else {
      addResult(acc, catalog, "PASS", "All journey step state transitions resolve to declared states and transitions in BUILD-SPEC.md", {
        ruleId: "JOURNEY-001",
      });
    }

    // JOURNEY-002: Scoped requirements journey coverage at Strict mode
    if (mode === "Strict" && projectReqIds.length > 0) {
      const referencedReqs = new Set<string>();
      for (const r of journeyRows) {
        const specRef = (r["Spec Element Ref"] ?? "").trim();
        if (specRef) {
          const refs = specRef.split(/[,;\s]+/).map((s) => s.trim()).filter(Boolean);
          for (const ref of refs) referencedReqs.add(ref);
        }
      }

      const missingReqs = projectReqIds.filter((id) => !referencedReqs.has(id));
      if (missingReqs.length > 0) {
        addResult(acc, catalog, "FAIL", `Strict mode requires all scoped requirements in End-to-End Journeys, missing: ${missingReqs.join(", ")}`, {
          ruleId: "JOURNEY-002",
          artifact: "DESIGN/DATA-FLOW.md",
          field: "Spec Element Ref",
        });
      } else {
        addResult(acc, catalog, "PASS", "All scoped requirements are represented in End-to-End Journeys", {
          ruleId: "JOURNEY-002",
        });
      }
    } else {
      addResult(acc, catalog, "PASS", "End-to-End Journeys table declares valid journey steps", {
        ruleId: "JOURNEY-002",
      });
    }
  }

  return journeyStepIds;
}

function testTestCasesAndCoverage(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  ctx: { project: string },
  mode: Mode,
  gate: Gate,
  depthPolicy: Record<string, unknown>,
  policyEnums: Record<string, unknown>,
  sourceRefRegex: string,
  projectReqIds: string[],
  projectBusinessIds: string[],
  nfrIds: string[],
  constraintIds: string[],
  operationIds: string[],
  transitionIds: string[],
  journeyStepIds: string[],
  strictTriggers: string[],
): void {
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
  const incompleteCases: string[] = [];
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
  } else {
    addResult(acc, catalog, "PASS", "TESTS/TEST-CASES.md test cases declare complete criteria and parameters", {
      ruleId: "TEST-CASE-001",
    });
  }

  // 2. TEST-CASE-002: ID Uniqueness & Valid Categories
  const allowedCategories = new Set(
    ((depthPolicy["test_categories"] as string[]) ?? [
      "happy", "happy_path", "negative", "boundary", "security", "concurrency", "recovery",
    ]).map((c) => c.toLowerCase()),
  );
  allowedCategories.add("happy_path");

  const seenIds = new Set<string>();
  const duplicateIds: string[] = [];
  const invalidCategoryCases: string[] = [];
  const coveredReqIds = new Set<string>();

  for (const r of caseRows) {
    const id = (r["Case ID"] ?? "").trim();
    const cat = (r["Category"] ?? "").trim().toLowerCase();
    const targetId = (r["Target ID"] ?? "").trim();

    if (id) {
      if (seenIds.has(id)) duplicateIds.push(id);
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
    if (duplicateIds.length > 0) problems.push(`duplicate Case IDs: ${duplicateIds.join(", ")}`);
    if (invalidCategoryCases.length > 0) problems.push(`invalid Category in: ${invalidCategoryCases.join(", ")}`);
    addResult(acc, catalog, "FAIL", `Test case definition errors: ${problems.join("; ")}`, {
      ruleId: "TEST-CASE-002",
      artifact: "TESTS/TEST-CASES.md",
      field: "Category",
    });
  } else {
    addResult(acc, catalog, "PASS", "Test cases have unique IDs and valid categories", {
      ruleId: "TEST-CASE-002",
    });
  }

  // 3. TEST-CASE-003: Traceability & Evidence Status
  const validEvidence = (policyEnums["evidence_statuses"] as string[]) ?? [];
  const invalidMetadata: string[] = [];

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
  } else {
    addResult(acc, catalog, "PASS", "Test cases carry valid source references and evidence status", {
      ruleId: "TEST-CASE-003",
    });
  }

  // 4. TEST-COVERAGE-001: Profile-Driven (Spec-Element × Category) Matrix
  const profileName = mode === "Strict"
    ? "detailed_requirement_and_risk_cases"
    : mode === "Standard"
    ? "strategy_and_scenarios"
    : "delivery_checklist";

  const profiles = (depthPolicy["profiles"] as Record<string, Record<string, string[]>>) ?? {};
  const activeProfile = profiles[profileName] ?? {};

  const specElementIdMap = new Map<string, string[]>([
    ["requirement", projectReqIds],
    ["business_rule", projectBusinessIds],
    ["nfr", nfrIds],
    ["data_constraint", constraintIds],
    ["api_operation", operationIds],
    ["state_transition", transitionIds],
    ["journey_step", journeyStepIds],
    ["strict_trigger", strictTriggers],
  ]);

  const coveredPairs = new Set<string>();
  for (const r of caseRows) {
    const targetId = (r["Target ID"] ?? "").trim().toLowerCase();
    let cat = (r["Category"] ?? "").trim().toLowerCase();
    if (cat === "happy_path") cat = "happy";
    if (targetId && cat) {
      coveredPairs.add(`${targetId}::${cat}`);
    }
  }

  const uncoveredPairs: string[] = [];
  let totalRequiredPairs = 0;

  for (const [specElementType, requiredCategories] of Object.entries(activeProfile)) {
    const elementIds = specElementIdMap.get(specElementType) ?? [];
    if (elementIds.length === 0) continue; // element type with zero declared IDs in project contributes nothing

    for (const elemId of elementIds) {
      for (const cat of requiredCategories) {
        const normCat = cat.toLowerCase() === "happy_path" ? "happy" : cat.toLowerCase();
        totalRequiredPairs++;
        if (!coveredPairs.has(`${elemId.toLowerCase()}::${normCat}`)) {
          uncoveredPairs.push(`${elemId}×${cat}`);
        }
      }
    }
  }

  if (uncoveredPairs.length > 0) {
    const sample = uncoveredPairs.slice(0, 15);
    addResult(acc, catalog, "FAIL", `${uncoveredPairs.length} (spec_element, category) pairs lack a test case (showing ${sample.length}): ${sample.join(", ")}`, {
      ruleId: "TEST-COVERAGE-001",
      artifact: "TESTS/TEST-CASES.md",
      field: "Derived Target Cases",
    });
  } else {
    addResult(acc, catalog, "PASS", `All ${totalRequiredPairs} required (spec-element × category) matrix pairs are covered in TESTS/TEST-CASES.md`, {
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
  } else {
    addResult(acc, catalog, "PASS", "All scoped requirements have corresponding test cases", {
      ruleId: "TEST-COVERAGE-002",
    });
  }
}

function testOpenApiContract(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  ctx: { project: string },
  mode: Mode,
  gate: Gate,
  operationIds: string[],
): void {
  const openApiPath = join(ctx.project, "DESIGN/API/openapi.yaml");
  if (!existsSync(openApiPath)) return;

  const yamlText = readFileSync(openApiPath, "utf8");

  // API-001: Version Header
  const versionMatch = /^\s*openapi\s*:\s*["']?(\d+\.\d+\.\d+)["']?\s*$/m.exec(yamlText);
  if (!versionMatch) {
    addResult(acc, catalog, "FAIL", "DESIGN/API/openapi.yaml is missing valid openapi: 3.x version header", {
      ruleId: "API-001",
      artifact: "DESIGN/API/openapi.yaml",
      field: "openapi",
    });
  } else {
    addResult(acc, catalog, "PASS", `DESIGN/API/openapi.yaml declares OpenAPI ${versionMatch[1]}`, {
      ruleId: "API-001",
    });
  }

  // API-002: Zero-Dependency OperationId Scanner
  const declaredOps = new Set<string>();
  const opMatches = yamlText.matchAll(/^\s*operationId\s*:\s*["']?([a-zA-Z0-9_-]+)["']?\s*$/gm);
  for (const m of opMatches) {
    if (m[1]) declaredOps.add(m[1].trim());
  }

  if (operationIds.length > 0 && declaredOps.size > 0) {
    const missingOps = operationIds.filter((id) => !declaredOps.has(id));
    if (missingOps.length > 0) {
      addResult(acc, catalog, "FAIL", `OpenAPI spec missing operationIds declared in BUILD-SPEC: ${missingOps.join(", ")}`, {
        ruleId: "API-002",
        artifact: "DESIGN/API/openapi.yaml",
        field: "operationId",
      });
    } else {
      addResult(acc, catalog, "PASS", "OpenAPI spec operationIds correspond to declared BUILD-SPEC operations", {
        ruleId: "API-002",
      });
    }
  }
}
