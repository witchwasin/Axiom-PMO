// Report-only scope advisory, ported from scripts/hook-scope-advisory.ps1.
// Reuses the real scope-diff matcher. Never emits a permission decision; always
// degrades to silence on any failure.
import { readFileSync, existsSync } from "node:fs";
import { join, resolve, isAbsolute } from "node:path";
import { readScopeDeclaration, readScopeDiffPolicy, resolveScopeVerdict, convertToScopeGlobRegex } from "../rules/scope-diff-matcher.js";
export function hookScopeAdvisory(projectPath, payloadText) {
    const silent = { output: "", exitCode: 0 };
    try {
        if (!payloadText?.trim())
            return silent;
        let payload;
        try {
            payload = JSON.parse(payloadText);
        }
        catch {
            return silent;
        }
        if (!payload)
            return silent;
        const toolInput = payload["tool_input"];
        if (!toolInput)
            return silent;
        const candidatePaths = [];
        for (const field of ["file_path", "path", "notebook_path"]) {
            const value = toolInput[field];
            if (value && typeof value === "string")
                candidatePaths.push(value);
        }
        if (candidatePaths.length === 0)
            return silent;
        let project = projectPath ?? payload["cwd"] ?? process.cwd();
        if (!existsSync(project))
            return silent;
        const resolvedProject = resolve(project);
        const optInPath = join(resolvedProject, ".axiom/hooks.json");
        if (!existsSync(optInPath))
            return silent;
        let optIn;
        try {
            optIn = JSON.parse(readFileSync(optInPath, "utf8"));
        }
        catch {
            return silent;
        }
        if (!optIn || optIn["scope_advisory"] !== true)
            return silent;
        const declaration = readScopeDeclaration(resolvedProject);
        if (!declaration.present || !declaration.valid)
            return silent;
        const includeRegexes = declaration.include.map((p) => new RegExp(convertToScopeGlobRegex(p)));
        const excludeRegexes = declaration.exclude.map((p) => new RegExp(convertToScopeGlobRegex(p)));
        const frameworkRoot = resolve(process.cwd());
        const exemptEntries = readScopeDiffPolicy(frameworkRoot).map((e) => ({ regex: new RegExp(convertToScopeGlobRegex(e.pattern)), reason: e.reason }));
        const findings = [];
        for (const candidate of candidatePaths) {
            let relative = candidate;
            try {
                const full = resolve(isAbsolute(candidate) ? candidate : join(resolvedProject, candidate));
                const projectFull = resolve(resolvedProject);
                const normalisedProject = projectFull.replace(/[/\\]+$/, "") + "/";
                if (full.startsWith(normalisedProject)) {
                    relative = full.substring(normalisedProject.length);
                }
                else {
                    continue; // outside project — nothing to say
                }
            }
            catch {
                continue;
            }
            relative = relative.replace(/\\/g, "/");
            const verdict = resolveScopeVerdict(relative, includeRegexes, excludeRegexes, exemptEntries);
            if (verdict.verdict === "out_of_scope")
                findings.push(relative);
        }
        if (findings.length === 0)
            return silent;
        const lines = [
            "Axiom-PMO scope advisory (report-only -- nothing is blocked):",
            ...findings.map((f) => `  - ${f} is outside this project's approved implementation_scope`),
            "",
            "This is a note, not a decision and not evidence. If the change is correct, the",
            "scope needs a recorded change; if it is not, it is worth reconsidering now rather",
            "than at review. SCOPE-DIFF checks this for real at the pull request.",
        ];
        return { output: JSON.stringify({ systemMessage: lines.join("\n") }) + "\n", exitCode: 0 };
    }
    catch {
        return silent;
    }
}
