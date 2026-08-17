// `axiom status`, ported from scripts/pmo-status.ps1. Read-only report derived
// from PROJECT.md + the validator's own output; never a second opinion.
import { readFileSync, existsSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import { importPmoConfig, getProjectOrchestrationDeclarations } from "../config/config-loader.js";
import { getProjectExecutionPath } from "../core/execution-path-validator.js";
import { getDesignInputCombinedDigest, getDesignOutputSetDigest } from "../rules/design-provider-validator.js";
import { runPortedChain } from "../probe/validate-chain.js";
function getProjectStatusLine(projectRoot) {
    const path = join(projectRoot, "PROJECT.md");
    if (!existsSync(path))
        return null;
    const m = /^\s*>?\s*Status:\s*(.+?)\s*$/m.exec(readFileSync(path, "utf8"));
    return m ? m[1].trim() : null;
}
const STATUS_TO_GATE = {
    draft: { current: "Draft", next: "Scope" },
    "scope-approved": { current: "Scope", next: "Design" },
    "design-ready": { current: "Design", next: "Handoff" },
    "release-approved": { current: "Release", next: null },
};
export function runPmoStatus(repoRoot, projectPath, format) {
    const project = resolve(projectPath);
    // The reference only rejects a missing *directory*; a directory without
    // PROJECT.md is a real project in a failed state and the validator's own
    // STRUCT-001 finding becomes the "next required" answer (governance_mode
    // stays Standard, exit 0 -- status never fails a build).
    if (!existsSync(project) || !statSync(project).isDirectory()) {
        return { output: `Project directory not found: ${projectPath}\n`, exitCode: 1 };
    }
    const rawStatus = getProjectStatusLine(project);
    const gateInfo = rawStatus && STATUS_TO_GATE[rawStatus] ? STATUS_TO_GATE[rawStatus] : STATUS_TO_GATE["draft"];
    const currentGate = gateInfo.current;
    const checkGate = gateInfo.next ?? gateInfo.current;
    const declaredPath = getProjectExecutionPath(project);
    const displayPath = declaredPath ?? "development_handoff";
    const orchestration = getProjectOrchestrationDeclarations(project);
    const researchMode = orchestration.researchMode ?? "off";
    const researchDepth = orchestration.researchDepth ?? "standard";
    const researchProvider = orchestration.researchProvider ?? "none";
    const uiDelivery = orchestration.uiDelivery ?? "legacy";
    let researchState = "off";
    if (researchMode !== "off") {
        const provPath = join(project, "RESEARCH/PROVENANCE.json");
        const reportPath = join(project, "RESEARCH/RESEARCH.md");
        if (!existsSync(provPath) || !existsSync(reportPath))
            researchState = "incomplete";
        else {
            try {
                const prov = JSON.parse(readFileSync(provPath, "utf8"));
                const rs = String(prov["research_status"] ?? "").trim();
                if (rs === "stopped")
                    researchState = "stopped";
                else if (rs === "complete")
                    researchState = "complete";
                else if (rs === "in_progress")
                    researchState = "in_progress";
                else
                    researchState = "incomplete";
            }
            catch {
                researchState = "incomplete";
            }
        }
    }
    let uiDeliveryState = "not_applicable";
    let providerReviewState = "missing";
    if (uiDelivery === "claude_design") {
        const manifestPath = join(project, "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json");
        const reviewPath = join(project, "DESIGN/CLAUDE-DESIGN/REVIEW.json");
        if (!existsSync(manifestPath))
            uiDeliveryState = "not_started";
        else {
            uiDeliveryState = "preparing";
            if (existsSync(reviewPath)) {
                try {
                    const review = JSON.parse(readFileSync(reviewPath, "utf8"));
                    const preflightPassed = review["preflight"] && String(review["preflight"]["status"]) === "passed";
                    let manifestCurrent = false;
                    let outputsCurrent = false;
                    try {
                        const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
                        const manifestDigest = getDesignInputCombinedDigest(manifest["inputs"] ?? []);
                        manifestCurrent = String(review["preflight"]?.["manifest_digest"] ?? "") === manifestDigest;
                        const outputRoot = join(project, "DESIGN/CLAUDE-DESIGN/OUTPUT");
                        outputsCurrent = String(review["preflight"]?.["outputs_digest"] ?? "") === getDesignOutputSetDigest(outputRoot);
                    }
                    catch { }
                    if (!preflightPassed)
                        providerReviewState = "failed";
                    else if (manifestCurrent && outputsCurrent)
                        providerReviewState = "current";
                    else
                        providerReviewState = "stale";
                    if (review["acceptance"] && String(review["acceptance"]["decision"] ?? "").trim())
                        uiDeliveryState = String(review["acceptance"]["decision"]).trim();
                    else
                        uiDeliveryState = "awaiting_review";
                }
                catch {
                    uiDeliveryState = "invalid_review";
                }
            }
        }
    }
    let openGovernedChanges = 0;
    const crPath = join(project, "CHANGE-REQUESTS.json");
    if (existsSync(crPath)) {
        try {
            const crDoc = JSON.parse(readFileSync(crPath, "utf8"));
            openGovernedChanges = (crDoc["changes"] ?? []).filter((c) => ["proposed", "approved"].includes(String(c["status"] ?? ""))).length;
        }
        catch {
            openGovernedChanges = -1;
        }
    }
    // The reference runs validate-project.ps1 WITHOUT -Mode (defaults to
    // Standard), so mode-resolver escalates to the project's real effective
    // mode from DELIVERY.md/PROJECT.md. The chain does the same internally;
    // runPortedChain reports the mode it enforced.
    const result = runPortedChain(repoRoot, project, "Standard", checkGate);
    const results = result.diagnostics;
    let nextFinding = null;
    const blockingFail = results.find((r) => r.level === "FAIL" && r.blocking);
    if (blockingFail)
        nextFinding = blockingFail;
    else
        nextFinding = results.find((r) => r.level === "WARN" && r.blocking) ?? null;
    let nextAction = null;
    if (researchMode !== "off") {
        if (researchState === "incomplete" || researchState === "in_progress")
            nextAction = "Human: complete or stop guided research before Scope approval";
        else if (researchState === "stopped")
            nextAction = "Human: decide the stopped research outcome or turn research off";
    }
    if (!nextAction && uiDelivery === "claude_design") {
        if (uiDeliveryState === "preparing")
            nextAction = "Human: run Claude Design and return candidate output to DESIGN/CLAUDE-DESIGN/OUTPUT";
        else if (uiDeliveryState === "awaiting_review")
            nextAction = "Human: record provider preflight and acceptance in DESIGN/CLAUDE-DESIGN/REVIEW.json";
        else if (uiDeliveryState === "revision_required")
            nextAction = "Human: return revised output to the provider and re-run the preflight";
        else if (uiDeliveryState === "rejected")
            nextAction = "Human: decide how to proceed after the rejected provider review";
        else if (uiDeliveryState === "accepted" && providerReviewState !== "current")
            nextAction = "Automated: re-run the deterministic preflight; the recorded review is stale";
    }
    if (!nextAction && openGovernedChanges > 0)
        nextAction = `Human: resolve ${openGovernedChanges} open governed change(s) before the next gate`;
    if (!nextAction && nextFinding)
        nextAction = `Automated: resolve blocking diagnostic ${nextFinding.rule_id} before ${checkGate}`;
    if (!nextAction && checkGate)
        nextAction = `Automated: run cli/axiom.mjs validate at the ${checkGate} gate`;
    const statusResult = {
        schema_version: "1.1",
        project,
        execution_path: displayPath,
        execution_path_declared: Boolean(declaredPath),
        governance_mode: result.effectiveMode,
        research_mode: researchMode,
        research_depth: researchDepth,
        research_provider: researchProvider,
        research_state: researchState,
        ui_delivery: uiDelivery,
        ui_delivery_state: uiDeliveryState,
        provider_review_state: providerReviewState,
        open_governed_changes: openGovernedChanges,
        current_gate: currentGate,
        checked_gate: checkGate,
        next_action: nextAction,
        next_required: nextFinding,
    };
    if (format === "Json") {
        return { output: JSON.stringify(statusResult, null, 2) + "\n", exitCode: 0 };
    }
    const lines = [];
    lines.push(`Axiom-PMO Project Status: ${project}`);
    lines.push("");
    const pathSuffix = declaredPath ? "" : " (default, not declared)";
    lines.push(`Execution Path:  ${displayPath}${pathSuffix}`);
    lines.push(`Governance Mode: ${result.effectiveMode}`);
    lines.push(`Research:        ${researchMode} (${researchDepth}, ${researchProvider}) - ${researchState}`);
    lines.push(`UI Delivery:     ${uiDelivery} - ${uiDeliveryState} (provider review: ${providerReviewState})`);
    lines.push(`Open Changes:    ${openGovernedChanges}`);
    lines.push(`Current Gate:    ${currentGate}`);
    if (nextAction)
        lines.push(`Next action:     ${nextAction}`);
    lines.push("");
    if (nextFinding) {
        lines.push(`Next required:   ${nextFinding.message}  [${nextFinding.rule_id}]`);
        if (nextFinding.suggestion)
            lines.push(`                 fix: ${nextFinding.suggestion}`);
    }
    else {
        lines.push(`Next required:   No blocking findings at the ${checkGate} gate.`);
    }
    return { output: lines.join("\n") + "\n", exitCode: 0 };
}
