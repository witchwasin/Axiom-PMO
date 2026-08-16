// `axiom export` stateful command, ported from scripts/export-execution-contract.ps1.
// Writes EXECUTION-CONTRACT.json + .sha256 sidecar from an approved DELIVERY.md
// work item and SCOPE.json. Verified by §8.6 fresh-tree methodology.

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { join, resolve, basename } from "node:path";
import { spawnSync } from "node:child_process";
import { getTableRowsAfterHeading, splitReferenceValues, type TableRow } from "../markdown/table-parser.js";
import { readScopeDeclaration } from "../rules/scope-diff-matcher.js";
import { getExecutionFileDigest } from "../exec/execution-contract-schema.js";

export interface ExportResult {
  output: string;
  exitCode: number;
}

function failExport(msg: string): ExportResult {
  return { output: `EXPORT FAILED: ${msg}\n`, exitCode: 1 };
}

function splitCellList(value: string): string[] {
  if (!value?.trim()) return [];
  return value.split(",").map((s) => s.trim()).filter((s) => s && s !== "none" && s !== "-");
}

export function exportExecutionContract(
  repoRoot: string,
  projectPath: string,
  workItemId: string,
  gitRepoRoot: string | null,
  outputPath: string | null,
  grant: string,
  force: boolean,
): ExportResult {
  const project = resolve(projectPath);
  const gitRoot = resolve(gitRepoRoot ?? project);

  const deliveryPath = join(project, "DELIVERY.md");
  if (!existsSync(deliveryPath)) return failExport(`No DELIVERY.md in ${project}. An execution contract is generated from an approved work item; there is no work item board to read.`);
  const deliveryText = readFileSync(deliveryPath, "utf8");
  const workItems = getTableRowsAfterHeading(deliveryText, "^##\\s+Work Items");
  if (workItems.length === 0) return failExport("DELIVERY.md has no Work Items table.");

  const item = workItems.find((row) => row["ID"] === workItemId);
  if (!item) return failExport(`Work item '${workItemId}' is not in DELIVERY.md's Work Items table.`);

  let projectCode = basename(project);
  const projectMdPath = join(project, "PROJECT.md");
  if (existsSync(projectMdPath)) {
    const projectText = readFileSync(projectMdPath, "utf8");
    const m = /^#\s+(?:PROJECT\s*-\s*)?(.+?)\s*$/m.exec(projectText);
    if (m && m[1]!.trim()) projectCode = m[1]!.trim();
  }

  const scope = readScopeDeclaration(project);
  if (!scope.present) return failExport(`No SCOPE.json in ${project}. An execution contract's allowed_paths are derived from the project's approved implementation scope -- declare it first (see templates/SCOPE.json). A contract must never grant broader path access than the approved scope.`);
  if (!scope.valid) return failExport(`SCOPE.json is invalid: ${scope.error}`);

  // pinned adversarial-review workflow path → prohibited_paths
  const reviewWorkflowPaths: string[] = [];
  const adversarialReviewPolicyPath = join(repoRoot, "pmo-config/adversarial-review-policy.json");
  if (existsSync(adversarialReviewPolicyPath)) {
    const policy = JSON.parse(readFileSync(adversarialReviewPolicyPath, "utf8"));
    const pinned = String((policy["externally_observed_binding"] as Record<string, unknown>)?.["pinned_workflow_path"] ?? "");
    if (pinned.trim()) reviewWorkflowPaths.push(pinned);
  }

  const baseSha = spawnSync("git", ["-C", gitRoot, "rev-parse", "--verify", "--quiet", "HEAD^{commit}"], { encoding: "utf8" }).stdout?.trim() ?? "";
  if (!baseSha) return failExport(`Could not resolve HEAD in ${gitRoot}. The contract pins an exact base commit (never a branch name, which moves); a repository with no resolvable HEAD cannot be exported from.`);

  const grantableActions = ["create_branch", "commit", "push", "merge", "deploy"];
  const gitAuthority: Record<string, boolean> = { create_branch: true, commit: false, push: false, merge: false, deploy: false };
  for (const piece of grant.split(",")) {
    const action = piece.trim();
    if (!action) continue;
    if (!grantableActions.includes(action)) return failExport(`Unknown git action in -Grant: '${action}'. Grantable actions are: ${grantableActions.join(", ")}.`);
    gitAuthority[action] = true;
  }

  const contract = {
    contract_version: "1.0",
    generated_by: "axiom export",
    project_id: projectCode,
    work_item_id: item["ID"],
    mode: item["Mode"],
    objective: item["Feature / Deliverable"],
    requirement_refs: splitCellList(item["Requirement Ref"] ?? ""),
    design_refs: splitCellList(item["Design Ref"] ?? ""),
    acceptance_criteria: splitCellList(item["Acceptance Criteria"] ?? ""),
    required_tests: splitCellList(item["Test Checklist"] ?? ""),
    base_sha: baseSha,
    allowed_paths: scope.include,
    prohibited_paths: [...new Set([...scope.exclude, ...reviewWorkflowPaths])],
    git_authority: gitAuthority,
    verification_note: "This contract is candidate input, not an approval. The execution result produced against it is a claim until Axiom-PMO verifies it against observable git state -- see docs/reference/execution-contract.md.",
  };

  const outPath = outputPath ?? join(project, ".execution", workItemId);
  const contractPath = join(outPath, "EXECUTION-CONTRACT.json");
  if (existsSync(contractPath) && !force) return failExport(`${contractPath} already exists. Re-exporting would change the digest an existing result may already reference; pass -Force to overwrite deliberately.`);

  mkdirSync(outPath, { recursive: true });
  let json = JSON.stringify(contract, null, 2);
  json = json.replace(/\r\n/g, "\n");
  if (!json.endsWith("\n")) json += "\n";
  writeFileSync(contractPath, json, "utf8");

  const digest = getExecutionFileDigest(contractPath)!;
  writeFileSync(contractPath + ".sha256", digest + "\n", "utf8");

  return {
    output: [
      "Execution contract exported",
      `  work item : ${workItemId}`,
      `  base      : ${baseSha}`,
      `  contract  : ${contractPath}`,
      `  digest    : ${digest}`,
      "",
      `The result produced against this contract must carry contract_sha256 = ${digest}`,
      `Verify it with: axiom verify --project <path> --result ${join(outPath, "EXECUTION-RESULT.json")}`,
      "",
    ].join("\n"),
    exitCode: 0,
  };
}
