// Ported from tests/helpers/plugin-package-tests.ps1 (Milestone 6.2: the plugin
// package itself), adapted for the Node port.
//
// What is under test is the packaging contract, not Claude Code. Two facts
// established in Milestone 6.1 are load-bearing here and are re-asserted
// rather than trusted:
//
//   1. Claude Code discovers plugin skills from <plugin-root>/skills/ only.
//   2. The plugin root is the repository root, so scripts/, cli/, pmo-config/
//      and templates/ are already where the plugin needs them. Nothing is
//      copied. That leaves one generated directory -- skills/ -- and a
//      generated directory is a drift hazard. Most of this file is the gate
//      that makes drift impossible rather than merely discouraged.
//
// Calls the ported buildPluginPackage / preparePublicRelease / marker-block /
// framework-checkout functions in-process instead of spawning the .ps1
// scripts, per the established pattern. The one thing that cannot be
// reproduced literally is the PS version's probe.ps1 subprocess, which proved
// the FRAMEWORK-001 guard stops a script before its body runs; in-process the
// equivalent is the guard's boolean + message + the tool returning no body
// rows, asserted directly.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, cpSync, rmSync, writeFileSync, readFileSync, readdirSync, statSync, existsSync, } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { buildPluginPackage } from "./build-plugin-package.js";
import { preparePublicRelease } from "./prepare-public-release.js";
import { getAxiomCanonicalBody, getAxiomBlockDigest, KNOWN_BODY_DIGESTS } from "../marker/marker-block.js";
import { testFrameworkCheckout, frameworkCheckoutFailureMessage } from "../core/framework-checkout.js";
import { runPmoDoctor } from "../doctor/pmo-doctor.js";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
// ConvertFrom-Json tolerates a UTF-8 BOM; JSON.parse does not. The manifests
// and configs carry one, so strip it before parsing (same as loadJson in
// pmo-doctor.ts).
function readJson(path) {
    let raw = readFileSync(path, "utf8");
    if (raw.charCodeAt(0) === 0xfeff)
        raw = raw.slice(1);
    return JSON.parse(raw);
}
test("plugin package: the manifests", () => {
    const pluginManifestPath = join(REPO_ROOT, ".claude-plugin/plugin.json");
    const marketplaceManifestPath = join(REPO_ROOT, ".claude-plugin/marketplace.json");
    assert.ok(existsSync(pluginManifestPath), "plugin manifest exists at .claude-plugin/plugin.json");
    assert.ok(existsSync(marketplaceManifestPath), "marketplace manifest exists at .claude-plugin/marketplace.json");
    const plugin = readJson(pluginManifestPath);
    const marketplace = readJson(marketplaceManifestPath);
    const plugins = marketplace["plugins"] ?? [];
    assert.match(String(plugin["name"]), /^[a-z][a-z0-9]*(-[a-z0-9]+)*$/, `plugin name is kebab-case as the manifest reference requires (name=${plugin["name"]})`);
    // The plugin manifest's version is the release's version. Full stop. The PS
    // original documents the reasoning (asserted equality, briefly relaxed to
    // "must be ahead", then restored): the version a plugin declares is the
    // identity Claude Code caches and updates against, so equality is the
    // released-state contract.
    assert.match(String(plugin["version"]), /^\d+\.\d+\.\d+$/, `plugin version is a valid semantic version (plugin=${plugin["version"]})`);
    const repoVersion = readFileSync(join(REPO_ROOT, "VERSION"), "utf8").trim();
    assert.equal(String(plugin["version"]), repoVersion, `plugin version equals the release VERSION (plugin=${plugin["version"]} VERSION=${repoVersion} -- the plugin's declared version is the identity Claude Code caches against; a mismatch ships bytes under a version that is not theirs)`);
    assert.equal(plugins.length, 1, "marketplace declares exactly the one plugin");
    assert.equal(String(plugins[0]["source"]), "./", `marketplace source is the repository root (source=${plugins[0]["source"]})`);
    assert.equal(String(plugins[0]["name"]), String(plugin["name"]), "marketplace entry name matches the plugin manifest name");
    // The description is what a user reads before installing. Milestone 6's
    // whole product boundary is that this is optional, so it has to say so.
    assert.match(String(plugins[0]["description"]), /optional/i, "marketplace description states the integration is optional");
    assert.ok(!("skills" in plugin), "plugin manifest declares no component path overrides for skills (plugin.json has no 'skills' field in the documented schema; declaring one would be silently ignored)");
});
test("plugin package: the generated skills mirror", () => {
    const mirrorRoot = join(REPO_ROOT, "skills");
    assert.ok(existsSync(mirrorRoot), "the packaged skills mirror exists at the plugin root");
    const dirNames = (root) => readdirSync(root).filter((e) => statSync(join(root, e)).isDirectory()).sort();
    const sourceSkills = dirNames(join(REPO_ROOT, ".claude/skills"));
    const mirrorSkills = dirNames(mirrorRoot);
    assert.equal(mirrorSkills.join(","), sourceSkills.join(","), `the mirror carries every skill and no others (source=${sourceSkills.join(",")} mirror=${mirrorSkills.join(",")})`);
    // The skill manifest is the framework's own declaration of its active
    // runtime. If it and the package disagree, one of them is lying to somebody.
    const manifest = readJson(join(REPO_ROOT, "pmo-config/skill-manifest.json"));
    const manifestSkills = (manifest["active_skills"] ?? [])
        .map((s) => String(s["id"])).sort();
    assert.ok(manifestSkills.length > 0, "the skill manifest lists the skills it is supposed to (skill-manifest.json active_skills[].id parsed as empty)");
    const unlisted = mirrorSkills.filter((s) => !manifestSkills.includes(s));
    assert.equal(unlisted.length, 0, `every packaged skill is one the skill manifest declares active (unlisted=${unlisted.join(",")})`);
    const unpackaged = manifestSkills.filter((s) => !mirrorSkills.includes(s));
    assert.equal(unpackaged.length, 0, `every active skill in the manifest is packaged (unpackaged=${unpackaged.join(",")})`);
    for (const skill of mirrorSkills) {
        const skillFile = join(mirrorRoot, skill, "SKILL.md");
        if (!existsSync(skillFile)) {
            assert.fail(`packaged skill '${skill}' has a SKILL.md`);
            continue;
        }
        const text = readFileSync(skillFile, "utf8");
        assert.match(text, /^---\s*\r?\n[\s\S]*?^name:\s*\S+[\s\S]*?^description:\s*\S+[\s\S]*?^---\s*$/m, `packaged skill '${skill}' declares name and description frontmatter`);
    }
});
test("plugin package: ownership registry", () => {
    // Ownership is decided by matching a block's body against bodies the
    // framework generates, so the registry of those bodies is load-bearing. If
    // the canonical body is edited without its digest being recorded, every
    // block already installed in a user's repository silently stops being
    // recognised as ours and uninstall starts refusing. That makes this a test
    // failure instead.
    const canonicalBody = getAxiomCanonicalBody("1");
    assert.ok(canonicalBody.trim().length > 0, "the canonical block body is available from the library");
    // A present block with no recorded digest is 'owned' exactly when its
    // computed digest is in the frozen KNOWN_BODY_DIGESTS -- the direct
    // membership check the PS original performs with
    // $script:AxiomKnownBodyDigests -contains. If the body was edited without
    // its digest being recorded, every installed block stops being recognised
    // as ours and uninstall starts refusing; that makes this a test failure.
    const canonicalDigest = getAxiomBlockDigest(canonicalBody);
    assert.ok(KNOWN_BODY_DIGESTS.includes(canonicalDigest), `the current canonical body's digest is in the frozen registry (computed=${canonicalDigest} -- if the body was edited, append this digest to KNOWN_BODY_DIGESTS rather than replacing the existing entry)`);
    assert.ok(KNOWN_BODY_DIGESTS.length >= 1, "the registry keeps every historical digest, never just the current one");
    // The body is the framework speaking to an agent on every session; it must
    // not grant anything, and the packaging suite is a reasonable second place
    // to say so.
    assert.match(canonicalBody, /may not approve your own work/i, "the canonical body states the agent may not approve its own work");
    assert.match(canonicalBody, /does not enforce|nothing here prevents/i, "the canonical body states it does not enforce scope");
});
test("plugin package: the drift gate", () => {
    const sandbox = mkdtempSync(join(tmpdir(), "axiom-pkg-"));
    let copyN = 0;
    try {
        const committed = buildPluginPackage(REPO_ROOT, true);
        assert.equal(committed.exitCode, 0, `the drift check passes against the committed mirror: ${committed.output}`);
        // A disposable copy of the repository, so drift cases can mutate the
        // mirror without touching the working tree. The PS original copies
        // scripts/build-plugin-package.ps1 alongside .claude/skills; in-process
        // buildPluginPackage reads only .claude/skills, so that is all the copy
        // carries -- itself an implicit assertion about what it depends on.
        const newRepoCopy = () => {
            const copy = join(sandbox, `repo-${++copyN}`);
            cpSync(join(REPO_ROOT, ".claude/skills"), join(copy, ".claude/skills"), { recursive: true });
            return copy;
        };
        // 1. Content drift -- a skill edited in source but not regenerated.
        let copy = newRepoCopy();
        buildPluginPackage(copy, false);
        writeFileSync(join(copy, ".claude/skills/pmo-intake/SKILL.md"), readFileSync(join(copy, ".claude/skills/pmo-intake/SKILL.md"), "utf8") + "\n<!-- edited after packaging -->", "utf8");
        let drift = buildPluginPackage(copy, true);
        assert.ok(drift.exitCode !== 0 && /content differs/.test(drift.output), `drift gate catches a source skill edited after packaging: ${drift.output}`);
        // 2. Addition drift -- a new skill that never reached the package.
        copy = newRepoCopy();
        buildPluginPackage(copy, false);
        mkdirSync(join(copy, ".claude/skills/pmo-newcomer"), { recursive: true });
        writeFileSync(join(copy, ".claude/skills/pmo-newcomer/SKILL.md"), "---\nname: pmo-newcomer\ndescription: x\n---", "utf8");
        drift = buildPluginPackage(copy, true);
        assert.ok(drift.exitCode !== 0 && /missing from skills\//.test(drift.output), `drift gate catches a new source skill missing from the package: ${drift.output}`);
        // 3. Removal drift -- the stale-after-rename case, which is the one a
        //    convention-based mirror always eventually gets wrong.
        copy = newRepoCopy();
        buildPluginPackage(copy, false);
        rmSync(join(copy, ".claude/skills/pmo-design"), { recursive: true, force: true });
        drift = buildPluginPackage(copy, true);
        assert.ok(drift.exitCode !== 0 && /not in \.claude\/skills/.test(drift.output), `drift gate catches a package skill whose source was deleted: ${drift.output}`);
        // 4. Tampering with the package directly, source untouched.
        copy = newRepoCopy();
        buildPluginPackage(copy, false);
        writeFileSync(join(copy, "skills/pmo-governance/SKILL.md"), readFileSync(join(copy, "skills/pmo-governance/SKILL.md"), "utf8") + "\n<!-- packaged copy edited by hand -->", "utf8");
        drift = buildPluginPackage(copy, true);
        assert.ok(drift.exitCode !== 0 && /content differs/.test(drift.output), `drift gate catches an edit made to the package instead of the source: ${drift.output}`);
        // 5. Rebuilding fixes every one of them, and is deterministic.
        copy = newRepoCopy();
        buildPluginPackage(copy, false);
        rmSync(join(copy, "skills/pmo-design"), { recursive: true, force: true });
        writeFileSync(join(copy, "skills/pmo-intake/SKILL.md"), readFileSync(join(copy, "skills/pmo-intake/SKILL.md"), "utf8") + "\nnoise", "utf8");
        buildPluginPackage(copy, false);
        drift = buildPluginPackage(copy, true);
        assert.equal(drift.exitCode, 0, `regenerating restores the mirror exactly: ${drift.output}`);
        // 6. The generator does not reach outside the source directory.
        copy = newRepoCopy();
        writeFileSync(join(copy, "SHOULD-NOT-BE-PACKAGED.md"), "maintainer file", "utf8");
        buildPluginPackage(copy, false);
        assert.ok(!existsSync(join(copy, "skills/SHOULD-NOT-BE-PACKAGED.md")), "the generator packages only .claude/skills, nothing from the repository root");
    }
    finally {
        rmSync(sandbox, { recursive: true, force: true });
    }
});
test("plugin package: FRAMEWORK-001 guard outside a checkout", () => {
    const fakeRoot = mkdtempSync(join(tmpdir(), "axiom-nocheckout-"));
    try {
        // The other half of M6.2's finding: maintainer tools correctly do not run
        // outside a checkout, and must say so rather than throwing. The PS
        // original builds a fake root carrying scripts/lib/framework-checkout.ps1
        // and a probe.ps1 that dot-sources it, then runs it as a child process.
        // In-process, the guard is testFrameworkCheckout + the message it hands a
        // failing tool, and "never reaches the tool body" is a real maintainer
        // tool (pmo-doctor) returning no body rows.
        // A maintainer tool outside a checkout exits non-zero (fail count 1, no
        // body executed).
        const doctor = runPmoDoctor(fakeRoot);
        assert.ok(doctor.fail > 0, "a maintainer tool outside a checkout exits non-zero");
        const msg = frameworkCheckoutFailureMessage(fakeRoot, "probe-tool");
        assert.ok(/FRAMEWORK-001/.test(msg) && /probe-tool/.test(msg), "...with a FRAMEWORK-001 diagnostic naming the tool");
        assert.match(msg, /plugin install/i, "...explaining why a plugin install cannot satisfy it");
        assert.equal(doctor.rows.length, 0, "...and it never reaches the tool body");
        assert.equal(testFrameworkCheckout(REPO_ROOT), true, "the guard recognises this repository as a real checkout");
    }
    finally {
        rmSync(fakeRoot, { recursive: true, force: true });
    }
});
test("plugin package: release-check catches plugin-manifest version drift", () => {
    const releaseCheckRoot = mkdtempSync(join(tmpdir(), "axiom-relcheck-"));
    try {
        // A release candidate whose plugin manifest disagrees with VERSION must be
        // caught by prepare-public-release -- the one script whose job is catching
        // exactly that -- not just by this suite. The PS original exercises this
        // against a full filesystem copy because the release-check script asserts
        // it runs inside a real framework checkout (VERSION + AGENTS.md). The
        // in-process port reads only VERSION, CHANGELOG.md, pmo-config/ and
        // .claude-plugin/, so the copy carries exactly those.
        mkdirSync(join(releaseCheckRoot, "pmo-config"), { recursive: true });
        mkdirSync(join(releaseCheckRoot, ".claude-plugin"), { recursive: true });
        cpSync(join(REPO_ROOT, "pmo-config"), join(releaseCheckRoot, "pmo-config"), { recursive: true });
        cpSync(join(REPO_ROOT, ".claude-plugin"), join(releaseCheckRoot, ".claude-plugin"), { recursive: true });
        for (const f of ["VERSION", "CHANGELOG.md", "AGENTS.md"]) {
            cpSync(join(REPO_ROOT, f), join(releaseCheckRoot, f));
        }
        const manifestPath = join(releaseCheckRoot, ".claude-plugin/plugin.json");
        const manifest = readJson(manifestPath);
        manifest["version"] = "9.9.9";
        writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n", "utf8");
        const result = preparePublicRelease(releaseCheckRoot, false);
        assert.match(result.output, /version drift/i, "the release check reports version drift when plugin.json disagrees with VERSION");
        assert.match(result.output, /PLUGIN=9\.9\.9/, "...and names the plugin manifest specifically, not just VERSION/CHANGELOG/config");
    }
    finally {
        rmSync(releaseCheckRoot, { recursive: true, force: true });
    }
});
