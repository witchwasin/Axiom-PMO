// Claude Design optional workflow (DPROV-002..007), ported from
// scripts/lib/design-provider-validator.ps1.

import { readFileSync, existsSync, statSync, readdirSync } from "node:fs";
import { join, resolve, isAbsolute } from "node:path";
import { getProjectOrchestrationDeclarations, testPlaceholderValue } from "../config/config-loader.js";
import { sortOrdinal } from "../core/ordinal-sort.js";
import { getSha256Hex } from "../digest/sha256-text.js";
import { getArtifactSha256 } from "../digest/artifact-hash.js";
import { testPhysicalContainment } from "../core/path-containment.js";
import { testGenericOwner } from "../core/owner-policy.js";
import { getDecisionDecider } from "./decision-log.js";
import { addResult } from "../core/result-writer.js";
import type { ResultAccumulator, ValidationRules } from "../core/context.js";
import type { Gate } from "../core/types.js";

function getDesignInputCombinedDigest(inputs: Array<Record<string, unknown>>): string {
  const lines = inputs.map((i) => `${String(i["path"] ?? "").trim()}|${String(i["sha256"] ?? "").trim()}`);
  return getSha256Hex(sortOrdinal(lines).join("\n"));
}

function getDesignOutputSetDigest(outputRoot: string): string {
  const lines: string[] = [];
  if (existsSync(outputRoot)) {
    const files: string[] = [];
    const walk = (dir: string) => {
      for (const entry of readdirSync(dir)) {
        const full = join(dir, entry);
        const st = statSync(full);
        if (st.isDirectory()) walk(full);
        else if (st.isFile()) files.push(full);
      }
    };
    walk(outputRoot);
    files.sort();
    for (const file of files) {
      const rel = file.substring(outputRoot.length).replace(/^[/\\]/, "").replace(/\\/g, "/");
      const hash = getArtifactSha256(file);
      lines.push(`${rel}|${hash}`);
    }
  }
  if (lines.length === 0) return getSha256Hex("empty");
  return getSha256Hex(sortOrdinal(lines).join("\n"));
}

function testDesignOutputInventory(outputRoot: string, declaredOutputs: Array<Record<string, unknown>>): string[] {
  const problems: string[] = [];
  const root = resolve(outputRoot);
  const actualFiles = new Map<string, string>();
  if (existsSync(outputRoot)) {
    const walk = (dir: string) => {
      for (const entry of readdirSync(dir)) {
        const full = join(dir, entry);
        if (!testPhysicalContainment(full, root)) {
          problems.push("output escapes boundary");
          continue;
        }
        const st = statSync(full);
        if (st.isDirectory()) walk(full);
        else if (st.isFile()) {
          const rel = full.substring(root.length).replace(/^[/\\]/, "").replace(/\\/g, "/");
          actualFiles.set(rel.toLowerCase(), full);
        }
      }
    };
    walk(outputRoot);
  }
  const declaredKeys: string[] = [];
  for (const decl of declaredOutputs) {
    const relativePath = String(decl["path"] ?? "").trim();
    if (!relativePath || isAbsolute(relativePath) || /^\.\.[\\/]/.test(relativePath) || relativePath.startsWith("/")) {
      problems.push("invalid declared output");
      continue;
    }
    const full = resolve(join(outputRoot, relativePath));
    if (!testPhysicalContainment(full, root)) {
      problems.push("declared output escapes");
      continue;
    }
    declaredKeys.push(relativePath.toLowerCase());
    if (!actualFiles.has(relativePath.toLowerCase())) problems.push("missing declared output");
    else {
      const actualHash = getArtifactSha256(actualFiles.get(relativePath.toLowerCase())!);
      if (String(decl["sha256"] ?? "").trim() === "" || actualHash !== String(decl["sha256"]).toLowerCase()) problems.push("stale declared output digest");
    }
  }
  for (const relLower of actualFiles.keys()) {
    if (!declaredKeys.includes(relLower)) problems.push("undeclared output");
  }
  return problems;
}

