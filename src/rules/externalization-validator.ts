// Externalization gate (EXT-001..004), ported from
// scripts/lib/externalization-validator.ps1.

import { readFileSync, existsSync, statSync } from "node:fs";
import { join, resolve, isAbsolute } from "node:path";
import { testPlaceholderValue, testDateValue } from "../config/config-loader.js";
import { testPhysicalContainment } from "../core/path-containment.js";
import { getArtifactSha256 } from "../digest/artifact-hash.js";
import { testGenericOwner } from "../core/owner-policy.js";
import { getDecisionDecider } from "./decision-log.js";
import { addResult } from "../core/result-writer.js";
import type { ResultAccumulator, ValidationRules } from "../core/context.js";
import type { Gate } from "../core/types.js";

interface ExternalizationEntry {
  id?: string;
  purpose?: string;
  provider?: string;
  provider_type?: string;
  outgoing_artifacts?: Array<{ path?: string; sha256?: string }>;
  classification?: string;
  minimization_redaction?: string;
  scan_result?: string;
  human_review_required?: boolean;
  network_transfer_occurred?: boolean;
  status?: string;
  recorded_at?: string;
  reviewer?: string;
  decision_ref?: string;
}

function testSensitivePathMatch(path: string, pattern: string): boolean {
  const regexText = pattern.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replaceAll("\\*", ".*");
  let rx: RegExp;
  try {
    rx = new RegExp(`^${regexText}$`, "i");
  } catch {
    return true;
  }
  for (const segment of path.split("/")) {
    if (rx.test(segment)) return true;
  }
  return rx.test(path);
}

function testExternalizationScanFinding(
  project: string,
  artifactPaths: string[],
  secretPatterns: Array<{ pattern?: string }>,
  sensitivePathPatterns: string[],
): boolean {
  const root = resolve(project);
  for (const relative of artifactPaths) {
    const normalized = relative.replace(/\\/g, "/");
    for (const pathPattern of sensitivePathPatterns) {
      if (testSensitivePathMatch(normalized, pathPattern)) return true;
    }
    const full = resolve(join(project, relative));
    if (!testPhysicalContainment(full, root)) continue;
    if (!existsSync(full) || !statSync(full).isFile()) continue;
    let content: string;
    try {
      content = readFileSync(full, "utf8");
    } catch {
      continue; // binary: not decodable as UTF-8
    }
    if (!content) continue;
    for (const entry of secretPatterns) {
      if (entry.pattern && new RegExp(entry.pattern).test(content)) return true;
    }
  }
  return false;
}

