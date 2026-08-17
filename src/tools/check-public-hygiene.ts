// `check-public-hygiene`, ported from scripts/check-public-hygiene.ps1. Scans
// tracked files for old names, local paths, stale branch topology, concrete
// commit ids, and secret token patterns.

import { readFileSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

interface HygieneCheck {
  id: string;
  pattern: string;
  regex: boolean;
  description: string;
}

interface HygieneResult {
  output: string;
  exitCode: number;
}

function toRepoPath(p: string): string {
  return p.replace(/\\/g, "/");
}

function isTextFile(fullPath: string): boolean {
  const bytes = readFileSync(fullPath);
  if (bytes.length === 0) return true;
  const limit = Math.min(bytes.length, 4096);
  for (let i = 0; i < limit; i++) if (bytes[i] === 0) return false;
  return true;
}

export function checkPublicHygiene(repoPath: string): HygieneResult {
  const repo = resolve(repoPath);
  const allowlistPath = join(repo, "pmo-config/public-hygiene-allowlist.json");
  if (!existsSync(allowlistPath)) {
    return { output: "FAIL: missing public hygiene allowlist: pmo-config/public-hygiene-allowlist.json\n", exitCode: 1 };
  }
  const allowlist = JSON.parse(readFileSync(allowlistPath, "utf8")) as Record<string, unknown>;

  function testAllowedMatch(relativePath: string, pattern: string): boolean {
    for (const entry of (allowlist["allowed_matches"] as Array<Record<string, unknown>>) ?? []) {
      if (entry["pattern"] !== pattern) continue;
      for (const allowedPath of (entry["paths"] as string[]) ?? []) {
        if (toRepoPath(relativePath) === toRepoPath(allowedPath)) return true;
      }
    }
    return false;
  }

  // private denylist (local, gitignored) — silently skipped if absent
  const privateChecks: HygieneCheck[] = [];
  const privatePatternsPath = join(repo, ".local/private-hygiene-patterns.json");
  if (existsSync(privatePatternsPath)) {
    const privateConfig = JSON.parse(readFileSync(privatePatternsPath, "utf8"));
    let i = 0;
    for (const pattern of (privateConfig["private_patterns"] as string[]) ?? []) {
      i++;
      privateChecks.push({ id: `PRIVATE-LOCAL-${String(i).padStart(3, "0")}`, pattern, regex: false, description: "private project name (local denylist)" });
    }
  }

  const trackedFiles: string[] = [
    ...spawnSync("git", ["-C", repo, "ls-files", "--cached"], { encoding: "utf8" }).stdout!.split("\n"),
    ...spawnSync("git", ["-C", repo, "ls-files", "--others", "--exclude-from=.gitignore"], { encoding: "utf8" }).stdout!.split("\n"),
  ].map((f) => f.trim()).filter(Boolean);
  const uniqueTracked = [...new Set(trackedFiles)];

  const selfExcludedPaths = ["pmo-config/public-hygiene-allowlist.json", "src/tools/check-public-hygiene.ts"];

  const checks: HygieneCheck[] = [
    { id: "OLD-NAME-001", pattern: "PMO-Template-Personal", regex: false, description: "old private product name" },
    { id: "LOCAL-PATH-001", pattern: "[A-Z]:\\\\Users\\\\", regex: true, description: "Windows local user path" },
    { id: "LOCAL-PATH-002", pattern: "/Users/[^/\\s]+", regex: true, description: "macOS local user path" },
    { id: "LOCAL-PATH-003", pattern: "~/Documents/", regex: true, description: "home Documents path" },
    { id: "OLD-URL-001", pattern: "github\\.com/witchwasin/PMO-Template-Personal", regex: true, description: "old repository URL" },
    { id: "BRANCH-001", pattern: "remediation/9plus", regex: false, description: "old remediation branch topology" },
    { id: "BRANCH-002", pattern: "hardening/0.5", regex: false, description: "old hardening branch topology" },
    { id: "COMMIT-001", pattern: "37c919b", regex: false, description: "old concrete commit id" },
    { id: "COMMIT-002", pattern: "8650f0f", regex: false, description: "old concrete commit id" },
    { id: "SECRET-001", pattern: "ghp_[A-Za-z0-9_]{20,}", regex: true, description: "GitHub token-like string" },
    { id: "SECRET-002", pattern: "github_pat_[A-Za-z0-9_]{20,}", regex: true, description: "GitHub fine-grained token-like string" },
    { id: "SECRET-003", pattern: "sk-[A-Za-z0-9]{20,}", regex: true, description: "API key-like string" },
    { id: "SECRET-004", pattern: "AKIA[0-9A-Z]{16}", regex: true, description: "AWS access key-like string" },
    { id: "SECRET-005", pattern: "BEGIN PRIVATE KEY", regex: true, description: "private key marker" },
    { id: "SECRET-006", pattern: "Bearer\\s+[A-Za-z0-9._~+/-]+=*", regex: true, description: "Bearer token-like string" },
    ...privateChecks,
  ];

  const problems: string[] = [];
  for (const file of uniqueTracked) {
    const relativePath = toRepoPath(file);
    if (selfExcludedPaths.includes(relativePath)) continue;
    // dist/ is the committed, generated bundle (DEC-026 §3). Its bytes are a
    // compiled copy of src/ and necessarily repeat the same literal patterns
    // (secret-token regexes, historical commit ids) this check exists to catch
    // in *authored* files. Scanning generated output would report the same
    // finding twice — once in src/, once in dist/ — with no new information.
    if (relativePath.startsWith("dist/")) continue;
    const fullPath = join(repo, file);
    if (!existsSync(fullPath)) continue;
    if (!isTextFile(fullPath)) continue;

    const text = readFileSync(fullPath, "utf8");
    for (const check of checks) {
      const matched = check.regex ? new RegExp(check.pattern).test(text) : text.includes(check.pattern);
      if (!matched) continue;
      if (testAllowedMatch(relativePath, check.pattern)) continue;
      problems.push(`${check.id}: ${check.description} in ${relativePath} (pattern: ${check.pattern})`);
    }
  }

  if (problems.length === 0) return { output: `Axiom-PMO Public Hygiene Check: ${repo}\nSummary: PASS=1 FAIL=0\n`, exitCode: 0 };

  const lines = [`Axiom-PMO Public Hygiene Check: ${repo}`, ...problems.map((p) => `[FAIL] ${p}`), `Summary: PASS=0 FAIL=${problems.length}`];
  return { output: lines.join("\n") + "\n", exitCode: 1 };
}
