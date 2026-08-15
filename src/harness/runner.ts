// Differential harness: runs the reference (PowerShell) and candidate (Node)
// entrypoints directly and compares canonical output. Never lets both sides
// route through one AXIOM_IMPL dispatcher (CR-009).

import { spawnSync } from "node:child_process";

export interface RunResult {
  stdout: string;
  stderr: string;
  exitCode: number | null;
}

export interface ReferenceSpec {
  exe: string;
  script: string;
  args: string[];
}

export interface CandidateSpec {
  entrypoint: string; // JS entrypoint that mirrors the reference script
  args: string[];
}

export function runCommand(cmd: string, args: string[]): RunResult {
  const r = spawnSync(cmd, args, { encoding: "utf8" });
  return { stdout: r.stdout ?? "", stderr: r.stderr ?? "", exitCode: r.status };
}

export function runReference(spec: ReferenceSpec): RunResult {
  return runCommand(spec.exe, [
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    spec.script,
    ...spec.args,
  ]);
}

export function runCandidate(spec: CandidateSpec): RunResult {
  return runCommand(process.execPath, [spec.entrypoint, ...spec.args]);
}

/**
 * Appends the child exit code the same way run-validation-tests.ps1 does, so the
 * canonical comparison includes the exit code as a compared value.
 */
export function rawWithExitCode(out: RunResult): string {
  return `${out.stdout.trimEnd()}\nEXIT_CODE=${out.exitCode ?? 1}`;
}

/**
 * Normalize host paths out of the raw output. Mirrors run-validation-tests.ps1's
 * `<REPO_ROOT>` replacement: both the raw path and its JSON-escaped (doubled
 * backslash) form are replaced.
 */
export function stripRepoRoot(raw: string, repoRoot: string): string {
  const escaped = repoRoot.replace(/\\/g, "\\\\");
  return raw.replaceAll(escaped, "<REPO_ROOT>").replaceAll(repoRoot, "<REPO_ROOT>");
}