export function testDesignProviderWorkflow(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  project: string,
  gate: Gate,
  orchestrationPolicy: Record<string, unknown>,
  decisionIds: string[] | null,
  handoffPolicy: Record<string, unknown>,
): void {
  const policy = (orchestrationPolicy["ui_delivery"] as Record<string, unknown>) ?? {};
  const manifestPath = join(project, String(policy["input_manifest"] ?? "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json"));
  const manifestExists = existsSync(manifestPath);
  const declared = getProjectOrchestrationDeclarations(project);
  const requiredAtGate = !manifestExists && declared.uiDelivery === "claude_design" && ["Handoff", "Release"].includes(gate);

  if (!manifestExists && !requiredAtGate) return;
  if (gate === "Draft") return;

  if (!manifestExists) {
    addResult(acc, catalog, "FAIL", "Claude Design is the declared UI delivery path but DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json is missing", { ruleId: "DPROV-002", artifact: "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json" });
    return;
  }

  let manifest: Record<string, unknown>;
  try {
    manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  } catch {
    addResult(acc, catalog, "FAIL", "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json is not valid JSON", { ruleId: "DPROV-002", artifact: "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json" });
    return;
  }

  const reviewPath = join(project, String(policy["review_manifest"] ?? "DESIGN/CLAUDE-DESIGN/REVIEW.json"));
  const reviewExists = existsSync(reviewPath);
  const outputRoot = join(project, String(policy["output_root"] ?? "DESIGN/CLAUDE-DESIGN/OUTPUT"));

  // DPROV-002: structure
  const structureProblems: string[] = [];
  const required = ["project_code", "provider", "purpose", "externalization", "generated_at", "inputs", "combined_digest"];
  for (const field of required) {
    const v = manifest[field];
    if (Array.isArray(v)) continue;
    if (v === undefined || v === null) {
      structureProblems.push(field);
      continue;
    }
    if (typeof v !== "object" && String(v).trim() === "") structureProblems.push(field);
  }
  const inputs = (manifest["inputs"] as Array<Record<string, unknown>>) ?? [];
  if (inputs.length === 0) structureProblems.push("inputs");
  for (const input of inputs) {
    if (String(input["path"] ?? "").trim() === "" || String(input["sha256"] ?? "").trim() === "") structureProblems.push("input ref");
  }
  const generatedAt = String(manifest["generated_at"] ?? "");
  if (!/^\d{4}-\d{2}-\d{2}T/.test(generatedAt)) structureProblems.push("generated_at");

  const inputPaths = inputs.map((i) => String(i["path"] ?? "").trim());
  if (!inputPaths.includes("PROJECT.md")) structureProblems.push("missing PROJECT.md input");
  if (existsSync(join(project, "DESIGN/BUILD-SPEC.md")) && !inputPaths.includes("DESIGN/BUILD-SPEC.md")) structureProblems.push("missing BUILD-SPEC input");
  for (const input of inputs) {
    const rel = String(input["path"] ?? "").trim();
    if (/^(source\/|\.\/source\/|\.\.|\/|\.\/)/.test(rel) && String(input["governed_justification"] ?? "").trim() === "") structureProblems.push("raw source input without justification");
  }

  // DPROV-003: freshness
  const freshnessProblems: string[] = [];
  const root = resolve(project);
  for (const input of inputs) {
    const rel = String(input["path"] ?? "");
    if (!rel || isAbsolute(rel) || /^\.\.[\\/]/.test(rel)) {
      freshnessProblems.push("input path");
      continue;
    }
    const full = resolve(join(project, rel));
    if (!testPhysicalContainment(full, root) || !existsSync(full) || !statSync(full).isFile()) {
      freshnessProblems.push(rel);
      continue;
    }
    const claimed = String(input["sha256"] ?? "");
    if (!/^[a-fA-F0-9]{64}$/.test(claimed) || getArtifactSha256(full) !== claimed.toLowerCase()) freshnessProblems.push(rel);
  }
  const declaredCombined = String(manifest["combined_digest"] ?? "");
  if (freshnessProblems.length === 0) {
    const recomputed = getDesignInputCombinedDigest(inputs);
    if (!/^[a-fA-F0-9]{64}$/.test(declaredCombined) || recomputed !== declaredCombined.toLowerCase()) freshnessProblems.push("combined_digest");
  }

  // DPROV-004: externalization binding
  const externalizationProblems: string[] = [];
  const extRef = String(manifest["externalization"] ?? "");
  const registryPath = join(project, String((orchestrationPolicy["externalization"] as Record<string, unknown>)?.["registry"] ?? "EXTERNALIZATION.json"));
  let approvedExt: Record<string, unknown> | null = null;
  if (existsSync(registryPath)) {
    try {
      const extDoc = JSON.parse(readFileSync(registryPath, "utf8"));
      for (const entry of extDoc.entries ?? []) {
        if (entry.status === "approved" && entry.id === extRef) approvedExt = entry;
      }
    } catch {}
  }
  if (approvedExt === null) externalizationProblems.push("externalization");
  else {
    const manifestProvider = String(manifest["provider"] ?? "").trim();
    const extProvider = String(approvedExt["provider"] ?? "").trim();
    const providerOk = extProvider.length > 0 && manifestProvider.length > 0 &&
      (extProvider.toLowerCase().includes(manifestProvider.toLowerCase()) || manifestProvider.toLowerCase().includes(extProvider.toLowerCase()));
    if (!providerOk) externalizationProblems.push("provider mismatch");
    const extPayload = new Map<string, string>();
    for (const ref of approvedExt["outgoing_artifacts"] as Array<Record<string, unknown>> ?? []) {
      extPayload.set(String(ref["path"] ?? "").trim().toLowerCase(), String(ref["sha256"] ?? "").trim().toLowerCase());
    }
    for (const input of inputs) {
      const pathKey = String(input["path"] ?? "").trim().toLowerCase();
      const hash = String(input["sha256"] ?? "").trim().toLowerCase();
      if (!extPayload.has(pathKey) || extPayload.get(pathKey) !== hash) externalizationProblems.push(`payload ${String(input["path"] ?? "").trim()}`);
    }
  }

  // DPROV-005/006: preflight + authority
  const preflightProblems: string[] = [];
  const authorityProblems: string[] = [];
  let review: Record<string, unknown> | null = null;
  let acceptance: Record<string, unknown> | null = null;
  const ownerPolicy = (handoffPolicy["owner_policy"] as Record<string, unknown>) ?? {};
  if (reviewExists) {
    try {
      review = JSON.parse(readFileSync(reviewPath, "utf8"));
    } catch {
      addResult(acc, catalog, "FAIL", "DESIGN/CLAUDE-DESIGN/REVIEW.json is not valid JSON", { ruleId: "DPROV-005", artifact: "DESIGN/CLAUDE-DESIGN/REVIEW.json" });
      return;
    }
    const rv = review as Record<string, unknown>;
    const preflight = rv["preflight"] as Record<string, unknown> | null;
    acceptance = (rv["acceptance"] as Record<string, unknown>) ?? null;
    const declaredOutputs = (rv["outputs"] as Array<Record<string, unknown>>) ?? [];

    if (!preflight || !/^(passed|failed)$/.test(String(preflight["status"] ?? ""))) {
      preflightProblems.push("preflight");
    } else if (String(preflight["status"]) === "failed") {
      preflightProblems.push("preflight failed");
    } else {
      if (freshnessProblems.length === 0) {
        const declaredManifestDigest = String(preflight["manifest_digest"] ?? "");
        if (!/^[a-fA-F0-9]{64}$/.test(declaredManifestDigest) || declaredManifestDigest.toLowerCase() !== declaredCombined.toLowerCase()) preflightProblems.push("stale manifest_digest");
      }
      const currentOutputs = getDesignOutputSetDigest(outputRoot);
      if (String(preflight["outputs_digest"] ?? "").trim() === "" || String(preflight["outputs_digest"]).toLowerCase() !== currentOutputs) preflightProblems.push("stale outputs");
      const inventoryProblems = testDesignOutputInventory(outputRoot, declaredOutputs);
      preflightProblems.push(...inventoryProblems);
      if (declaredOutputs.length === 0) preflightProblems.push("empty output inventory");
    }

    if (acceptance && String(acceptance["decision"] ?? "").trim() !== "" && (!preflight || String(preflight["status"]) !== "passed")) preflightProblems.push("review before preflight");
  } else if (["Handoff", "Release"].includes(gate)) {
    preflightProblems.push(`review missing at ${gate}`);
  }

  if (reviewExists) {
    if (acceptance && String(acceptance["decision"] ?? "").trim() !== "") {
      const decision = String(acceptance["decision"] ?? "");
      const acceptanceDecisions = (policy["acceptance_decisions"] as string[]) ?? [];
      const reviewerKinds = (policy["reviewer_kinds"] as string[]) ?? [];
      if (!acceptanceDecisions.includes(decision)) authorityProblems.push("decision");
      const kind = String(acceptance["reviewer_kind"] ?? "");
      if (!reviewerKinds.includes(kind)) authorityProblems.push("reviewer_kind");
      const reviewer = String(acceptance["reviewer"] ?? "");
      const decisionRef = String(acceptance["decision_ref"] ?? "");
      if (reviewer.trim() === "" || testGenericOwner(reviewer, ownerPolicy)) authorityProblems.push("reviewer");
      if (decision === "accepted" && kind === "ai") authorityProblems.push("AI acceptance");
      const decider = decisionRef && (decisionIds ?? []).includes(decisionRef) ? getDecisionDecider(project, decisionRef) : null;
      if (!decisionRef || !(decisionIds ?? []).includes(decisionRef) || decider === null || testGenericOwner(decider, ownerPolicy)) authorityProblems.push("decision_ref");
    }
    if (["Handoff", "Release"].includes(gate)) {
      if (!acceptance || String(acceptance["decision"] ?? "") !== "accepted") authorityProblems.push(`acceptance not accepted at ${gate}`);
      else if (String(acceptance["reviewer_kind"] ?? "") !== "human") authorityProblems.push(`acceptance not human at ${gate}`);
    }
  }

  // DPROV-007: change-control routing
  const changeControlProblems: string[] = [];
  let findings: Array<Record<string, unknown>> = [];
  if (reviewExists && review) findings = (review["findings"] as Array<Record<string, unknown>>) ?? [];
  const registryIds: string[] = [];
  const registrySummaries: string[] = [];
  const crRegistryPath = join(project, "CHANGE-REQUESTS.json");
  if (existsSync(crRegistryPath)) {
    try {
      const crDoc = JSON.parse(readFileSync(crRegistryPath, "utf8"));
      for (const change of crDoc.changes ?? []) {
        if (change.id) registryIds.push(String(change.id));
        if (change.summary) registrySummaries.push(String(change.summary));
      }
    } catch {}
  }
  let openBlockingFinding = false;
  const findingLenses = (policy["finding_lenses"] as string[]) ?? [];
  const findingImpacts = (policy["finding_impacts"] as string[]) ?? [];
  const findingStatuses = (policy["finding_statuses"] as string[]) ?? [];
  for (const finding of findings) {
    const findingId = String(finding["id"] ?? "");
    const lens = String(finding["lens"] ?? "");
    const impact = String(finding["impact"] ?? "");
    const findingStatus = String(finding["status"] ?? "");
    const summary = String(finding["summary"] ?? "");
    const owner = String(finding["owner"] ?? "");
    const decisionRef = String(finding["decision_ref"] ?? "");
    if (!/^DP-\d{3,}$/.test(findingId) || !findingLenses.includes(lens) || !findingImpacts.includes(impact) || !findingStatuses.includes(findingStatus) || summary.trim() === "" || testPlaceholderValue(summary) || owner.trim() === "" || testGenericOwner(owner, ownerPolicy)) {
      changeControlProblems.push("finding schema");
      continue;
    }
    if (findingStatus === "resolved") {
      const decider = decisionRef && (decisionIds ?? []).includes(decisionRef) ? getDecisionDecider(project, decisionRef) : null;
      if (!decisionRef || !(decisionIds ?? []).includes(decisionRef) || decider === null || testGenericOwner(decider, ownerPolicy)) changeControlProblems.push(`${findingId} resolution`);
    }
    const mustRoute = ["technical", "scope"].includes(impact) || ["technical", "scope"].includes(lens);
    if (mustRoute) {
      let routed = false;
      for (const id of registryIds) {
        if (id && summary.includes(id)) routed = true;
      }
      for (const entrySummary of registrySummaries) {
        if (entrySummary.includes(findingId)) routed = true;
      }
      if (!routed) changeControlProblems.push(`${findingId} not routed`);
      if (findingStatus !== "resolved") openBlockingFinding = true;
    }
  }
  if (reviewExists && acceptance && String(acceptance["decision"] ?? "") === "accepted" && openBlockingFinding) changeControlProblems.push("accepted with open blocking finding");

  if (structureProblems.length) addResult(acc, catalog, "FAIL", `Design provider input manifest is incomplete: ${[...new Set(structureProblems)].join(", ")}`, { ruleId: "DPROV-002", artifact: "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json" });
  else addResult(acc, catalog, "PASS", "Design provider input manifest declares the required contract", { ruleId: "DPROV-002" });
  if (freshnessProblems.length) addResult(acc, catalog, "FAIL", `Design provider manifest references or digests are invalid or stale: ${[...new Set(freshnessProblems)].join(", ")}`, { ruleId: "DPROV-003", artifact: "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json" });
  else addResult(acc, catalog, "PASS", "Design provider manifest references and digests are current", { ruleId: "DPROV-003" });
  if (externalizationProblems.length) addResult(acc, catalog, "FAIL", `Design provider manifest externalization binding is invalid: ${[...new Set(externalizationProblems)].join(", ")}`, { ruleId: "DPROV-004", artifact: "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json", field: "externalization" });
  else addResult(acc, catalog, "PASS", "Design provider manifest cites a binding approved externalization entry", { ruleId: "DPROV-004" });
  if (preflightProblems.length) addResult(acc, catalog, "FAIL", `Design provider preflight or output contract is invalid: ${[...new Set(preflightProblems)].join(", ")}`, { ruleId: "DPROV-005", artifact: "DESIGN/CLAUDE-DESIGN/REVIEW.json" });
  else if (!reviewExists) addResult(acc, catalog, "PASS", "No design provider review recorded yet (preflight not required before review exists)", { ruleId: "DPROV-005" });
  else addResult(acc, catalog, "PASS", "Design provider preflight and output placement are valid", { ruleId: "DPROV-005" });
  if (authorityProblems.length) addResult(acc, catalog, "FAIL", `Design provider review authority is invalid: ${[...new Set(authorityProblems)].join(", ")}`, { ruleId: "DPROV-006", artifact: "DESIGN/CLAUDE-DESIGN/REVIEW.json" });
  else if (!reviewExists) addResult(acc, catalog, "PASS", "No design provider review recorded yet", { ruleId: "DPROV-006" });
  else addResult(acc, catalog, "PASS", "Design provider review carries valid Human acceptance evidence", { ruleId: "DPROV-006" });
  if (changeControlProblems.length) addResult(acc, catalog, "FAIL", `Design provider findings violate Change Control routing: ${[...new Set(changeControlProblems)].join(", ")}`, { ruleId: "DPROV-007", artifact: "DESIGN/CLAUDE-DESIGN/REVIEW.json" });
  else addResult(acc, catalog, "PASS", "Design provider findings are routed through Change Control", { ruleId: "DPROV-007" });
}
