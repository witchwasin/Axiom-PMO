// SCOPE-DIFF matching engine: glob compilation, scope declaration loading, and
// per-file verdicts. No git invocation lives here (see scope-diff-git-adapter.ts).
// Ported from scripts/lib/scope-diff-matcher.ps1 — deterministic only, by design.

import { readFileSync } from "node:fs";
import { join } from "node:path";

const GLOBSTAR = "\x01";
const STAR = "\x02";
const QMARK = "\x03";

// Escape regex metacharacters the same way .NET's [regex]::Escape does for the
// set that can appear in a human glob: it does NOT escape '/', and the wildcard
// characters are already tokenized away. JS has no built-in escape, so we list
// the set explicitly.
function escapeRegex(s: string): string {
  return s.replace(/[\\^$.|+()[\]{}#]/g, "\\$&");
}

/**
 * Converts a scope glob to a regex. Grammar: `*` (any run except `/`), `?` (any
 * single char except `/`), `**` (globstar). No character classes, brace
 * expansion, or extglob. Ported from ConvertTo-ScopeGlobRegex.
 */
export function convertToScopeGlobRegex(pattern: string): string {
  const tokenized = pattern.replaceAll("**", GLOBSTAR).replaceAll("*", STAR).replaceAll("?", QMARK);
  let escaped = escapeRegex(tokenized);

  if (escaped === GLOBSTAR) {
    escaped = ".*";
  } else {
    escaped = escaped.replaceAll("/" + GLOBSTAR + "/", "/(?:.*/)?");
    escaped = escaped.replace(new RegExp("^" + GLOBSTAR + "/"), "(?:.*/)?");
    escaped = escaped.replace(new RegExp("/" + GLOBSTAR + "$"), "(?:/.*)?");
    escaped = escaped.replaceAll(GLOBSTAR, ".*");
  }

  escaped = escaped.replaceAll(STAR, "[^/]*");
  escaped = escaped.replaceAll(QMARK, "[^/]");
  return "^" + escaped + "$";
}

/** Syntax gate, ported from Test-ScopeGlobSyntax. Returns an error string or null. */
export function testScopeGlobSyntax(pattern: string): string | null {
  if (pattern.trim() === "") return "pattern is empty";
  if (pattern.startsWith("/")) {
    return "pattern must not start with '/' -- patterns are already repo-root-relative";
  }
  if (pattern.includes("\\")) {
    return "pattern contains a backslash -- use forward slashes, git paths are always POSIX-style even on Windows";
  }
  if (/(^|\/)\.\.(\/|$)/.test(pattern)) {
    return "pattern contains a '..' segment, which has no meaningful effect on a repo-relative include/exclude list";
  }
  if (pattern.includes("\0")) return "pattern contains a NUL character";
  return null;
}

export interface ScopeDeclaration {
  present: boolean;
  valid: boolean;
  error: string | null;
  include: string[];
  exclude: string[];
  path: string;
}

/** Loads <ProjectPath>/SCOPE.json, ported from Read-ScopeDeclaration. */
export function readScopeDeclaration(projectPath: string): ScopeDeclaration {
  const scopePath = join(projectPath, "SCOPE.json");
  let raw: string;
  try {
    raw = readFileSync(scopePath, "utf8");
  } catch {
    return { present: false, valid: false, error: null, include: [], exclude: [], path: scopePath };
  }

  let doc: Record<string, unknown>;
  try {
    doc = JSON.parse(raw) as Record<string, unknown>;
  } catch (e) {
    return {
      present: true,
      valid: false,
      error: `SCOPE.json is not valid JSON: ${(e as Error).message}`,
      include: [],
      exclude: [],
      path: scopePath,
    };
  }

  const scope = doc["implementation_scope"] as Record<string, unknown> | undefined;
  if (!scope) {
    return {
      present: true,
      valid: false,
      error: "SCOPE.json is missing the 'implementation_scope' object",
      include: [],
      exclude: [],
      path: scopePath,
    };
  }

  const includeRaw = scope["include"];
  if (includeRaw === null || includeRaw === undefined) {
    return {
      present: true,
      valid: false,
      error: "implementation_scope.include is missing",
      include: [],
      exclude: [],
      path: scopePath,
    };
  }
  const include = includeRaw as unknown[];
  if (include.length === 0) {
    return {
      present: true,
      valid: false,
      error:
        "implementation_scope.include is an empty list -- every changed file would be a violation; declare at least one path",
      include: [],
      exclude: [],
      path: scopePath,
    };
  }

  let exclude: unknown[] = [];
  if (scope["exclude"] !== null && scope["exclude"] !== undefined) {
    exclude = scope["exclude"] as unknown[];
  }

  for (const pattern of [...include, ...exclude]) {
    if (typeof pattern !== "string") {
      return {
        present: true,
        valid: false,
        error: "implementation_scope entries must all be strings",
        include: [],
        exclude: [],
        path: scopePath,
      };
    }
    const syntaxError = testScopeGlobSyntax(pattern);
    if (syntaxError) {
      return {
        present: true,
        valid: false,
        error: `invalid pattern '${pattern}': ${syntaxError}`,
        include: [],
        exclude: [],
        path: scopePath,
      };
    }
  }

  return {
    present: true,
    valid: true,
    error: null,
    include: include as string[],
    exclude: exclude as string[],
    path: scopePath,
  };
}

export interface ExemptEntry {
  pattern: string;
  reason: string;
}

/** Loads pmo-config/scope-diff-policy.json, ported from Read-ScopeDiffPolicy. */
export function readScopeDiffPolicy(repoRoot: string): ExemptEntry[] {
  const policyPath = join(repoRoot, "pmo-config/scope-diff-policy.json");
  let raw: string;
  try {
    raw = readFileSync(policyPath, "utf8");
  } catch {
    throw new Error(`Missing runtime scope-diff policy config: ${policyPath}`);
  }
  const doc = JSON.parse(raw) as { repo_wide_exempt?: Array<{ pattern?: unknown; reason?: unknown }> };
  const tooBroad = ["**", "*", "**/*", "**/**"];
  const seen = new Set<string>();
  const entries: ExemptEntry[] = [];
  for (const item of doc.repo_wide_exempt ?? []) {
    const pattern = String(item.pattern ?? "");
    const reason = String(item.reason ?? "");

    const syntaxError = testScopeGlobSyntax(pattern);
    if (syntaxError) {
      throw new Error(`Invalid entry in ${policyPath} -- pattern '${pattern}': ${syntaxError}`);
    }
    if (tooBroad.includes(pattern)) {
      throw new Error(
        `Invalid entry in ${policyPath} -- pattern '${pattern}' is too broad for a repo-wide exemption: it would exempt effectively every file in every project from SCOPE-DIFF. Name a specific file or path prefix instead.`,
      );
    }
    if (reason.trim() === "") {
      throw new Error(
        `Invalid entry in ${policyPath} -- pattern '${pattern}' has no reason. Every repo-wide exemption must document why it is exempt.`,
      );
    }
    if (seen.has(pattern)) {
      throw new Error(`Invalid entry in ${policyPath} -- duplicate pattern '${pattern}'`);
    }
    seen.add(pattern);
    entries.push({ pattern, reason });
  }
  return entries;
}

export type ScopeVerdictKind = "excluded" | "exempt" | "in_scope" | "out_of_scope";

export interface ScopeVerdict {
  verdict: ScopeVerdictKind;
  reason: string | null;
}

/**
 * One file's verdict against a compiled scope. Precedence: exclude > exempt >
 * include > out_of_scope. Case-sensitive. Ported from Resolve-ScopeVerdict.
 */
export function resolveScopeVerdict(
  path: string,
  includeRegexes: RegExp[],
  excludeRegexes: RegExp[],
  exemptEntries: Array<{ regex: RegExp; reason: string }>,
): ScopeVerdict {
  for (const rx of excludeRegexes) {
    if (rx.test(path)) return { verdict: "excluded", reason: null };
  }
  for (const entry of exemptEntries) {
    if (entry.regex.test(path)) return { verdict: "exempt", reason: entry.reason };
  }
  for (const rx of includeRegexes) {
    if (rx.test(path)) return { verdict: "in_scope", reason: null };
  }
  return { verdict: "out_of_scope", reason: null };
}
