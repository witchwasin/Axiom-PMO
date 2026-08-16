// `assess-handoff`, ported from scripts/assess-handoff.ps1. Reporting tool, not
// a gate: runs the Handoff gate, reads the semantic review, and answers
// "ready to start / integrate / demo / UAT / release" plus a capped score.
import { readFileSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { importPmoConfig } from "../config/config-loader.js";
import { getSourceSnapshotDigest, getReviewInputDigest, getHeadingPattern } from "../rules/handoff-validator.js";
import { getTableRowsAfterHeading } from "../markdown/table-parser.js";
import { runPortedChain } from "../probe/validate-chain.js";
export function runAssessHandoff(repoRoot, projectPath, mode, format) {
    const project = resolve(projectPath);
    const cfg = importPmoConfig(repoRoot);
    const handoffPolicy = cfg.handoffPolicy;
    const scorePolicy = handoffPolicy["score"] ?? {};
    const gateResult = runPortedChain(repoRoot, project, mode, "Handoff");
    const results = gateResult.diagnostics;
    const failures = results.filter((r) => r.level === "FAIL");
    const warnings = results.filter((r) => r.level === "WARN");
    const deterministicFail = failures.length > 0;
    const gateExitCode = failures.length > 0 ? 1 : warnings.some((w) => w.blocking) ? 2 : 0;
    const reviewPolicy = handoffPolicy["semantic_review"] ?? {};
    const reviewPath = join(project, String(reviewPolicy["artifact"]));
    const reviewPresent = existsSync(reviewPath);
    let review = null;
    if (reviewPresent) {
        try {
            review = JSON.parse(readFileSync(reviewPath, "utf8"));
        }
        catch {
            review = null;
        }
    }
    const projectFile = join(project, "PROJECT.md");
    const projectText = existsSync(projectFile) ? readFileSync(projectFile, "utf8") : "";
    const currentSourceDigest = getSourceSnapshotDigest(projectText);
    const currentInputDigest = getReviewInputDigest(project, handoffPolicy);
    const recordedSourceDigest = review ? String((review["source_snapshot"] ?? {})["digest"] ?? "").trim().toLowerCase() : "";
    const recordedInputDigest = review ? String((review["review_inputs"] ?? {})["digest"] ?? "").trim().toLowerCase() : "";
    const sourceStale = Boolean(review && currentSourceDigest && recordedSourceDigest && currentSourceDigest !== recordedSourceDigest);
    const inputStale = Boolean(review && currentInputDigest && recordedInputDigest && currentInputDigest !== recordedInputDigest);
    const reviewStale = sourceStale || inputStale;
    const reviewUsable = review !== null && !reviewStale && Boolean(recordedSourceDigest) && Boolean(recordedInputDigest);
    const openStatuses = reviewPolicy["closure_policy"]?.["open_statuses"] ?? [];
    const openFindings = review ? (review["findings"] ?? []).filter((f) => openStatuses.includes(String(f["status"]))) : [];
    const openActions = [];
    const handoffPath = join(project, "HANDOFF.md");
    if (existsSync(handoffPath)) {
        const handoffText = readFileSync(handoffPath, "utf8");
        for (const row of getTableRowsAfterHeading(handoffText, getHeadingPattern("Open Actions", 2))) {
            const status = String(row["Status"] ?? "").trim().toLowerCase();
            if (!openStatuses.includes(status))
                continue;
            openActions.push({
                finding_id: String(row["Action ID"] ?? "").trim(),
                severity: "action",
                blocking_point: String(row["Blocking Point"] ?? "").trim(),
                owner: String(row["Owner"] ?? "").trim(),
                artifact: "HANDOFF.md",
                origin: "open_action",
            });
        }
    }
    const findingIds = openFindings.map((f) => String(f["finding_id"] ?? "").trim());
    const findingItemIds = openFindings.map((f) => String(f["item_id"] ?? "").trim()).filter((id) => id !== "");
    const uniqueActions = openActions.filter((a) => !findingIds.includes(a.finding_id) && !findingItemIds.includes(a.finding_id));
    const allBlockers = [
        ...openFindings.map((f) => ({
            finding_id: String(f["finding_id"] ?? "").trim(),
            severity: String(f["severity"] ?? ""),
            blocking_point: String(f["blocking_point"] ?? ""),
            owner: String(f["owner"] ?? ""),
            artifact: String(f["artifact"] ?? ""),
            origin: "review_finding",
        })),
        ...uniqueActions,
    ];
    const stageBlockingMap = handoffPolicy["stage_blocking_map"] ?? {};
    const stageBlockers = {};
    for (const [stage, points] of Object.entries(stageBlockingMap)) {
        stageBlockers[stage] = allBlockers.filter((b) => points.includes(b.blocking_point));
    }
    const contractValid = !deterministicFail;
    function stageVerdict(stage) {
        if (!contractValid)
            return false;
        if ((stageBlockers[stage] ?? []).length > 0)
            return false;
        if (!reviewUsable)
            return null;
        return true;
    }
    function stageReason(stage) {
        if (!contractValid)
            return "blocked: the contract has deterministic failures";
        const blockers = stageBlockers[stage] ?? [];
        if (blockers.length > 0)
            return `blocked by ${blockers.map((b) => b.finding_id).join(", ")}`;
        if (!reviewUsable) {
            if (review === null)
                return "unknown: no semantic review has been recorded";
            if (reviewStale)
                return "unknown: the semantic review is stale";
            return "unknown: the semantic review does not record both freshness digests";
        }
        return "no recorded blocker";
    }
    const stageNames = ["Ready to Start Development", "Ready to Integrate", "Ready to Demo", "Ready for UAT", "Ready for Release"];
    const verdicts = { "Contract Valid": contractValid };
    const verdictReasons = { "Contract Valid": contractValid ? "no deterministic failures" : `${failures.length} deterministic FAIL diagnostic(s)` };
    for (const stage of stageNames) {
        verdicts[stage] = stageVerdict(stage);
        verdictReasons[stage] = stageReason(stage);
    }
    function dimensionPoints(id) {
        const dim = (scorePolicy["dimensions"] ?? []).find((d) => String(d["id"]) === id);
        return dim ? Number(dim["points"]) : 0;
    }
    function dimensionScore(id, ruleIds) {
        const points = dimensionPoints(id);
        const distinctFailingRules = new Set(results.filter((r) => ruleIds.includes(r.rule_id) && r.level === "FAIL").map((r) => r.rule_id)).size;
        if (distinctFailingRules === 0)
            return points;
        const penalty = Math.ceil(points * 0.5 * distinctFailingRules);
        return Math.max(0, points - penalty);
    }
    const dimensionScores = {
        source_scope_integrity: dimensionScore("source_scope_integrity", ["SOURCE-001", "SOURCE-002", "SOURCE-003", "EVIDENCE-001", "HANDOFF-002"]),
        requirement_design_traceability: dimensionScore("requirement_design_traceability", ["REF-001", "RTM-001", "RTM-002", "HANDOFF-001"]),
        engineering_contract: dimensionScore("engineering_contract", ["HANDOFF-005"]),
        acceptance_seed_testability: dimensionScore("acceptance_seed_testability", ["HANDOFF-006", "HANDOFF-007"]),
        dependency_owner_capacity: dimensionScore("dependency_owner_capacity", ["HANDOFF-003", "HANDOFF-004", "HANDOFF-009"]),
        security_privacy_environment: dimensionScore("security_privacy_environment", ["HANDOFF-011", "HANDOFF-012"]),
        demo_operational_readiness: dimensionScore("demo_operational_readiness", ["HANDOFF-008"]),
    };
    const lensMap = scorePolicy["lens_dimension_map"] ?? {};
    const penaltyBySeverity = scorePolicy["open_finding_penalty"] ?? {};
    for (const finding of openFindings) {
        const lens = String(finding["lens"] ?? "");
        const dimensionId = lensMap[lens];
        if (typeof dimensionId !== "string" || !(dimensionId in dimensionScores))
            continue;
        const penalty = penaltyBySeverity[String(finding["severity"] ?? "")];
        if (penalty === undefined)
            continue;
        dimensionScores[dimensionId] = Math.max(0, dimensionScores[dimensionId] - Number(penalty));
    }
    const blockingDimensionMap = scorePolicy["blocking_point_dimension_map"] ?? {};
    const actionPenalty = Number(scorePolicy["open_action_penalty"]?.["points"] ?? 0);
    for (const action of allBlockers.filter((b) => b.origin === "open_action")) {
        const dimensionId = blockingDimensionMap[action.blocking_point];
        if (typeof dimensionId !== "string" || !(dimensionId in dimensionScores))
            continue;
        dimensionScores[dimensionId] = Math.max(0, dimensionScores[dimensionId] - actionPenalty);
    }
    const rawScore = Object.values(dimensionScores).reduce((a, b) => a + b, 0);
    let score = rawScore;
    const appliedCaps = [];
    if (!reviewUsable) {
        const reason = !reviewPresent ? "semantic review is missing" : !review ? "semantic review does not parse" : "semantic review is stale";
        appliedCaps.push({ id: "review_absent_or_stale", max_score: 70, reason });
        score = Math.min(score, 70);
    }
    const hasOwnerOrSequenceGap = results.some((r) => r.rule_id === "HANDOFF-003" && r.level === "FAIL") || results.some((r) => r.rule_id === "HANDOFF-004" && r.level === "FAIL");
    if (hasOwnerOrSequenceGap) {
        appliedCaps.push({ id: "missing_owner_or_sequence", max_score: 69, reason: "a work item has no named owner, or the build sequence is not executable as declared" });
        score = Math.min(score, 69);
    }
    const openCriticalBeforeBuild = openFindings.filter((f) => String(f["severity"]) === "critical" && String(f["blocking_point"]) === "before_build");
    if (openCriticalBeforeBuild.length > 0) {
        const ids = openCriticalBeforeBuild.map((f) => String(f["finding_id"])).join(", ");
        appliedCaps.push({ id: "open_before_build_critical", max_score: 49, reason: `open critical finding(s) block before_build: ${ids}` });
        score = Math.min(score, 49);
    }
    let overallVerdict = "READY";
    if (deterministicFail) {
        overallVerdict = "BLOCKED";
        appliedCaps.push({ id: "deterministic_fail", max_score: null, reason: `${failures.length} deterministic FAIL diagnostic(s)` });
    }
    else if (verdicts["Ready to Start Development"] === false) {
        overallVerdict = "NOT READY TO BUILD";
    }
    else if (!reviewUsable) {
        overallVerdict = "CONTRACT VALID, NOT REVIEWED";
    }
    else if (verdicts["Ready to Demo"] === false) {
        overallVerdict = "READY TO BUILD, NOT READY TO DEMO";
    }
    const dimensionsOut = (scorePolicy["dimensions"] ?? []).map((d) => ({
        id: String(d["id"]),
        title: String(d["title"]),
        points: Number(d["points"]),
        awarded: dimensionScores[String(d["id"])] ?? 0,
    }));
    const assessment = {
        schema_version: "1.1",
        project,
        mode,
        gate: "Handoff",
        gate_exit_code: gateExitCode,
        verdict: overallVerdict,
        verdicts,
        verdict_reasons: verdictReasons,
        score: {
            raw: rawScore,
            awarded: score,
            total: Number(scorePolicy["total"] ?? 100),
            dimensions: dimensionsOut,
            caps_applied: appliedCaps,
            disclaimer: String(scorePolicy["disclaimer"] ?? ""),
        },
        semantic_review: {
            present: reviewPresent,
            usable: reviewUsable,
            stale: reviewStale,
            stale_reason: sourceStale ? "source snapshot changed" : inputStale ? "a reviewed artifact changed" : null,
            reviewer_kind: review ? String(review["reviewer_kind"] ?? "") : null,
            is_approval: false,
            open_blockers: allBlockers,
        },
        deterministic: { fail: failures.length, warn: warnings.length },
    };
    if (format === "Json")
        return { output: JSON.stringify(assessment, null, 2) + "\n", exitCode: 0 };
    const lines = [];
    lines.push(`Axiom-PMO Handoff Readiness: ${project}`);
    lines.push(`Mode: ${mode}`);
    lines.push("");
    lines.push(`Verdict: ${overallVerdict}`);
    lines.push("");
    for (const [key, value] of Object.entries(verdicts)) {
        const mark = value === null ? "  ?" : value ? "YES" : "NO ";
        lines.push(`  ${mark}  ${key.padEnd(28)} ${verdictReasons[key]}`);
    }
    if (Object.values(verdicts).some((v) => v === null)) {
        lines.push("");
        lines.push("  ? means the evidence to answer does not exist yet -- not that the answer is no.");
    }
    if (deterministicFail) {
        lines.push("");
        lines.push("Blocking before anything else (deterministic):");
        for (const f of failures) {
            const where = [f.artifact, f.item_id].filter(Boolean).join(" / ");
            lines.push(`  - [${f.rule_id}]${where ? ` (${where})` : ""} ${f.message}`);
        }
    }
    if (allBlockers.length > 0) {
        lines.push("");
        lines.push("Open blockers by blocking point:");
        for (const point of handoffPolicy["blocking_points"] ?? []) {
            const atPoint = allBlockers.filter((b) => b.blocking_point === point);
            if (atPoint.length === 0)
                continue;
            lines.push(`  ${point}`);
            for (const b of atPoint) {
                const source = b.origin === "open_action" ? "HANDOFF.md open action" : "review finding";
                lines.push(`    - ${b.finding_id} [${b.severity}] owner: ${b.owner}  (${source})`);
            }
        }
    }
    lines.push("");
    lines.push(`Score: ${score} / ${scorePolicy["total"]}`);
    for (const d of dimensionsOut) {
        lines.push(`  ${String(d.awarded).padStart(3)} / ${String(d.points).padEnd(3)}  ${d.title}`);
    }
    if (appliedCaps.length > 0) {
        lines.push("");
        lines.push(`Caps applied (raw score was ${rawScore}):`);
        for (const cap of appliedCaps) {
            const limit = cap.max_score === null ? "verdict BLOCKED" : `max ${cap.max_score}`;
            lines.push(`  - ${cap.id}: ${limit} -- ${cap.reason}`);
        }
    }
    lines.push("");
    lines.push(String(scorePolicy["disclaimer"]));
    if (!reviewUsable)
        lines.push("The semantic review is not usable, so nothing here reflects a reader's judgement of whether the plan makes sense.");
    return { output: lines.join("\n") + "\n", exitCode: 0 };
}