export function testExternalizationRegistry(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  project: string,
  gate: Gate,
  orchestrationPolicy: Record<string, unknown>,
  policy: Record<string, unknown>,
  decisionIds: string[] | null,
  handoffPolicy: Record<string, unknown>,
): void {
  const extPolicy = (orchestrationPolicy["externalization"] as Record<string, unknown>) ?? {};
  const path = join(project, String(extPolicy["registry"] ?? "EXTERNALIZATION.json"));
  if (!existsSync(path)) return;
  if (gate === "Draft") return;

  let doc: { schema_version?: string; entries?: ExternalizationEntry[] };
  try {
    doc = JSON.parse(readFileSync(path, "utf8"));
  } catch {
    addResult(acc, catalog, "FAIL", "EXTERNALIZATION.json is not valid JSON", { ruleId: "EXT-001", artifact: "EXTERNALIZATION.json" });
    return;
  }
  const entries = doc.entries ?? [];
  if (doc.schema_version !== "1.0" || entries.length === 0) {
    addResult(acc, catalog, "FAIL", "EXTERNALIZATION.json has no supported registry entries", { ruleId: "EXT-001", artifact: "EXTERNALIZATION.json" });
    return;
  }

  const structureProblems: string[] = [];
  const authorityProblems: string[] = [];
  const scanProblems: string[] = [];
  const freshnessProblems: string[] = [];
  const humanReviewRequired = (extPolicy["human_review_required"] as string[]) ?? [];
  const secretPatterns = (extPolicy["secret_patterns"] as Array<{ pattern?: string }>) ?? [];
  let sensitivePathPatterns = (policy["permissions"] as Record<string, unknown> | undefined)?.["sensitive_paths"] as string[] | undefined;
  if (!sensitivePathPatterns || sensitivePathPatterns.length === 0) {
    sensitivePathPatterns = [".env", ".env.*", "*.pem", "*.key", "*.pfx", "*.p12", "id_rsa", "id_ed25519"];
  }
  const internalDefaultReview = Boolean(extPolicy["internal_default_human_review"]);
  const providerTypes = (extPolicy["provider_types"] as string[]) ?? [];
  const classifications = (extPolicy["classifications"] as string[]) ?? [];
  const scanResults = (extPolicy["scan_results"] as string[]) ?? [];
  const statuses = (extPolicy["statuses"] as string[]) ?? [];
  const ownerPolicy = (handoffPolicy["owner_policy"] as Record<string, unknown>) ?? {};

  for (const entry of entries) {
    const id = String(entry.id ?? "");
    const required = ["id", "purpose", "provider", "provider_type", "outgoing_artifacts", "classification", "minimization_redaction", "scan_result", "human_review_required", "network_transfer_occurred", "status", "recorded_at"];
    const missing = required.filter((f) => {
      const v = entry[f as keyof ExternalizationEntry];
      if (Array.isArray(v) || typeof v === "object" && v !== null || typeof v === "boolean") return false;
      return v === undefined || String(v).trim() === "";
    });
    const idBad = !/^EXT-\d{3,}$/.test(id);
    if (idBad || missing.length > 0) {
      structureProblems.push(id || "unnamed entry");
      continue;
    }

    if (typeof entry.network_transfer_occurred !== "boolean") structureProblems.push(`${id} network_transfer_occurred`);
    if (typeof entry.human_review_required !== "boolean") structureProblems.push(`${id} human_review_required`);

    if (!providerTypes.includes(entry.provider_type ?? "")) structureProblems.push(`${id} provider_type`);
    if (!classifications.includes(entry.classification ?? "")) structureProblems.push(`${id} classification`);
    if (!scanResults.includes(entry.scan_result ?? "")) structureProblems.push(`${id} scan_result`);
    if (!statuses.includes(entry.status ?? "")) structureProblems.push(`${id} status`);
    const recordedAt = entry.recorded_at ?? "";
    const recordedOk = /^\d{4}-\d{2}-\d{2}T/.test(recordedAt) || testDateValue(recordedAt);
    if (!recordedOk) structureProblems.push(`${id} recorded_at`);
    if (String(entry.minimization_redaction ?? "").trim() === "" || testPlaceholderValue(String(entry.minimization_redaction ?? ""))) structureProblems.push(`${id} minimization`);
    if (String(entry.purpose ?? "").trim() === "" || testPlaceholderValue(String(entry.purpose ?? ""))) structureProblems.push(`${id} purpose`);

    const artifactRefs = entry.outgoing_artifacts ?? [];
    if (artifactRefs.length === 0) {
      structureProblems.push(`${id} outgoing_artifacts`);
      continue;
    }
    const resolvedArtifacts: string[] = [];
    for (const ref of artifactRefs) {
      const relative = String(ref.path ?? "");
      if (!relative || isAbsolute(relative) || /^\.\.[\\/]/.test(relative)) {
        structureProblems.push(`${id} artifact ref`);
        continue;
      }
      const full = resolve(join(project, relative));
      const root = resolve(project);
      if (!testPhysicalContainment(full, root) || !existsSync(full) || !statSync(full).isFile()) {
        structureProblems.push(`${id} artifact ref`);
        continue;
      }
      resolvedArtifacts.push(relative);
      const claimed = String(ref.sha256 ?? "");
      if (!/^[a-fA-F0-9]{64}$/.test(claimed)) {
        freshnessProblems.push(`${id} digest`);
      } else if (getArtifactSha256(full) !== claimed.toLowerCase()) {
        freshnessProblems.push(id);
      }
    }

    const reviewFlagProp = typeof entry.human_review_required === "boolean" ? entry.human_review_required : false;
    let requiresHuman = humanReviewRequired.includes(entry.classification ?? "") ||
      ["finding", "not_run"].includes(entry.scan_result ?? "") ||
      reviewFlagProp === true;
    if (!requiresHuman && entry.classification === "Internal" && internalDefaultReview) requiresHuman = true;
    if (requiresHuman && reviewFlagProp !== true) authorityProblems.push(`${id} review flag`);
    if (requiresHuman) {
      const reviewer = String(entry.reviewer ?? "");
      const decisionRef = String(entry.decision_ref ?? "");
      const decider = decisionRef && (decisionIds ?? []).includes(decisionRef) ? getDecisionDecider(project, decisionRef) : null;
      if (reviewer.trim() === "" || testGenericOwner(reviewer, ownerPolicy)) authorityProblems.push(`${id} reviewer`);
      if (!decisionRef || !(decisionIds ?? []).includes(decisionRef) || decider === null || testGenericOwner(decider, ownerPolicy)) authorityProblems.push(`${id} decision`);
    }

    if (entry.scan_result === "clean" && testExternalizationScanFinding(project, resolvedArtifacts, secretPatterns, sensitivePathPatterns)) {
      scanProblems.push(id);
    }
  }

  if (structureProblems.length) addResult(acc, catalog, "FAIL", `Externalization registry has invalid entries: ${[...new Set(structureProblems)].join(", ")}`, { ruleId: "EXT-001", artifact: "EXTERNALIZATION.json" });
  else addResult(acc, catalog, "PASS", "Externalization registry structure and artifact references are valid", { ruleId: "EXT-001" });
  if (authorityProblems.length) addResult(acc, catalog, "FAIL", `Externalization entries lack required Human evidence: ${[...new Set(authorityProblems)].join(", ")}`, { ruleId: "EXT-002", artifact: "EXTERNALIZATION.json" });
  else addResult(acc, catalog, "PASS", "Required externalization transfers carry named-Human decision evidence", { ruleId: "EXT-002" });
  if (scanProblems.length) addResult(acc, catalog, "FAIL", `Declared clean scan does not match a deterministic re-scan of outgoing artifacts: ${[...new Set(scanProblems)].join(", ")}`, { ruleId: "EXT-003", artifact: "EXTERNALIZATION.json" });
  else addResult(acc, catalog, "PASS", "Declared externalization scan results match a deterministic re-scan", { ruleId: "EXT-003" });
  if (freshnessProblems.length) addResult(acc, catalog, "FAIL", `Externalization artifact digests are missing or stale: ${[...new Set(freshnessProblems)].join(", ")}`, { ruleId: "EXT-004", artifact: "EXTERNALIZATION.json" });
  else addResult(acc, catalog, "PASS", "Externalization artifact digests are current", { ruleId: "EXT-004" });
}
