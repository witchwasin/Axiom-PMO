// Guided Research (RESEARCH-002..007), ported from scripts/lib/research-validator.ps1.

import { readFileSync, existsSync, statSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { getProjectOrchestrationDeclarations } from "../config/config-loader.js";
import { testPlaceholderValue } from "../config/config-loader.js";
import { getTableRowsAfterHeading, type TableRow } from "../markdown/table-parser.js";
import { testPhysicalContainment } from "../core/path-containment.js";
import { testGenericOwner } from "../core/owner-policy.js";
import { getDecisionDecider } from "./decision-log.js";
import { addResult } from "../core/result-writer.js";
import type { ResultAccumulator, ValidationRules } from "../core/context.js";
import type { Gate } from "../core/types.js";

function getResearchSnapshotIds(project: string): string[] {
  const ids: string[] = [];
  const projectMd = join(project, "PROJECT.md");
  if (existsSync(projectMd)) {
    try {
      const text = readFileSync(projectMd, "utf8");
      for (const row of getTableRowsAfterHeading(text, "(?i)^\\s*#{1,4}\\s*Source Snapshot\\s*$")) {
        let first = Object.values(row)[0] ?? null;
        if (row["Source ID"]) first = row["Source ID"]!;
        if (first && first.trim() !== "") ids.push(first.trim());
      }
    } catch {}
  }
  const sourceRoot = join(project, "source");
  if (existsSync(sourceRoot)) {
    const walk = (dir: string) => {
      for (const entry of readdirSync(dir)) {
        const full = join(dir, entry);
        let st;
        try { st = statSync(full); } catch { continue; }
        if (st.isDirectory()) walk(full);
        else if (st.isFile()) {
          for (const m of entry.matchAll(/([A-Z]{2,6}-\d{6,8})/g)) ids.push(m[1]!);
        }
      }
    };
    walk(sourceRoot);
  }
  return [...new Set(ids)].sort();
}

function getProjectTextCache(project: string): string {
  const parts: string[] = [];
  for (const relative of ["PROJECT.md", "source/"]) {
    const path = join(project, relative);
    if (existsSync(path)) {
      try {
        const content = readFileSync(path, "utf8");
        if (content) parts.push(content);
      } catch {}
    }
  }
  return parts.join("\n");
}

function testResearchSourceResolvable(reference: string, project: string, snapshotIds: string[], decisionIds: string[] | null, projectText: string): boolean {
  const ref = reference.trim();
  if (!ref) return false;
  if (/^https?:\/\//.test(ref)) return true;
  if (/^FILE:/.test(ref)) {
    const relative = ref.substring(5).trim();
    if (!relative) return false;
    const full = resolve(join(project, relative));
    const root = resolve(project);
    return testPhysicalContainment(full, root) && existsSync(full) && statSync(full).isFile();
  }
  if (/^DEC-\d{3,}$/.test(ref)) return (decisionIds ?? []).includes(ref);
  if (/^(MOM|REQ)-[A-Za-z0-9_]+/.test(ref)) return snapshotIds.includes(ref);
  if (/^(TR|ISSUE|PR)-\S+/.test(ref)) {
    return projectText.trim() !== "" && new RegExp(ref.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).test(projectText);
  }
  return false;
}

export function testResearchWorkflow(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  project: string,
  gate: Gate,
  orchestrationPolicy: Record<string, unknown>,
  policyEnums: Record<string, unknown>,
  decisionIds: string[] | null,
  handoffPolicy: Record<string, unknown>,
): void {
  const policy = (orchestrationPolicy["research"] as Record<string, unknown>) ?? {};
  const mode = getProjectOrchestrationDeclarations(project).researchMode;
  if (!mode || mode === "off") return;
  if (gate === "Draft") return;

  const reportPath = join(project, String(policy["report_artifact"] ?? "RESEARCH/RESEARCH.md"));
  const provenancePath = join(project, String(policy["provenance_artifact"] ?? "RESEARCH/PROVENANCE.json"));

  const structureProblems: string[] = [];
  let reportText = "";
  if (!existsSync(reportPath)) {
    structureProblems.push("RESEARCH/RESEARCH.md");
  } else {
    reportText = readFileSync(reportPath, "utf8");
    const requiredSections = [
      "Research Status and Scope",
      "Problem and Research Questions",
      "Existing Solutions",
      "Feature Parity",
      "Relevant Standards and Regulations",
      "Differentiation and Value Implications",
      "Risks and Unknowns",
      "Impact Assessment",
      "Change Proposals",
      "Explicit Limits and Unanswered Questions",
    ];
    for (const section of requiredSections) {
      const pattern = new RegExp(`^\\s*#{1,4}\\s*${section.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*$`, "im");
      if (!pattern.test(reportText)) structureProblems.push(section);
    }
  }

  let provenance: Record<string, unknown> | null = null;
  let claims: Array<Record<string, unknown>> = [];
  const claimIds: string[] = [];
  let researchStatus: string | null = null;
  if (!existsSync(provenancePath)) {
    structureProblems.push("RESEARCH/PROVENANCE.json");
  } else {
    try {
      provenance = JSON.parse(readFileSync(provenancePath, "utf8"));
    } catch {
      addResult(acc, catalog, "FAIL", "RESEARCH/PROVENANCE.json is not valid JSON", { ruleId: "RESEARCH-002", artifact: "RESEARCH/PROVENANCE.json" });
      return;
    }
    const prov = provenance as Record<string, unknown>;
    if (prov["schema_version"] !== "1.0") structureProblems.push("schema_version");
    claims = (prov["claims"] as Array<Record<string, unknown>>) ?? [];
    if (claims.length === 0) structureProblems.push("claims");
    for (const claim of claims) {
      if (/^RC-\d{3,}$/.test(String(claim["id"] ?? ""))) claimIds.push(String(claim["id"]));
    }
    const rs = prov["research_status"];
    if (rs && String(rs).trim() !== "") researchStatus = String(rs).trim();
  }

  const provenanceProblems: string[] = [];
  let evidenceStatuses = (policyEnums["evidence_statuses"] as string[]) ?? [];
  if (evidenceStatuses.length === 0) evidenceStatuses = ["verified", "supported", "inferred", "missing", "conflict"];
  let sourceVerifications = (policy["source_verifications"] as string[]) ?? [];
  if (sourceVerifications.length === 0) sourceVerifications = ["verified", "unverified", "pending"];
  let freshnessModels = (policy["freshness_models"] as string[]) ?? [];
  if (freshnessModels.length === 0) freshnessModels = ["cutoff", "none"];

  let freshnessCutoff: string | null = null;
  if (provenance) {
    const freshness = provenance["freshness"] as Record<string, unknown> | undefined;
    if (!freshness || String(freshness["model"] ?? "").trim() === "") {
      provenanceProblems.push("freshness");
    } else if (!freshnessModels.includes(String(freshness["model"]))) {
      provenanceProblems.push("freshness model");
    } else if (String(freshness["model"]) === "cutoff") {
      const cutoffRaw = String(freshness["cutoff"] ?? "").trim();
      if (!/^\d{4}-\d{2}-\d{2}$/.test(cutoffRaw)) provenanceProblems.push("freshness cutoff");
      else freshnessCutoff = cutoffRaw;
    }
  }
  const snapshotIds = getResearchSnapshotIds(project);
  const projectText = getProjectTextCache(project);
  const reportHeadings: string[] = [];
  for (const line of reportText.split(/\r?\n/)) {
    const m = /^\s*#{1,4}\s+(.+?)\s*$/.exec(line);
    if (m) reportHeadings.push(m[1]!.trim());
  }
  for (const claim of claims) {
    const id = String(claim["id"] ?? "");
    if (!/^RC-\d{3,}$/.test(id) || String(claim["claim"] ?? "").trim() === "" || String(claim["report_section"] ?? "").trim() === "") {
      provenanceProblems.push("claim structure");
      continue;
    }
    if (!evidenceStatuses.includes(String(claim["evidence_status"] ?? ""))) provenanceProblems.push(`${id} evidence_status`);
    if (!reportHeadings.includes(String(claim["report_section"] ?? "").trim())) provenanceProblems.push(`${id} report_section`);
    const sources = (claim["sources"] as Array<Record<string, unknown>>) ?? [];
    if (sources.length === 0) {
      provenanceProblems.push(`${id} no source`);
      continue;
    }
    let sourceOk = false;
    for (const source of sources) {
      const reference = String(source["reference"] ?? "");
      if (testResearchSourceResolvable(reference, project, snapshotIds, decisionIds, projectText)) sourceOk = true;
      const title = String(source["title"] ?? "");
      const issuer = String(source["issuer"] ?? "");
      if (title.trim() === "" || testPlaceholderValue(title) || issuer.trim() === "" || testPlaceholderValue(issuer)) provenanceProblems.push(`${id} source metadata`);
      if (typeof source["primary"] !== "boolean") provenanceProblems.push(`${id} primary`);
      if (!sourceVerifications.includes(String(source["verification"] ?? ""))) provenanceProblems.push(`${id} verification`);
      const dateVal = source["date"];
      if (freshnessCutoff !== null && (dateVal === undefined || String(dateVal ?? "").trim() === "")) {
        provenanceProblems.push(`${id} date required for cutoff`);
      } else if (dateVal !== undefined) {
        const dateRaw = String(dateVal).trim();
        if (dateRaw !== "" && !/^\d{4}-\d{2}-\d{2}$/.test(dateRaw)) provenanceProblems.push(`${id} date`);
        else if (dateRaw !== "" && freshnessCutoff !== null && dateRaw < freshnessCutoff) provenanceProblems.push(`${id} stale source`);
      }
    }
    if (!sourceOk) provenanceProblems.push(`${id} unresolvable source`);
  }

  const proposalProblems: string[] = [];
  const scopeProblems: string[] = [];
  const impactProblems: string[] = [];
  const proposalStatuses = (policy["proposal_statuses"] as string[]) ?? [];
  const proposalImpacts = (policy["proposal_impacts"] as string[]) ?? [];
  const proposalIds: string[] = [];
  const proposalByStatus: Record<string, string> = {};
  const ownerPolicy = (handoffPolicy["owner_policy"] as Record<string, unknown>) ?? {};
  if (existsSync(reportPath)) {
    reportText = readFileSync(reportPath, "utf8");
    for (const row of getTableRowsAfterHeading(reportText, "(?i)^\\s*#{1,4}\\s*Change Proposals\\s*$")) {
      const proposalId = String(row["Proposal ID"] ?? "");
      const status = String(row["Status"] ?? "").trim();
      const impact = String(row["Impact"] ?? "").trim();
      const acceptedImpact = String(row["Accepted Impact"] ?? "").trim();
      const owner = String(row["Human Owner"] ?? "");
      const decisionRef = String(row["Decision Ref"] ?? "");

      if (/^CP-\d{3,}$/.test(proposalId)) {
        proposalIds.push(proposalId);
        proposalByStatus[proposalId] = status;
      }
      if (!/^CP-\d{3,}$/.test(proposalId)) {
        proposalProblems.push("proposal structure");
        continue;
      }
      if (!proposalStatuses.includes(status)) proposalProblems.push(`${proposalId} status`);
      if (!proposalImpacts.includes(impact)) proposalProblems.push(`${proposalId} impact`);
      if (owner.trim() === "" || testGenericOwner(owner, ownerPolicy)) proposalProblems.push(`${proposalId} owner`);

      if (status === "accepted" || status === "rejected") {
        const decider = decisionRef && (decisionIds ?? []).includes(decisionRef) ? getDecisionDecider(project, decisionRef) : null;
        if (!decisionRef || !(decisionIds ?? []).includes(decisionRef) || decider === null || testGenericOwner(decider, ownerPolicy)) proposalProblems.push(`${proposalId} decision`);
      }

      const blocksScope = /^\s*yes\b/i.test(acceptedImpact) || impact === "scope";
      if (blocksScope && status === "proposed" && ["Scope", "Design", "Handoff", "Release"].includes(gate)) scopeProblems.push(proposalId);
    }
    if (researchStatus === "stopped" && ["Scope", "Design", "Handoff", "Release"].includes(gate)) scopeProblems.push("stopped research");

    for (const row of getTableRowsAfterHeading(reportText, "(?i)^\\s*#{1,4}\\s*Impact Assessment\\s*$")) {
      const findingRef = String(row["Finding Ref"] ?? "").trim();
      const mapsTo = String(row["Maps To"] ?? "").trim();
      const proposedImpact = String(row["Proposed Impact"] ?? "").trim();
      const status = String(row["Status"] ?? "").trim();
      const changeProposal = String(row["Change Proposal"] ?? "").trim();

      if (!/^RC-\d{3,}$/.test(findingRef)) {
        impactProblems.push("impact finding ref");
        continue;
      }
      if (!claimIds.includes(findingRef)) impactProblems.push(`${findingRef} unknown claim`);
      if (mapsTo.trim() === "" || testPlaceholderValue(mapsTo)) impactProblems.push(`${findingRef} maps_to`);
      if (proposedImpact.trim() === "" || testPlaceholderValue(proposedImpact)) impactProblems.push(`${findingRef} impact`);
      if (!proposalStatuses.includes(status)) impactProblems.push(`${findingRef} status`);

      if (status === "accepted") {
        if (!/^CP-\d{3,}$/.test(changeProposal)) impactProblems.push(`${findingRef} no proposal`);
        else if (!proposalIds.includes(changeProposal) || !["accepted", "rejected"].includes(proposalByStatus[changeProposal] ?? "")) impactProblems.push(`${findingRef} undecided proposal`);
      }
    }
  }

  const providerProblems: string[] = [];
  if (provenance) {
    const providerUsed = String(provenance["provider_used"] ?? "").trim();
    const declaredProvider = getProjectOrchestrationDeclarations(project).researchProvider;
    if (providerUsed.trim() === "" || testPlaceholderValue(providerUsed)) providerProblems.push("provider_used");
    const resolvedProviders = (policy["providers"] as string[] ?? []).filter((p) => p !== "none" && p !== "auto");
    if (declaredProvider === "auto") {
      if (!resolvedProviders.includes(providerUsed)) providerProblems.push("provider agreement");
    } else if (declaredProvider && declaredProvider !== "none" && providerUsed !== declaredProvider) {
      providerProblems.push("provider agreement");
    }
    if (typeof provenance["provider_available"] !== "boolean") providerProblems.push("provider_available");
    if (typeof provenance["fallback_used"] !== "boolean") providerProblems.push("fallback_used");
    const providerAvailable = typeof provenance["provider_available"] === "boolean" ? provenance["provider_available"] : null;
    const fallbackUsed = typeof provenance["fallback_used"] === "boolean" ? provenance["fallback_used"] : null;

    if (String(researchStatus ?? "").trim() === "") providerProblems.push("research_status");
    else if (!((policy["research_statuses"] as string[]) ?? []).includes(researchStatus!)) providerProblems.push("research_status");

    if (researchStatus === "stopped") {
      const stopReason = String(provenance["stop_reason"] ?? "");
      const nextAction = String(provenance["next_action"] ?? "");
      if (stopReason.trim() === "" || testPlaceholderValue(stopReason)) providerProblems.push("stop_reason");
      if (nextAction.trim() === "" || testPlaceholderValue(nextAction)) providerProblems.push("next_action");
    } else if (researchStatus !== "stopped" && providerAvailable === false && fallbackUsed === false) {
      providerProblems.push("unavailable without fallback");
    }
    if (fallbackUsed === true && providerAvailable !== false) providerProblems.push("fallback without unavailable provider");

    const retrievedAt = provenance["retrieved_at"];
    const retrievedAtOk = typeof retrievedAt === "string" && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/.test(retrievedAt);
    if (!retrievedAtOk) providerProblems.push("retrieved_at");
  }

  const externalizationProblems: string[] = [];
  const externalProviders = (policy["external_providers"] as string[]) ?? [];
  const declaredProvider = getProjectOrchestrationDeclarations(project).researchProvider;
  if (externalProviders.includes(declaredProvider ?? "")) {
    let extRef = "";
    if (provenance) extRef = String(provenance["externalization"] ?? "");
    let approvedExt: Record<string, unknown> | null = null;
    const registryPath = join(project, String((orchestrationPolicy["externalization"] as Record<string, unknown>)?.["registry"] ?? "EXTERNALIZATION.json"));
    if (existsSync(registryPath)) {
      try {
        const extDoc = JSON.parse(readFileSync(registryPath, "utf8"));
        for (const entry of extDoc.entries ?? []) {
          if (entry.status === "approved" && entry.id === extRef) approvedExt = entry;
        }
      } catch {}
    }
    if (approvedExt === null) {
      externalizationProblems.push("externalization");
    } else {
      const providerUsed = provenance ? String(provenance["provider_used"] ?? "").trim() : "";
      const extProvider = String(approvedExt["provider"] ?? "").trim();
      const providerOk = providerUsed.length > 0 && extProvider.length > 0 &&
        (extProvider.toLowerCase().includes(providerUsed.toLowerCase()) || providerUsed.toLowerCase().includes(extProvider.toLowerCase()));
      if (!providerOk) externalizationProblems.push("provider mismatch");
    }
  }

  if (structureProblems.length) addResult(acc, catalog, "FAIL", `Guided research artifacts are missing or incomplete: ${[...new Set(structureProblems)].join(", ")}`, { ruleId: "RESEARCH-002", artifact: "RESEARCH/RESEARCH.md" });
  else addResult(acc, catalog, "PASS", "Guided research artifacts declare the required contract", { ruleId: "RESEARCH-002" });
  if (provenanceProblems.length) addResult(acc, catalog, "FAIL", `Research provenance is missing or unresolvable: ${[...new Set(provenanceProblems)].join(", ")}`, { ruleId: "RESEARCH-003", artifact: "RESEARCH/PROVENANCE.json" });
  else addResult(acc, catalog, "PASS", "Every material research claim maps to a resolvable source", { ruleId: "RESEARCH-003" });
  if (proposalProblems.length || impactProblems.length) addResult(acc, catalog, "FAIL", `Research change proposals or impact assessments lack valid Human decisions: ${[...new Set([...proposalProblems, ...impactProblems])].join(", ")}`, { ruleId: "RESEARCH-004", artifact: "RESEARCH/RESEARCH.md", field: "Change Proposals" });
  else addResult(acc, catalog, "PASS", "Research change proposals carry valid Human decision evidence", { ruleId: "RESEARCH-004" });
  if (scopeProblems.length) addResult(acc, catalog, "FAIL", `Scope cannot be approved with unresolved accepted-impact research proposals: ${[...new Set(scopeProblems)].join(", ")}`, { ruleId: "RESEARCH-005", artifact: "RESEARCH/RESEARCH.md", field: "Change Proposals" });
  else if (claims.length > 0) addResult(acc, catalog, "PASS", "No unresolved accepted-impact research proposal blocks this gate", { ruleId: "RESEARCH-005" });
  if (providerProblems.length) addResult(acc, catalog, "FAIL", `Research provider availability is not recorded truthfully: ${[...new Set(providerProblems)].join(", ")}`, { ruleId: "RESEARCH-006", artifact: "RESEARCH/PROVENANCE.json" });
  else addResult(acc, catalog, "PASS", "Research provider availability and fallback are recorded truthfully", { ruleId: "RESEARCH-006" });
  if (externalizationProblems.length) addResult(acc, catalog, "FAIL", `External research providers must cite a binding approved externalization entry: ${[...new Set(externalizationProblems)].join(", ")}`, { ruleId: "RESEARCH-007", artifact: "RESEARCH/PROVENANCE.json", field: "externalization" });
  else addResult(acc, catalog, "PASS", "Research provider usage cites approved externalization evidence", { ruleId: "RESEARCH-007" });
}
