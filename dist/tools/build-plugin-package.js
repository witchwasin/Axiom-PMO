// `build-plugin-package`, ported from scripts/build-plugin-package.ps1. Generates
// (or checks) the skills/ mirror of .claude/skills/.
import { readFileSync, writeFileSync, existsSync, statSync, readdirSync, mkdirSync, rmSync, copyFileSync } from "node:fs";
import { join, resolve, dirname } from "node:path";
import { createHash } from "node:crypto";
function sha256(buf) {
    return createHash("sha256").update(buf).digest("hex").toLowerCase();
}
function getSkillFileMap(root) {
    const map = {};
    if (!existsSync(root))
        return map;
    const walk = (dir) => {
        for (const entry of readdirSync(dir)) {
            const full = join(dir, entry);
            if (statSync(full).isDirectory())
                walk(full);
            else if (statSync(full).isFile()) {
                const relative = full.substring(root.length).replace(/^[/\\]/, "").replace(/\\/g, "/");
                map[relative] = sha256(readFileSync(full));
            }
        }
    };
    walk(root);
    return map;
}
export function buildPluginPackage(repoRoot, check) {
    const repo = resolve(repoRoot);
    const sourceRoot = join(repo, ".claude/skills");
    const mirrorRoot = join(repo, "skills");
    if (!existsSync(sourceRoot))
        return { output: "[FAIL] PLUGIN-PKG-001 Source skills directory not found: .claude/skills\n", exitCode: 1 };
    const source = getSkillFileMap(sourceRoot);
    const sourceKeys = Object.keys(source).sort();
    if (check) {
        const mirror = getSkillFileMap(mirrorRoot);
        const problems = [];
        for (const key of sourceKeys) {
            if (!(key in mirror))
                problems.push(`missing from skills/: ${key}`);
            else if (mirror[key] !== source[key])
                problems.push(`content differs: ${key}`);
        }
        for (const key of Object.keys(mirror)) {
            if (!(key in source))
                problems.push(`present in skills/ but not in .claude/skills/: ${key}`);
        }
        if (problems.length > 0) {
            return {
                output: "[FAIL] PLUGIN-PKG-002 The packaged skills mirror has drifted from .claude/skills/\n" +
                    problems.map((p) => `        - ${p}`).join("\n") + "\n\nSummary: PASS=0 FAIL=1\n",
                exitCode: 1,
            };
        }
        return { output: `[PASS] PLUGIN-PKG-002 Packaged skills mirror matches .claude/skills/ (${sourceKeys.length} files)\n\nSummary: PASS=1 FAIL=0\n`, exitCode: 0 };
    }
    if (existsSync(mirrorRoot))
        rmSync(mirrorRoot, { recursive: true, force: true });
    mkdirSync(mirrorRoot, { recursive: true });
    for (const relative of sourceKeys) {
        const target = join(mirrorRoot, relative);
        mkdirSync(dirname(target), { recursive: true });
        copyFileSync(join(sourceRoot, relative), target);
    }
    return { output: `Generated skills/ from .claude/skills/ (${sourceKeys.length} files).\nThis directory is generated. Edit .claude/skills/ and re-run this script.\n`, exitCode: 0 };
}
