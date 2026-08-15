// Handoff gate checks (HANDOFF-001..014, TEST-DESIGN-001/002), ported from
// scripts/lib/handoff-validator.ps1. Reads the declared contract; never infers
// domain meaning.

import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { getTableRowsAfterHeading, getTableLinesAfterHeading, splitReferenceValues, type TableRow } from "../markdown/table-parser.js";
import { sortOrdinal, sortOrdinalUnique } from "../core/ordinal-sort.js";
import { getSha256Hex } from "../digest/sha256-text.js";
import { testPlaceholderValue, testDateValue } from "../config/config-loader.js";
import { resolveReference, type ReferenceTypesConfig } from "../core/reference-resolver.js";
import { testGenericOwner, getHandoffPolicySeverity } from "../core/owner-policy.js";
import { getDecisionDecider } from "./decision-log.js";
import { addResult } from "../core/result-writer.js";
import type { ResultAccumulator, ValidationRules } from "../core/context.js";
import type { Mode, Gate } from "../core/types.js";

function getHeadingPattern(heading: string, level = 2): string {
  return "^\\s*" + "#".repeat(level) + "\\s+" + heading.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\s*$";
}

function getHandoffMetadata(text: string): Record<string, string> {
  const meta: Record<string, string> = {};
  for (const line of text.split(/\r?\n/)) {
    if (/^\s*##/.test(line)) break;
    const m = /^\s*[-*]\s*([^:]+?)\s*:\s*(.*)$/.exec(line);
    if (m) meta[m[1]!.trim()] = m[2]!.trim();
  }
  return meta;
}

function getSourceSnapshotDigest(projectText: string): string | null {
  const rows: TableRow[] = [
    ...getTableRowsAfterHeading(projectText, "^##\\s+Source Snapshot"),
    ...getTableRowsAfterHeading(projectText, "^##\\s+Source Inventory"),
  ];
  if (rows.length === 0) return null;
  const lines = rows.map((row) => Object.entries(row).map(([k, v]) => `${k}=${v}`.trim()).join("|"));
  return getSha256Hex(sortOrdinal(lines).join("\n"));
}

function getReviewInputDigest(project: string, handoffPolicy: Record<string, unknown>): string | null {
  const freshness = (handoffPolicy["semantic_review"] as Record<string, unknown>)?.["freshness"] as Record<string, unknown>;
  const files = (freshness?.["review_input_files"] as string[]) ?? [];
  if (files.length === 0) return null;
  const parts: string[] = [];
  for (const relativePath of sortOrdinal(files)) {
    const path = join(project, relativePath);
    if (!existsSync(path)) {
      parts.push(`${relativePath}\n<absent>`);
      continue;
    }
    let content = readFileSync(path, "utf8");
    const normalized = content.replace(/\r\n/g, "\n").replace(/[ \t]+(?=\n)/g, "");
    parts.push(`${relativePath}\n${normalized.trimEnd()}`);
  }
  return getSha256Hex(parts.join("\n--\n"));
}

function resolveLeadingReference(value: string, decisionIds: string[] | null, requirementIds: string[] | null, ctx: { project: string; referenceTypesConfig: ReferenceTypesConfig }): boolean {
  const trimmed = value.trim();
  if (trimmed.length === 0) return false;
  const token = trimmed.split(/[\s,;]+/)[0]!.trim().replace(/[.:]+$/, "");
  if (token.length === 0) return false;
  const result = resolveReference(token, ctx.referenceTypesConfig, ctx.project, decisionIds, requirementIds);
  return result.resolved;
}

function getTableHeaderCells(text: string, heading: string, level = 2): string[] | null {
  const lines = getTableLinesAfterHeading(text, getHeadingPattern(heading, level));
  if (lines.length < 2) return null;
  const parts = lines[0]!.split("|");
  const cells: string[] = [];
  for (let i = 1; i < parts.length - 1; i++) cells.push(parts[i]!.trim());
  return cells;
}

interface HandoffState {
  ownerProblems: number;
  headerOk: boolean;
}

function testTableHeader(acc: ResultAccumulator, catalog: ValidationRules | undefined, text: string, heading: string, level: number, expected: string[], artifact: string, handoffPolicy: Record<string, unknown>, state: HandoffState): boolean {
  const policy = handoffPolicy["table_headers"] as Record<string, unknown> | undefined;
  if (!policy || policy["enforce"] !== true) return true;
  if (!expected || expected.length === 0) return true;

  const actual = getTableHeaderCells(text, heading, level);
  if (actual === null) return true;

  const expectedList = expected;
  if (actual.join("|") === expectedList.join("|")) return true;

  const sameSet = sortOrdinal(actual).join("|") === sortOrdinal(expectedList).join("|");
  if (sameSet && policy["order_matters"] === true) {
    addResult(acc, catalog, "FAIL", `Table '${heading}' has the declared columns in a different order (expected: ${expectedList.join(" | ")})`, { ruleId: "HANDOFF-013", blocking: true, artifact, field: heading });
    state.headerOk = false;
    return false;
  }

  const missing = expectedList.filter((e) => !actual.includes(e));
  const unexpected = actual.filter((a) => !expectedList.includes(a));
  const detail: string[] = [];
  if (missing.length > 0) detail.push(`missing: ${missing.join(", ")}`);
  if (unexpected.length > 0) detail.push(`unexpected: ${unexpected.join(", ")}`);
  addResult(acc, catalog, "FAIL", `Table '${heading}' header does not match the declared columns (${detail.join("; ")})`, { ruleId: "HANDOFF-013", blocking: true, artifact, field: heading });
  state.headerOk = false;
  return false;
}

function getDeclaredProjectCode(projectText: string, handoffPolicy: Record<string, unknown>): string | null {
  const pattern = String((handoffPolicy["project_identity"] as Record<string, unknown>)?.["authority_pattern"] ?? "");
  if (!pattern.trim()) return null;
  const m = new RegExp(pattern, "m").exec(projectText);
  return m ? m[1]!.trim() : null;
}

function getSectionBody(text: string, heading: string, level = 2): string | null {
  const lines = text.split(/\r?\n/);
  const pattern = new RegExp(getHeadingPattern(heading, level));
  let start = -1;
  for (let i = 0; i < lines.length; i++) {
    if (pattern.test(lines[i]!)) { start = i; break; }
  }
  if (start < 0) return null;
  const body: string[] = [];
  for (let i = start + 1; i < lines.length; i++) {
    if (new RegExp(`^\\s*#{1,${level}}\\s+`).test(lines[i]!)) break;
    body.push(lines[i]!);
  }
  return body.join("\n");
}

export function testHandoffReadiness(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  ctx: { project: string; referenceTypesConfig: ReferenceTypesConfig; handoffPolicy: Record<string, unknown> },
  mode: Mode,
  gate: Gate,
  workItems: TableRow[],
  deliveryIds: string[],
  projectReqIds: string[],
  decisionIds: string[] | null,
  projectText: string,
): void {
  const handoffPolicy = ctx.handoffPolicy;
  const state: HandoffState = { ownerProblems: 0, headerOk: true };
  const ownerPolicy = (handoffPolicy["owner_policy"] as Record<string, unknown>) ?? {};
  const ownerLevel = getHandoffPolicySeverity((ownerPolicy["severity_by_mode"] as Record<string, unknown>) ?? null, mode);
  const handoffDoc = (handoffPolicy["handoff_document"] as Record<string, unknown>) ?? {};
  const handoffPath = join(ctx.project, "HANDOFF.md");

  if (!existsSync(handoffPath)) {
    addResult(acc, catalog, "FAIL", "HANDOFF.md is required at the Handoff gate but was not found", { ruleId: "HANDOFF-001", blocking: true, artifact: "HANDOFF.md" });
    return;
  }
  const handoffText = readFileSync(handoffPath, "utf8");

  // HANDOFF-001 metadata
  const meta = getHandoffMetadata(handoffText);
  const metaProblems: string[] = [];
  let handoffTarget = "";
  for (const field of (handoffDoc["metadata_fields"] as Array<Record<string, unknown>>) ?? []) {
    const key = String(field["key"]);
    let isRequired = field["required"] === true;
    if (field["required_modes"]) isRequired = ((field["required_modes"] as string[]) ?? []).includes(mode);
    if (!isRequired) continue;

    if (!(key in meta)) {
      metaProblems.push(key);
      continue;
    }
    const value = meta[key]!;
    if (testPlaceholderValue(value)) {
      metaProblems.push(key);
      continue;
    }
    if (field["owner_field"] === true && testGenericOwner(value, ownerPolicy)) {
      addResult(acc, catalog, ownerLevel, `Handoff metadata '${key}' is a generic placeholder, not a named person`, { ruleId: "HANDOFF-003", blocking: true, artifact: "HANDOFF.md", field: key });
      state.ownerProblems++;
    }
    if (key === "Handoff Target") handoffTarget = value.toLowerCase();
    if (key === "Mode" && value !== mode) metaProblems.push(`${key} says '${value}' but the effective mode is '${mode}'`);
    if (key === "Horizon" && !testDateValue(value)) metaProblems.push(`${key} '${value}' is not an ISO-8601 date (yyyy-MM-dd)`);
    if (key === "Build Spec Ref" && !existsSync(join(ctx.project, value))) metaProblems.push(`${key} points at '${value}', which does not exist`);
  }
  if (metaProblems.length > 0) {
    addResult(acc, catalog, "FAIL", `HANDOFF.md metadata is incomplete: ${metaProblems.join(", ")}`, { ruleId: "HANDOFF-001", blocking: true, artifact: "HANDOFF.md" });
  } else {
    addResult(acc, catalog, "PASS", "HANDOFF.md declares complete handoff metadata", { ruleId: "HANDOFF-001" });
  }

  testHandoffProjectIdentity(acc, catalog, ctx.project, projectText, meta, handoffPolicy);

  if (handoffTarget && !((handoffPolicy["handoff_targets"] as string[]) ?? []).includes(handoffTarget)) {
    addResult(acc, catalog, "FAIL", `Handoff Target '${handoffTarget}' is not one of: ${((handoffPolicy["handoff_targets"] as string[]) ?? []).join(", ")}`, { ruleId: "HANDOFF-001", blocking: true, artifact: "HANDOFF.md", field: "Handoff Target" });
  }

  const buildSpecRequired = (((handoffPolicy["required_artifacts"] as Record<string, unknown>)?.[mode] as string[]) ?? []).includes("DESIGN/BUILD-SPEC.md");
  const buildSpecPath = join(ctx.project, "DESIGN/BUILD-SPEC.md");
  const buildSpecExists = existsSync(buildSpecPath);
  if (buildSpecRequired && !buildSpecExists) {
    addResult(acc, catalog, "FAIL", `DESIGN/BUILD-SPEC.md is required for ${mode} handoff but was not found`, { ruleId: "HANDOFF-001", blocking: true, artifact: "DESIGN/BUILD-SPEC.md" });
  }

  // HANDOFF-002 sections
  const sectionRows: Record<string, TableRow[]> = {};
  let headerOk = true;
  const deferredNoneToken = String(handoffDoc["deferred_explicit_none_token"] ?? "none");
  for (const section of (handoffDoc["sections"] as Array<Record<string, unknown>>) ?? []) {
    const heading = String(section["heading"]);
    const rows = getTableRowsAfterHeading(handoffText, getHeadingPattern(heading, 2));
    sectionRows[heading] = rows;

    if (section["table"] === true && section["columns"]) {
      if (!testTableHeader(acc, catalog, handoffText, heading, 2, (section["columns"] as string[]), "HANDOFF.md", handoffPolicy, state)) headerOk = false;
    }

    let applies = true;
    if (section["required_targets"]) applies = ((section["required_targets"] as string[]) ?? []).includes(handoffTarget);
    else if (section["required"] !== true) applies = false;
    if (!applies) continue;

    const minRows = section["min_rows"] !== undefined ? Number(section["min_rows"]) : 0;
    if (rows.length >= Math.max(minRows, 1)) continue;

    if (rows.length === 0 && minRows === 0 && section["allow_explicit_none"] === true) {
      const body = getSectionBody(handoffText, heading, 2);
      if (body && new RegExp(`^\\s*${deferredNoneToken.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`, "im").test(body)) continue;
    }

    const ruleId = section["rule"] ? String(section["rule"]) : "HANDOFF-002";
    addResult(acc, catalog, "FAIL", `HANDOFF.md section '${heading}' has no entries and no explicit 'none' declaration`, { ruleId, blocking: true, artifact: "HANDOFF.md", field: heading });
  }

  const buildNowRows = sectionRows["Build Now"] ?? [];
  const unresolvedBuildNow: string[] = [];
  for (const row of buildNowRows) {
    for (const ref of splitReferenceValues(row["Work Item Ref"] ?? "")) {
      if (!deliveryIds.includes(ref)) unresolvedBuildNow.push(ref);
    }
    if (testGenericOwner(row["Owner"] ?? "", ownerPolicy)) {
      addResult(acc, catalog, ownerLevel, `Build Now item '${row["Item"]}' has no named owner`, { ruleId: "HANDOFF-003", blocking: true, artifact: "HANDOFF.md", itemId: String(row["Item"] ?? ""), field: "Owner" });
      state.ownerProblems++;
    }
  }
  if (unresolvedBuildNow.length > 0) {
    addResult(acc, catalog, "FAIL", `Build Now references work items that do not exist in DELIVERY.md: ${sortOrdinalUnique(unresolvedBuildNow).join(", ")}`, { ruleId: "HANDOFF-002", blocking: true, artifact: "HANDOFF.md", field: "Work Item Ref" });
  } else if (buildNowRows.length > 0) {
    addResult(acc, catalog, "PASS", "Build Now scope resolves to declared work items", { ruleId: "HANDOFF-002" });
  }

  // HANDOFF-003
  const buildNowRefs = sortOrdinalUnique(buildNowRows.flatMap((r) => splitReferenceValues(r["Work Item Ref"] ?? "")));
  const unownedItems: string[] = [];
  for (const item of workItems) {
    if (!buildNowRefs.includes(item["ID"] ?? "")) continue;
    if (testGenericOwner(item["Owner"] ?? "", ownerPolicy)) unownedItems.push(item["ID"]!);
  }
  if (unownedItems.length > 0) {
    addResult(acc, catalog, ownerLevel, `Work items in the handoff scope have no named owner: ${unownedItems.join(", ")}`, { ruleId: "HANDOFF-003", blocking: true, artifact: "DELIVERY.md", field: "Owner" });
    state.ownerProblems++;
  }

  // HANDOFF-004
  testHandoffBuildSequence(acc, catalog, handoffText, sectionRows["Build Sequence and Dependencies"] ?? [], buildNowRefs, deliveryIds, ownerPolicy, ownerLevel, state);

  if (state.ownerProblems === 0) {
    addResult(acc, catalog, "PASS", "Every owner in the handoff scope names a person, in HANDOFF.md and DELIVERY.md", { ruleId: "HANDOFF-003" });
  }

  // HANDOFF-009
  testHandoffOpenActions(acc, catalog, sectionRows["Open Actions"] ?? [], handoffPolicy, ownerPolicy, ownerLevel);

  // HANDOFF-008
  if (handoffDoc["demo_milestone_fields"] && ["demo", "pilot"].includes(handoffTarget)) {
    testHandoffDemoMilestone(acc, catalog, sectionRows["Demo Milestone"] ?? [], handoffPolicy, ownerPolicy);
  }

  // HANDOFF-012
  testHandoffEnvironmentMatrix(acc, catalog, sectionRows["Environment and Device Matrix"] ?? [], handoffPolicy, decisionIds, ctx);

  // HANDOFF-005/006/007/011/012
  if (buildSpecExists) {
    testBuildSpec(acc, catalog, ctx.project, mode, handoffTarget, handoffPolicy, projectReqIds, decisionIds, projectText, ctx, state);
  }

  if (headerOk && state.headerOk) {
    addResult(acc, catalog, "PASS", "Every governed table header matches the columns the policy declares", { ruleId: "HANDOFF-013" });
  }

  // HANDOFF-010
  testHandoffSemanticReview(acc, catalog, ctx.project, mode, handoffPolicy, projectText, decisionIds, ctx);
}

function testHandoffProjectIdentity(acc: ResultAccumulator, catalog: ValidationRules | undefined, project: string, projectText: string, metadata: Record<string, string>, handoffPolicy: Record<string, unknown>): void {
  const policy = handoffPolicy["project_identity"] as Record<string, unknown> | undefined;
  if (!policy || policy["enforce"] !== true) return;

  const declared = getDeclaredProjectCode(projectText, handoffPolicy);
  if (!declared || !declared.trim()) return;

  const mismatches: Array<{ artifact: string; field: string; value: string }> = [];
  for (const target of (policy["cross_checked"] as Array<Record<string, unknown>>) ?? []) {
    const artifact = String(target["artifact"]);
    const field = String(target["field"]);
    let actual: string | null = null;

    if (String(target["kind"]) === "metadata") {
      if (field in metadata) actual = metadata[field]!;
    } else {
      const path = join(project, artifact);
      if (!existsSync(path)) continue;
      try {
        const doc = JSON.parse(readFileSync(path, "utf8")) as Record<string, unknown>;
        if (field in doc) actual = String(doc[field]);
      } catch {
        continue;
      }
    }

    if (!actual || !actual.trim()) continue;
    if (actual.trim() !== declared) mismatches.push({ artifact, field, value: actual.trim() });
  }

  if (mismatches.length > 0) {
    for (const m of mismatches) {
      addResult(acc, catalog, "FAIL", `${m.artifact} names project '${m.value}' but PROJECT.md declares '${declared}'`, { ruleId: "HANDOFF-014", blocking: true, artifact: m.artifact, field: m.field });
    }
  } else {
    addResult(acc, catalog, "PASS", "Handoff artifacts agree with PROJECT.md on the project code", { ruleId: "HANDOFF-014" });
  }
}

function testHandoffBuildSequence(acc: ResultAccumulator, catalog: ValidationRules | undefined, handoffText: string, rows: TableRow[], buildNowRefs: string[], deliveryIds: string[], ownerPolicy: Record<string, unknown>, ownerLevel: "WARN" | "FAIL", state: HandoffState): void {
  if (rows.length === 0) return;
  const problems: string[] = [];
  const stepOf: Record<string, number> = {};
  const seenSteps: Record<string, boolean> = {};

  for (const row of rows) {
    const step = (row["Step"] ?? "").trim();
    if (!/^\d+$/.test(step)) {
      problems.push(`step '${step}' is not a number`);
      continue;
    }
    if (seenSteps[step]) problems.push(`step ${step} is used more than once`);
    seenSteps[step] = true;
    for (const ref of splitReferenceValues(row["Work Item Ref"] ?? "")) stepOf[ref] = Number.parseInt(step, 10);
  }

  for (const row of rows) {
    const refs = splitReferenceValues(row["Work Item Ref"] ?? "");
    for (const ref of refs) {
      if (!deliveryIds.includes(ref)) problems.push(`${ref} is sequenced but is not a DELIVERY.md work item`);
    }
    if (testGenericOwner(row["Owner"] ?? "", ownerPolicy)) {
      addResult(acc, catalog, ownerLevel, `Build sequence step ${row["Step"]} has no named owner`, { ruleId: "HANDOFF-003", blocking: true, artifact: "HANDOFF.md", itemId: `step ${row["Step"]}`, field: "Owner" });
      state.ownerProblems++;
    }

    const dependsRaw = (row["Depends On"] ?? "").trim();
    if (dependsRaw.length === 0 || testPlaceholderValue(dependsRaw)) {
      problems.push(`step ${row["Step"]} does not declare its dependencies (use 'none' when there are none)`);
      continue;
    }
    if (dependsRaw.toLowerCase() === "none") continue;

    const consumerStep = refs.length > 0 && stepOf[refs[0]!] !== undefined ? stepOf[refs[0]!] : null;
    for (const dep of splitReferenceValues(dependsRaw)) {
      if (stepOf[dep] === undefined) {
        problems.push(`step ${row["Step"]} depends on ${dep}, which is not scheduled anywhere in the sequence`);
        continue;
      }
      if (consumerStep !== null && consumerStep !== undefined && stepOf[dep]! >= consumerStep) {
        problems.push(`step ${row["Step"]} depends on ${dep}, which is scheduled at step ${stepOf[dep]} (not before it)`);
      }
    }
  }

  for (const ref of buildNowRefs) {
    if (stepOf[ref] === undefined) problems.push(`${ref} is in Build Now but has no place in the build sequence`);
  }

  if (problems.length > 0) {
    for (const problem of sortOrdinalUnique(problems)) {
      addResult(acc, catalog, "FAIL", `Build sequence is not executable as declared: ${problem}`, { ruleId: "HANDOFF-004", blocking: true, artifact: "HANDOFF.md", field: "Build Sequence and Dependencies" });
    }
  } else {
    addResult(acc, catalog, "PASS", "Build sequence is complete and dependency-ordered", { ruleId: "HANDOFF-004" });
  }
}

function testHandoffOpenActions(acc: ResultAccumulator, catalog: ValidationRules | undefined, rows: TableRow[], handoffPolicy: Record<string, unknown>, ownerPolicy: Record<string, unknown>, ownerLevel: "WARN" | "FAIL"): void {
  if (rows.length === 0) {
    addResult(acc, catalog, "PASS", "No open actions declared at handoff", { ruleId: "HANDOFF-009" });
    return;
  }
  const validPoints = (handoffPolicy["blocking_points"] as string[]) ?? [];
  let problems = 0;
  for (const row of rows) {
    const actionId = (row["Action ID"] ?? "").trim();
    const point = (row["Blocking Point"] ?? "").trim();
    if (point.length === 0 || testPlaceholderValue(point) || !validPoints.includes(point)) {
      addResult(acc, catalog, "FAIL", `Open action ${actionId} has no valid blocking point (expected one of: ${validPoints.join(", ")})`, { ruleId: "HANDOFF-009", blocking: true, artifact: "HANDOFF.md", itemId: actionId, field: "Blocking Point" });
      problems++;
    }
    if (testGenericOwner(row["Owner"] ?? "", ownerPolicy)) {
      addResult(acc, catalog, "FAIL", `Open action ${actionId} has no named owner`, { ruleId: "HANDOFF-009", blocking: true, artifact: "HANDOFF.md", itemId: actionId, field: "Owner" });
      problems++;
    }
  }
  if (problems === 0) addResult(acc, catalog, "PASS", "Every open action has an owner and a blocking point", { ruleId: "HANDOFF-009" });
}

function testHandoffDemoMilestone(acc: ResultAccumulator, catalog: ValidationRules | undefined, rows: TableRow[], handoffPolicy: Record<string, unknown>, ownerPolicy: Record<string, unknown>): void {
  const lookup: Record<string, string> = {};
  for (const row of rows) {
    const key = (row["Field"] ?? "").trim();
    if (key.length > 0) lookup[key] = (row["Value"] ?? "").trim();
  }
  const missing: string[] = [];
  for (const field of ((handoffPolicy["handoff_document"] as Record<string, unknown>)["demo_milestone_fields"] as Array<Record<string, unknown>>) ?? []) {
    const key = String(field["key"]);
    if (field["required"] !== true) continue;
    if (!(key in lookup) || testPlaceholderValue(lookup[key]!)) {
      missing.push(key);
      continue;
    }
    if (field["owner_field"] === true && testGenericOwner(lookup[key]!, ownerPolicy)) missing.push(`${key} (generic, not a named person)`);
  }
  if (missing.length > 0) {
    addResult(acc, catalog, "FAIL", `Demo milestone is not operable as declared -- missing: ${missing.join(", ")}`, { ruleId: "HANDOFF-008", blocking: true, artifact: "HANDOFF.md", field: "Demo Milestone" });
  } else {
    addResult(acc, catalog, "PASS", "Demo milestone declares device, integrator, capacity, and reset path", { ruleId: "HANDOFF-008" });
  }
}

function testHandoffEnvironmentMatrix(acc: ResultAccumulator, catalog: ValidationRules | undefined, rows: TableRow[], handoffPolicy: Record<string, unknown>, decisionIds: string[] | null, ctx: { project: string; referenceTypesConfig: ReferenceTypesConfig }): void {
  if (rows.length === 0) return;
  const unresolved = ((handoffPolicy["environment_capabilities"] as Record<string, unknown>)?.["unresolved_tokens"] as string[]) ?? [];
  const problems: Array<{ env: string; column: string; reason: string }> = [];
  for (const row of rows) {
    const env = (row["Environment"] ?? "").trim();
    for (const column of ["Serving Model", "Decision Ref"]) {
      const value = (row[column] ?? "").trim();
      let isUnresolved = value.length === 0 || testPlaceholderValue(value);
      for (const token of unresolved) {
        if (value.toLowerCase() === token.trim().toLowerCase()) isUnresolved = true;
      }
      if (isUnresolved) {
        problems.push({ env, column, reason: "is unresolved" });
        continue;
      }
      if (column === "Decision Ref" && !resolveLeadingReference(value, decisionIds, null, ctx)) {
        problems.push({ env, column, reason: "does not lead with a resolvable reference" });
      }
    }
  }
  if (problems.length > 0) {
    for (const p of problems) {
      addResult(acc, catalog, "FAIL", `Environment '${p.env}' ${p.column} ${p.reason}; a developer cannot pick a runtime from this`, { ruleId: "HANDOFF-012", blocking: true, artifact: "HANDOFF.md", itemId: p.env, field: p.column });
    }
  } else {
    addResult(acc, catalog, "PASS", "Environment and device matrix declares a resolved serving model for every environment", { ruleId: "HANDOFF-012" });
  }
}

function testBuildSpec(acc: ResultAccumulator, catalog: ValidationRules | undefined, project: string, mode: Mode, handoffTarget: string, handoffPolicy: Record<string, unknown>, projectReqIds: string[], decisionIds: string[] | null, projectText: string, ctx: { project: string; referenceTypesConfig: ReferenceTypesConfig }, state: HandoffState): void {
  const spec = handoffPolicy["build_spec"] as Record<string, unknown>;
  const text = readFileSync(join(project, "DESIGN/BUILD-SPEC.md"), "utf8");
  const statusMarker = String(spec["status_marker"]);
  const rationaleMarker = String(spec["rationale_marker"]);
  const minWords = Number((spec["not_required_policy"] as Record<string, unknown>)["min_rationale_words"]);

  const sectionProblems: string[] = [];
  for (const section of (spec["sections"] as Array<Record<string, unknown>>) ?? []) {
    const heading = String(section["heading"]);
    let applies = false;
    if (section["required_modes"] && ((section["required_modes"] as string[]) ?? []).includes(mode)) applies = true;
    if (section["required_targets"] && ((section["required_targets"] as string[]) ?? []).includes(handoffTarget)) applies = true;
    if (applies && section["required_declarations"]) {
      for (const declaration of (section["required_declarations"] as string[]) ?? []) {
        if (!new RegExp(`^\\s*>?\\s*${String(declaration).replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}:`, "m").test(projectText)) { applies = false; break; }
      }
    }
    if (!applies) continue;

    const body = getSectionBody(text, heading, 3);
    if (body === null) {
      sectionProblems.push(`'${heading}' is missing`);
      continue;
    }

    let status: string | null = null;
    const statusMatch = new RegExp(`^\\s*${statusMarker.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*:\\s*(\\S+)\\s*$`, "im").exec(body);
    if (statusMatch) status = statusMatch[1]!.trim().toLowerCase();
    if (!status) {
      sectionProblems.push(`'${heading}' does not declare a ${statusMarker} line`);
      continue;
    }
    const statusValues = (spec["status_values"] as string[]) ?? [];
    if (!statusValues.includes(status)) {
      sectionProblems.push(`'${heading}' has ${statusMarker} '${status}', expected one of: ${statusValues.join(", ")}`);
      continue;
    }

    if (status === "not_required") {
      if (section["allow_not_required"] !== true) {
        sectionProblems.push(`'${heading}' is marked not_required but policy does not allow waiving it`);
        continue;
      }
      let rationale = "";
      const rm = new RegExp(`^\\s*${rationaleMarker.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*:\\s*(.+)$`, "im").exec(body);
      if (rm) rationale = rm[1]!.trim();
      if (rationale.length === 0 || testPlaceholderValue(rationale)) sectionProblems.push(`'${heading}' is marked not_required without a ${rationaleMarker}`);
      else if (rationale.split(/\s+/).length < minWords) sectionProblems.push(`'${heading}' has a ${rationaleMarker} shorter than ${minWords} words`);
      continue;
    }

    const contentLines = body.split(/\r?\n/).filter((l) => {
      const t = l.trim();
      return t.length > 0 && !new RegExp(`^${statusMarker.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*:`).test(t);
    });
    if (contentLines.length === 0) {
      sectionProblems.push(`'${heading}' is marked specified but has no content`);
      continue;
    }
    if (section["table"] === true) {
      const rows = getTableRowsAfterHeading(text, getHeadingPattern(heading, 3));
      if (rows.length === 0) sectionProblems.push(`'${heading}' is marked specified but its table has no rows`);
      if (section["columns"]) {
        if (!testTableHeader(acc, catalog, text, heading, 3, (section["columns"] as string[]), "DESIGN/BUILD-SPEC.md", handoffPolicy, state)) {
          state.headerOk = false;
        }
      }
    }
  }

  if (sectionProblems.length > 0) {
    for (const problem of sectionProblems) {
      addResult(acc, catalog, "FAIL", `BUILD-SPEC section ${problem}`, { ruleId: "HANDOFF-005", blocking: true, artifact: "DESIGN/BUILD-SPEC.md" });
    }
  } else {
    addResult(acc, catalog, "PASS", `BUILD-SPEC declares every section required for ${mode} handoff`, { ruleId: "HANDOFF-005" });
  }

  testBuildSpecAcceptanceCases(acc, catalog, text, handoffPolicy, projectReqIds);
  testBuildSpecDataInventory(acc, catalog, text, handoffPolicy, decisionIds, ctx);
  testBuildSpecCapabilities(acc, catalog, text, handoffPolicy, decisionIds, ctx);
}

function testBuildSpecAcceptanceCases(acc: ResultAccumulator, catalog: ValidationRules | undefined, text: string, handoffPolicy: Record<string, unknown>, projectReqIds: string[]): void {
  const rows = getTableRowsAfterHeading(text, getHeadingPattern("Acceptance Cases", 3));
  if (rows.length === 0) return;
  const classes = ((handoffPolicy["acceptance_cases"] as Record<string, unknown>)?.["execution_classes"] as string[]) ?? [];
  let missingClass = 0;
  let missingFixture = 0;

  for (const row of rows) {
    const caseId = (row["Case ID"] ?? "").trim();
    const requirementRef = (row["Requirement Ref"] ?? "").trim();
    const unresolvedReqs = splitReferenceValues(requirementRef).filter((r) => !projectReqIds.includes(r));
    if (requirementRef.length === 0 || testPlaceholderValue(requirementRef)) {
      addResult(acc, catalog, "FAIL", `Acceptance case ${caseId} cites no requirement`, { ruleId: "HANDOFF-006", blocking: true, artifact: "DESIGN/BUILD-SPEC.md", itemId: caseId, field: "Requirement Ref" });
      missingClass++;
    } else if (unresolvedReqs.length > 0) {
      addResult(acc, catalog, "FAIL", `Acceptance case ${caseId} cites requirements not declared in PROJECT.md: ${unresolvedReqs.join(", ")}`, { ruleId: "HANDOFF-006", blocking: true, artifact: "DESIGN/BUILD-SPEC.md", itemId: caseId, field: "Requirement Ref" });
      missingClass++;
    }

    const execution = (row["Execution"] ?? "").trim().toLowerCase();
    if (execution.length === 0 || !classes.includes(execution)) {
      addResult(acc, catalog, "FAIL", `Acceptance case ${caseId} has no execution class (expected one of: ${classes.join(", ")})`, { ruleId: "HANDOFF-006", blocking: true, artifact: "DESIGN/BUILD-SPEC.md", itemId: caseId, field: "Execution" });
      missingClass++;
    }

    const fixture = (row["Fixture / Seed"] ?? "").trim();
    if (fixture.length === 0 || testPlaceholderValue(fixture)) {
      addResult(acc, catalog, "FAIL", `Acceptance case ${caseId} declares no seed or fixture strategy`, { ruleId: "HANDOFF-007", blocking: true, artifact: "DESIGN/BUILD-SPEC.md", itemId: caseId, field: "Fixture / Seed" });
      missingFixture++;
    }
    const reset = (row["Reset"] ?? "").trim();
    if (reset.length === 0 || testPlaceholderValue(reset)) {
      addResult(acc, catalog, "FAIL", `Acceptance case ${caseId} declares no reset strategy`, { ruleId: "HANDOFF-007", blocking: true, artifact: "DESIGN/BUILD-SPEC.md", itemId: caseId, field: "Reset" });
      missingFixture++;
    }
  }

  if (missingClass === 0) addResult(acc, catalog, "PASS", "Every acceptance case is classified automated or manual", { ruleId: "HANDOFF-006" });
  if (missingFixture === 0) addResult(acc, catalog, "PASS", "Every acceptance case declares seed and reset strategy", { ruleId: "HANDOFF-007" });
}

function testBuildSpecDataInventory(acc: ResultAccumulator, catalog: ValidationRules | undefined, text: string, handoffPolicy: Record<string, unknown>, decisionIds: string[] | null, ctx: { project: string; referenceTypesConfig: ReferenceTypesConfig }): void {
  const rows = getTableRowsAfterHeading(text, getHeadingPattern("Security, Privacy and Data Inventory", 3));
  if (rows.length === 0) return;
  const sensitiveData = (handoffPolicy["sensitive_data"] as Record<string, unknown>) ?? {};
  const yesValues = (sensitiveData["declared_yes_values"] as string[]) ?? [];
  const noValues = (sensitiveData["declared_no_values"] as string[]) ?? [];
  const requireExplicit = sensitiveData["requires_explicit_declaration"] === true;
  let problems = 0;

  for (const row of rows) {
    const element = (row["Data Element"] ?? "").trim();
    const declared = (row["Contains Sensitive Data"] ?? "").trim().toLowerCase();
    let isSensitive = yesValues.some((v) => declared === v.toLowerCase());
    const isNotSensitive = noValues.some((v) => declared === v.toLowerCase());

    if (requireExplicit && !isSensitive && !isNotSensitive) {
      addResult(acc, catalog, "FAIL", `Data element '${element}' does not declare whether it contains sensitive data (expected one of: ${[...yesValues, ...noValues].join(", ")})`, { ruleId: "HANDOFF-011", blocking: true, artifact: "DESIGN/BUILD-SPEC.md", itemId: element, field: "Contains Sensitive Data" });
      problems++;
      continue;
    }
    if (!isSensitive) continue;

    for (const column of ["Classification Decision", "Retention Decision"]) {
      const value = (row[column] ?? "").trim();
      if (value.length === 0 || testPlaceholderValue(value)) {
        addResult(acc, catalog, "FAIL", `Data element '${element}' is declared sensitive but has no ${column}`, { ruleId: "HANDOFF-011", blocking: true, artifact: "DESIGN/BUILD-SPEC.md", itemId: element, field: column });
        problems++;
      } else if (!resolveLeadingReference(value, decisionIds, null, ctx)) {
        addResult(acc, catalog, "FAIL", `Data element '${element}' ${column} '${value}' does not lead with a resolvable decision reference`, { ruleId: "HANDOFF-011", blocking: true, artifact: "DESIGN/BUILD-SPEC.md", itemId: element, field: column });
        problems++;
      }
    }
  }

  if (problems === 0) addResult(acc, catalog, "PASS", "Every data element declared sensitive carries a classification and retention decision", { ruleId: "HANDOFF-011" });
}

function testBuildSpecCapabilities(acc: ResultAccumulator, catalog: ValidationRules | undefined, text: string, handoffPolicy: Record<string, unknown>, decisionIds: string[] | null, ctx: { project: string; referenceTypesConfig: ReferenceTypesConfig }): void {
  const rows = getTableRowsAfterHeading(text, getHeadingPattern("Target Devices and Runtime Capabilities", 3));
  if (rows.length === 0) return;
  const unresolved = ((handoffPolicy["environment_capabilities"] as Record<string, unknown>)?.["unresolved_tokens"] as string[]) ?? [];
  let problems = 0;

  for (const row of rows) {
    const capability = (row["Capability"] ?? "").trim();
    for (const column of ["Serving Model", "Environment Decision"]) {
      const value = (row[column] ?? "").trim();
      let bad = value.length === 0 || testPlaceholderValue(value);
      for (const token of unresolved) {
        if (value.toLowerCase() === token.trim().toLowerCase()) bad = true;
      }
      if (bad) {
        addResult(acc, catalog, "FAIL", `Runtime capability '${capability}' has an unresolved ${column}`, { ruleId: "HANDOFF-012", blocking: true, artifact: "DESIGN/BUILD-SPEC.md", itemId: capability, field: column });
        problems++;
      } else if (column === "Environment Decision" && !resolveLeadingReference(value, decisionIds, null, ctx)) {
        addResult(acc, catalog, "FAIL", `Runtime capability '${capability}' ${column} '${value}' does not lead with a resolvable decision reference`, { ruleId: "HANDOFF-012", blocking: true, artifact: "DESIGN/BUILD-SPEC.md", itemId: capability, field: column });
        problems++;
      }
    }
  }

  if (problems === 0) addResult(acc, catalog, "PASS", "Every declared runtime capability has a resolved serving model and environment decision", { ruleId: "HANDOFF-012" });
}

function testHandoffSemanticReview(acc: ResultAccumulator, catalog: ValidationRules | undefined, project: string, mode: Mode, handoffPolicy: Record<string, unknown>, projectText: string, decisionIds: string[] | null, ctx: { project: string; referenceTypesConfig: ReferenceTypesConfig }): void {
  const reviewPolicy = (handoffPolicy["semantic_review"] as Record<string, unknown>) ?? {};
  const reviewPath = join(project, String(reviewPolicy["artifact"]));
  const missingLevel = getHandoffPolicySeverity((reviewPolicy["severity_when_missing"] as Record<string, unknown>) ?? null, mode, "warn");
  const isRequired = ((reviewPolicy["required_modes"] as string[]) ?? []).includes(mode);

  if (!existsSync(reviewPath)) {
    if (isRequired) {
      addResult(acc, catalog, missingLevel, `${reviewPolicy["artifact"]} is missing; handoff readiness rests on deterministic checks alone`, { ruleId: "HANDOFF-010", blocking: true, artifact: String(reviewPolicy["artifact"]) });
    } else {
      addResult(acc, catalog, "INFO", `${reviewPolicy["artifact"]} is not present and not required for ${mode}`, { ruleId: "HANDOFF-010" });
    }
    return;
  }

  let review: Record<string, unknown>;
  try {
    review = JSON.parse(readFileSync(reviewPath, "utf8"));
  } catch {
    addResult(acc, catalog, "FAIL", `${reviewPolicy["artifact"]} is not valid JSON`, { ruleId: "HANDOFF-010", blocking: true, artifact: String(reviewPolicy["artifact"]) });
    return;
  }

  const problems: string[] = [];
  if (String(review["schema_version"] ?? "") !== String(reviewPolicy["schema_version"])) problems.push(`schema_version is '${review["schema_version"]}', expected '${reviewPolicy["schema_version"]}'`);
  if (!((reviewPolicy["reviewer_kinds"] as string[]) ?? []).includes(String(review["reviewer_kind"] ?? ""))) problems.push(`reviewer_kind '${review["reviewer_kind"]}' is not one of: ${((reviewPolicy["reviewer_kinds"] as string[]) ?? []).join(", ")}`);

  const policyLensIds = ((reviewPolicy["lenses"] as Array<Record<string, unknown>>) ?? []).map((l) => String(l["id"]));
  const reviewedLensIds = ((review["lenses"] as Array<Record<string, unknown>>) ?? []).map((l) => String(l["lens"]));
  const missingLenses = policyLensIds.filter((id) => !reviewedLensIds.includes(id));
  const unknownLenses = reviewedLensIds.filter((id) => id && !policyLensIds.includes(id));
  if (missingLenses.length > 0) problems.push(`lenses not reviewed: ${missingLenses.join(", ")}`);
  if (unknownLenses.length > 0) problems.push(`unknown review lenses: ${sortOrdinalUnique(unknownLenses).join(", ")}`);

  const validSeverities = (reviewPolicy["finding_severities"] as string[]) ?? [];
  const validStatuses = (reviewPolicy["finding_statuses"] as string[]) ?? [];
  const validPoints = (handoffPolicy["blocking_points"] as string[]) ?? [];
  const closure = (reviewPolicy["closure_policy"] as Record<string, unknown>) ?? null;
  if (!closure) throw new Error("handoff-policy.json semantic_review is missing closure_policy; refusing to guess who may close a finding.");
  const openStatuses = (closure["open_statuses"] as string[]) ?? [];
  const aiClosable = (closure["ai_closable_statuses"] as string[]) ?? [];
  const humanOnlyLenses = (closure["human_only_close_lenses"] as string[]) ?? [];
  const needsDecisionRef = (closure["statuses_requiring_decision_ref"] as string[]) ?? [];
  const reviewerIsAi = String(review["reviewer_kind"] ?? "") === "ai";
  const ownerPolicy = (handoffPolicy["owner_policy"] as Record<string, unknown>) ?? {};

  for (const finding of (review["findings"] as Array<Record<string, unknown>>) ?? []) {
    const id = String(finding["finding_id"] ?? "").trim();
    if (id.length === 0) { problems.push("a finding has no finding_id"); continue; }
    const lens = String(finding["lens"] ?? "").trim();
    const status = String(finding["status"] ?? "").trim();

    if (!validSeverities.includes(String(finding["severity"] ?? ""))) problems.push(`${id} has severity '${finding["severity"]}'`);
    if (!validStatuses.includes(status)) problems.push(`${id} has status '${status}'`);
    if (!validPoints.includes(String(finding["blocking_point"] ?? ""))) problems.push(`${id} has blocking_point '${finding["blocking_point"]}'`);
    if (lens.length === 0 || !policyLensIds.includes(lens)) problems.push(`${id} is filed under unknown lens '${lens}'`);
    if (testGenericOwner(String(finding["owner"] ?? ""), ownerPolicy)) problems.push(`${id} has no named owner`);
    if (((finding["evidence_refs"] as unknown[]) ?? []).length === 0) problems.push(`${id} cites no evidence`);
    if (!String(finding["suggestion"] ?? "").trim()) problems.push(`${id} offers no suggestion`);

    if (openStatuses.includes(status)) continue;

    const decisionRef = String(finding["decision_ref"] ?? "").trim();
    if (needsDecisionRef.includes(status)) {
      if (decisionRef.length === 0) problems.push(`${id} is '${status}' with no decision_ref -- a finding is only closed by a decision somebody recorded`);
      else if (!resolveLeadingReference(decisionRef, decisionIds, null, ctx)) problems.push(`${id} is '${status}' but decision_ref '${decisionRef}' does not resolve`);
    }

    if (reviewerIsAi) {
      if (humanOnlyLenses.includes(lens)) problems.push(`${id} is '${status}' under lens '${lens}', which only a human may close -- an AI reviewer must leave it open and name the person who decides`);
      else if (!aiClosable.includes(status)) problems.push(`${id} is '${status}', which an AI reviewer may not set (allowed: ${aiClosable.join(", ")})`);
    }

    if (humanOnlyLenses.includes(lens) && closure["human_only_requires_decision_log_entry"] === true) {
      const dm = /(DEC-\d{3})/.exec(decisionRef);
      if (!dm) problems.push(`${id} is '${status}' under human-only lens '${lens}' and cites no decision-log entry -- closure there must reference a DEC-### somebody signed`);
      else {
        const decisionId = dm[1]!;
        const decider = getDecisionDecider(project, decisionId);
        if (decider === null) problems.push(`${id} cites ${decisionId}, which is not a row in decision-log.md`);
        else if (testGenericOwner(decider, ownerPolicy)) problems.push(`${id} closes a human-only lens against ${decisionId}, whose decider is '${decider}' rather than a named person`);
      }
    }
  }

  const staleLevel = getHandoffPolicySeverity(((reviewPolicy["freshness"] as Record<string, unknown>)?.["stale_severity"] as Record<string, unknown>) ?? null, mode, "warn");
  let isStale = false;

  const currentSourceDigest = getSourceSnapshotDigest(projectText);
  const recordedSourceDigest = String(((review["source_snapshot"] as Record<string, unknown>) ?? {})["digest"] ?? "").trim().toLowerCase();
  if (!recordedSourceDigest) problems.push("source_snapshot.digest is not recorded, so freshness cannot be checked");
  else if (currentSourceDigest && currentSourceDigest !== recordedSourceDigest) {
    addResult(acc, catalog, staleLevel, `${reviewPolicy["artifact"]} is stale: it was recorded against a different Source Snapshot than PROJECT.md currently declares`, { ruleId: "HANDOFF-010", blocking: true, artifact: String(reviewPolicy["artifact"]), field: "source_snapshot.digest" });
    isStale = true;
  }

  const currentInputDigest = getReviewInputDigest(project, handoffPolicy);
  const recordedInputDigest = String(((review["review_inputs"] as Record<string, unknown>) ?? {})["digest"] ?? "").trim().toLowerCase();
  if (!recordedInputDigest) problems.push("review_inputs.digest is not recorded, so changes to the reviewed artifacts cannot be detected");
  else if (currentInputDigest && currentInputDigest !== recordedInputDigest) {
    addResult(acc, catalog, staleLevel, `${reviewPolicy["artifact"]} is stale: a governed artifact it reviewed has changed since it was recorded`, { ruleId: "HANDOFF-010", blocking: true, artifact: String(reviewPolicy["artifact"]), field: "review_inputs.digest" });
    isStale = true;
  }

  if (problems.length > 0) {
    for (const problem of problems) {
      addResult(acc, catalog, "FAIL", `Semantic handoff review is incomplete: ${problem}`, { ruleId: "HANDOFF-010", blocking: true, artifact: String(reviewPolicy["artifact"]) });
    }
  } else if (!isStale) {
    addResult(acc, catalog, "PASS", `Semantic handoff review covers all ${policyLensIds.length} lenses, is current against both digests, and closes nothing without a decision`, { ruleId: "HANDOFF-010" });
    const openCritical = ((review["findings"] as Array<Record<string, unknown>>) ?? []).filter((f) => String(f["status"]) === "open" && String(f["severity"]) === "critical");
    if (openCritical.length > 0) {
      addResult(acc, catalog, "WARN", `Semantic review has ${openCritical.length} open critical finding(s): ${openCritical.map((f) => `${f["finding_id"]} [${f["blocking_point"]}]`).join(", ")}`, { ruleId: "HANDOFF-010", blocking: true, artifact: String(reviewPolicy["artifact"]) });
    }
  }
}

export function testEarlyTestDesign(acc: ResultAccumulator, catalog: ValidationRules | undefined, project: string, mode: Mode, gate: Gate, projectReqIds: string[], projectText: string, handoffPolicy: Record<string, unknown>): void {
  if (mode === "Lite" || !["Design", "Handoff"].includes(gate)) return;
  if (!/^\s*>?\s*(Research mode|UI delivery):/m.test(projectText)) return;
  const path = join(project, "DESIGN/BUILD-SPEC.md");
  if (!existsSync(path)) {
    addResult(acc, catalog, "FAIL", "BUILD-SPEC is required during Design for mode-aware testability", { ruleId: "TEST-DESIGN-001", artifact: "DESIGN/BUILD-SPEC.md" });
    return;
  }
  const text = readFileSync(path, "utf8");
  const rows = getTableRowsAfterHeading(text, "^###\\s+Test Strategy");
  if (!/^###\s+Test Strategy\s*[\s\S]*?^Status:\s*specified\s*$/m.test(text) || rows.length === 0) {
    addResult(acc, catalog, "FAIL", "BUILD-SPEC Test Strategy is missing or incomplete", { ruleId: "TEST-DESIGN-001", artifact: "DESIGN/BUILD-SPEC.md", field: "Test Strategy" });
    return;
  }
  const ownerPolicy = (handoffPolicy["owner_policy"] as Record<string, unknown>) ?? {};
  const bad = rows.filter((r) =>
    testPlaceholderValue(String(r["Test Area"] ?? "")) ||
    testPlaceholderValue(String(r["Requirement / Risk Ref"] ?? "")) ||
    testPlaceholderValue(String(r["Level"] ?? "")) ||
    !["automated", "manual", "exploratory"].includes(String(r["Execution"] ?? "")) ||
    testGenericOwner(String(r["Owner"] ?? ""), ownerPolicy));
  if (bad.length > 0) addResult(acc, catalog, "FAIL", "BUILD-SPEC Test Strategy contains incomplete cases", { ruleId: "TEST-DESIGN-001", artifact: "DESIGN/BUILD-SPEC.md", field: "Test Strategy" });
  else addResult(acc, catalog, "PASS", "BUILD-SPEC carries mode-aware test strategy", { ruleId: "TEST-DESIGN-001" });

  const covered = [...new Set(rows.flatMap((r) => [...(String(r["Requirement / Risk Ref"] ?? "")).matchAll(/REQ-\d{3,}/g)].map((m) => m[0])))];
  const missing = projectReqIds.filter((req) => !covered.includes(req));
  if (missing.length > 0) addResult(acc, catalog, "FAIL", `Test Strategy does not cover scoped requirements: ${missing.join(", ")}`, { ruleId: "TEST-DESIGN-002", artifact: "DESIGN/BUILD-SPEC.md", field: "Test Strategy" });
  else addResult(acc, catalog, "PASS", "Test Strategy covers applicable scoped requirements", { ruleId: "TEST-DESIGN-002" });
}
