// Probe-only validation chain: runs the *ported* validators in the exact order
// validate-project.ps1 does, so a differential probe can compare rule-level
// output against the PowerShell reference. This is NOT the production
// orchestrator (handoff / design-provider / visual-proof / adversarial-review /
// execution-contract / scope-diff are not yet ported); it exists to give the
// 9 ported modules a real differential oracle.
import { resolve } from "node:path";
import { importPmoConfig, getPolicySourceRefRegex, testOrchestrationDeclarations } from "../config/config-loader.js";
import { createAccumulator } from "../core/context.js";
import { resolveEffectiveMode } from "../core/mode-resolver.js";
import { testGithubTaskSource, testRequiredArtifacts, getProjectFileSets, getProjectText } from "../core/artifact-policy.js";
import { testExecutionPath, getProjectExecutionPath } from "../core/execution-path-validator.js";
import { testGovernedPlaceholders, testProjectSourceSection, testSensitiveFilenames, testLinks } from "../rules/source-validator.js";
import { testDeliveryWorkItems } from "../rules/workitem-validator.js";
import { getDecisionIds } from "../rules/decision-log.js";
import { testChangeControlRegistry } from "../rules/change-control-validator.js";
import { testExternalizationRegistry } from "../rules/externalization-validator.js";
import { testResearchWorkflow } from "../rules/research-validator.js";
import { testRaidBlocker, testReleaseArtifact, testReleaseScopeCompletion, testStrictReleaseGuardrails } from "../rules/release-validator.js";
import { testDesignSystemTokens } from "../rules/design-system-validator.js";
import { testDesignProviderWorkflow } from "../rules/design-provider-validator.js";
import { testVisualProofReview } from "../rules/visual-proof-validator.js";
import { testHandoffReadiness, testEarlyTestDesign } from "../rules/handoff-validator.js";
import { testSpecificationDepth } from "../rules/depth-validator.js";
import { invokeScopeDiffCheck } from "../rules/scope-diff-validator.js";
import { writeValidationOutput, getExitCode } from "../core/result-writer.js";
import { DIAGNOSTICS_SCHEMA_VERSION } from "../core/types.js";
export function runPortedChain(repoRoot, project, mode, gate) {
    const acc = createAccumulator();
    const config = importPmoConfig(repoRoot);
    const catalog = config.validationRules;
    const policyEnums = config.policyEnums;
    const sourceRefRegex = getPolicySourceRefRegex(policyEnums);
    const effectiveMode = resolveEffectiveMode(acc, catalog, project, mode, gate);
    const taskSourceIsGithub = testGithubTaskSource(project);
    testRequiredArtifacts(acc, catalog, project, effectiveMode, gate, config.artifactPolicy, taskSourceIsGithub);
    const fileSets = getProjectFileSets(project);
    const decisionIds = getDecisionIds(project);
    testGovernedPlaceholders(acc, catalog, fileSets.governedFiles, project, gate);
    const projectText = getProjectText(project);
    const ctx = {
        project,
        referenceTypesConfig: config.referenceTypesConfig,
        policy: config.policy,
        handoffPolicy: config.handoffPolicy,
        depthPolicy: config.depthPolicy,
    };
    // Reference: validate-project.ps1 only calls Test-ProjectSourceSection
    // `if ($projectText)`; with no PROJECT.md at all, every downstream
    // consumer of $sourceResult gets the pre-declared empty defaults instead.
    // Calling this unconditionally (as this chain did before) fires TASK-001/
    // SOURCE-001/SOURCE-002/APPROVAL-001 against an empty string, which the
    // reference never does for a missing-PROJECT.md project -- found via the
    // newly-ported validation-fixtures golden check (invalid-no-project).
    let sourceResult = { projectReqIds: [], projectBusinessIds: [], projectTaskSource: null, projectSourceIds: [] };
    if (projectText) {
        sourceResult = testProjectSourceSection(acc, catalog, ctx, projectText, effectiveMode, gate, sourceRefRegex, policyEnums, decisionIds);
    }
    const deliveryPath = resolve(project, "DELIVERY.md");
    const workItemResult = testDeliveryWorkItems(acc, catalog, project, deliveryPath, gate, policyEnums, config.sentinelRules, sourceResult.projectReqIds, sourceResult.projectBusinessIds, sourceResult.projectTaskSource);
    testExecutionPath(acc, catalog, project, policyEnums, workItemResult.workItems);
    const executionPath = getProjectExecutionPath(project) ?? "development_handoff";
    testOrchestrationDeclarations(acc, catalog, project, gate, config.orchestrationPolicy);
    testChangeControlRegistry(acc, catalog, project, gate, config.orchestrationPolicy, effectiveMode, executionPath, sourceResult.projectReqIds, decisionIds, config.handoffPolicy);
    testEarlyTestDesign(acc, catalog, project, effectiveMode, gate, sourceResult.projectReqIds, projectText, config.handoffPolicy);
    // Optional tracks (PS order: externalization, research, design-provider).
    testExternalizationRegistry(acc, catalog, project, gate, config.orchestrationPolicy, config.policy, decisionIds, config.handoffPolicy);
    testResearchWorkflow(acc, catalog, project, gate, config.orchestrationPolicy, policyEnums, decisionIds, config.handoffPolicy);
    testDesignProviderWorkflow(acc, catalog, project, gate, config.orchestrationPolicy, decisionIds, config.handoffPolicy);
    testRaidBlocker(acc, catalog, project, gate);
    const releaseResult = testReleaseArtifact(acc, catalog, ctx, project, effectiveMode, gate, workItemResult.deliveryIds, decisionIds);
    testReleaseScopeCompletion(acc, catalog, ctx, workItemResult.workItems, releaseResult.releaseText, effectiveMode, gate, decisionIds, releaseResult.releaseRegistry);
    testStrictReleaseGuardrails(acc, catalog, ctx, policyEnums, sourceRefRegex, project, effectiveMode, gate, sourceResult.projectReqIds, workItemResult.deliveryIds, decisionIds, releaseResult.releaseRegistry, sourceResult.projectSourceIds);
    if (gate === "Handoff") {
        testHandoffReadiness(acc, catalog, ctx, effectiveMode, gate, workItemResult.workItems, workItemResult.deliveryIds, sourceResult.projectReqIds, decisionIds, projectText);
        testVisualProofReview(acc, catalog, project, effectiveMode, config.handoffPolicy, projectText, decisionIds);
    }
    testSpecificationDepth(acc, catalog, ctx, projectText, effectiveMode, gate, sourceResult.projectReqIds, decisionIds, sourceRefRegex);
    testDesignSystemTokens(acc, catalog, project, gate);
    testSensitiveFilenames(acc, catalog, fileSets.allProjectFiles, project);
    testLinks(acc, catalog, fileSets.governedFiles, fileSets.userSourceFiles, gate);
    return { diagnostics: acc.messages, accumulator: acc, effectiveMode };
}
// Assembles and renders one full validate envelope -- runs the chain,
// optionally the opt-in SCOPE-DIFF check, computes the exit code, and writes
// Text or JSON. Shared by cli/axiom.mjs's `validate`/`handoff` commands and
// demo.ts's own gate step, which used to spawn validate-project.ps1 directly
// instead of calling this (Phase 9 fix -- see demo.ts's own comment).
export function runValidateEnvelope(repoRoot, project, mode, gate, failOnWarning, format, scopeDiff = {}) {
    const chain = runPortedChain(repoRoot, project, mode, gate);
    const acc = chain.accumulator;
    let scopeDiffResult = null;
    if (scopeDiff.base && scopeDiff.head) {
        const config = importPmoConfig(repoRoot);
        const gitRoot = scopeDiff.repoRoot ? resolve(scopeDiff.repoRoot) : repoRoot;
        scopeDiffResult = invokeScopeDiffCheck(acc, config.validationRules, project, gitRoot, repoRoot, scopeDiff.base, scopeDiff.head);
    }
    const exitCode = getExitCode(acc.fail, acc.warnBlocking, failOnWarning);
    const envelope = {
        schema_version: DIAGNOSTICS_SCHEMA_VERSION,
        project,
        requested_mode: mode,
        effective_mode: chain.effectiveMode,
        gate,
        summary: {
            pass: acc.pass,
            warn: acc.warn,
            warn_blocking: acc.warnBlocking,
            fail: acc.fail,
            exit_code: exitCode,
        },
        results: acc.messages,
    };
    if (scopeDiffResult)
        envelope.scope_diff = scopeDiffResult;
    return {
        output: writeValidationOutput(format, envelope, project, mode, chain.effectiveMode, gate) + "\n",
        exitCode,
    };
}
