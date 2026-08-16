// Ported from tests/helpers/ci-check-evidence-live-tests.ps1.
//
// Live integration test for the `ci-check` test-evidence adapter
// (testCiCheckEvidence in src/exec/execution-contract-evidence.ts).
//
// Deliberately separate from the offline/hermetic execution-contract suite:
// this one adapter's entire value is that it asks a third party (the GitHub
// API) the verified actor cannot impersonate, so mocking it here would test
// the mock. SKIPS rather than fails when live context (gh CLI, a real
// remote, a real completed check run in recent history) is absent -- a
// skipped assertion is not a passed one, so skips are logged loudly.
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { testCiCheckEvidence, getGitHubOwnerRepo } from "./execution-contract-evidence.js";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
function newCiEntry(name, commitSha, conclusion, checkRunId) {
    const raw = { type: "ci-check", name, commit_sha: commitSha };
    if (conclusion)
        raw["conclusion"] = conclusion;
    if (checkRunId)
        raw["check_run_id"] = checkRunId;
    return { type: "ci-check", name, known: true, fieldsPresent: true, missingFields: [], provenance: "externally-observed", raw };
}
function gh(...args) {
    const r = spawnSync("gh", args, { encoding: "utf8", cwd: REPO_ROOT });
    return { ok: r.status === 0, stdout: r.stdout ?? "" };
}
function git(...args) {
    const r = spawnSync("git", ["-C", REPO_ROOT, ...args], { encoding: "utf8" });
    return { ok: r.status === 0, stdout: (r.stdout ?? "").trim() };
}
function commandExists(cmd) {
    const r = spawnSync(process.platform === "win32" ? "where" : "which", [cmd], { encoding: "utf8" });
    return r.status === 0;
}
test("ci-check live evidence: positive path, case sensitivity, check_run_id binding, ambiguity", (t) => {
    if (!commandExists("gh")) {
        t.skip("gh CLI not on PATH -- this test only means anything where a real GitHub API is reachable");
        return;
    }
    const remote = git("remote", "get-url", "origin");
    if (!remote.ok || !remote.stdout.trim()) {
        t.skip("no git remote to query");
        return;
    }
    const ownerRepo = getGitHubOwnerRepo(remote.stdout);
    if (!ownerRepo) {
        t.skip("remote URL is not a GitHub repository reference");
        return;
    }
    // Find a commit that has a completed, successful check run -- starting at
    // HEAD~1, deliberately skipping HEAD (its own checks are in flight).
    let foundSha = null;
    let foundCheckName = null;
    let foundCheckRunId = null;
    let foundFailingName = null;
    for (let depth = 1; depth < 9; depth++) {
        const sha = git("rev-parse", `HEAD~${depth}`);
        if (!sha.ok || !sha.stdout)
            break;
        const raw = gh("api", `repos/${ownerRepo}/commits/${sha.stdout}/check-runs`);
        if (!raw.ok)
            continue;
        let data;
        try {
            data = JSON.parse(raw.stdout);
        }
        catch {
            continue;
        }
        for (const run of data.check_runs ?? []) {
            if (run.status !== "completed")
                continue;
            if (run.conclusion === "success" && !foundCheckName) {
                foundSha = sha.stdout;
                foundCheckName = run.name;
                foundCheckRunId = String(run.id);
            }
            if (["failure", "cancelled", "timed_out"].includes(run.conclusion ?? "") && !foundFailingName) {
                foundFailingName = run.name;
            }
        }
        if (foundCheckName)
            break;
    }
    if (!foundCheckName || !foundSha) {
        t.skip("no commit in the last 8 with a completed successful check run -- nothing real to verify against");
        return;
    }
    // --- the positive path, finally exercised ---
    let r = testCiCheckEvidence(newCiEntry(foundCheckName, foundSha), REPO_ROOT);
    assert.ok(r.verified, `a real successful check run on a real commit verifies: ${r.reason}`);
    // --- case sensitivity: "Build" must not satisfy evidence naming "build" ---
    const flippedName = foundCheckName.toUpperCase();
    const flippedNameUsable = flippedName !== foundCheckName;
    if (flippedNameUsable) {
        r = testCiCheckEvidence(newCiEntry(flippedName, foundSha), REPO_ROOT);
        assert.ok(!r.verified, "name-search path: a different-case name does not verify a real, currently-passing run");
    }
    // --- check_run_id: the direct-lookup path and its binding checks ---
    if (foundCheckRunId) {
        r = testCiCheckEvidence(newCiEntry(foundCheckName, foundSha, undefined, foundCheckRunId), REPO_ROOT);
        assert.ok(r.verified, `citing check_run_id directly verifies the same real run: ${r.reason}`);
        r = testCiCheckEvidence(newCiEntry(foundCheckName, "0".repeat(40), undefined, foundCheckRunId), REPO_ROOT);
        assert.ok(!r.verified, "check_run_id bound to the wrong commit_sha does not verify");
        r = testCiCheckEvidence(newCiEntry("this-check-name-does-not-exist-anywhere", foundSha, undefined, foundCheckRunId), REPO_ROOT);
        assert.ok(!r.verified, "check_run_id bound to the wrong name does not verify");
        r = testCiCheckEvidence(newCiEntry(foundCheckName, foundSha, undefined, "1"), REPO_ROOT);
        assert.ok(!r.verified, "a nonexistent check_run_id does not verify");
        r = testCiCheckEvidence(newCiEntry(foundCheckName, foundSha, undefined, "not-a-number"), REPO_ROOT);
        assert.ok(!r.verified, "a non-numeric check_run_id does not verify");
        if (flippedNameUsable) {
            r = testCiCheckEvidence(newCiEntry(flippedName, foundSha, undefined, foundCheckRunId), REPO_ROOT);
            assert.ok(!r.verified, "check_run_id path: a different-case name does not verify a real, currently-passing run");
        }
    }
    // --- and the ways it must not verify ---
    r = testCiCheckEvidence(newCiEntry("this-check-name-does-not-exist-anywhere", foundSha), REPO_ROOT);
    assert.ok(!r.verified, "a check name that does not exist on that commit does not verify");
    r = testCiCheckEvidence(newCiEntry(foundCheckName, "0".repeat(40)), REPO_ROOT);
    assert.ok(!r.verified, "the right check name on a nonexistent commit does not verify");
    r = testCiCheckEvidence(newCiEntry("this-check-name-does-not-exist-anywhere", foundSha, "success"), REPO_ROOT);
    assert.ok(!r.verified, "a claimed conclusion of success does not rescue a check the API cannot confirm");
    if (foundFailingName) {
        r = testCiCheckEvidence(newCiEntry(foundFailingName, foundSha, "success"), REPO_ROOT);
        assert.ok(!r.verified, "a check the API reports as not-success is rejected despite the result claiming success");
    }
    // --- ambiguity: the same name, more than one completed run ---
    const rawAll = gh("api", `repos/${ownerRepo}/commits/${foundSha}/check-runs`);
    if (rawAll.ok) {
        try {
            const allData = JSON.parse(rawAll.stdout);
            const byName = new Map();
            const successIdByName = new Map();
            for (const run of allData.check_runs ?? []) {
                if (run.status !== "completed")
                    continue;
                const n = run.name;
                if (!byName.has(n))
                    byName.set(n, []);
                byName.get(n).push(run.conclusion ?? "");
                if (run.conclusion === "success" && !successIdByName.has(n))
                    successIdByName.set(n, String(run.id));
            }
            let ambiguousName = null;
            let ambiguousSuccessId = null;
            let allSuccessDuplicateName = null;
            for (const [k, vals] of byName) {
                if (vals.length < 2)
                    continue;
                const distinct = [...new Set(vals)];
                if (distinct.length > 1 && !ambiguousName) {
                    ambiguousName = k;
                    if (successIdByName.has(k))
                        ambiguousSuccessId = successIdByName.get(k);
                }
                if (distinct.length === 1 && distinct[0] === "success" && !allSuccessDuplicateName)
                    allSuccessDuplicateName = k;
            }
            if (ambiguousName) {
                r = testCiCheckEvidence(newCiEntry(ambiguousName, foundSha, "success"), REPO_ROOT);
                assert.ok(!r.verified, "a name with both a passing and a failing completed run does not verify");
                if (ambiguousSuccessId) {
                    r = testCiCheckEvidence(newCiEntry(ambiguousName, foundSha, undefined, ambiguousSuccessId), REPO_ROOT);
                    assert.ok(r.verified, "the decisive case: citing the successful run's id verifies despite a failing sibling under the same name");
                }
            }
            if (allSuccessDuplicateName) {
                r = testCiCheckEvidence(newCiEntry(allSuccessDuplicateName, foundSha), REPO_ROOT);
                assert.ok(r.verified, "duplicate runs that all report success still verify");
            }
        }
        catch {
            // No usable ambiguity data on this commit; nothing further to assert.
        }
    }
});
