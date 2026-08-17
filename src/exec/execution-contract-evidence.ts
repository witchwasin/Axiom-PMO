// Real test-evidence verification, ported from scripts/lib/execution-contract-evidence.ps1.
// Opens files, hashes bytes, parses XML, queries the gh API. Every check
// defaults to Verified=false on any ambiguity.

import { readFileSync, existsSync } from "node:fs";
import { join, resolve, isAbsolute, sep } from "node:path";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import type { TestEvidenceEntry } from "./execution-contract-schema.js";

export interface EvidenceResult {
  verified: boolean;
  reason: string | null;
  evidenceDigest: string | null;
}

function sha256Hex(data: Buffer | string): string {
  return createHash("sha256").update(data).digest("hex").toLowerCase();
}

function isContained(projectPath: string, relPath: string): { ok: boolean; full?: string; reason?: string } {
  if (/^[/\\]/.test(relPath) || /^[A-Za-z]:[\\/]?/.test(relPath)) {
    return { ok: false, reason: `path '${relPath}' is absolute; paths must be relative to the project root` };
  }
  const rootFull = resolve(projectPath);
  const resolvedFull = resolve(join(projectPath, relPath));
  if (resolvedFull !== rootFull && !resolvedFull.startsWith(rootFull + sep)) {
    return { ok: false, reason: `path '${relPath}' escapes the project root -- containment breach` };
  }
  if (!existsSync(resolvedFull)) {
    return { ok: false, reason: `no file at '${relPath}'` };
  }
  return { ok: true, full: resolvedFull };
}

function xmlIntAttribute(node: { attributes: Record<string, unknown> }, name: string): number {
  const attr = node.attributes[name];
  if (attr === undefined) return 0;
  const parsed = Number.parseInt(String(attr), 10);
  return Number.isNaN(parsed) ? 0 : parsed;
}

interface JUnitSuite {
  attributes: Record<string, unknown>;
}

// Minimal, safe JUnit XML parse: no DTD/external entities are possible because
// we never resolve external resources; a regex-free structural parse into a
// flat <testsuite> list. For JUnit's simple shape this is sufficient and safe.
function parseJUnitSuites(xml: string): JUnitSuite[] {
  const suites: JUnitSuite[] = [];
  const suiteRe = /<testsuite\b([^>]*)\/?>/g;
  let m: RegExpExecArray | null;
  while ((m = suiteRe.exec(xml)) !== null) {
    const attrs: Record<string, unknown> = {};
    const attrRe = /([A-Za-z_][\w-]*)\s*=\s*"([^"]*)"/g;
    let am: RegExpExecArray | null;
    while ((am = attrRe.exec(m[1]!)) !== null) attrs[am[1]!] = am[2];
    suites.push({ attributes: attrs });
  }
  return suites;
}

export function testJUnitEvidence(entry: TestEvidenceEntry, projectPath: string): EvidenceResult {
  const result: EvidenceResult = { verified: false, reason: null, evidenceDigest: null };
  const relPath = String(entry.raw["path"] ?? "");
  const claimedSha = String(entry.raw["sha256"] ?? "");

  const containment = isContained(projectPath, relPath);
  if (!containment.ok) { result.reason = containment.reason!; return result; }
  const full = containment.full!;

  const actualSha = sha256Hex(readFileSync(full));
  if (actualSha !== claimedSha.toLowerCase()) {
    result.reason = `the file's actual SHA-256 (${actualSha}) does not match the claimed sha256 (${claimedSha})`;
    return result;
  }

  let xml: string;
  try {
    xml = readFileSync(full, "utf8");
  } catch {
    result.reason = "the file's contents could not be read as text";
    return result;
  }

  const suites = parseJUnitSuites(xml);
  if (suites.length === 0) {
    result.reason = "no <testsuite> element found -- not a JUnit XML document";
    return result;
  }
  let totalTests = 0;
  let totalFailures = 0;
  let totalErrors = 0;
  for (const suite of suites) {
    totalTests += xmlIntAttribute(suite, "tests");
    totalFailures += xmlIntAttribute(suite, "failures");
    totalErrors += xmlIntAttribute(suite, "errors");
  }
  if (totalTests === 0) {
    result.reason = "the JUnit report has zero recorded tests -- an empty report is not evidence a test suite ran";
    return result;
  }
  if (totalFailures + totalErrors > 0) {
    result.reason = `the JUnit report itself records ${totalFailures} failure(s) and ${totalErrors} error(s) -- a failing run is not evidence of a passing test`;
    return result;
  }

  result.verified = true;
  result.evidenceDigest = actualSha;
  return result;
}

