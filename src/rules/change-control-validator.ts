// CHANGE-REQUESTS.json validation (CHANGE-001/002/003), ported from
// scripts/lib/change-control-validator.ps1.

import { readFileSync, existsSync, statSync } from "node:fs";
import { join, resolve, isAbsolute } from "node:path";
import { createHash } from "node:crypto";
import { testGenericOwner } from "../core/owner-policy.js";
import { getDecisionDecider } from "./decision-log.js";
import { addResult } from "../core/result-writer.js";
import type { ResultAccumulator, ValidationRules } from "../core/context.js";
import type { Mode, Gate } from "../core/types.js";

interface ChangeEntry {
  id?: string;
  detected_at?: string;
  source?: string;
  classification?: string;
  summary?: string;
  reason?: string;
  affected_requirements?: string[];
  affected_artifacts?: string[];
  scope_impact?: boolean;
  acceptance_impact?: boolean;
  mode_impact?: string;
  status?: string;
  owner?: string;
  decision_ref?: string;
  downstream_validation?: {
    status?: string;
    artifacts?: Array<{ path?: string; sha256?: string }>;
    execution_contracts?: Array<{ path?: string; sha256?: string }>;
  };
}

function testCurrentDigestReference(
  project: string,
  reference: { path?: string; sha256?: string } | undefined,
  executionContract: boolean,
): boolean {
  if (!reference) return false;
  const relative = String(reference.path ?? "");
  const claimed = String(reference.sha256 ?? "");
  if (!relative || isAbsolute(relative) || /^\.\.[\\/]/.test(relative)) return false;
  if (executionContract && !/^\.execution\/[^/]+\/EXECUTION-CONTRACT\.json$/.test(relative.replace(/\\/g, "/"))) return false;
  const full = resolve(join(project, relative));
  const root = resolve(project);
  if (!full.startsWith(root + "/") || !existsSync(full) || !statSync(full).isFile()) return false;
  if (!/^[a-fA-F0-9]{64}$/.test(claimed)) return false;
  return createHash("sha256").update(readFileSync(full)).digest("hex").toLowerCase() === claimed.toLowerCase();
}

