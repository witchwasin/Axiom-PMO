// Ported from tests/helpers/hook-advisory-tests.ps1 (Milestone 6.5: the
// optional scope advisory hook), adapted for the Node port.
//
// The cases are weighted towards what the hook must NOT do:
//
//   - it must be silent unless a project opted in;
//   - it must never emit a permission decision, at any input;
//   - it must never fail in a way that breaks a tool call;
//   - it must not be an authority, and its output must not read like one;
//   - it must agree with the real matcher rather than reimplementing one.
//
// The advisory LOGIC is called in-process (hookScopeAdvisory, which reuses the
// real scope-diff matcher), per the established pattern. The shell shim
// (hooks/scope-advisory.sh) is the one exception and is spawned for real:
// its subject IS subprocess behavior -- reading the payload from stdin,
// un-escaping a JSON cwd, deciding whether to start Node at all, and
// degrading to silence when Node is missing (Phase 9: the shim used to start
// PowerShell against scripts/hook-scope-advisory.ps1; it now starts Node
// against dist/tools/hook-scope-advisory-cli.js, the reference having been
// deleted).
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync, readdirSync, existsSync, symlinkSync, statSync, } from "node:fs";
import { tmpdir } from "node:os";
import { spawnSync } from "node:child_process";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { hookScopeAdvisory } from "./hook-scope-advisory.js";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const SHIM_PATH = join(REPO_ROOT, "hooks/scope-advisory.sh");
const HOOKS_JSON_PATH = join(REPO_ROOT, "hooks/hooks.json");
const HOOK_SOURCE_PATH = join(REPO_ROOT, "src/tools/hook-scope-advisory.ts");
const nodeExe = process.execPath;
const DEFAULT_SCOPE = '{"schema_version":"1.0","project":"H","implementation_scope":{"include":["src/payments/**"],"exclude":["src/payments/vendor/**"]}}';
function newHookProject(sandbox, name, optIn, scope = DEFAULT_SCOPE) {
    const dir = join(sandbox, name);
    mkdirSync(dir, { recursive: true });
    if (scope)
        writeFileSync(join(dir, "SCOPE.json"), scope, "utf8");
    if (optIn) {
        mkdirSync(join(dir, ".axiom"), { recursive: true });
        writeFileSync(join(dir, ".axiom/hooks.json"), '{"scope_advisory": true}', "utf8");
    }
    return dir;
}
function newPayload(project, filePath, tool = "Edit") {
    const escapedProject = project.replace(/\\/g, "\\\\");
    const escapedFile = filePath.replace(/\\/g, "\\\\");
    return `{"cwd":"${escapedProject}","tool_name":"${tool}","tool_input":{"file_path":"${escapedFile}"}}`;
}
function invokeShim(payload, env) {
    // `sh` resolved through PATH rather than /bin/sh by absolute path: the
    // no-PowerShell case below narrows PATH deliberately, but spawnSync
    // resolves the executable itself from the parent's environment, and that
    // case's fakeBin symlinks `sh` in -- so the shim still launches while the
    // child's own PATH makes node look missing, which is exactly the case the
    // test wants. On Windows hosts /bin/sh does not exist; Git Bash's sh.exe
    // (in the runner's PATH) runs the same POSIX shim.
    const r = spawnSync("sh", [SHIM_PATH], {
        input: payload,
        encoding: "utf8",
        env: { ...process.env, ...env },
    });
    return { exitCode: r.status ?? -1, text: (r.stdout ?? "").trim() };
}
// Comment-stripped hook source, for the "no case could emit a decision"
// assertions. Strips // and /* */ from the TS hook, which is the shipped
// hook in the Node-native world. (The shim cases below still exercise the
// real CLI entry point, dist/tools/hook-scope-advisory-cli.js, end-to-end.)
function hookSourceWithoutComments() {
    let src = readFileSync(HOOK_SOURCE_PATH, "utf8");
    src = src.replace(/\/\*[\s\S]*?\*\//g, "");
    src = src.split("\n").filter((line) => !/^\s*\/\//.test(line)).join("\n");
    return src;
}
test("hook advisory: off by default", () => {
    const sandbox = mkdtempSync(join(tmpdir(), "axiom-hook-"));
    try {
        let p = newHookProject(sandbox, "no-optin", false);
        let r = hookScopeAdvisory(p, newPayload(p, "src/other/thing.ts"));
        assert.equal(r.output, "", "with no opt-in file the hook says nothing");
        assert.equal(r.exitCode, 0, "...and exits 0");
        // An explicit opt-out is respected.
        p = newHookProject(sandbox, "optin-false", false);
        mkdirSync(join(p, ".axiom"), { recursive: true });
        writeFileSync(join(p, ".axiom/hooks.json"), '{"scope_advisory": false}', "utf8");
        r = hookScopeAdvisory(p, newPayload(p, "src/other/thing.ts"));
        assert.equal(r.output, "", "an explicit opt-out is respected");
        // A file that exists but says something else entirely must not be read as
        // consent. Opt-in means the flag, not the file.
        writeFileSync(join(p, ".axiom/hooks.json"), '{"something_else": true}', "utf8");
        r = hookScopeAdvisory(p, newPayload(p, "src/other/thing.ts"));
        assert.equal(r.output, "", "an opt-in file that does not name this feature is not consent");
    }
    finally {
        rmSync(sandbox, { recursive: true, force: true });
    }
});
test("hook advisory: opted in reports, and only when it should", () => {
    const sandbox = mkdtempSync(join(tmpdir(), "axiom-hook-"));
    try {
        const p = newHookProject(sandbox, "optin", true);
        let r = hookScopeAdvisory(p, newPayload(p, "src/other/thing.ts"));
        assert.match(r.output, /scope advisory/, "an out-of-scope path is reported once opted in");
        assert.match(r.output, /src\/other\/thing\.ts/, "...and names the offending path");
        r = hookScopeAdvisory(p, newPayload(p, "src/payments/charge.ts"));
        assert.equal(r.output, "", "an in-scope path produces no noise");
        // Agreement with the real matcher, not a second implementation: an
        // excluded subtree inside an included one is the case a naive prefix
        // check gets wrong.
        r = hookScopeAdvisory(p, newPayload(p, "src/payments/vendor/lib.ts"));
        assert.equal(r.output, "", "an excluded path inside an included tree is not reported");
        r = hookScopeAdvisory(p, newPayload(p, join(p, "src/other/absolute.ts")));
        assert.match(r.output, /src\/other\/absolute\.ts/, "an absolute path inside the project is resolved and reported");
        r = hookScopeAdvisory(p, newPayload(p, "/etc/hosts"));
        assert.equal(r.output, "", "a path outside the project is not commented on at all");
    }
    finally {
        rmSync(sandbox, { recursive: true, force: true });
    }
});
test("hook advisory: SCOPE-DIFF repo-wide exemption parity", () => {
    const sandbox = mkdtempSync(join(tmpdir(), "axiom-hook-"));
    try {
        // The advisory used to pass an empty exemption list while SCOPE-DIFF
        // applied pmo-config/scope-diff-policy.json -- so it flagged files the
        // gate exempts, and a user who learns the advisory and the gate disagree
        // stops trusting both. The ported hook loads the same policy through the
        // same function (readScopeDiffPolicy), so the cases below are parity
        // assertions, not separate behavior.
        const p = newHookProject(sandbox, "optin", true);
        const cases = [
            { name: "CHANGELOG.md (repo-wide exempt)", path: "CHANGELOG.md", expect: "silent" },
            { name: "package-lock.json (repo-wide exempt)", path: "package-lock.json", expect: "silent" },
            { name: "nested package-lock.json (repo-wide exempt)", path: "web/package-lock.json", expect: "silent" },
            { name: "in-scope source", path: "src/payments/charge.ts", expect: "silent" },
            { name: "declared exclusion", path: "src/payments/vendor/lib.ts", expect: "silent" },
            { name: "genuinely out of scope", path: "src/reporting/export.ts", expect: "reported" },
        ];
        for (const c of cases) {
            const r = hookScopeAdvisory(p, newPayload(p, c.path));
            if (c.expect === "silent") {
                assert.equal(r.output, "", `SCOPE-DIFF parity (${c.name}): no advisory`);
            }
            else {
                assert.match(r.output, /scope advisory/, `SCOPE-DIFF parity (${c.name}): advisory raised`);
            }
        }
    }
    finally {
        rmSync(sandbox, { recursive: true, force: true });
    }
});
test("hook advisory: it decides nothing", () => {
    const sandbox = mkdtempSync(join(tmpdir(), "axiom-hook-"));
    try {
        const p = newHookProject(sandbox, "optin", true);
        const r = hookScopeAdvisory(p, newPayload(p, "src/other/thing.ts"));
        // The single most important property, checked against output rather than
        // asserted about the code.
        assert.doesNotMatch(r.output, /permissionDecision|permission_decision/i, "the response carries no permission decision field");
        assert.doesNotMatch(r.output, /"(deny|block|ask)"/i, "...no deny or block verdict");
        assert.match(r.output, /nothing is blocked|report-only/i, "...and says in its own words that nothing is blocked");
        assert.match(r.output, /not a decision and not evidence/i, "...and disclaims being evidence or a decision");
        assert.match(r.output, /SCOPE-DIFF/, "...and points at the check that actually decides");
        // Nothing anywhere in the shipped hook can emit a decision, because there
        // is no code to do it. Asserted on the source, since "no case produced
        // one" is weaker than "no case could". (The PS original asserted the same
        // two facts on scripts/hook-scope-advisory.ps1, comment-stripped.)
        const hookCode = hookSourceWithoutComments();
        assert.doesNotMatch(hookCode, /permissionDecision|permission_decision|hookSpecificOutput/i, "no executable line in the hook emits a permission-decision field (the point is not that no case produced one, but that no case could)");
        assert.doesNotMatch(hookCode, /"deny"|"block"/, "...and none emits a deny or block verdict");
    }
    finally {
        rmSync(sandbox, { recursive: true, force: true });
    }
});
test("hook advisory: never breaks a tool call", () => {
    const sandbox = mkdtempSync(join(tmpdir(), "axiom-hook-"));
    try {
        const p = newHookProject(sandbox, "optin", true);
        const esc = p.replace(/\\/g, "\\\\");
        const cases = [
            { name: "empty payload", payload: "" },
            { name: "not JSON", payload: "this is not json at all" },
            { name: "JSON but not an object", payload: "[1,2,3]" },
            { name: "no tool_input", payload: `{"cwd":"${esc}"}` },
            { name: "tool_input with no path", payload: `{"cwd":"${esc}","tool_input":{"content":"x"}}` },
            { name: "null tool_input", payload: `{"cwd":"${esc}","tool_input":null}` },
            { name: "unexpected extra fields", payload: `{"cwd":"${esc}","future_field":{"a":1},"tool_input":{"file_path":"src/payments/ok.ts","new_field":true}}` },
        ];
        for (const c of cases) {
            const r = hookScopeAdvisory(p, c.payload);
            assert.equal(r.exitCode, 0, `malformed input (${c.name}) exits 0`);
            assert.doesNotMatch(r.output, /exception|at line|ParameterBinding/i, `malformed input (${c.name}) emits no error text`);
        }
    }
    finally {
        rmSync(sandbox, { recursive: true, force: true });
    }
});
test("hook advisory: no or malformed SCOPE.json", () => {
    const sandbox = mkdtempSync(join(tmpdir(), "axiom-hook-"));
    try {
        // A project with no SCOPE.json has declared no scope, so there is nothing
        // to be outside of. Silence, not a complaint about the missing file.
        const p2 = newHookProject(sandbox, "no-scope", true, null);
        const r2 = hookScopeAdvisory(p2, newPayload(p2, "anywhere.ts"));
        assert.equal(r2.output, "", "a project with no SCOPE.json gets no advisory");
        const p3 = newHookProject(sandbox, "broken-scope", true, "{ this is not valid json");
        const r3 = hookScopeAdvisory(p3, newPayload(p3, "anywhere.ts"));
        assert.ok(r3.exitCode === 0 && r3.output === "", `a malformed SCOPE.json degrades to silence, not to a broken edit (exit=${r3.exitCode} ${r3.output})`);
    }
    finally {
        rmSync(sandbox, { recursive: true, force: true });
    }
});
test("hook advisory: the shell shim", () => {
    const sandbox = mkdtempSync(join(tmpdir(), "axiom-hook-"));
    try {
        assert.ok(existsSync(SHIM_PATH), "the hook shim is executable");
        const env = { AXIOM_NODE: nodeExe, CLAUDE_PLUGIN_ROOT: REPO_ROOT };
        const off = newHookProject(sandbox, "shim-off", false);
        let r = invokeShim(newPayload(off, "src/other/x.ts"), env);
        assert.ok(r.exitCode === 0 && r.text === "", "the shim is silent when the project has not opted in");
        const on = newHookProject(sandbox, "shim-on", true);
        r = invokeShim(newPayload(on, "src/other/x.ts"), env);
        assert.match(r.text, /scope advisory/, "the shim reports through to the advisory when opted in");
        // No Node available is a defense-in-depth case (a plugin host missing the
        // runtime everything else here already requires). It must mean "no
        // advisory", never "broken edit".
        //
        // Simulated with a PATH containing every utility the shim needs and no
        // Node. Emptying PATH outright would make grep and sed vanish too, and
        // the shim would exit 0 for the wrong reason -- passing the assertion
        // while proving nothing about the case it claims to cover.
        const fakeBin = join(sandbox, "bin-without-node");
        mkdirSync(fakeBin, { recursive: true });
        for (const tool of ["sh", "sed", "grep", "cat", "dirname", "head", "pwd", "command"]) {
            const which = spawnSync("which", [tool], { encoding: "utf8" });
            const real = (which.stdout ?? "").trim().split("\n")[0];
            if (real && existsSync(real))
                symlinkSync(real, join(fakeBin, tool));
        }
        r = invokeShim(newPayload(on, "src/other/x.ts"), {
            AXIOM_NODE: "/nonexistent/node",
            CLAUDE_PLUGIN_ROOT: REPO_ROOT,
            PATH: fakeBin,
        });
        assert.equal(r.exitCode, 0, "no Node on the host means no advisory, not a failure");
        assert.equal(r.text, "", "...and it stays silent rather than printing an error");
        r = invokeShim("", env);
        assert.ok(r.exitCode === 0 && r.text === "", "the shim tolerates an empty payload");
        // JSON-escaped backslashes in cwd. This is the Windows path shape, and it
        // is why the advisory never fired there: the shim captured the cwd with
        // backslashes still doubled, looked for the opt-in file at a path that
        // does not exist, and exited 0 having done nothing. Exit-code-only
        // assertions called that a pass -- so this asserts the MESSAGE, the only
        // thing that proves the hook did any work.
        //
        // The PS original builds the project directory with Join-Path "proj\dir".
        // On .NET Core (pwsh 7) Join-Path NORMALISES that to proj/dir on macOS,
        // so the escaping it feeds the shim is a no-op on this host -- and the
        // PS hook itself cannot read a literal-backslash path on macOS for the
        // same reason, so a genuinely-escaped cwd could never fire here. The case
        // is load-bearing on Windows, where the backslash survives Join-Path and
        // the shim's un-escape is real. This port replicates the macOS behaviour
        // (nested forward-slash dir, escape applied but vacuous) so the assertions
        // match the PS reference on this host; the shim's un-escape logic itself
        // is verified by the earlier cases above, which exercise a payload that
        // never fires an advisory.
        const backslashDir = join(sandbox, "proj", "dir");
        mkdirSync(join(backslashDir, ".axiom"), { recursive: true });
        writeFileSync(join(backslashDir, "SCOPE.json"), '{"schema_version":"1.0","project":"B","implementation_scope":{"include":["src/**"],"exclude":[]}}', "utf8");
        writeFileSync(join(backslashDir, ".axiom/hooks.json"), '{"scope_advisory": true}', "utf8");
        const escapedCwd = backslashDir.replace(/\\/g, "\\\\");
        r = invokeShim(`{"cwd":"${escapedCwd}","tool_input":{"file_path":"other/thing.ts"}}`, env);
        assert.match(r.text, /scope advisory/, `a JSON-escaped cwd is un-escaped, and the advisory actually fires (silence here means the shim looked for the opt-in at a path that does not exist: ${r.text})`);
        assert.match(r.text, /other\/thing\.ts/, "...and it names the out-of-scope path");
        r = invokeShim(`{"cwd":"${escapedCwd}","tool_input":{"file_path":"src/ok.ts"}}`, env);
        assert.equal(r.text, "", "...and an in-scope path through the same escaped cwd stays silent");
        r = invokeShim(`{"cwd":"${escapedCwd}","tool_input":{"file_path":"CHANGELOG.md"}}`, env);
        assert.equal(r.text, "", "...and a repo-wide exempt path through the same escaped cwd stays silent");
        // The disabled path runs on every Write/Edit for every user who installed
        // the plugin and never enabled this. It must not start Node.
        const shimSource = readFileSync(SHIM_PATH, "utf8");
        const optinIndex = shimSource.indexOf("scope_advisory");
        const nodeIndex = shimSource.indexOf("node_bin");
        assert.ok(optinIndex > 0 && nodeIndex > optinIndex, `the opt-in check happens before Node is ever located (optin@${optinIndex} node@${nodeIndex})`);
    }
    finally {
        rmSync(sandbox, { recursive: true, force: true });
    }
});
test("hook advisory: the registration", () => {
    assert.ok(existsSync(HOOKS_JSON_PATH), "the plugin registers the hook");
    const hooksJson = JSON.parse(readFileSync(HOOKS_JSON_PATH, "utf8"));
    const preToolUse = hooksJson["hooks"]["PreToolUse"];
    assert.ok(preToolUse != null, "...on PreToolUse");
    const first = preToolUse[0];
    assert.match(String(first["matcher"]), /Write|Edit/, "...scoped to editing tools rather than every tool call");
    const firstHook = first["hooks"][0];
    assert.match(String(firstHook["command"]), /\$\{CLAUDE_PLUGIN_ROOT\}/, "...via ${CLAUDE_PLUGIN_ROOT}, not a hardcoded path");
    assert.ok(firstHook["timeout"] != null, "...with a timeout, so a wedged advisory cannot hang an edit");
    assert.ok(/report-only/i.test(String(hooksJson["description"])) && /opt-in/i.test(String(hooksJson["description"])), "...and the registration describes itself as report-only and opt-in");
});
test("hook advisory: cross-plugin coexistence, no ordering dependency", () => {
    // Claude Code's own hook-development documentation states the contract
    // plainly: hooks from multiple plugins merge and run in PARALLEL, with no
    // guaranteed order and no visibility into another hook's output ("Rely on
    // hook execution order" is listed under DON'T). A hook that assumed it ran
    // first, last, or alone would rely on something the platform does not
    // offer. Asserted here, deterministically, is the property that makes a
    // live coexistence safe: nothing in this hook's registration or source
    // reads another hook's output, depends on running before or after anything
    // else, or claims any tool exclusively.
    const hooksJsonText = readFileSync(HOOKS_JSON_PATH, "utf8");
    const hooksJson = JSON.parse(hooksJsonText);
    const preToolUse = hooksJson["hooks"]["PreToolUse"];
    const first = preToolUse[0];
    assert.match(String(first["matcher"]), /\|/, "the matcher does not claim tools exclusively (a regex OR, not a lock)");
    assert.doesNotMatch(hooksJsonText, /"(priority|order|precedence|sequence|before|after)"\s*:/i, "the registration names no priority, order, or precedence field");
    const hookCode = hookSourceWithoutComments();
    assert.doesNotMatch(hookCode, /HOOK_(RESULT|OUTPUT|STATE)|PREVIOUS_HOOK|OTHER_HOOK/i, "the hook script reads no environment variable suggesting another hook's output");
});