export function getGitHubOwnerRepo(remoteUrl: string): string | null {
  if (!remoteUrl?.trim()) return null;
  const m = /github\.com[:/]([^/]+)\/([^/.]+?)(\.git)?$/.exec(remoteUrl.trim());
  if (!m) return null;
  return `${m[1]}/${m[2]}`;
}

function ghApi(apiPath: string): { ok: boolean; output: string } {
  const r = spawnSync("gh", ["api", apiPath], { encoding: "utf8" });
  return { ok: r.status === 0, output: r.stdout ?? "" };
}

function gitRemote(repoRoot: string): { ok: boolean; output: string } {
  const r = spawnSync("git", ["-C", repoRoot, "remote", "get-url", "origin"], { encoding: "utf8" });
  return { ok: r.status === 0, output: (r.stdout ?? "").trim() };
}

function resolveGhOwnerRepo(repoRoot: string): { ok: boolean; ownerRepo?: string; reason?: string } {
  const r = spawnSync("gh", ["--version"], { encoding: "utf8" });
  if (r.status !== 0) return { ok: false, reason: "no GitHub API context available (gh CLI not found on PATH) -- cannot independently verify, so this is unverified rather than a pass" };
  const remote = gitRemote(repoRoot);
  const remoteUrl = remote.output;
  if (!remote.ok || !remoteUrl.trim()) return { ok: false, reason: "could not resolve a git remote to query -- cannot independently verify" };
  const ownerRepo = getGitHubOwnerRepo(remoteUrl);
  if (!ownerRepo) return { ok: false, reason: "the git remote is not a recognizable GitHub URL -- cannot independently verify" };
  return { ok: true, ownerRepo };
}

export function testCiCheckEvidence(entry: TestEvidenceEntry, gitRepoRoot: string): EvidenceResult {
  const result: EvidenceResult = { verified: false, reason: null, evidenceDigest: null };
  const name = String(entry.raw["name"] ?? "");
  const commitSha = String(entry.raw["commit_sha"] ?? "");
  const checkRunId = String(entry.raw["check_run_id"] ?? "");
  if (!name.trim() || !commitSha.trim()) {
    result.reason = "missing name or commit_sha";
    return result;
  }

  const ctx = resolveGhOwnerRepo(gitRepoRoot);
  if (!ctx.ok) { result.reason = ctx.reason!; return result; }
  const ownerRepo = ctx.ownerRepo!;

  if (checkRunId.trim() !== "") {
    const parsedId = Number.parseInt(checkRunId, 10);
    if (Number.isNaN(parsedId)) {
      result.reason = `check_run_id '${checkRunId}' is not a valid integer`;
      return result;
    }
    const runApi = ghApi(`repos/${ownerRepo}/check-runs/${parsedId}`);
    if (!runApi.ok) {
      result.reason = `the GitHub API query for check run ${parsedId} failed -- cannot independently verify (network, auth, or the run does not exist)`;
      return result;
    }
    let run: Record<string, unknown>;
    try { run = JSON.parse(runApi.output); } catch {
      result.reason = `the GitHub API response for check run ${parsedId} could not be parsed`;
      return result;
    }
    if (String(run["head_sha"] ?? "") !== commitSha) {
      result.reason = `check run ${parsedId} belongs to commit ${run["head_sha"]}, not ${commitSha} -- cannot cite it as evidence for a different commit`;
      return result;
    }
    if (String(run["name"] ?? "") !== name) {
      result.reason = `check run ${parsedId} is named '${run["name"]}', not '${name}' (case-sensitive) -- the id and name in the evidence entry disagree`;
      return result;
    }
    if (String(run["status"] ?? "") !== "completed") {
      result.reason = `check run ${parsedId} has not completed (status: ${run["status"]}) -- an unfinished check is not evidence of a passing test`;
      return result;
    }
    if (String(run["conclusion"] ?? "") !== "success") {
      result.reason = `check run ${parsedId}'s observed conclusion is '${run["conclusion"]}', not success`;
      return result;
    }
    result.verified = true;
    return result;
  }

  const api = ghApi(`repos/${ownerRepo}/commits/${commitSha}/check-runs`);
  if (!api.ok) {
    result.reason = `the GitHub API query for commit ${commitSha} failed -- cannot independently verify (network, auth, or the commit is not on GitHub)`;
    return result;
  }
  let data: { check_runs?: Array<Record<string, unknown>> };
  try { data = JSON.parse(api.output); } catch {
    result.reason = "the GitHub API response could not be parsed";
    return result;
  }
  const matchingRuns = (data.check_runs ?? []).filter((r) => String(r["name"] ?? "") === name);
  if (matchingRuns.length === 0) {
    result.reason = `no check run named '${name}' (case-sensitive) was found for commit ${commitSha}`;
    return result;
  }
  const completedRuns = matchingRuns.filter((r) => String(r["status"] ?? "") === "completed");
  if (completedRuns.length === 0) {
    const inFlight = matchingRuns.map((r) => String(r["status"] ?? "")).join(", ");
    result.reason = `check run '${name}' on commit ${commitSha} has not completed (status: ${inFlight}) -- an unfinished check is not evidence of a passing test`;
    return result;
  }
  const nonSuccess = completedRuns.filter((r) => String(r["conclusion"] ?? "") !== "success");
  if (nonSuccess.length > 0) {
    const conclusions = completedRuns.map((r) => String(r["conclusion"] ?? "")).join(", ");
    if (completedRuns.length > 1) {
      result.reason = `commit ${commitSha} has ${completedRuns.length} completed check runs named '${name}' and they do not all report success (observed: ${conclusions}). A name that passed on one attempt and failed on another is not evidence.`;
    } else {
      result.reason = `the check run's conclusion, as observed via the GitHub API, is '${conclusions}', not success`;
    }
    return result;
  }

  result.verified = true;
  return result;
}

