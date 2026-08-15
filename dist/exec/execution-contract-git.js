// Git ground truth for execution-contract verification, ported from
// scripts/lib/execution-contract-git.ps1. Read-only local plumbing; raw git
// stderr goes only to process stderr, never into a diagnostic.
import { spawnSync } from "node:child_process";
import { getScopeDiffChangedFiles } from "../git/scope-diff-git-adapter.js";
function runGit(repoRoot, args) {
    const r = spawnSync("git", ["-C", repoRoot, ...args], { encoding: "utf8" });
    return { out: r.stdout ?? "", code: r.status };
}
export function testExecutionRefResolvable(repoRoot, ref) {
    const { out, code } = runGit(repoRoot, ["rev-parse", "--verify", "--quiet", `${ref}^{commit}`]);
    return code === 0 && out.trim() !== "";
}
export function resolveExecutionCommitSha(repoRoot, ref) {
    const { out, code } = runGit(repoRoot, ["rev-parse", "--verify", "--quiet", `${ref}^{commit}`]);
    if (code !== 0)
        return null;
    const text = out.trim();
    if (text === "")
        return null;
    return text;
}
export function testExecutionAncestry(repoRoot, ancestor, descendant) {
    const { code } = runGit(repoRoot, ["merge-base", "--is-ancestor", ancestor, descendant]);
    return code === 0;
}
export function getExecutionCommitRange(repoRoot, baseRef, headRef) {
    const r = spawnSync("git", ["-C", repoRoot, "--no-pager", "rev-list", `${baseRef}..${headRef}`], { encoding: "utf8" });
    if (r.status !== 0) {
        const stderr = (r.stderr ?? "").trim();
        if (stderr)
            process.stderr.write(stderr + "\n");
        return null;
    }
    return (r.stdout ?? "").split("\n").map((s) => s.trim()).filter((s) => s !== "");
}
export function getExecutionChangedFiles(repoRoot, baseRef, headRef) {
    return getScopeDiffChangedFiles(repoRoot, baseRef, headRef);
}
export function testExecutionCommitOnRemote(repoRoot, commitSha) {
    const refs = runGit(repoRoot, ["for-each-ref", "--format=%(refname)", "refs/remotes"]);
    if (refs.code !== 0)
        return null;
    const refList = refs.out.split("\n").map((s) => s.trim()).filter((s) => s !== "");
    if (refList.length === 0)
        return null;
    const containing = runGit(repoRoot, ["branch", "--remotes", "--contains", commitSha]);
    if (containing.code !== 0)
        return false;
    for (const line of containing.out.split("\n")) {
        if (line.trim() !== "")
            return true;
    }
    return false;
}
export function getExecutionGitObservation(repoRoot, baseRef, headRef) {
    if (!testExecutionRefResolvable(repoRoot, baseRef)) {
        return {
            ok: false,
            errorCode: "base-unresolvable",
            errorDetail: "The contract's base commit could not be resolved in this checkout. On a shallow clone the base commit is commonly absent; increase fetch-depth (or use fetch-depth: 0). A base that cannot be resolved cannot be verified against, so this run reports an infrastructure failure rather than a verdict.",
        };
    }
    if (!testExecutionRefResolvable(repoRoot, headRef)) {
        return {
            ok: false,
            errorCode: "head-unresolvable",
            errorDetail: "The result's head commit could not be resolved in this checkout. The result claims work at a commit this repository does not contain.",
        };
    }
    const baseSha = resolveExecutionCommitSha(repoRoot, baseRef);
    const headSha = resolveExecutionCommitSha(repoRoot, headRef);
    const isDescendant = testExecutionAncestry(repoRoot, baseSha, headSha);
    const commits = getExecutionCommitRange(repoRoot, baseSha, headSha);
    const diff = getExecutionChangedFiles(repoRoot, baseSha, headSha);
    if (!diff.ok) {
        return {
            ok: false,
            errorCode: "diff-failed",
            errorDetail: "Could not compute the changed-file diff between the contract base and the result head. See the workflow run log for the underlying git error.",
        };
    }
    const onRemote = headSha ? testExecutionCommitOnRemote(repoRoot, headSha) : null;
    return {
        ok: true,
        errorCode: null,
        errorDetail: null,
        baseSha,
        headSha,
        headDescendsFromBase: isDescendant,
        commits: commits ?? [],
        commitCount: commits?.length ?? 0,
        changes: diff.changes,
        headOnRemote: onRemote,
    };
}
