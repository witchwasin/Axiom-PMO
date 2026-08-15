// Digest tools (design-provider-digest, handoff-digest, visual-proof-digest),
// ported from scripts/*-digest.ps1. Node entrypoints that print the digests a
// review/manifest must record, reusing the already-ported digest functions.
import { readFileSync, existsSync, statSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { importPmoConfig } from "../config/config-loader.js";
import { getSourceSnapshotDigest, getReviewInputDigest } from "../rules/handoff-validator.js";
import { getVisualProofReviewInputDigest, testVisualProofActivated } from "../rules/visual-proof-validator.js";
import { getDesignInputCombinedDigest, getDesignOutputSetDigest } from "../rules/design-provider-validator.js";
import { getArtifactSha256 } from "../digest/artifact-hash.js";
export function designProviderDigest(repoRoot, projectPath) {
    const project = resolve(projectPath);
    const cfg = importPmoConfig(repoRoot);
    const orchestrationPolicy = cfg.orchestrationPolicy;
    const manifestPath = join(project, String((orchestrationPolicy["ui_delivery"] ?? {})["input_manifest"] ?? "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json"));
    if (!existsSync(manifestPath))
        return { output: `No input manifest found: ${manifestPath}\n`, exitCode: 1 };
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    const inputs = manifest["inputs"] ?? [];
    const lines = [];
    const currentInputs = [];
    for (const input of inputs) {
        const relative = String(input["path"] ?? "");
        const full = join(project, relative);
        const hash = existsSync(full) ? getArtifactSha256(full) : "MISSING";
        lines.push(`input: ${relative} -> ${hash}`);
        currentInputs.push({ path: relative, sha256: hash });
    }
    lines.push(`combined_digest: ${getDesignInputCombinedDigest(currentInputs)}`);
    const outputRoot = join(project, String((orchestrationPolicy["ui_delivery"] ?? {})["output_root"] ?? "DESIGN/CLAUDE-DESIGN/OUTPUT"));
    lines.push(`outputs_digest: ${getDesignOutputSetDigest(outputRoot)}`);
    if (existsSync(outputRoot)) {
        const files = [];
        const walk = (dir) => {
            for (const entry of readdirSync(dir)) {
                const full = join(dir, entry);
                if (statSync(full).isDirectory())
                    walk(full);
                else if (statSync(full).isFile())
                    files.push(full);
            }
        };
        walk(outputRoot);
        files.sort();
        for (const file of files) {
            const relative = file.substring(outputRoot.length).replace(/^[/\\]/, "").replace(/\\/g, "/");
            lines.push(`output: ${relative} -> ${getArtifactSha256(file)}`);
        }
    }
    return { output: lines.join("\n") + "\n", exitCode: 0 };
}
export function handoffDigest(repoRoot, projectPath, which = "Both") {
    const project = resolve(projectPath);
    const projectFile = join(project, "PROJECT.md");
    if (!existsSync(projectFile))
        return { output: `No PROJECT.md found: ${projectFile}\n`, exitCode: 1 };
    const cfg = importPmoConfig(repoRoot);
    const handoffPolicy = cfg.handoffPolicy;
    const sourceDigest = getSourceSnapshotDigest(readFileSync(projectFile, "utf8"));
    if (!sourceDigest)
        return { output: "PROJECT.md has no Source Snapshot or Source Inventory table to digest.\n", exitCode: 1 };
    const inputDigest = getReviewInputDigest(project, handoffPolicy);
    if (which === "Source")
        return { output: sourceDigest + "\n", exitCode: 0 };
    if (which === "ReviewInputs")
        return { output: (inputDigest ?? "") + "\n", exitCode: 0 };
    return { output: `source_snapshot.digest : ${sourceDigest}\nreview_inputs.digest   : ${inputDigest}\n`, exitCode: 0 };
}
export function visualProofDigest(repoRoot, projectPath) {
    const project = resolve(projectPath);
    const cfg = importPmoConfig(repoRoot);
    const proof = cfg.handoffPolicy["visual_proof"] ?? null;
    if (!proof)
        return { output: "handoff-policy.json has no visual_proof policy.\n", exitCode: 1 };
    if (!testVisualProofActivated(project, proof))
        return { output: "Visual Proof is inactive: the project does not contain all configured creative artifacts.\n", exitCode: 1 };
    return { output: getVisualProofReviewInputDigest(project, proof) + "\n", exitCode: 0 };
}
