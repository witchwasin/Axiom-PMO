// Failure Pattern Registry aggregator, ported from scripts/aggregate-diagnostics.ps1.
// Stateful: writes immutable event files + rebuilds FAILURE-PATTERNS.json from
// every event on disk. Local and opt-in by construction.

import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, statSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { randomBytes, createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { runPortedChain } from "../probe/validate-chain.js";

function sha256Hex(data: string): string {
  return createHash("sha256").update(data, "utf8").digest("hex").toLowerCase();
}

// Pure privacy-boundary functions, hoisted to module scope (out of
// aggregateDiagnostics' closure) and exported so they are directly unit
// testable, matching how tests/helpers/learning-registry-tests.ps1
// dot-sources scripts/aggregate-diagnostics.ps1 for these definitions.
export function normalizeItemId(itemId: string, allowedPatterns: string[]): string | null {
  if (!itemId?.trim()) return null;
  for (const pattern of allowedPatterns) {
    if (new RegExp(pattern).test(itemId)) return itemId.replace(/\d+/g, "#");
  }
  return "other";
}

export function governedArtifactOrOther(artifact: string, allowlist: string[]): string | null {
  if (!artifact?.trim()) return null;
  if (allowlist.includes(artifact)) return artifact;
  return "other";
}

export function normalizeExecutionPath(ep: string, allowed: string[]): string {
  return allowed.includes(ep) ? ep : "unknown";
}

export interface AggregateResult {
  output: string;
  exitCode: number;
  registry: Record<string, unknown> | null;
}

export function aggregateDiagnostics(
  repoRoot: string,
  projectPath: string | null,
  mode: string,
  gate: string,
  rebuildOnly: boolean,
  format: "Text" | "Json",
): AggregateResult {
  const repo = resolve(repoRoot);
  const policyPath = join(repo, "pmo-config/learning-policy.json");
  if (!existsSync(policyPath)) throw new Error(`Missing runtime learning policy config: ${policyPath}`);
  const policy = JSON.parse(readFileSync(policyPath, "utf8")) as Record<string, unknown>;

  const eventsDir = join(repo, String((policy["storage"] as Record<string, unknown>)["events_dir"]));
  const registryPath = join(repo, String((policy["storage"] as Record<string, unknown>)["registry_path"]));
  const saltPath = join(repo, String((policy["storage"] as Record<string, unknown>)["salt_path"]));
  mkdirSync(eventsDir, { recursive: true });

  function getRepositorySalt(): string {
    if (existsSync(saltPath)) return readFileSync(saltPath, "utf8").trim();
    const salt = randomBytes(32).toString("hex");
    mkdirSync(dirname(saltPath), { recursive: true });
    writeFileSync(saltPath, salt);
    return salt;
  }

  function getProjectHash(projectAbs: string, salt: string): string {
    return sha256Hex(`${salt}|${projectAbs}`);
  }

  if (!rebuildOnly) {
    if (!projectPath) throw new Error("aggregate-diagnostics requires -ProjectPath unless -RebuildOnly is set.");
    const project = resolve(projectPath);
    // The reference records the child validator's *effective* mode (mode-
    // resolver escalation), never the requested one -- a strict-triggered
    // project must be clustered as Strict even when aggregated at Standard.
    const chain = runPortedChain(repo, project, mode as "Lite" | "Standard" | "Strict", gate as "Draft" | "Scope" | "Design" | "Handoff" | "Release");
    const envelope = { effective_mode: chain.effectiveMode, gate, results: chain.diagnostics };
    if (!envelope.results) throw new Error(`aggregate-diagnostics: validate-project produced no parseable diagnostics for ${project}.`);

    const salt = getRepositorySalt();
    const projectHash = getProjectHash(project, salt);
    let executionPathMatch = "development_handoff";
    const projectMdPath = join(project, "PROJECT.md");
    if (existsSync(projectMdPath)) {
      const m = /^\s*>?\s*Execution path:\s*(.+?)\s*$/m.exec(readFileSync(projectMdPath, "utf8"));
      if (m) executionPathMatch = m[1]!.trim();
    }
    executionPathMatch = normalizeExecutionPath(executionPathMatch, (policy["execution_path_allowed_values"] as string[]) ?? []);

    const commitOut = spawnSync("git", ["-C", project, "rev-parse", "HEAD"], { encoding: "utf8" });
    const commitHash = commitOut.status === 0 && commitOut.stdout?.trim() ? commitOut.stdout.trim() : null;

    const runId = randomBytes(16).toString("hex");
    const timestamp = new Date().toISOString().replace(/[-:T.]/g, "").slice(0, 15) + "Z";
    const eventFile = join(eventsDir, `${timestamp}-${runId}.jsonl`);

    const allowlist = (policy["governed_artifact_allowlist"] as string[]) ?? [];
    const lines: string[] = [];
    for (const row of envelope.results) {
      if (row.level !== "WARN" && row.level !== "FAIL") continue;
      const event = {
        schema_version: "1.0",
        recorded_at: new Date().toISOString(),
        run_id: runId,
        rule_id: row.rule_id,
        level: row.level,
        blocking: row.blocking,
        mode: envelope.effective_mode,
        gate: envelope.gate,
        execution_path: executionPathMatch,
        artifact: governedArtifactOrOther(row.artifact ?? "", allowlist),
        item_id: normalizeItemId(row.item_id ?? "", (policy["item_id_allowed_patterns"] as string[]) ?? []),
        project_hash: projectHash,
        commit_hash: commitHash,
      };
      lines.push(JSON.stringify(event));
    }
    if (lines.length > 0) writeFileSync(eventFile, lines.join("\n"));
  }

  // Rebuild registry from events
  const allEvents: Array<Record<string, unknown>> = [];
  if (existsSync(eventsDir)) {
    for (const f of readdirSync(eventsDir).filter((f) => f.endsWith(".jsonl")).sort()) {
      const content = readFileSync(join(eventsDir, f), "utf8");
      for (const line of content.split("\n")) {
        if (!line.trim()) continue;
        try { allEvents.push(JSON.parse(line)); } catch {}
      }
    }
  }

  const byRule = new Map<string, { rule_id: string; count: number; run_ids: Set<string>; commits: Set<string>; projects: Set<string>; item_id_patterns: Set<string>; first_seen: string; last_seen: string }>();
  for (const event of allEvents) {
    const ruleId = String(event["rule_id"]);
    if (!byRule.has(ruleId)) {
      byRule.set(ruleId, { rule_id: ruleId, count: 0, run_ids: new Set(), commits: new Set(), projects: new Set(), item_id_patterns: new Set(), first_seen: String(event["recorded_at"]), last_seen: String(event["recorded_at"]) });
    }
    const e = byRule.get(ruleId)!;
    e.count++;
    if (event["run_id"]) e.run_ids.add(String(event["run_id"]));
    if (event["commit_hash"]) e.commits.add(String(event["commit_hash"]));
    if (event["project_hash"]) e.projects.add(String(event["project_hash"]));
    if (event["item_id"]) e.item_id_patterns.add(String(event["item_id"]));
    if (String(event["recorded_at"]) < e.first_seen) e.first_seen = String(event["recorded_at"]);
    if (String(event["recorded_at"]) > e.last_seen) e.last_seen = String(event["recorded_at"]);
  }

  const clusters = [...byRule.keys()].sort().map((ruleId) => {
    const e = byRule.get(ruleId)!;
    return {
      rule_id: e.rule_id,
      count: e.count,
      distinct_run_ids: e.run_ids.size,
      distinct_commits: e.commits.size,
      distinct_projects: e.projects.size,
      distinct_item_id_patterns: [...e.item_id_patterns].sort(),
      first_seen: e.first_seen,
      last_seen: e.last_seen,
      disposition: "undetermined",
    };
  });

  const registry = {
    schema_version: "1.0",
    generated_at: new Date().toISOString(),
    rebuilt_from_event_count: allEvents.length,
    clusters,
  };
  mkdirSync(dirname(registryPath), { recursive: true });
  writeFileSync(registryPath, JSON.stringify(registry, null, 2));

  if (format === "Json") return { output: JSON.stringify(registry, null, 2) + "\n", exitCode: 0, registry };

  const lines2: string[] = [];
  lines2.push("Axiom-PMO Failure Pattern Registry");
  lines2.push(`  events dir : ${eventsDir} (${allEvents.length} events)`);
  lines2.push(`  registry   : ${registryPath}`);
  lines2.push("");
  for (const c of clusters) {
    lines2.push(`${c.rule_id}: ${c.count} event(s), ${c.distinct_projects} project(s), ${c.distinct_commits} commit(s)`);
  }
  return { output: lines2.join("\n") + "\n", exitCode: 0, registry };
}
