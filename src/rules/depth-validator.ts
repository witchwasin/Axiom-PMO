// Specification depth validation (WS2, WS3, WS9a, WS9b), gated by `Spec depth: full`.
// Validates SRS completeness (SRS-001..004), Technology Decisions (ARCH-001),
// and Entity Relationships (DATA-003, DATA-004).

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

  const depthPolicy = ctx.depthPolicy ?? {};
  const policyEnums = (ctx.policy?.["enums"] as Record<string, unknown>) ?? {};

  // 1. SRS Validation (SRS-001..004)
  testSrsArtifact(acc, catalog, ctx, mode, gate, depthPolicy, policyEnums, sourceRefRegex);

  // 2. BUILD-SPEC Extended Tables (ARCH-001, DATA-003, DATA-004)
  testBuildSpecDepth(acc, catalog, ctx, mode, gate, decisionIds, sourceRefRegex);
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
): void {
  const srsPath = join(ctx.project, "DESIGN/SRS.md");
  if (!existsSync(srsPath)) {
    if (mode !== "Lite" && (gate === "Design" || gate === "Handoff" || gate === "Release")) {
      addResult(acc, catalog, "FAIL", "DESIGN/SRS.md is required under Spec depth: full but was not found", {
        ruleId: "SRS-001",
        artifact: "DESIGN/SRS.md",
      });
    }
    return;
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
  testSrsNfrTable(acc, catalog, text, mode, policyEnums, sourceRefRegex);
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
): void {
  const specPath = join(ctx.project, "DESIGN/BUILD-SPEC.md");
  if (!existsSync(specPath)) return;
  const text = readFileSync(specPath, "utf8");

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
  const dataModelRows = getTableRowsAfterHeading(text, getHeadingPattern("Data Model", 3));
  const erRows = getTableRowsAfterHeading(text, getHeadingPattern("Entity Relationships", 3));

  if (erRows.length > 0) {
    const knownEntities = new Set<string>();
    const entityAttributes = new Map<string, Set<string>>();

    for (const r of dataModelRows) {
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
}
