// `new-project`, ported from scripts/new-project.ps1. Generates a project from
// templates, substituting the declared mode/path/research/ui fields. Stateful
// (writes files); verified by §8.6 fresh-tree.
import { readFileSync, writeFileSync, mkdirSync, existsSync, copyFileSync } from "node:fs";
import { join, resolve, isAbsolute } from "node:path";
import { runPortedChain } from "../probe/validate-chain.js";
import { writeValidationOutput } from "../core/result-writer.js";
import { DIAGNOSTICS_SCHEMA_VERSION } from "../core/types.js";
function isoDate(d) {
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
// PowerShell Set-Content appends a trailing newline; replicate so generated
// files are byte-identical to the reference generator.
function psWrite(path, content) {
    writeFileSync(path, content + "\n", "utf8");
}
export function newProject(repoRoot, projectCode, mode, executionPath, researchMode, researchDepth, researchProvider, uiDelivery, strictTrigger, modeReason, modeApprovedBy, outputRoot, includeHandoff, target, horizonDays, specDepth = "legacy") {
    const repo = resolve(repoRoot);
    const targetRoot = isAbsolute(outputRoot) ? outputRoot : join(repo, outputRoot);
    const projectDir = join(targetRoot, projectCode);
    const today = isoDate(new Date());
    if (existsSync(projectDir))
        return { output: `Project already exists: ${projectDir}\n`, exitCode: 1 };
    mkdirSync(join(projectDir, "source/REQ"), { recursive: true });
    mkdirSync(join(projectDir, "source/MOM"), { recursive: true });
    mkdirSync(join(projectDir, "source/Transcript"), { recursive: true });
    copyFileSync(join(repo, "templates/PROJECT.md"), join(projectDir, "PROJECT.md"));
    copyFileSync(join(repo, "templates/DELIVERY.md"), join(projectDir, "DELIVERY.md"));
    let projectText = readFileSync(join(projectDir, "PROJECT.md"), "utf8")
        .replaceAll("<PROJECT-CODE>", projectCode)
        .replace("Lite / Standard / Strict", mode)
        .replace("development_handoff / governed_ai_execution", executionPath)
        .replace("off / guided / auto", researchMode)
        .replace("quick / standard / deep", researchDepth)
        .replace("none / feyman / web / auto", researchProvider)
        .replace("not_applicable / dev_guided / claude_design", uiDelivery)
        .replace("legacy / full", specDepth)
        .replaceAll("<YYYY-MM-DD>", today)
        .replaceAll("YYYY-MM-DD", today);
    psWrite(join(projectDir, "PROJECT.md"), projectText);
    let deliveryText = readFileSync(join(projectDir, "DELIVERY.md"), "utf8")
        .replaceAll("<PROJECT-CODE>", projectCode)
        .replace("Lite / Standard / Strict", mode);
    const defaultDesignRef = mode === "Lite" ? "not_required" : "DESIGN/BUILD-SPEC.md";
    deliveryText = deliveryText.replace(/\| D-001 \| Standard \| none \| normal feature \| PM \| <feature> \| REQ-001 \| DESIGN\/FLOW\.puml \|/, `| D-001 | ${mode} | ${strictTrigger} | ${modeReason} | ${modeApprovedBy} | <feature> | REQ-001 | ${defaultDesignRef} |`);
    psWrite(join(projectDir, "DELIVERY.md"), deliveryText);
    const copyTemplate = (src, dest) => {
        psWrite(dest, readFileSync(src, "utf8").replaceAll("<PROJECT-CODE>", projectCode));
    };
    if (mode !== "Lite") {
        mkdirSync(join(projectDir, "DESIGN"), { recursive: true });
        copyTemplate(join(repo, "templates/RELEASE.md"), join(projectDir, "RELEASE.md"));
        copyTemplate(join(repo, "templates/BUILD-SPEC.md"), join(projectDir, "DESIGN/BUILD-SPEC.md"));
    }
    if (mode !== "Lite" && uiDelivery !== "not_applicable") {
        copyTemplate(join(repo, "templates/WIREFRAME.md"), join(projectDir, "DESIGN/WIREFRAME.md"));
        psWrite(join(projectDir, "DESIGN/FLOW.puml"), `@startuml\nstart\n:Define ${projectCode} flow;\nstop\n@enduml`);
    }
    if (uiDelivery === "claude_design") {
        mkdirSync(join(projectDir, "DESIGN/CLAUDE-DESIGN/OUTPUT"), { recursive: true });
        copyTemplate(join(repo, "templates/DESIGN-PROVIDER-INPUT.json"), join(projectDir, "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json"));
        copyTemplate(join(repo, "templates/DESIGN-PROVIDER-REVIEW.json"), join(projectDir, "DESIGN/CLAUDE-DESIGN/REVIEW.json"));
    }
    if (mode === "Strict") {
        copyTemplate(join(repo, "templates/RAID-log.md"), join(projectDir, "RAID-log.md"));
        copyTemplate(join(repo, "templates/decision-log.md"), join(projectDir, "decision-log.md"));
        copyTemplate(join(repo, "templates/RTM.json"), join(projectDir, "RTM.json"));
    }
    if (includeHandoff) {
        const horizon = isoDate(new Date(Date.now() + horizonDays * 86400000));
        const handoffText = readFileSync(join(repo, "templates/HANDOFF.md"), "utf8")
            .replaceAll("<PROJECT-CODE>", projectCode)
            .replace("- Mode: <Lite | Standard | Strict>", `- Mode: ${mode}`)
            .replace("- Handoff Target: <demo | pilot | production | internal>", `- Handoff Target: ${target}`)
            .replace("- Horizon: <YYYY-MM-DD>", `- Horizon: ${horizon}`);
        psWrite(join(projectDir, "HANDOFF.md"), handoffText);
        const reviewText = readFileSync(join(repo, "templates/HANDOFF-REVIEW.json"), "utf8")
            .replaceAll("<PROJECT-CODE>", projectCode)
            .replace('"handoff_target": "<demo | pilot | production | internal>"', `"handoff_target": "${target}"`);
        psWrite(join(projectDir, "HANDOFF-REVIEW.json"), reviewText);
    }
    // The reference runs validate-project.ps1 -Gate Draft as a child, so its
    // Text report streams straight into the caller's stdout between "Draft
    // validation:" and "Next actions:". The port must show the same report or
    // `axiom init` would silently drop the first gate's verdict from the output.
    const draft = runPortedChain(repo, projectDir, mode, "Draft");
    const draftExitCode = draft.accumulator.fail > 0 ? 1 : 0;
    const draftEnvelope = {
        schema_version: DIAGNOSTICS_SCHEMA_VERSION,
        project: projectDir,
        requested_mode: mode,
        effective_mode: draft.effectiveMode,
        gate: "Draft",
        summary: {
            pass: draft.accumulator.pass,
            warn: draft.accumulator.warn,
            warn_blocking: draft.accumulator.warnBlocking,
            fail: draft.accumulator.fail,
            exit_code: draftExitCode,
        },
        results: draft.diagnostics,
    };
    const draftReport = writeValidationOutput("Text", draftEnvelope, projectDir, mode, draft.effectiveMode, "Draft");
    const lines = [
        `Created ${mode} project (${executionPath}): ${projectDir}`,
        "",
        "Draft validation:",
        ...draftReport.split("\n"),
        "",
        "Next actions:",
        "1. Add source files under source/MOM, source/REQ, or source/Transcript.",
        `2. Record the source snapshot in PROJECT.md after adding sources.`,
        "3. Replace remaining draft placeholders before Scope/Release gates.",
    ];
    if (includeHandoff) {
        lines.push("4. Fill HANDOFF.md and DESIGN/BUILD-SPEC.md, then record the review:");
        lines.push(`   node cli/axiom.mjs validate --project ${projectDir} --mode ${mode} --gate Handoff`);
        lines.push(`   node cli/axiom.mjs handoff --project ${projectDir} --mode ${mode}`);
    }
    return { output: lines.join("\n") + "\n", exitCode: draftExitCode };
}
