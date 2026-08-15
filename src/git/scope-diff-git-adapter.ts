// SCOPE-DIFF's only git-touching module, ported from
// scripts/lib/scope-diff-git-adapter.ps1. Read-only local git plumbing against
// commits already present in the checkout — never a network op, never a write.
// Raw git stderr is never returned in a diagnostic; it goes only to this
// process's own stderr (the workflow run log).

import { spawnSync } from "node:child_process";

export interface ScopeDiffChange {
  status: string;
  path: string;
  oldPath: string | null;
}

export interface ScopeDiffChangedFiles {
  ok: boolean;
  errorCode: string | null;
  errorDetail: string | null;
  changes: ScopeDiffChange[];
}

function resolveRef(repoRoot: string, ref: string): boolean {
  const r = spawnSync("git", ["-C", repoRoot, "rev-parse", "--verify", "--quiet", `${ref}^{commit}`], {
    encoding: "utf8",
  });
  return r.status === 0 && (r.stdout ?? "").trim() !== "";
}

/** Parses `git diff --name-status -z` NUL-separated output. */
export function convertFromScopeDiffNameStatus(rawOutput: string): ScopeDiffChange[] {
  const changes: ScopeDiffChange[] = [];
  if (rawOutput.length === 0) return changes;

  const tokens = rawOutput.split("\0");
  let i = 0;
  while (i < tokens.length) {
    const status = tokens[i]!;
    if (status === "") {
      i++;
      continue;
    }
    i++;
    if (status.startsWith("R") || status.startsWith("C")) {
      if (i + 1 >= tokens.length) break;
      const oldPath = tokens[i]!;
      i++;
      const newPath = tokens[i]!;
      i++;
      changes.push({ status, path: newPath, oldPath });
    } else {
      if (i >= tokens.length) break;
      const path = tokens[i]!;
      i++;
      changes.push({ status, path, oldPath: null });
    }
  }
  return changes;
}

export function getScopeDiffChangedFiles(
  repoRoot: string,
  baseRef: string,
  headRef: string,
): ScopeDiffChangedFiles {
  if (!resolveRef(repoRoot, baseRef)) {
    return {
      ok: false,
      errorCode: "base-unresolvable",
      errorDetail:
        `The base commit (${baseRef}) could not be resolved in this checkout. This is commonly a shallow checkout: actions/checkout defaults to fetch-depth 1, which does not include the base commit for a scope-diff comparison. Increase fetch-depth (or use fetch-depth: 0) in the checkout step.`,
      changes: [],
    };
  }
  if (!resolveRef(repoRoot, headRef)) {
    return {
      ok: false,
      errorCode: "head-unresolvable",
      errorDetail: `The head commit (${headRef}) could not be resolved in this checkout.`,
      changes: [],
    };
  }

  const r = spawnSync(
    "git",
    [
      "-C",
      repoRoot,
      "-c",
      "diff.renames=true",
      "-c",
      "diff.renameLimit=32767",
      "--no-pager",
      "diff",
      "--no-color",
      "--find-renames",
      "--name-status",
      "-z",
      baseRef,
      headRef,
    ],
    { encoding: "utf8" },
  );

  if (r.status !== 0) {
    const stderrText = (r.stderr ?? "").trim();
    if (stderrText) process.stderr.write(stderrText + "\n");
    return {
      ok: false,
      errorCode: "diff-failed",
      errorDetail: `git diff exited ${r.status} comparing ${baseRef} to ${headRef}. See the workflow run log for the underlying git error.`,
      changes: [],
    };
  }

  return {
    ok: true,
    errorCode: null,
    errorDetail: null,
    changes: convertFromScopeDiffNameStatus(r.stdout ?? ""),
  };
}
