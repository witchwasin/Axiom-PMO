// Node equivalent of scripts/verify-execution-result.ps1: entrypoint that
// checks an execution result against its contract and git state. Produces the
// same JSON envelope (execution_verification + results[]).
import { resolve } from "node:path";
import { importPmoConfig } from "../config/config-loader.js";
import { createAccumulator } from "../core/context.js";
import { getExitCode } from "../core/result-writer.js";
import { invokeExecutionContractVerification } from "./execution-contract-validator.js";
export function runVerifyExecutionResult(repoRoot, projectPath, resultPath, gitRepoRoot, contractPath, preflight) {
    const acc = createAccumulator();
    const config = importPmoConfig(repoRoot);
    const catalog = config.validationRules;
    const resolvedProject = resolve(projectPath);
    const resolvedGitRoot = gitRepoRoot ? resolve(gitRepoRoot) : resolvedProject;
    const resolvedResult = resolve(resultPath);
    const verification = invokeExecutionContractVerification(acc, catalog, resolvedProject, resolvedResult, resolvedGitRoot, repoRoot, contractPath, preflight);
    const exitCode = getExitCode(acc.fail, acc.warnBlocking, false);
    const envelope = {
        schema_version: "1.1",
        project: resolvedProject,
        requested_mode: "Standard",
        effective_mode: "Standard",
        gate: "Draft",
        summary: {
            pass: acc.pass,
            warn: acc.warn,
            warn_blocking: acc.warnBlocking,
            fail: acc.fail,
            exit_code: exitCode,
        },
        results: acc.messages,
        execution_verification: verification,
    };
    return { envelope, exitCode };
}
