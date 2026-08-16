// `axiom run` stateful command, ported from scripts/run-execution-command.ps1.
// Runs a command for real via the platform shell and seals a runner-exit-record
// (JSON + .sha256 sidecar). Verified by §8.6 fresh-tree methodology.

import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { join, resolve, isAbsolute, relative } from "node:path";
import { createHash } from "node:crypto";
import { randomUUID } from "node:crypto";
import { readExecutionContract } from "../exec/execution-contract-schema.js";
import { getExecutionFileDigest } from "../exec/execution-contract-schema.js";

function sha256(buf: Buffer): string {
  return createHash("sha256").update(buf).digest("hex").toLowerCase();
}

export interface RunResult {
  output: string;
  exitCode: number;
}

export function runExecutionCommand(
  projectPath: string,
  workItemId: string,
  name: string,
  command: string,
  workingDirectory = ".",
  contractPath: string | null = null,
): RunResult {
  const project = resolve(projectPath);
  const contractP = contractPath ?? join(project, ".execution", workItemId, "EXECUTION-CONTRACT.json");

  const contract = readExecutionContract(contractP);
  if (!contract.present) return { output: `RUN FAILED: No execution contract at ${contractP}. A run record must be bound to an exported contract's digest.\n`, exitCode: 1 };
  if (!contract.valid) return { output: `RUN FAILED: Execution contract is invalid: ${contract.error}\n`, exitCode: 1 };

  const sidecarPath = contractP + ".sha256";
  if (!existsSync(sidecarPath)) return { output: `RUN FAILED: No digest sidecar at ${sidecarPath}. Export the contract with axiom export before running evidence against it.\n`, exitCode: 1 };
  const sidecarDigest = readFileSync(sidecarPath, "utf8").trim().toLowerCase();
  if (sidecarDigest !== contract.digest) return { output: "RUN FAILED: The contract's digest does not match its sidecar -- it was modified after export. Re-export before recording evidence against it.\n", exitCode: 1 };

  // containment
  const rootFull = resolve(project);
  if (isAbsolute(workingDirectory) || /^[A-Za-z]:[\\/]?/.test(workingDirectory)) {
    return { output: `RUN FAILED: -WorkingDirectory must be relative to the project, not absolute: ${workingDirectory}\n`, exitCode: 1 };
  }
  const cwdFull = resolve(join(project, workingDirectory));
  if (cwdFull !== rootFull && !cwdFull.startsWith(rootFull + "/")) {
    return { output: `RUN FAILED: -WorkingDirectory escapes the project root: ${workingDirectory}\n`, exitCode: 1 };
  }
  if (!existsSync(cwdFull)) return { output: `RUN FAILED: -WorkingDirectory does not exist: ${workingDirectory}\n`, exitCode: 1 };
  const cwdRelative = cwdFull === rootFull ? "." : relative(rootFull, cwdFull).replace(/\\/g, "/");

  // run via platform shell (child process, not in-process eval)
  const shellExe = process.platform === "win32" ? "cmd.exe" : "/bin/sh";
  const shellArgs = process.platform === "win32" ? ["/c", command] : ["-c", command];

  const startedAt = new Date().toISOString();
  const child = spawnSync(shellExe, shellArgs, { cwd: cwdFull, encoding: "utf8" });
  const endedAt = new Date().toISOString();
  const capturedText = (child.stdout ?? "") + (child.stderr ?? "");
  const exitCode = child.status ?? 1;

  const stdoutSha256 = sha256(Buffer.from(capturedText, "utf8"));
  const runId = randomUUID();

  const record = {
    run_id: runId,
    work_item_id: workItemId,
    contract_sha256: contract.digest,
    command,
    cwd: cwdRelative,
    exit_code: exitCode,
    started_at: startedAt,
    ended_at: endedAt,
    stdout_sha256: stdoutSha256,
    sealed_by: "axiom-runner",
  };

  const runsDir = join(project, ".execution", workItemId, "runs");
  mkdirSync(runsDir, { recursive: true });
  const recordPath = join(runsDir, `${runId}.json`);
  let json = JSON.stringify(record, null, 2);
  json = json.replace(/\r\n/g, "\n");
  if (!json.endsWith("\n")) json += "\n";
  writeFileSync(recordPath, json, "utf8");

  const recordDigest = getExecutionFileDigest(recordPath)!;
  writeFileSync(recordPath + ".sha256", recordDigest + "\n", "utf8");

  const relRecordPath = `.execution/${workItemId}/runs/${runId}.json`;

  const lines = [
    "Command run and sealed",
    `  command    : ${command}`,
    `  cwd        : ${cwdRelative}`,
    `  exit code  : ${exitCode}`,
    `  record     : ${recordPath}`,
    "",
  ];
  if (exitCode === 0) {
    lines.push("Add this to EXECUTION-RESULT.json's test_evidence:");
    lines.push(`  { "type": "runner-exit-record", "name": "${name}", "run_record_path": "${relRecordPath}" }`);
  } else {
    lines.push("Exit code was non-zero -- verification will reject this record for any required test that names it.");
  }
  return { output: lines.join("\n") + "\n", exitCode };
}
