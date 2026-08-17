#!/usr/bin/env node
// Thin CLI entry point for hooks/scope-advisory.sh (Phase 9: replaces the
// shim's `pwsh -File scripts/hook-scope-advisory.ps1` call, now that the
// PowerShell reference is gone). Reads the PreToolUse payload on stdin,
// matching the reference's own contract; writes the advisory to stdout and
// always exits 0, same as hookScopeAdvisory itself guarantees.

import { hookScopeAdvisory } from "./hook-scope-advisory.js";

function readStdin(): Promise<string> {
  return new Promise((resolvePromise) => {
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => { data += chunk; });
    process.stdin.on("end", () => resolvePromise(data));
    process.stdin.on("error", () => resolvePromise(data));
  });
}

function takeArg(args: string[], name: string): string | null {
  const index = args.indexOf(`-${name}`);
  if (index === -1 || index + 1 >= args.length) return null;
  return args[index + 1]!;
}

async function main(): Promise<void> {
  const projectPath = takeArg(process.argv.slice(2), "ProjectPath");
  const payload = await readStdin();
  const result = hookScopeAdvisory(projectPath, payload);
  if (result.output) process.stdout.write(result.output);
  process.exit(result.exitCode);
}

void main();
