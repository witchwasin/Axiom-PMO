// Phase 6 -- final-tree differential gate, tool surface (deterministic half).
//
// The validator-surface report (differential-probe, execution-probe, marker-*,
// doctor-probe, stateful-probe, setup-probe) proves rule-level parity. This
// probe closes the gap the old report's "Remaining" section listed: the
// orchestrators/tools in src/tools/ that were ported in Phase 5 but never
// differentially exercised against their own PowerShell entrypoint.
//
// Same discipline as differential-probe: direct reference (pwsh -File the
// real script) vs direct candidate (the ported TS function, in-process) on
// identical fixtures. Never both sides through one dispatcher. Outputs are
// compared canonically (golden normalizer), or as parsed JSON when the two
// sides legitimately emit JSON (key order is not a contract for a JSON
// consumer), or byte-for-byte where the reference itself is deterministic.
import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync, rmSync, mkdtempSync, cpSync, existsSync, readdirSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { resolvePwsh } from "./pwsh-resolver.js";
import { getCanonicalGoldenText, getGoldenDiffReport } from "../output/canonical-normalizer.js";
import { runPmoStatus } from "../tools/pmo-status.js";
import { runAssessHandoff } from "../tools/assess-handoff.js";
import { resolveCiProfile } from "../tools/ci-profile.js";
import { measureContext, formatContextTable } from "../tools/measure-context.js";
import { hookScopeAdvisory } from "../tools/hook-scope-advisory.js";
import { checkPublicHygiene } from "../tools/check-public-hygiene.js";
import { buildPluginPackage } from "../tools/build-plugin-package.js";
import { runDemo } from "../tools/demo.js";
import { runAllChecks } from "../tools/run-all-checks.js";
import { resolveCiSuite } from "../tools/run-ci-suite.js";
import { preparePublicRelease } from "../tools/prepare-public-release.js";
import { designProviderDigest, handoffDigest, visualProofDigest } from "../tools/digest-tools.js";
import { updateSourceSnapshot } from "../tools/update-source-snapshot.js";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const PWSH = resolvePwsh();
let pass = 0;
let fail = 0;
function check(name, ok, detail = "") {
    if (ok) {
        pass++;
        console.log(`[PASS] ${name}`);
    }
    else {
        fail++;
        console.log(`[FAIL] ${name}${detail ? " -- " + detail : ""}`);
    }
}
function runPs(script, args, extraEnv = {}) {
    const r = spawnSync(PWSH, ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", join(REPO_ROOT, script), ...args], {
        encoding: "utf8",
        env: { ...process.env, AXIOM_PWSH: PWSH, ...extraEnv },
    });
    return { stdout: r.stdout ?? "", stderr: r.stderr ?? "", exitCode: r.status ?? 1 };
}
// pwsh 7.6 paints Format-Table headers with ANSI even when stdout is
// redirected. The colour is presentation, not content; strip it on the
// reference side only.
const stripAnsi = (s) => s.replace(/\x1b\[[0-9;]*m/g, "");
function deepSortKeys(v) {
    if (Array.isArray(v))
        return v.map(deepSortKeys);
    if (v !== null && typeof v === "object") {
        const out = {};
        for (const k of Object.keys(v).sort())
            out[k] = deepSortKeys(v[k]);
        return out;
    }
    return v;
}
function jsonCanonical(text) {
    try {
        return JSON.stringify(deepSortKeys(JSON.parse(text)));
    }
    catch {
        return null;
    }
}
function compareOutputs(name, ref, cand) {
    const refCanon = getCanonicalGoldenText(ref.stdout);
    const candCanon = getCanonicalGoldenText(cand.output);
    const same = refCanon === candCanon;
    const exitSame = (ref.exitCode ?? 1) === (cand.exitCode ?? 1);
    check(`${name}: output`, same, same ? "" : getGoldenDiffReport(refCanon, candCanon).join(" | "));
    check(`${name}: exit`, exitSame, `reference=${ref.exitCode} candidate=${cand.exitCode}`);
}
// ---------------------------------------------------------------------------
// ci-profile: pure classifier, JSON on stdout, no I/O.
// ---------------------------------------------------------------------------
{
    // -File array binding only ever binds the FIRST value of a -ChangedPaths
    // list (later values fall through to -Profile's ValidateSet and error), so
    // multi-path cases go through -ChangedPathsPath (one path per line), exactly
    // the reference's own documented alternative. Single-path cases use the
    // named parameter directly.
    const ciCases = [
        { label: "mixed", paths: ["src/core/context.ts", "docs/foo.md", "tests/a.test.ts"] },
        { label: "high-risk validator", paths: ["scripts/validate-project.ps1"] },
        { label: "empty (default fast)", paths: [] },
        { label: "cli + example", paths: ["cli/axiom.mjs", "examples/x"] },
        { label: "windows backslash path", paths: ["src\\core\\context.ts"] },
    ];
    for (const c of ciCases) {
        let ref;
        if (c.paths.length === 0) {
            ref = runPs("scripts/ci-profile.ps1", []);
        }
        else if (c.paths.length === 1) {
            ref = runPs("scripts/ci-profile.ps1", ["-ChangedPaths", c.paths[0]]);
        }
        else {
            const dir = mkdtempSync(join(tmpdir(), "tool-probe-ci-"));
            const pf = join(dir, "paths.txt");
            writeFileSync(pf, c.paths.join("\n") + "\n");
            ref = runPs("scripts/ci-profile.ps1", ["-ChangedPathsPath", pf]);
            rmSync(dir, { recursive: true, force: true });
        }
        const cand = resolveCiProfile(c.paths);
        const candJson = JSON.stringify(cand);
        const refJson = jsonCanonical(ref.stdout);
        check(`ci-profile ${c.label}: JSON matches`, refJson === jsonCanonical(candJson), `ref=${refJson} cand=${jsonCanonical(candJson)}`);
        check(`ci-profile ${c.label}: exit 0`, ref.exitCode === 0, `exit ${ref.exitCode}`);
    }
}
// ---------------------------------------------------------------------------
// pmo-status: read-only report; JSON deep-equal + Text canonical.
// ---------------------------------------------------------------------------
{
    const fixtures = [
        { label: "standard", path: join(REPO_ROOT, "examples/STANDARD-FEATURE") },
        { label: "strict-escalation", path: join(REPO_ROOT, "examples/STRICT-HIGH-RISK") },
        { label: "handoff-demo", path: join(REPO_ROOT, "examples/HANDOFF-DEMO") },
    ];
    for (const f of fixtures) {
        const ref = runPs("scripts/pmo-status.ps1", ["-ProjectPath", f.path, "-Format", "Json"]);
        const cand = runPmoStatus(REPO_ROOT, f.path, "Json");
        const refCanon = jsonCanonical(ref.stdout);
        const candCanon = jsonCanonical(cand.output);
        check(`pmo-status ${f.label} json: equal`, refCanon === candCanon && refCanon !== null, refCanon === candCanon ? "" : `ref=${refCanon} cand=${candCanon}`);
        check(`pmo-status ${f.label} json: exit`, (ref.exitCode ?? 1) === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
    }
    // Text format on one fixture (canonical, path-normalized already since both
    // sides print the same absolute fixture path).
    {
        const path = join(REPO_ROOT, "examples/HANDOFF-DEMO");
        const ref = runPs("scripts/pmo-status.ps1", ["-ProjectPath", path]);
        const cand = runPmoStatus(REPO_ROOT, path, "Text");
        const refCanon = getCanonicalGoldenText(ref.stdout);
        const candCanon = getCanonicalGoldenText(cand.output);
        check("pmo-status handoff-demo text: equal", refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
        check("pmo-status handoff-demo text: exit", (ref.exitCode ?? 1) === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
    }
    // A directory that exists but has no PROJECT.md: the reference treats it as
    // a real project whose STRUCT-001 finding is the "next required" answer.
    {
        const dir = mkdtempSync(join(tmpdir(), "tool-probe-status-"));
        try {
            const ref = runPs("scripts/pmo-status.ps1", ["-ProjectPath", dir, "-Format", "Json"]);
            const cand = runPmoStatus(REPO_ROOT, dir, "Json");
            const refCanon = jsonCanonical(ref.stdout);
            const candCanon = jsonCanonical(cand.output);
            check("pmo-status empty-dir json: equal", refCanon === candCanon && refCanon !== null, refCanon === candCanon ? "" : `ref=${refCanon} cand=${candCanon}`);
            check("pmo-status empty-dir json: exit", (ref.exitCode ?? 1) === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
        }
        finally {
            rmSync(dir, { recursive: true, force: true });
        }
    }
}
// ---------------------------------------------------------------------------
// assess-handoff: gate + review + score. JSON deep-equal + Text canonical.
// ---------------------------------------------------------------------------
{
    const cases = [
        { label: "handoff-demo json", path: join(REPO_ROOT, "examples/HANDOFF-DEMO"), format: "Json" },
        { label: "valid-handoff-strict json", path: join(REPO_ROOT, "tests/fixtures/valid-handoff-strict"), format: "Json" },
        { label: "invalid-handoff-missing text", path: join(REPO_ROOT, "tests/fixtures/invalid-handoff-missing"), format: "Text" },
    ];
    for (const c of cases) {
        const ref = runPs("scripts/assess-handoff.ps1", ["-ProjectPath", c.path, "-Format", c.format]);
        const cand = runAssessHandoff(REPO_ROOT, c.path, "Standard", c.format);
        if (c.format === "Json") {
            const refCanon = jsonCanonical(ref.stdout);
            const candCanon = jsonCanonical(cand.output);
            check(`assess-handoff ${c.label}: equal`, refCanon === candCanon && refCanon !== null, refCanon === candCanon ? "" : `ref=${refCanon} cand=${candCanon}`);
        }
        else {
            const refCanon = getCanonicalGoldenText(ref.stdout);
            const candCanon = getCanonicalGoldenText(cand.output);
            check(`assess-handoff ${c.label}: equal`, refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
        }
        check(`assess-handoff ${c.label}: exit`, (ref.exitCode ?? 1) === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
    }
}
// ---------------------------------------------------------------------------
// digest tools: deterministic hash reports; exact byte comparison.
// ---------------------------------------------------------------------------
{
    const vp = join(REPO_ROOT, "examples/DESIGN-SYSTEM-DEMO");
    {
        const ref = runPs("scripts/visual-proof-digest.ps1", ["-ProjectPath", vp]);
        const cand = visualProofDigest(REPO_ROOT, vp);
        check("visual-proof-digest: output", getCanonicalGoldenText(ref.stdout) === getCanonicalGoldenText(cand.output), getGoldenDiffReport(getCanonicalGoldenText(ref.stdout), getCanonicalGoldenText(cand.output)).join(" | "));
        check("visual-proof-digest: exit", (ref.exitCode ?? 1) === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
    }
    const hd = join(REPO_ROOT, "examples/HANDOFF-DEMO");
    for (const which of ["Both", "Source", "ReviewInputs"]) {
        const ref = runPs("scripts/handoff-digest.ps1", ["-ProjectPath", hd, "-Which", which]);
        const cand = handoffDigest(REPO_ROOT, hd, which);
        check(`handoff-digest ${which}: output`, getCanonicalGoldenText(ref.stdout) === getCanonicalGoldenText(cand.output), getGoldenDiffReport(getCanonicalGoldenText(ref.stdout), getCanonicalGoldenText(cand.output)).join(" | "));
        check(`handoff-digest ${which}: exit`, (ref.exitCode ?? 1) === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
    }
    const dp = join(REPO_ROOT, "examples/OPTIONAL-TRACKS");
    {
        const ref = runPs("scripts/design-provider-digest.ps1", ["-ProjectPath", dp]);
        const cand = designProviderDigest(REPO_ROOT, dp);
        check("design-provider-digest: output", getCanonicalGoldenText(ref.stdout) === getCanonicalGoldenText(cand.output), getGoldenDiffReport(getCanonicalGoldenText(ref.stdout), getCanonicalGoldenText(cand.output)).join(" | "));
        check("design-provider-digest: exit", (ref.exitCode ?? 1) === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
    }
}
// ---------------------------------------------------------------------------
// measure-context: Format-Table output; ANSI stripped on the reference side,
// then byte-for-byte against the port's Format-Table replica.
// ---------------------------------------------------------------------------
{
    const defaultFiles = ["AGENTS.md", "CLAUDE.md", "CONTEXT-ROUTER.md", "pmo-config/context-map.json", "pmo-config/policy.json"];
    {
        const ref = runPs("scripts/measure-context.ps1", []);
        const cand = formatContextTable(measureContext(REPO_ROOT, defaultFiles));
        const refClean = stripAnsi(ref.stdout);
        check("measure-context default files: output", refClean === cand, getGoldenDiffReport(getCanonicalGoldenText(refClean), getCanonicalGoldenText(cand)).join(" | "));
        check("measure-context default files: exit", (ref.exitCode ?? 1) === 0, `exit ${ref.exitCode}`);
    }
    {
        const ref = runPs("scripts/measure-context.ps1", ["-Files", "AGENTS.md"]);
        const cand = formatContextTable(measureContext(REPO_ROOT, ["AGENTS.md"]));
        const refClean = stripAnsi(ref.stdout);
        check("measure-context single file: output", refClean === cand, getGoldenDiffReport(getCanonicalGoldenText(refClean), getCanonicalGoldenText(cand)).join(" | "));
    }
}
// ---------------------------------------------------------------------------
// hook-scope-advisory: report-only advisory; JSON bytes or silence.
// ---------------------------------------------------------------------------
function advisoryProject(optIn) {
    const dir = mkdtempSync(join(tmpdir(), "tool-probe-advisory-"));
    mkdirSync(join(dir, "src/payments"), { recursive: true });
    writeFileSync(join(dir, "PROJECT.md"), "# P-ADV\n");
    writeFileSync(join(dir, "SCOPE.json"), JSON.stringify({
        schema_version: "1.0",
        project: "P-ADV",
        implementation_scope: { include: ["src/payments/**"], exclude: [] },
    }));
    if (optIn) {
        mkdirSync(join(dir, ".axiom"), { recursive: true });
        writeFileSync(join(dir, ".axiom/hooks.json"), JSON.stringify({ scope_advisory: true }));
    }
    const payload = JSON.stringify({ cwd: dir, tool_input: { file_path: "src/reporting/export.ts" } });
    return { dir, payload };
}
{
    const { dir, payload } = advisoryProject(true);
    try {
        const payloadPath = join(dir, "payload.json");
        writeFileSync(payloadPath, payload);
        const ref = runPs("scripts/hook-scope-advisory.ps1", ["-ProjectPath", dir, "-PayloadPath", payloadPath]);
        const cand = hookScopeAdvisory(dir, payload);
        check("hook-advisory out-of-scope: output", getCanonicalGoldenText(ref.stdout) === getCanonicalGoldenText(cand.output), getGoldenDiffReport(getCanonicalGoldenText(ref.stdout), getCanonicalGoldenText(cand.output)).join(" | "));
        check("hook-advisory out-of-scope: exit", (ref.exitCode ?? 1) === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
    }
    finally {
        rmSync(dir, { recursive: true, force: true });
    }
}
{
    const dir = mkdtempSync(join(tmpdir(), "tool-probe-advisory-"));
    try {
        mkdirSync(join(dir, "src/payments"), { recursive: true });
        writeFileSync(join(dir, "PROJECT.md"), "# P-ADV\n");
        writeFileSync(join(dir, "SCOPE.json"), JSON.stringify({
            schema_version: "1.0", project: "P-ADV",
            implementation_scope: { include: ["src/payments/**"], exclude: [] },
        }));
        mkdirSync(join(dir, ".axiom"), { recursive: true });
        writeFileSync(join(dir, ".axiom/hooks.json"), JSON.stringify({ scope_advisory: true }));
        const payload = JSON.stringify({ cwd: dir, tool_input: { file_path: "src/payments/charge.ts" } });
        const payloadPath = join(dir, "payload.json");
        writeFileSync(payloadPath, payload);
        const ref = runPs("scripts/hook-scope-advisory.ps1", ["-ProjectPath", dir, "-PayloadPath", payloadPath]);
        const cand = hookScopeAdvisory(dir, payload);
        check("hook-advisory in-scope: silent on both sides", ref.stdout.trim() === "" && cand.output === "", `ref=[${ref.stdout}] cand=[${cand.output}]`);
    }
    finally {
        rmSync(dir, { recursive: true, force: true });
    }
}
{
    const { dir, payload } = advisoryProject(false);
    try {
        const payloadPath = join(dir, "payload.json");
        writeFileSync(payloadPath, payload);
        const ref = runPs("scripts/hook-scope-advisory.ps1", ["-ProjectPath", dir, "-PayloadPath", payloadPath]);
        const cand = hookScopeAdvisory(dir, payload);
        check("hook-advisory no-opt-in: silent on both sides", ref.stdout.trim() === "" && cand.output === "", `ref=[${ref.stdout}] cand=[${cand.output}]`);
    }
    finally {
        rmSync(dir, { recursive: true, force: true });
    }
}
// ---------------------------------------------------------------------------
// check-public-hygiene: scans tracked files of the framework repo itself.
// ---------------------------------------------------------------------------
{
    const ref = runPs("scripts/check-public-hygiene.ps1", ["-RepoPath", REPO_ROOT]);
    const cand = checkPublicHygiene(REPO_ROOT);
    const refCanon = getCanonicalGoldenText(ref.stdout);
    const candCanon = getCanonicalGoldenText(cand.output);
    check("check-public-hygiene: output", refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
    check("check-public-hygiene: exit", (ref.exitCode ?? 1) === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
}
// ---------------------------------------------------------------------------
// build-plugin-package: -Check against the real repo, plus a drifted mirror
// and a fresh generate, both on a temp copy (the script resolves its roots
// from $PSScriptRoot/.. so the copy carries its own .claude/skills + skills).
// ---------------------------------------------------------------------------
{
    const ref = runPs("scripts/build-plugin-package.ps1", ["-Check"]);
    const cand = buildPluginPackage(REPO_ROOT, true);
    const refCanon = getCanonicalGoldenText(ref.stdout);
    const candCanon = getCanonicalGoldenText(cand.output);
    check("build-plugin-package -Check (synced): output", refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
    check("build-plugin-package -Check (synced): exit", (ref.exitCode ?? 1) === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
}
function pluginTree(desync) {
    const dir = mkdtempSync(join(tmpdir(), "tool-probe-plugin-"));
    cpSync(join(REPO_ROOT, ".claude/skills"), join(dir, ".claude/skills"), { recursive: true });
    cpSync(join(REPO_ROOT, "scripts/build-plugin-package.ps1"), join(dir, "scripts/build-plugin-package.ps1"));
    cpSync(join(REPO_ROOT, ".claude/skills"), join(dir, "skills"), { recursive: true });
    if (desync) {
        // Modify one mirrored file so the mirror no longer matches the source.
        const srcRoot = join(REPO_ROOT, ".claude/skills");
        const walk = (d) => {
            for (const e of ["SKILL.md", "skill.md", "skill.yml"]) {
                if (existsSync(join(d, e)))
                    return join(d, e);
            }
            const entries = ["pmo-intake", "pmo-scope", "pmo-release"].map((s) => join(d, s)).filter((p) => existsSync(p));
            for (const sub of entries) {
                const found = walk(sub);
                if (found)
                    return found;
            }
            return null;
        };
        const srcFile = walk(srcRoot);
        if (!srcFile)
            throw new Error("no SKILL.md found under .claude/skills");
        const rel = srcFile.substring(srcRoot.length);
        writeFileSync(join(dir, "skills", rel), readFileSync(srcFile, "utf8") + "\n# drifted\n");
    }
    return dir;
}
function treeSnapshot(root, sub) {
    const out = {};
    const base = join(root, sub);
    const walk = (d) => {
        for (const entry of readdirSync(d)) {
            const full = join(d, entry);
            if (statSync(full).isDirectory())
                walk(full);
            else
                out[full.substring(base.length).replace(/^[/\\]/, "")] = readFileSync(full).toString("base64");
        }
    };
    if (existsSync(base))
        walk(base);
    return out;
}
{
    const dir = pluginTree(true);
    try {
        // The copied script resolves its own roots from $PSScriptRoot/.., so it
        // operates on the same drifted tree the candidate sees.
        const refCopy = spawnSync(PWSH, ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", join(dir, "scripts/build-plugin-package.ps1"), "-Check"], { encoding: "utf8", env: { ...process.env, AXIOM_PWSH: PWSH } });
        const cand = buildPluginPackage(dir, true);
        const refCanon = getCanonicalGoldenText(refCopy.stdout ?? "");
        const candCanon = getCanonicalGoldenText(cand.output);
        check("build-plugin-package -Check (drifted): output", refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
        check("build-plugin-package -Check (drifted): exit", (refCopy.status ?? 1) === cand.exitCode, `ref=${refCopy.status} cand=${cand.exitCode}`);
    }
    finally {
        rmSync(dir, { recursive: true, force: true });
    }
}
{
    const dir = pluginTree(false);
    try {
        rmSync(join(dir, "skills"), { recursive: true, force: true });
        const ref = spawnSync(PWSH, ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", join(dir, "scripts/build-plugin-package.ps1")], { encoding: "utf8", env: { ...process.env, AXIOM_PWSH: PWSH } });
        const cand = buildPluginPackage(dir, false);
        const refCanon = getCanonicalGoldenText(ref.stdout ?? "");
        const candCanon = getCanonicalGoldenText(cand.output);
        check("build-plugin-package generate: output", refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
        check("build-plugin-package generate: exit", (ref.status ?? 1) === cand.exitCode, `ref=${ref.status} cand=${cand.exitCode}`);
        const refSnap = treeSnapshot(dir, "skills");
        const candSnap = treeSnapshot(dir, "skills");
        const sameFiles = JSON.stringify(Object.keys(refSnap).sort()) === JSON.stringify(Object.keys(candSnap).sort());
        const sameBytes = Object.keys(refSnap).every((k) => refSnap[k] === candSnap[k]);
        check("build-plugin-package generate: file set identical", sameFiles);
        check("build-plugin-package generate: bytes identical", sameBytes);
    }
    finally {
        rmSync(dir, { recursive: true, force: true });
    }
}
// ---------------------------------------------------------------------------
// update-source-snapshot: -DryRun (timestamp modulo).
// ---------------------------------------------------------------------------
{
    const dir = mkdtempSync(join(tmpdir(), "tool-probe-snapshot-"));
    try {
        mkdirSync(join(dir, "source/REQ"), { recursive: true });
        writeFileSync(join(dir, "source/REQ/REQ-0001.md"), "# REQ-0001\n");
        writeFileSync(join(dir, "PROJECT.md"), [
            "# P99-SNAP",
            "",
            "## Source Snapshot",
            "",
            "| Source ID | Version / Date | SHA256 | Last Synced At |",
            "|---|---|---|---|",
            "| REQ-0001 | v1 | deadbeef | 2026-01-01T00:00:00Z |",
            "",
            "## Other",
            "x",
            "",
        ].join("\n"));
        const ref = runPs("scripts/update-source-snapshot.ps1", ["-ProjectPath", dir, "-DryRun"]);
        const cand = updateSourceSnapshot(dir, true);
        const norm = (s) => getCanonicalGoldenText(s).replace(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:\d{2})/g, "<TS>");
        check("update-source-snapshot -DryRun: output", norm(ref.stdout) === norm(cand.output), getGoldenDiffReport(norm(ref.stdout), norm(cand.output)).join(" | "));
        check("update-source-snapshot -DryRun: exit", (ref.exitCode ?? 1) === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
    }
    finally {
        rmSync(dir, { recursive: true, force: true });
    }
}
// ---------------------------------------------------------------------------
// prepare-public-release: non-destructive readiness, on the repo itself.
// ---------------------------------------------------------------------------
{
    const ref = runPs("scripts/prepare-public-release.ps1", []);
    const cand = preparePublicRelease(REPO_ROOT, false);
    const refCanon = getCanonicalGoldenText(ref.stdout);
    const candCanon = getCanonicalGoldenText(cand.output);
    check("prepare-public-release: output", refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
    check("prepare-public-release: exit", (ref.exitCode ?? 1) === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
}
// ---------------------------------------------------------------------------
// run-ci-suite: -ResolveOnly mapping (host prefix normalized) + unknown suite.
// ---------------------------------------------------------------------------
{
    const suites = ["doctor", "hygiene", "golden", "validation-fixtures", "config-mutation", "line-ending", "plugin-drift", "cli", "github-action", "all"];
    for (const suite of suites) {
        const ref = runPs("scripts/run-ci-suite.ps1", ["-Suite", suite, "-RepoPath", REPO_ROOT, "-ResolveOnly"]);
        const cand = resolveCiSuite(REPO_ROOT, suite);
        if ("error" in cand) {
            check(`run-ci-suite ${suite}: no error from candidate`, false, cand.error);
            continue;
        }
        // The reference prints the resolved host executable (absolute path or
        // `node`) and an ABSOLUTE script target; the candidate's contract is
        // command + args with a repo-relative target. Compare from the first
        // option onward, prefixing repo-relative targets so both sides name the
        // same absolute script, with the repo root normalized out.
        // The reference prints an absolute target for PowerShell suites (its
        // suiteMap joins $repo in) but leaves node-suite targets relative.
        const absify = (a) => cand.cmd === "pwsh" && (a.startsWith("scripts/") || a.startsWith("tests/") || a.startsWith("cli/") || a.startsWith("src/"))
            ? `<REPO>/${a}`
            : a;
        const candLine = cand.args.map(absify).join(" ").replaceAll(REPO_ROOT, "<REPO>");
        const refLine = ref.stdout.trim().replace(/^\S+\s+/, "").replaceAll(REPO_ROOT, "<REPO>");
        check(`run-ci-suite ${suite}: resolve line`, refLine === candLine, `ref=[${refLine}] cand=[${candLine}]`);
    }
    {
        const ref = runPs("scripts/run-ci-suite.ps1", ["-Suite", "bogus", "-RepoPath", REPO_ROOT]);
        const cand = resolveCiSuite(REPO_ROOT, "bogus");
        const refCanon = getCanonicalGoldenText(ref.stdout);
        check("run-ci-suite unknown suite: message", "error" in cand && refCanon === getCanonicalGoldenText(cand.error + "\n"), `ref=[${refCanon}] cand=${"error" in cand ? cand.error : "no error"}`);
        check("run-ci-suite unknown suite: exit 1", ref.exitCode === 1, `exit ${ref.exitCode}`);
    }
}
// ---------------------------------------------------------------------------
// demo: full transcript, -Plain -NoPause. Both sides spawn the same child
// validators, so this doubles as a Text-report parity check.
// ---------------------------------------------------------------------------
{
    const ref = runPs("scripts/demo.ps1", ["-Plain", "-NoPause"]);
    const cand = runDemo(REPO_ROOT, true, true);
    const refCanon = getCanonicalGoldenText(ref.stdout);
    const candCanon = getCanonicalGoldenText(cand.output);
    check("demo: output", refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
    check("demo: exit", (ref.exitCode ?? 1) === cand.exitCode, `ref=${ref.exitCode} cand=${cand.exitCode}`);
}
// ---------------------------------------------------------------------------
// run-all-checks: fault-injection path. Both sides stop at the first failing
// child with identical framing (the full-pass framing is the same code path
// with zero-length child output, covered by the checks below it).
// ---------------------------------------------------------------------------
{
    const child = join(REPO_ROOT, "tests/helpers/exit-1.ps1");
    const ref = runPs("scripts/run-all-checks.ps1", ["-TestChildScript", child]);
    const cand = runAllChecks(REPO_ROOT, "tests/helpers/exit-1.ps1");
    const refCanon = getCanonicalGoldenText(ref.stdout);
    const candCanon = getCanonicalGoldenText(cand.output);
    check("run-all-checks fault-injection: output", refCanon === candCanon, getGoldenDiffReport(refCanon, candCanon).join(" | "));
    check("run-all-checks fault-injection: exit 1", (ref.exitCode ?? 1) === cand.exitCode && cand.exitCode === 1, `ref=${ref.exitCode} cand=${cand.exitCode}`);
}
// ---------------------------------------------------------------------------
// CLI: the wrapper forwards to the same scripts, so the compatibility case is
// CLI-vs-direct-script parity (the wrapper must add nothing and drop nothing).
// ---------------------------------------------------------------------------
function runCli(args, opts = {}) {
    const r = spawnSync(process.execPath, [join(REPO_ROOT, "cli/axiom.mjs"), ...args], {
        encoding: "utf8",
        cwd: opts.cwd ?? REPO_ROOT,
        env: { ...process.env, AXIOM_PWSH: PWSH },
    });
    return { stdout: r.stdout ?? "", stderr: r.stderr ?? "", exitCode: r.status ?? 1 };
}
{
    const hd = join(REPO_ROOT, "examples/HANDOFF-DEMO");
    const cli = runCli(["status", "--project", hd, "--json"]);
    const direct = runPs("scripts/pmo-status.ps1", ["-ProjectPath", hd, "-Format", "Json"]);
    check("cli status --json: output equals direct script", getCanonicalGoldenText(cli.stdout) === getCanonicalGoldenText(direct.stdout), getGoldenDiffReport(getCanonicalGoldenText(cli.stdout), getCanonicalGoldenText(direct.stdout)).join(" | "));
    check("cli status --json: exit equals direct", cli.exitCode === direct.exitCode, `cli=${cli.exitCode} direct=${direct.exitCode}`);
    const sf = join(REPO_ROOT, "examples/STANDARD-FEATURE");
    const cliV = runCli(["validate", "--project", sf, "--gate", "Release", "--json"]);
    const directV = runPs("scripts/validate-project.ps1", ["-ProjectPath", sf, "-Mode", "Standard", "-Gate", "Release", "-Format", "Json"]);
    check("cli validate --json: output equals direct script", getCanonicalGoldenText(cliV.stdout) === getCanonicalGoldenText(directV.stdout), getGoldenDiffReport(getCanonicalGoldenText(cliV.stdout), getCanonicalGoldenText(directV.stdout)).join(" | "));
    check("cli validate --json: exit equals direct", cliV.exitCode === directV.exitCode, `cli=${cliV.exitCode} direct=${directV.exitCode}`);
    const cliH = runCli(["handoff", "--project", hd, "--json"]);
    const gateDirect = runPs("scripts/validate-project.ps1", ["-ProjectPath", hd, "-Mode", "Standard", "-Gate", "Handoff", "-Format", "Json"]);
    const assessDirect = runPs("scripts/assess-handoff.ps1", ["-ProjectPath", hd, "-Mode", "Standard", "-Format", "Json"]);
    let envelope = null;
    try {
        envelope = JSON.parse(cliH.stdout);
    }
    catch { }
    check("cli handoff --json: envelope parses", envelope !== null);
    if (envelope) {
        check("cli handoff --json: gate payload equals direct", jsonCanonical(JSON.stringify(envelope["gate"])) === jsonCanonical(gateDirect.stdout), `envelope gate vs direct: ${jsonCanonical(JSON.stringify(envelope["gate"]))} != ${jsonCanonical(gateDirect.stdout)}`);
        check("cli handoff --json: assessment payload equals direct", jsonCanonical(JSON.stringify(envelope["assessment"])) === jsonCanonical(assessDirect.stdout), `envelope assessment vs direct: ${jsonCanonical(JSON.stringify(envelope["assessment"]))} != ${jsonCanonical(assessDirect.stdout)}`);
        check("cli handoff --json: exit is the gate's exit", cliH.exitCode === gateDirect.exitCode, `cli=${cliH.exitCode} gate=${gateDirect.exitCode}`);
    }
    const unknown = runCli(["bogus"]);
    check("cli unknown command: exit 64", unknown.exitCode === 64, `exit ${unknown.exitCode}`);
    check("cli unknown command: stderr names it", unknown.stderr.includes("Unknown command: bogus"), `stderr=[${unknown.stderr.slice(0, 80)}]`);
    const missing = runCli(["status", "--project", "/nonexistent/xyz"]);
    check("cli missing project: exit 64", missing.exitCode === 64, `exit ${missing.exitCode}`);
    check("cli missing project: stderr names it", missing.stderr.includes("project directory not found: /nonexistent/xyz"), `stderr=[${missing.stderr.slice(0, 80)}]`);
}
// ---------------------------------------------------------------------------
// GitHub Action wrapper: report JSON/MD contract against the direct validator
// JSON, report-only softening, and enforce escalation.
// ---------------------------------------------------------------------------
{
    const runAction = (args, cwd) => {
        const r = spawnSync(process.execPath, [join(REPO_ROOT, "scripts/github-action/run-action.mjs"), ...args], {
            encoding: "utf8",
            cwd,
            env: { ...process.env, AXIOM_PWSH: PWSH, GITHUB_OUTPUT: "", GITHUB_STEP_SUMMARY: "" },
        });
        return { stdout: r.stdout ?? "", stderr: r.stderr ?? "", exitCode: r.status ?? 1 };
    };
    const wd = mkdtempSync(join(tmpdir(), "tool-probe-action-"));
    try {
        const sf = join(REPO_ROOT, "examples/STANDARD-FEATURE");
        const jsonPath = join(wd, "axiom-report.json");
        const mdPath = join(wd, "axiom-report.md");
        const r = runAction(["--project", sf, "--gate", "Release", "--json-report-path", jsonPath, "--md-report-path", mdPath], wd);
        const direct = runPs("scripts/validate-project.ps1", ["-ProjectPath", sf, "-Mode", "Standard", "-Gate", "Release", "-Format", "Json"]);
        check("action pass fixture: exit 0", r.exitCode === 0, `exit ${r.exitCode}`);
        let report = null;
        try {
            report = JSON.parse(readFileSync(jsonPath, "utf8"));
        }
        catch { }
        check("action pass fixture: report JSON written", report !== null);
        if (report && direct.exitCode === 0) {
            const directEnvelope = JSON.parse(direct.stdout);
            const dSummary = deepSortKeys(directEnvelope["summary"]);
            const rSummary = deepSortKeys(report["summary"] ?? {});
            check("action pass fixture: report summary equals validator", JSON.stringify(rSummary) === JSON.stringify(dSummary), `report=${JSON.stringify(rSummary)} validator=${JSON.stringify(dSummary)}`);
            check("action pass fixture: report carries configured project", String(report["project"]) === sf, `project=${report["project"]}`);
            check("action pass fixture: markdown report written", existsSync(mdPath) && (readFileSync(mdPath, "utf8").length > 0));
        }
        // Report-only softens a governance FAIL into a passing step...
        const bad = join(REPO_ROOT, "tests/fixtures/invalid-rtm-broken-release-ref");
        const badJson = join(wd, "bad-report.json");
        const badMd = join(wd, "bad-report.md");
        const rBad = runAction(["--project", bad, "--json-report-path", badJson, "--md-report-path", badMd], wd);
        check("action failing fixture report-only: exit 0", rBad.exitCode === 0, `exit ${rBad.exitCode}`);
        let badReport = null;
        try {
            badReport = JSON.parse(readFileSync(badJson, "utf8"));
        }
        catch { }
        const failCount = badReport?.["summary"]?.["fail"] ?? -1;
        check("action failing fixture report-only: report still shows FAIL", (badReport !== null) && failCount > 0, `fail=${failCount}`);
        // ...and --enforce makes the same run fail the step.
        const rEnforce = runAction(["--project", bad, "--enforce", "true", "--json-report-path", join(wd, "bad-report2.json"), "--md-report-path", join(wd, "bad-report2.md")], wd);
        check("action failing fixture enforce: exit 1", rEnforce.exitCode === 1, `exit ${rEnforce.exitCode}`);
    }
    finally {
        rmSync(wd, { recursive: true, force: true });
    }
}
// ---------------------------------------------------------------------------
// Documented skips (each has a reason; none is an unexplained gap):
//  - capture-plugin-load-evidence: drives the real `claude` CLI, which mutates
//    ~/.claude (install/uninstall of the axiom-pmo plugin). Both sides drive
//    the same external binary, so the differential value is the wrapper's
//    transcript handling, covered by unit tests; running it here would modify
//    the user's machine outside the project tree. Skipped.
// ---------------------------------------------------------------------------
console.log("  [SKIP] capture-plugin-load-evidence: live claude CLI mutates ~/.claude; both sides drive the same external binary (documented in the Phase 6 report)");
console.log(`\nSummary: PASS=${pass} FAIL=${fail}`);
if (fail > 0)
    process.exitCode = 1;
