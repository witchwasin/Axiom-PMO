// Probe-only validation chain: runs the *ported* validators in the exact order
// validate-project.ps1 does, so a differential probe can compare rule-level
// output against the PowerShell reference. This is NOT the production
// orchestrator (handoff / design-provider / visual-proof / adversarial-review /
// execution-contract / scope-diff are not yet ported); it exists to give the
// 9 ported modules a real differential oracle.

import { resolve } from "node:path";
import { importPmoConfig, getPolicySourceRefRegex, testOrchestrationDeclarations } from "../config/config-loader.js";
import { createAccumulator, type Config, type ResultAccumulator } from "../core/context.js";
import type { Mode, Gate, Diagnostic } from "../core/types.js";
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

export interface ChainResult {
  diagnostics: Diagnostic[];
  accumulator: ResultAccumulator;
}

export function runPortedChain(
  repoRoot: string,
  project: string,
  mode: Mode,
  gate: Gate,
): ChainResult {
  const acc = createAccumulator();
  const config: Config = importPmoConfig(repoRoot);
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
    referenceTypesConfig: config.referenceTypesConfig as unknown as import("../core/reference-resolver.js").ReferenceTypesConfig,
    policy: config.policy,
    handoffPolicy: config.handoffPolicy,
  };
  const sourceResult = testProjectSourceSection(
    acc, catalog, ctx, projectText, effectiveMode, gate, sourceRefRegex, policyEnums, decisionIds,
  );

  const deliveryPath = resolve(project, "DELIVERY.md");
  const workItemResult = testDeliveryWorkItems(
    acc, catalog, project, deliveryPath, gate, policyEnums, config.sentinelRules,
    sourceResult.projectReqIds, sourceResult.projectBusinessIds, sourceResult.projectTaskSource,
  );

  testExecutionPath(acc, catalog, project, policyEnums, workItemResult.workItems);
  const executionPath = getProjectExecutionPath(project) ?? "development_handoff";

  testOrchestrationDeclarations(acc, catalog, project, gate, config.orchestrationPolicy);
  testChangeControlRegistry(
    acc, catalog, project, gate, config.orchestrationPolicy, effectiveMode, executionPath,
    sourceResult.projectReqIds, decisionIds, config.handoffPolicy,
  );
  testEarlyTestDesign(acc, catalog, project, effectiveMode, gate, sourceResult.projectReqIds, projectText, config.handoffPolicy);

  // Optional tracks (PS order: externalization, research, design-provider).
  testExternalizationRegistry(acc, catalog, project, gate, config.orchestrationPolicy, config.policy, decisionIds, config.handoffPolicy);
  testResearchWorkflow(acc, catalog, project, gate, config.orchestrationPolicy, policyEnums, decisionIds, config.handoffPolicy);
  testDesignProviderWorkflow(acc, catalog, project, gate, config.orchestrationPolicy, decisionIds, config.handoffPolicy);

  testRaidBlocker(acc, catalog, project, gate);

  const releaseResult = testReleaseArtifact(acc, catalog, ctx, project, effectiveMode, gate, workItemResult.deliveryIds, decisionIds);

  testReleaseScopeCompletion(
    acc, catalog, ctx, workItemResult.workItems, releaseResult.releaseText,
    effectiveMode, gate, decisionIds, releaseResult.releaseRegistry,
  );

  testStrictReleaseGuardrails(
    acc, catalog, ctx, policyEnums, sourceRefRegex, project,
    effectiveMode, gate, sourceResult.projectReqIds, workItemResult.deliveryIds, decisionIds,
    releaseResult.releaseRegistry, sourceResult.projectSourceIds,
  );

  if (gate === "Handoff") {
    testHandoffReadiness(acc, catalog, ctx, effectiveMode, gate, workItemResult.workItems, workItemResult.deliveryIds, sourceResult.projectReqIds, decisionIds, projectText);
    testVisualProofReview(acc, catalog, project, effectiveMode, config.handoffPolicy, projectText, decisionIds);
  }
  testDesignSystemTokens(acc, catalog, project, gate);
  testSensitiveFilenames(acc, catalog, fileSets.allProjectFiles, project);
  testLinks(acc, catalog, fileSets.governedFiles, fileSets.userSourceFiles, gate);

  return { diagnostics: acc.messages, accumulator: acc };
}
