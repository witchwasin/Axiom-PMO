// SCOPE-DIFF orchestration: combines the matcher (what is approved) and the git
// adapter (what changed) into structured diagnostics, ported from
// scripts/lib/scope-diff-validator.ps1. Emits through the same accumulator as
// every other validator.

import {
  readScopeDeclaration,
  readScopeDiffPolicy,
  resolveScopeVerdict,
  convertToScopeGlobRegex,
  type ScopeVerdictKind,
  type ScopeVerdict,
} from "./scope-diff-matcher.js";
import { getScopeDiffChangedFiles, type ScopeDiffChange } from "../git/scope-diff-git-adapter.js";
import { addResult } from "../core/result-writer.js";
import type { ResultAccumulator, ValidationRules } from "../core/context.js";
import type { ScopeDiffResult } from "../core/types.js";

const VERDICT_SEVERITY: Record<ScopeVerdictKind, number> = {
  excluded: 3,
  out_of_scope: 2,
  exempt: 1,
  in_scope: 0,
};

function resolveCombinedVerdict(a: ScopeVerdict, b: ScopeVerdict | null): ScopeVerdict {
  if (!b) return a;
  const sevA = VERDICT_SEVERITY[a.verdict];
  const sevB = VERDICT_SEVERITY[b.verdict];
  if (sevB > sevA) return b;
  return a;
}

function emptyResult(base: string, head: string, verdict: ScopeDiffResult["verdict"]): ScopeDiffResult {
  return {
    base_sha: base,
    head_sha: head,
    approved_include: [],
    approved_exclude: [],
    changed_in_scope: [],
    changed_out_of_scope: [],
    changed_excluded: [],
    exempt: [],
    renames: [],
    verdict,
  };
}

export function invokeScopeDiffCheck(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  projectPath: string,
  gitRepoRoot: string,
  frameworkRoot: string,
  baseRef: string,
  headRef: string,
): ScopeDiffResult {
  const scope = readScopeDeclaration(projectPath);
  if (!scope.present) {
    addResult(acc, catalog, "FAIL", "No approved implementation scope declared for this project. SCOPE-DIFF was requested (base/head were supplied) but no SCOPE.json exists, so this run cannot prove any changed file is approved. A missing scope declaration is never treated as 'everything is approved.'", { ruleId: "SCOPE-DIFF-002", artifact: "SCOPE.json" });
    return emptyResult(baseRef, headRef, "scope_missing");
  }
  if (!scope.valid) {
    addResult(acc, catalog, "FAIL", `Scope declaration is invalid: ${scope.error}`, { ruleId: "SCOPE-DIFF-003", artifact: "SCOPE.json" });
    return emptyResult(baseRef, headRef, "invalid_scope");
  }

  const diffResult = getScopeDiffChangedFiles(gitRepoRoot, baseRef, headRef);
  if (!diffResult.ok) {
    addResult(acc, catalog, "FAIL", `Could not compute the changed-file diff between ${baseRef} and ${headRef}: ${diffResult.errorDetail}`, { ruleId: "SCOPE-DIFF-004" });
    return {
      base_sha: baseRef,
      head_sha: headRef,
      approved_include: scope.include,
      approved_exclude: scope.exclude,
      changed_in_scope: [],
      changed_out_of_scope: [],
      changed_excluded: [],
      exempt: [],
      renames: [],
      verdict: "git_error",
    };
  }

  const includeRegexes = scope.include.map((p) => new RegExp(convertToScopeGlobRegex(p)));
  const excludeRegexes = scope.exclude.map((p) => new RegExp(convertToScopeGlobRegex(p)));
  const exemptEntries = readScopeDiffPolicy(frameworkRoot).map((e) => ({
    regex: new RegExp(convertToScopeGlobRegex(e.pattern)),
    reason: e.reason,
  }));

  const inScope: string[] = [];
  const outOfScope: string[] = [];
  const excluded: string[] = [];
  const exempt: Array<{ path: string; reason: string }> = [];
  const renames: ScopeDiffResult["renames"] = [];

  for (const change of diffResult.changes) {
    const newVerdict = resolveScopeVerdict(change.path, includeRegexes, excludeRegexes, exemptEntries);
    let combined = newVerdict;
    if (change.oldPath) {
      const oldVerdict = resolveScopeVerdict(change.oldPath, includeRegexes, excludeRegexes, exemptEntries);
      combined = resolveCombinedVerdict(newVerdict, oldVerdict);
      renames.push({
        status: change.status,
        old_path: change.oldPath,
        new_path: change.path,
        old_verdict: oldVerdict.verdict,
        new_verdict: newVerdict.verdict,
      });
    }

    switch (combined.verdict) {
      case "excluded":
        excluded.push(change.path);
        addResult(acc, catalog, "FAIL", `Changed file matches an excluded path in the approved implementation scope: ${change.path}${renameNote(change)}`, { ruleId: "SCOPE-DIFF-005", artifact: change.path });
        break;
      case "out_of_scope":
        outOfScope.push(change.path);
        addResult(acc, catalog, "FAIL", `Changed file is outside the approved implementation scope: ${change.path}${renameNote(change)}`, { ruleId: "SCOPE-DIFF-001", artifact: change.path });
        break;
      case "exempt":
        exempt.push({ path: change.path, reason: combined.reason ?? "" });
        break;
      case "in_scope":
        inScope.push(change.path);
        break;
    }
  }

  const verdict: ScopeDiffResult["verdict"] =
    outOfScope.length > 0 || excluded.length > 0 ? "fail" : "pass";
  if (verdict === "pass") {
    if (diffResult.changes.length === 0) {
      addResult(acc, catalog, "PASS", `No changed files between ${baseRef} and ${headRef}`, { ruleId: "SCOPE-DIFF-001" });
    } else {
      const exemptNote = exempt.length > 0 ? ` (${exempt.length} repo-wide exempt)` : "";
      addResult(acc, catalog, "PASS", `All ${diffResult.changes.length} changed file(s) are within the approved implementation scope${exemptNote}`, { ruleId: "SCOPE-DIFF-001" });
    }
  }

  return {
    base_sha: baseRef,
    head_sha: headRef,
    approved_include: scope.include,
    approved_exclude: scope.exclude,
    changed_in_scope: inScope,
    changed_out_of_scope: outOfScope,
    changed_excluded: excluded,
    exempt,
    renames,
    verdict,
  };
}

function renameNote(change: ScopeDiffChange): string {
  return change.oldPath ? ` (renamed from ${change.oldPath})` : "";
}
