// Covers ci-profile-cli.ts's own argument handling and GITHUB_OUTPUT writing;
// resolveCiProfile's classification logic itself is exercised by
// differential-probe's sibling case coverage and tool-probe.ts's frozen
// ci-profile golden fixture -- this file is deliberately just the plumbing
// around it.
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const CLI = join(REPO_ROOT, "dist/tools/ci-profile-cli.js");
function run(args, env = {}) {
    const r = spawnSync(process.execPath, [CLI, ...args], { encoding: "utf8", env: { ...process.env, ...env } });
    return { stdout: r.stdout ?? "", exitCode: r.status ?? 1 };
}
test("ci-profile-cli: -Profile full prints the full profile", () => {
    const r = run(["-Profile", "full"]);
    const json = JSON.parse(r.stdout);
    assert.equal(json.profile, "full");
    assert.equal(json.hosts, "windows-ps51,windows-ps7,linux,macos");
});
test("ci-profile-cli: -Profile targeted with a single host and suite", () => {
    const r = run(["-Profile", "targeted", "-TargetHost", "linux", "-Suite", "cli"]);
    const json = JSON.parse(r.stdout);
    assert.equal(json.profile, "targeted");
    assert.equal(json.hosts, "linux");
    assert.equal(json.suite, "cli");
});
test("ci-profile-cli: -ChangedPathsPath classifies from a file", () => {
    const dir = mkdtempSync(join(tmpdir(), "ci-profile-cli-"));
    try {
        const pathsFile = join(dir, "changed.txt");
        writeFileSync(pathsFile, "docs/foo.md\n", "utf8");
        const r = run(["-ChangedPathsPath", pathsFile]);
        const json = JSON.parse(r.stdout);
        assert.equal(json.profile, "fast");
    }
    finally {
        rmSync(dir, { recursive: true, force: true });
    }
});
test("ci-profile-cli: -GithubOutput appends profile/suite/hosts/reason/matrix", () => {
    const dir = mkdtempSync(join(tmpdir(), "ci-profile-cli-"));
    try {
        const outputPath = join(dir, "gh-output.txt");
        writeFileSync(outputPath, "", "utf8");
        const r = run(["-Profile", "targeted", "-TargetHost", "macos", "-Suite", "doctor", "-GithubOutput"], { GITHUB_OUTPUT: outputPath });
        assert.equal(r.exitCode, 0);
        const written = readFileSync(outputPath, "utf8");
        assert.match(written, /^profile=targeted$/m);
        assert.match(written, /^suite=doctor$/m);
        assert.match(written, /^hosts=macos$/m);
        assert.match(written, /^matrix=\[\{"name":"macos","runsOn":"macos-15","shell":"pwsh","exe":"pwsh"\}\]$/m);
    }
    finally {
        rmSync(dir, { recursive: true, force: true });
    }
});
test("ci-profile-cli: unknown -TargetHost fails loudly, not silently", () => {
    const r = run(["-Profile", "targeted", "-TargetHost", "bogus-host"]);
    assert.notEqual(r.exitCode, 0);
});
