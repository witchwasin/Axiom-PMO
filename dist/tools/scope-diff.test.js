// Ported from tests/helpers/scope-diff-tests.ps1 (M4.5 SCOPE-DIFF), adapted
// for the Node port.
//
// The PS original exercises validate-project.ps1 as a subprocess with
// -ScopeDiffBase/-ScopeDiffHead/-ScopeDiffRepoRoot; every assertion here is
// about the scope_diff envelope and the SCOPE-DIFF-* diagnostic rows, so the
// port calls the ported orchestrator entrypoint -- invokeScopeDiffCheck --
// in-process with a fresh accumulator. SCOPE-DIFF's entire job is comparing
// real git history against a real scope declaration, so each case still builds
// a small, disposable git repository rather than reusing this repository's own
// history (which changes).
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { spawnSync } from "node:child_process";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { invokeScopeDiffCheck } from "../rules/scope-diff-validator.js";
import { readScopeDiffPolicy } from "../rules/scope-diff-matcher.js";
import { createAccumulator } from "../core/context.js";
import { importPmoConfig } from "../config/config-loader.js";
import { runPortedChain } from "../probe/validate-chain.js";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const cfg = importPmoConfig(REPO_ROOT);
function git(dir, ...args) {
    const r = spawnSync("git", ["-C", dir, ...args], { encoding: "utf8" });
    return { ok: r.status === 0, stdout: (r.stdout ?? "").trim(), status: r.status };
}
function newGitFixture() {
    const dir = mkdtempSync(join(tmpdir(), "axiom-scope-diff-"));
    const init = git(dir, "init", "-q", "--initial-branch=main");
    if (!init.ok)
        git(dir, "init", "-q"); // older git: no --initial-branch
    git(dir, "config", "user.email", "test@axiom-pmo.local");
    git(dir, "config", "user.name", "Axiom Scope Diff Tests");
    return dir;
}
function writeFixtureFile(dir, relativePath, content = "content") {
    const full = join(dir, relativePath);
    mkdirSync(dirname(full), { recursive: true });
    writeFileSync(full, content, "utf8");
}
function newFixtureCommit(dir, message) {
    git(dir, "add", "-A");
    git(dir, "commit", "-q", "-m", message);
    return git(dir, "rev-parse", "HEAD").stdout;
}
function runScopeDiff(project, repoRoot, base, head) {
    const acc = createAccumulator();
    const result = invokeScopeDiffCheck(acc, cfg.validationRules, project, repoRoot, REPO_ROOT, base, head);
    return { result, diagnostics: acc.messages };
}
function scopeDiffRows(diagnostics, ruleId, level = "") {
    return diagnostics.filter((d) => d.rule_id === ruleId && (level === "" || d.level === level));
}
const SCOPE = '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/payments/**"],"exclude":[]}}';
test("scope-diff: verdicts -- in scope passes, one file outside fails", () => {
    const dir = newGitFixture();
    try {
        // All changed files in approved include -> PASS.
        writeFixtureFile(dir, "src/payments/foo.ts", "a");
        writeFixtureFile(dir, "SCOPE.json", SCOPE);
        const base = newFixtureCommit(dir, "base");
        writeFixtureFile(dir, "src/payments/foo.ts", "b");
        const head = newFixtureCommit(dir, "change");
        let r = runScopeDiff(dir, dir, base, head);
        assert.equal(r.result.verdict, "pass", `in-scope-only: verdict is pass (got ${r.result.verdict})`);
        assert.equal(scopeDiffRows(r.diagnostics, "SCOPE-DIFF-001")[0]?.level, "PASS", "in-scope-only: SCOPE-DIFF-001 row is PASS level");
        // One file outside scope -> FAIL.
        writeFixtureFile(dir, "src/auth/bar.ts", "new");
        const head2 = newFixtureCommit(dir, "change-2");
        r = runScopeDiff(dir, dir, base, head2);
        assert.equal(r.result.verdict, "fail", "one-outside: verdict is fail");
        assert.ok(r.result.changed_out_of_scope.includes("src/auth/bar.ts"), "one-outside: out_of_scope lists the offending file");
        assert.equal(scopeDiffRows(r.diagnostics, "SCOPE-DIFF-001", "FAIL").filter((d) => d.artifact === "src/auth/bar.ts").length, 1, "one-outside: SCOPE-DIFF-001 FAIL row names the file as artifact");
    }
    finally {
        rmSync(dir, { recursive: true, force: true });
    }
});
test("scope-diff: path matching is case-sensitive (was a scope bypass)", () => {
    const dir = newGitFixture();
    try {
        writeFixtureFile(dir, "src/payments/foo.ts", "a");
        writeFixtureFile(dir, "SCOPE.json", SCOPE);
        const base = newFixtureCommit(dir, "base");
        writeFixtureFile(dir, "src/payments/foo.ts", "b");
        git(dir, "add", "-A");
        // Added via git plumbing (hash-object + update-index --cacheinfo), not a
        // working-tree write: on a case-insensitive-but-case-preserving
        // filesystem (macOS APFS's default, and Windows/NTFS), writing to
        // "SRC/PAYMENTS/bar.ts" when "src/payments/" already exists on disk
        // silently resolves into the existing directory, and git then reports
        // the on-disk case -- which would hide the very case-sensitivity bug
        // this test exists to catch. Injecting the blob directly into the index
        // bypasses the filesystem's own case-folding entirely, so this test is
        // meaningful on every host this suite runs on (see also
        // docs/reference/scope-declaration.md).
        const blob = git(dir, "hash-object", "-w", "--stdin").stdout;
        git(dir, "update-index", "--add", "--cacheinfo", `100644,${blob},SRC/PAYMENTS/bar.ts`);
        git(dir, "commit", "-q", "-m", "change");
        const head = git(dir, "rev-parse", "HEAD").stdout;
        const r = runScopeDiff(dir, dir, base, head);
        assert.equal(r.result.verdict, "fail", "case-sensitive: verdict is fail");
        assert.ok(r.result.changed_out_of_scope.includes("SRC/PAYMENTS/bar.ts"), "case-sensitive: wrong-case path reported out of scope");
        assert.ok(!r.result.changed_in_scope.includes("SRC/PAYMENTS/bar.ts"), "case-sensitive: wrong-case path not counted as in scope");
    }
    finally {
        rmSync(dir, { recursive: true, force: true });
    }
});
test("scope-diff: excluded files and include/exclude precedence", () => {
    const dir = newGitFixture();
    try {
        // Excluded file changed -> FAIL (SCOPE-DIFF-005, distinct from 001).
        writeFixtureFile(dir, "src/payments/generated/client.ts", "a");
        writeFixtureFile(dir, "SCOPE.json", '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/payments/**"],"exclude":["src/payments/generated/**"]}}');
        const base = newFixtureCommit(dir, "base");
        writeFixtureFile(dir, "src/payments/generated/client.ts", "b");
        const head = newFixtureCommit(dir, "change");
        let r = runScopeDiff(dir, dir, base, head);
        assert.equal(r.result.verdict, "fail", "excluded: verdict is fail");
        assert.ok(r.result.changed_excluded.includes("src/payments/generated/client.ts") && !r.result.changed_out_of_scope.includes("src/payments/generated/client.ts"), "excluded: reported under changed_excluded, not out_of_scope");
        assert.equal(scopeDiffRows(r.diagnostics, "SCOPE-DIFF-005", "FAIL").length, 1, "excluded: rule id is SCOPE-DIFF-005, not SCOPE-DIFF-001");
        // Same path matches both include and exclude -- exclude must win.
        writeFixtureFile(dir, "src/a.ts", "a");
        writeFixtureFile(dir, "SCOPE.json", '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/**"],"exclude":["src/a.ts"]}}');
        const base2 = newFixtureCommit(dir, "base-2");
        writeFixtureFile(dir, "src/a.ts", "b");
        const head2 = newFixtureCommit(dir, "change-2");
        r = runScopeDiff(dir, dir, base2, head2);
        assert.equal(scopeDiffRows(r.diagnostics, "SCOPE-DIFF-005").length, 1, "precedence: exclude wins over include");
    }
    finally {
        rmSync(dir, { recursive: true, force: true });
    }
});
test("scope-diff: missing and invalid scope declarations", () => {
    const dir = newGitFixture();
    try {
        // Missing scope declaration.
        writeFixtureFile(dir, "src/a.ts", "a");
        const base = newFixtureCommit(dir, "base");
        writeFixtureFile(dir, "src/a.ts", "b");
        const head = newFixtureCommit(dir, "change");
        let r = runScopeDiff(dir, dir, base, head);
        assert.equal(scopeDiffRows(r.diagnostics, "SCOPE-DIFF-002", "FAIL").length, 1, "missing scope: SCOPE-DIFF-002 FAIL");
        assert.equal(r.diagnostics.some((d) => d.level === "FAIL") ? 1 : 0, 1, "missing scope: overall exit code is 1 (not silently passing)");
        // Invalid glob/syntax.
        writeFixtureFile(dir, "src/a.ts", "a");
        writeFixtureFile(dir, "SCOPE.json", '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["/src/**"],"exclude":[]}}');
        const base2 = newFixtureCommit(dir, "base-2");
        writeFixtureFile(dir, "src/a.ts", "b");
        const head2 = newFixtureCommit(dir, "change-2");
        r = runScopeDiff(dir, dir, base2, head2);
        assert.equal(scopeDiffRows(r.diagnostics, "SCOPE-DIFF-003", "FAIL").length, 1, "invalid syntax: SCOPE-DIFF-003 FAIL");
        // Empty include list is also invalid syntax.
        writeFixtureFile(dir, "src/a.ts", "a");
        writeFixtureFile(dir, "SCOPE.json", '{"schema_version":"1.0","project":"T","implementation_scope":{"include":[],"exclude":[]}}');
        const base3 = newFixtureCommit(dir, "base-3");
        writeFixtureFile(dir, "src/a.ts", "b");
        const head3 = newFixtureCommit(dir, "change-3");
        r = runScopeDiff(dir, dir, base3, head3);
        assert.equal(scopeDiffRows(r.diagnostics, "SCOPE-DIFF-003", "FAIL").length, 1, "empty include: SCOPE-DIFF-003 FAIL");
    }
    finally {
        rmSync(dir, { recursive: true, force: true });
    }
});
test("scope-diff: added / modified / deleted files and renames", () => {
    const dir = newGitFixture();
    try {
        // Added / modified / deleted files, all in scope.
        writeFixtureFile(dir, "src/keep.ts", "a");
        writeFixtureFile(dir, "src/remove.ts", "a");
        writeFixtureFile(dir, "SCOPE.json", '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/**"],"exclude":[]}}');
        const base = newFixtureCommit(dir, "base");
        writeFixtureFile(dir, "src/keep.ts", "b"); // modified
        writeFixtureFile(dir, "src/added.ts", "new"); // added
        rmSync(join(dir, "src/remove.ts")); // deleted
        const head = newFixtureCommit(dir, "change");
        let r = runScopeDiff(dir, dir, base, head);
        assert.equal(r.result.verdict, "pass", "add/modify/delete: verdict is pass (all three still in scope)");
        assert.ok(r.result.changed_in_scope.includes("src/added.ts"), "add/modify/delete: added file counted");
        assert.ok(r.result.changed_in_scope.includes("src/keep.ts"), "add/modify/delete: modified file counted");
        assert.ok(r.result.changed_in_scope.includes("src/remove.ts"), "add/modify/delete: deleted file counted");
        // Rename in-scope-to-in-scope.
        const renameContent = "some reasonably long content so git's similarity heuristic detects a rename instead of a delete+add";
        writeFixtureFile(dir, "src/payments/old name.ts", renameContent);
        writeFixtureFile(dir, "SCOPE.json", SCOPE);
        const base2 = newFixtureCommit(dir, "base-2");
        git(dir, "mv", "src/payments/old name.ts", "src/payments/new name.ts");
        const head2 = newFixtureCommit(dir, "rename");
        r = runScopeDiff(dir, dir, base2, head2);
        assert.equal(r.result.verdict, "pass", "rename in-scope-to-in-scope: verdict pass");
        const renameRow = r.result.renames.filter((x) => x.new_path === "src/payments/new name.ts");
        assert.equal(renameRow.length, 1, "rename in-scope-to-in-scope: renames array has one structured entry");
        assert.ok(renameRow[0].old_path === "src/payments/old name.ts" && renameRow[0].old_verdict === "in_scope" && renameRow[0].new_verdict === "in_scope", "rename in-scope-to-in-scope: structured entry has both verdicts");
        // Rename in-scope-to-out-of-scope.
        writeFixtureFile(dir, "src/payments/old name.ts", renameContent);
        writeFixtureFile(dir, "SCOPE.json", SCOPE);
        const base3 = newFixtureCommit(dir, "base-3");
        // `git mv` does not create the destination directory -- without this, the
        // move fails silently and base==head, which is exactly the bug this
        // comment is here to stop from recurring: the first version of this test
        // passed a "fail" assertion for the wrong reason (no diff at all, not a
        // real rename) until this was added.
        mkdirSync(join(dir, "src/auth"), { recursive: true });
        git(dir, "mv", "src/payments/old name.ts", "src/auth/new name.ts");
        const head3 = newFixtureCommit(dir, "rename-out");
        r = runScopeDiff(dir, dir, base3, head3);
        assert.equal(r.result.verdict, "fail", "rename in-scope-to-out-of-scope: verdict fail (worse side wins)");
        assert.match(scopeDiffRows(r.diagnostics, "SCOPE-DIFF-001", "FAIL")[0].message, /renamed from/, "rename: violation message mentions the rename");
        const renameRow2 = r.result.renames.filter((x) => x.new_path === "src/auth/new name.ts");
        assert.equal(renameRow2.length, 1, "rename in-scope-to-out-of-scope: structured entry present");
        assert.ok(renameRow2[0].old_path === "src/payments/old name.ts" && renameRow2[0].old_verdict === "in_scope" && renameRow2[0].new_verdict === "out_of_scope", "rename in-scope-to-out-of-scope: old side recorded in_scope, new side out_of_scope");
    }
    finally {
        rmSync(dir, { recursive: true, force: true });
    }
});
test("scope-diff: special-character paths and git error handling", () => {
    const dir = newGitFixture();
    try {
        // Path with space and special characters.
        writeFixtureFile(dir, "SCOPE.json", '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/**"],"exclude":[]}}');
        const base = newFixtureCommit(dir, "base");
        writeFixtureFile(dir, "src/with space (and parens) [brackets].ts", "content");
        const head = newFixtureCommit(dir, "change");
        let r = runScopeDiff(dir, dir, base, head);
        assert.ok(r.result.changed_in_scope.includes("src/with space (and parens) [brackets].ts"), `special characters: path parsed and matched correctly (got: ${r.result.changed_in_scope.join(", ")})`);
        // Base SHA not found.
        writeFixtureFile(dir, "SCOPE.json", '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/**"],"exclude":[]}}');
        const head2 = newFixtureCommit(dir, "base-2");
        r = runScopeDiff(dir, dir, "0000000000000000000000000000000000000000", head2);
        const badBase = scopeDiffRows(r.diagnostics, "SCOPE-DIFF-004", "FAIL");
        assert.equal(badBase.length, 1, "bad base SHA: SCOPE-DIFF-004 FAIL");
        assert.match(badBase[0].message, /fetch-depth/, "bad base SHA: message mentions fetch-depth guidance");
        // Head ref invalid.
        const base3 = newFixtureCommit(dir, "base-3");
        r = runScopeDiff(dir, dir, base3, "not-a-real-ref-at-all");
        assert.equal(scopeDiffRows(r.diagnostics, "SCOPE-DIFF-004", "FAIL").length, 1, "bad head ref: SCOPE-DIFF-004 FAIL");
        // Empty diff (base == head).
        const head3 = git(dir, "rev-parse", "HEAD").stdout;
        r = runScopeDiff(dir, dir, head3, head3);
        assert.equal(r.result.verdict, "pass", "empty diff: verdict pass");
        assert.equal(r.result.changed_in_scope.length + r.result.changed_out_of_scope.length, 0, "empty diff: zero changed files in every bucket");
        // Git error output is not persisted into the diagnostic.
        r = runScopeDiff(dir, dir, "totally-bogus-ref-xyz", head3);
        const row = scopeDiffRows(r.diagnostics, "SCOPE-DIFF-004")[0];
        assert.doesNotMatch(row.message, /fatal:|unknown revision/, "git error privacy: message does not contain raw git stderr markers");
    }
    finally {
        rmSync(dir, { recursive: true, force: true });
    }
});
test("scope-diff: repo-wide exemptions", () => {
    const dir = newGitFixture();
    try {
        // A repo-wide exempt path passes without being in include.
        writeFixtureFile(dir, "src/a.ts", "a");
        writeFixtureFile(dir, "SCOPE.json", '{"schema_version":"1.0","project":"T","implementation_scope":{"include":["src/**"],"exclude":[]}}');
        const base = newFixtureCommit(dir, "base");
        writeFixtureFile(dir, "package-lock.json", "{}"); // matches pmo-config/scope-diff-policy.json's repo_wide_exempt
        const head = newFixtureCommit(dir, "change");
        let r = runScopeDiff(dir, dir, base, head);
        assert.equal(r.result.verdict, "pass", "repo-wide exempt: verdict pass");
        assert.equal(r.result.exempt.filter((e) => e.path === "package-lock.json" && e.reason).length, 1, "repo-wide exempt: file listed with a reason");
        assert.ok(!r.result.changed_in_scope.includes("package-lock.json"), "repo-wide exempt: not double-counted into changed_in_scope");
        // An unrelated, non-exempt file still fails.
        writeFixtureFile(dir, "some-other-lockfile.lock", "{}"); // NOT in the repo-wide exempt list
        const head2 = newFixtureCommit(dir, "change-2");
        r = runScopeDiff(dir, dir, base, head2);
        assert.equal(r.result.verdict, "fail", "non-exempt unrelated file: verdict fail");
        assert.ok(r.result.changed_out_of_scope.includes("some-other-lockfile.lock"), "non-exempt unrelated file: not silently allowed");
    }
    finally {
        rmSync(dir, { recursive: true, force: true });
    }
});
test("scope-diff: repo-wide exemption policy validation", () => {
    const policyDir = mkdtempSync(join(tmpdir(), "axiom-scope-diff-policy-"));
    try {
        mkdirSync(join(policyDir, "pmo-config"), { recursive: true });
        const policyPath = join(policyDir, "pmo-config/scope-diff-policy.json");
        const writePolicy = (json) => writeFileSync(policyPath, json, "utf8");
        writePolicy('{"repo_wide_exempt":[{"pattern":"**","reason":"shared files"}]}');
        assert.throws(() => readScopeDiffPolicy(policyDir), /too broad/, "repo-wide policy: '**' pattern is rejected, not silently accepted");
        writePolicy('{"repo_wide_exempt":[{"pattern":"foo.lock","reason":""}]}');
        assert.throws(() => readScopeDiffPolicy(policyDir), /no reason/, "repo-wide policy: empty reason is rejected");
        writePolicy('{"repo_wide_exempt":[{"pattern":"foo.lock","reason":"a"},{"pattern":"foo.lock","reason":"b"}]}');
        assert.throws(() => readScopeDiffPolicy(policyDir), /duplicate pattern/, "repo-wide policy: duplicate pattern is rejected");
        // The framework's own policy is itself valid.
        const entries = readScopeDiffPolicy(REPO_ROOT);
        assert.ok(entries.length > 0, "repo-wide policy: framework's own policy.json passes validation");
    }
    finally {
        rmSync(policyDir, { recursive: true, force: true });
    }
});
test("scope-diff: opt-in -- omitted refs change nothing", () => {
    const dir = newGitFixture();
    try {
        writeFixtureFile(dir, "PROJECT.md", "# T");
        newFixtureCommit(dir, "base");
        // The ported chain never invokes scope-diff unless refs are supplied (the
        // same opt-in the PS original asserts at the envelope level: no scope_diff
        // key, no SCOPE-DIFF-* rows).
        const result = runPortedChain(REPO_ROOT, dir, "Lite", "Draft");
        assert.ok(!("scope_diff" in result), "opt-in: scope_diff key is absent when not requested");
        assert.equal(result.diagnostics.filter((d) => d.rule_id.startsWith("SCOPE-DIFF-")).length, 0, "opt-in: no SCOPE-DIFF rows appear when not requested");
    }
    finally {
        rmSync(dir, { recursive: true, force: true });
    }
});