export function testRunnerExitEvidence(entry: TestEvidenceEntry, projectPath: string, contractSha256: string, workItemId: string): EvidenceResult {
  const result: EvidenceResult = { verified: false, reason: null, evidenceDigest: null };
  const relPath = String(entry.raw["run_record_path"] ?? "");
  if (!relPath.trim()) {
    result.reason = "no run_record_path -- a runner-exit-record must point at the sealed file scripts/run-execution-command.ps1 produced, not describe its own command/exit_code inline";
    return result;
  }

  const containment = isContained(projectPath, relPath);
  if (!containment.ok) { result.reason = containment.reason!.replace("path", "run_record_path"); return result; }
  const recordFull = containment.full!;
  const sidecarFull = recordFull + ".sha256";
  if (!existsSync(sidecarFull)) {
    result.reason = `run record at '${relPath}' has no .sha256 sidecar -- an unsealed record is not evidence`;
    return result;
  }

  const sidecarText = readFileSync(sidecarFull, "utf8").trim().toLowerCase();
  const actualDigest = sha256Hex(readFileSync(recordFull));
  if (sidecarText !== actualDigest) {
    result.reason = "the run record's contents do not match its sealed digest -- it was modified after scripts/run-execution-command.ps1 wrote it";
    return result;
  }

  let record: Record<string, unknown>;
  try { record = JSON.parse(readFileSync(recordFull, "utf8")); } catch {
    result.reason = "the run record is not valid JSON";
    return result;
  }
  if (String(record["sealed_by"] ?? "") !== "axiom-runner") {
    result.reason = "the run record's sealed_by is not 'axiom-runner'";
    return result;
  }
  if (String(record["work_item_id"] ?? "") !== workItemId) {
    result.reason = `the run record is bound to work item '${record["work_item_id"]}', not '${workItemId}' -- evidence for different work cannot satisfy this contract`;
    return result;
  }
  if (String(record["contract_sha256"] ?? "") !== contractSha256) {
    result.reason = "the run record is bound to a different contract digest -- it was not produced against the contract being verified";
    return result;
  }
  const exitCode = Number.parseInt(String(record["exit_code"] ?? ""), 10);
  if (Number.isNaN(exitCode)) {
    result.reason = "the run record's exit_code is not a valid integer";
    return result;
  }
  if (exitCode !== 0) {
    result.reason = `the sealed exit code was ${exitCode}, not 0`;
    return result;
  }

  result.verified = true;
  result.evidenceDigest = actualDigest;
  return result;
}

export function testEvidenceEntryVerified(entry: TestEvidenceEntry, projectPath: string, gitRepoRoot: string, contractSha256: string, workItemId: string): EvidenceResult {
  if (!entry.known) return { verified: false, reason: `unrecognized evidence type '${entry.type}'`, evidenceDigest: null };
  if (!entry.fieldsPresent) return { verified: false, reason: `missing required field(s): ${entry.missingFields.join(", ")}`, evidenceDigest: null };

  switch (entry.type) {
    case "junit-artifact": return testJUnitEvidence(entry, projectPath);
    case "ci-check": return testCiCheckEvidence(entry, gitRepoRoot);
    case "runner-exit-record": return testRunnerExitEvidence(entry, projectPath, contractSha256, workItemId);
    default: return { verified: false, reason: `'${entry.type}' is not independently verifiable by design (agent-claimed evidence)`, evidenceDigest: null };
  }
}
