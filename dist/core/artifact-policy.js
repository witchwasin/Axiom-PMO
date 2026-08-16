// File/directory presence checks and the Mode x Gate artifact matrix, ported
// from scripts/lib/artifact-policy.ps1.
import { readFileSync, existsSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { addResult } from "./result-writer.js";
function testFile(acc, catalog, project, relativePath, requirement) {
    const path = join(project, relativePath);
    if (existsSync(path) && statSync(path).isFile()) {
        addResult(acc, catalog, "PASS", `Found ${relativePath}`, { ruleId: "STRUCT-001" });
        return true;
    }
    if (requirement === "required") {
        addResult(acc, catalog, "FAIL", `Missing ${relativePath}`, { ruleId: "STRUCT-001" });
    }
    else {
        addResult(acc, catalog, "INFO", `Missing optional file ${relativePath}`, { ruleId: "STRUCT-001" });
    }
    return false;
}
function testDir(acc, catalog, project, relativePath, requirement) {
    const path = join(project, relativePath);
    if (existsSync(path) && statSync(path).isDirectory()) {
        addResult(acc, catalog, "PASS", `Found ${relativePath}/`, { ruleId: "STRUCT-001" });
        return true;
    }
    if (requirement === "required") {
        addResult(acc, catalog, "FAIL", `Missing ${relativePath}/`, { ruleId: "STRUCT-001" });
    }
    else {
        addResult(acc, catalog, "INFO", `Missing optional directory ${relativePath}/`, { ruleId: "STRUCT-001" });
    }
    return false;
}
export function getProjectText(project) {
    const path = join(project, "PROJECT.md");
    if (existsSync(path))
        return readFileSync(path, "utf8");
    return "";
}
function isUserSourcePath(relativePath) {
    // Port of Test-UserSourcePath's core: source/, MOM/, REQ/, Transcript/, Others/.
    return /(^|[\\/])(source|MOM|REQ|Transcript|Others)[\\/]/.test(relativePath);
}
const TEXT_EXTENSIONS = [".md", ".yaml", ".yml", ".puml", ".html"];
// PowerShell's Get-ChildItem -Recurse -File emits each directory's files in
// case-insensitive name order, then recurses into the subdirectories in the
// same order. readdirSync returns the raw directory order, which differs per
// host/filesystem, so we replicate the reference enumeration explicitly -- the
// file order is observable in messages like PLACEHOLDER-001's file list.
function psEnumOrder(a, b) {
    const al = a.toLowerCase();
    const bl = b.toLowerCase();
    if (al < bl)
        return -1;
    if (al > bl)
        return 1;
    return a < b ? -1 : a > b ? 1 : 0;
}
export function getProjectFileSets(project) {
    const allProjectFiles = [];
    const walk = (dir) => {
        const entries = readdirSync(dir).sort(psEnumOrder);
        const subdirs = [];
        for (const entry of entries) {
            const full = join(dir, entry);
            let st;
            try {
                st = statSync(full);
            }
            catch {
                continue;
            }
            if (st.isDirectory())
                subdirs.push(full);
            else if (st.isFile())
                allProjectFiles.push(full);
        }
        for (const sub of subdirs)
            walk(sub);
    };
    walk(project);
    const allTextFiles = allProjectFiles.filter((f) => TEXT_EXTENSIONS.some((e) => f.toLowerCase().endsWith(e)));
    const governedFiles = [];
    const userSourceFiles = [];
    for (const f of allTextFiles) {
        const rel = relative(project, f);
        if (isUserSourcePath(rel))
            userSourceFiles.push(f);
        else
            governedFiles.push(f);
    }
    return { allProjectFiles, allTextFiles, governedFiles, userSourceFiles };
}
export function testRequiredArtifacts(acc, catalog, project, mode, gate, artifactPolicy, taskSourceIsGithub) {
    testFile(acc, catalog, project, "PROJECT.md", "required");
    const matrixRequired = [];
    const modeMatrix = artifactPolicy["artifact_matrix"]?.[mode];
    if (modeMatrix?.[gate]) {
        matrixRequired.push(...modeMatrix[gate]);
    }
    const deliveryOptionalViaGithub = taskSourceIsGithub && matrixRequired.includes("DELIVERY.md");
    const allTrackedArtifacts = ["DELIVERY.md", "RELEASE.md", "RAID-log.md", "decision-log.md", "DESIGN", "RTM.json", "HANDOFF.md", "DESIGN/BUILD-SPEC.md"];
    for (const artifact of allTrackedArtifacts) {
        let requirement = matrixRequired.includes(artifact) ? "required" : "optional";
        if (artifact === "DELIVERY.md" && deliveryOptionalViaGithub)
            requirement = "optional";
        if ((artifact === "HANDOFF.md" || artifact === "DESIGN/BUILD-SPEC.md") && requirement === "optional")
            continue;
        if (artifact === "DESIGN") {
            testDir(acc, catalog, project, "DESIGN", requirement);
        }
        else {
            testFile(acc, catalog, project, artifact, requirement);
        }
    }
    testDir(acc, catalog, project, "source", "optional");
    if (deliveryOptionalViaGithub && !existsSync(join(project, "DELIVERY.md"))) {
        addResult(acc, catalog, "WARN", "Task source is GitHub Issues; DELIVERY.md is absent, so work-item completion cannot be verified offline (check the GitHub board / CI)", { ruleId: "TASK-003", blocking: false });
    }
}
export function testGithubTaskSource(project) {
    const path = join(project, "PROJECT.md");
    if (!existsSync(path))
        return false;
    const text = readFileSync(path, "utf8");
    const isGithub = /^[ \t]*>?[ \t]*Task source:[ \t]*github[ \t]*\r?$/m.test(text);
    const hasRepo = /^[ \t]*github_repository:[ \t]*\S+/m.test(text);
    return isGithub && hasRepo;
}