export function testChangeControlRegistry(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  project: string,
  gate: Gate,
  orchestrationPolicy: Record<string, unknown>,
  mode: Mode,
  executionPath: string,
  projectReqIds: string[],
  decisionIds: string[],
  handoffPolicy: Record<string, unknown>,
): void {
  const path = join(project, "CHANGE-REQUESTS.json");
  if (!existsSync(path)) return;
  if (gate === "Draft") return;

  let doc: { schema_version?: string; changes?: ChangeEntry[] };
  try {
    doc = JSON.parse(readFileSync(path, "utf8"));
  } catch {
    addResult(acc, catalog, "FAIL", "CHANGE-REQUESTS.json is not valid JSON", { ruleId: "CHANGE-001", artifact: "CHANGE-REQUESTS.json" });
    return;
  }
  const changes = doc.changes ?? [];
  if (doc.schema_version !== "1.0" || changes.length === 0) {
    addResult(acc, catalog, "FAIL", "CHANGE-REQUESTS.json has no supported registry entries", { ruleId: "CHANGE-001", artifact: "CHANGE-REQUESTS.json" });
    return;
  }

  const structureProblems: string[] = [];
  const authorityProblems: string[] = [];
  const blocking: string[] = [];
  const downstreamProblems: string[] = [];

  const cc = (orchestrationPolicy["change_control"] as Record<string, unknown>) ?? {};
  let blockingClassifications = (cc["blocking_by_mode"] as Record<string, unknown> | undefined)?.[mode] as string[] | undefined;
  if (!blockingClassifications || blockingClassifications.length === 0) {
    blockingClassifications = (cc["blocking_classifications"] as string[]) ?? [];
  }
  const sources = (cc["sources"] as string[]) ?? [];
  const classifications = (cc["classifications"] as string[]) ?? [];
  const statuses = (cc["statuses"] as string[]) ?? [];
  const modeImpacts = (cc["mode_impacts"] as string[]) ?? [];
  const ownerPolicy = (handoffPolicy["owner_policy"] as Record<string, unknown>) ?? {};

  for (const change of changes) {
    const id = String(change.id ?? "");
    const required = ["id", "detected_at", "source", "classification", "summary", "reason", "affected_requirements", "affected_artifacts", "scope_impact", "acceptance_impact", "mode_impact", "status", "owner"];
    const missing = required.filter((f) => change[f as keyof ChangeEntry] === undefined || String(change[f as keyof ChangeEntry] ?? "").trim() === "");
    if (!/^CR-\d{3,}$/.test(id) || missing.length > 0) {
      structureProblems.push(id || "unnamed entry");
      continue;
    }
    if (!sources.includes(change.source ?? "")) structureProblems.push(`${id} source`);
    if (!classifications.includes(change.classification ?? "")) structureProblems.push(`${id} classification`);
    if (!statuses.includes(change.status ?? "")) structureProblems.push(`${id} status`);
    if (!modeImpacts.includes(change.mode_impact ?? "")) structureProblems.push(`${id} mode impact`);
    for (const req of change.affected_requirements ?? []) {
      if (!projectReqIds.includes(req)) structureProblems.push(`${id} requirement ref`);
    }
    for (const artifact of change.affected_artifacts ?? []) {
      const rel = String(artifact);
      if (isAbsolute(rel) || /^\.\.[\\/]/.test(rel)) {
        structureProblems.push(`${id} artifact ref`);
        continue;
      }
      const candidate = resolve(join(project, rel));
      const root = resolve(project);
      if (!candidate.startsWith(root + "/") || !existsSync(candidate)) structureProblems.push(`${id} artifact ref`);
    }

    if (testGenericOwner(String(change.owner ?? ""), ownerPolicy)) authorityProblems.push(`${id} owner`);
    if (["approved", "implemented", "rejected", "superseded"].includes(change.status ?? "")) {
      const decisionRef = String(change.decision_ref ?? "");
      const decider = decisionRef && decisionIds.includes(decisionRef) ? getDecisionDecider(project, decisionRef) : null;
      if (!decisionRef || !decisionIds.includes(decisionRef) || decider === null || testGenericOwner(decider, ownerPolicy)) {
        authorityProblems.push(`${id} decision`);
      }
    }

    const hasDownstreamImpact = Boolean(change.scope_impact) || Boolean(change.acceptance_impact) || String(change.mode_impact ?? "") !== "none";
    if (change.status === "implemented" && hasDownstreamImpact) {
      const validation = change.downstream_validation;
      let invalid = !validation || String(validation.status ?? "") !== "current";
      const artifactRefs = validation?.artifacts ?? [];
      if (artifactRefs.length === 0 || artifactRefs.some((a) => !testCurrentDigestReference(project, a, false))) invalid = true;
      if (executionPath === "governed_ai_execution") {
        const contractRefs = validation?.execution_contracts ?? [];
        if (contractRefs.length === 0 || contractRefs.some((c) => !testCurrentDigestReference(project, c, true))) invalid = true;
      }
      if (invalid) downstreamProblems.push(id);
    }

    if (blockingClassifications.includes(change.classification ?? "") && !["implemented", "rejected", "superseded"].includes(change.status ?? "")) {
      blocking.push(id);
    }
  }

  if (structureProblems.length) {
    addResult(acc, catalog, "FAIL", `Change registry has invalid entries: ${[...new Set(structureProblems)].join(", ")}`, { ruleId: "CHANGE-001", artifact: "CHANGE-REQUESTS.json" });
  } else {
    addResult(acc, catalog, "PASS", "Change registry structure and references are valid", { ruleId: "CHANGE-001" });
  }
  if (authorityProblems.length) {
    addResult(acc, catalog, "FAIL", `Change decisions or owners are invalid: ${[...new Set(authorityProblems)].join(", ")}`, { ruleId: "CHANGE-002", artifact: "CHANGE-REQUESTS.json" });
  } else if (changes.some((c) => ["approved", "implemented", "rejected", "superseded"].includes(c.status ?? ""))) {
    addResult(acc, catalog, "PASS", "Governed change dispositions carry named-Human decision evidence", { ruleId: "CHANGE-002" });
  }
  if ((gate === "Handoff" || gate === "Release") && (blocking.length || downstreamProblems.length)) {
    const ids = [...new Set([...blocking, ...downstreamProblems])];
    addResult(acc, catalog, "FAIL", `Unresolved or stale governed changes: ${ids.join(", ")}`, { ruleId: "CHANGE-003", artifact: "CHANGE-REQUESTS.json" });
  }
}
