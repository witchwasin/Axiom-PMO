// `demo`, ported from scripts/demo.ps1. Three-minute proof: run the Handoff gate
// on broken + fixed demo projects. Calls the in-process TS engine directly
// (runValidateEnvelope / runAssessHandoff) -- the same functions cli/axiom.mjs's
// `validate`/`handoff` commands use -- rather than spawning validate-project.ps1
// / assess-handoff.ps1 via pwsh, which this file used to do and which meant
// `axiom demo` failed outright with no PowerShell host present.

import { existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { runValidateEnvelope } from "../probe/validate-chain.js";
import { runAssessHandoff } from "./assess-handoff.js";

export interface DemoResult {
  output: string;
  exitCode: number;
}

function writeRule(text: string): string {
  const bar = "=".repeat(74);
  // One trailing newline only: the caller joins output lines with "\n", so a
  // second one here would print a blank line the reference's Write-Host ""
  // (exactly one) does not.
  return `\n${bar}\n${text}\n${bar}\n`;
}

export function runDemo(repoRoot: string, plain: boolean, noPause: boolean): DemoResult {
  const repo = resolve(repoRoot);
  const broken = join(repo, "demo/broken-project");
  const fixed = join(repo, "demo/fixed-project");
  for (const p of [broken, fixed]) {
    if (!existsSync(p)) return { output: `Demo project not found: ${p}\n`, exitCode: 1 };
  }

  const out: string[] = [];

  // trimEnd so the following out.push("") contributes exactly the one blank
  // line the reference's Write-Host "" emits after a child; a raw push would
  // double-count the child's own trailing newline.
  function pushChildOutput(text: string): void {
    if (text && text.trim() !== "") out.push(text.trimEnd());
  }
  const invokeGate = (projectPath: string, failOnWarning = false): number => {
    const r = runValidateEnvelope(repo, projectPath, "Standard", "Handoff", failOnWarning, "Text");
    pushChildOutput(r.output);
    return r.exitCode;
  };
  const invokeAssess = (projectPath: string): number => {
    const r = runAssessHandoff(repo, projectPath, "Standard", "Text");
    pushChildOutput(r.output);
    return r.exitCode;
  };

  out.push(writeRule("Axiom-PMO -- the Handoff gate in three minutes"));
  out.push("Two synthetic projects. Both have a PROJECT.md, a design, a work-item");
  out.push("board, and an approved Design Ready gate. Both would pass every gate");
  out.push("Axiom-PMO 1.0 could run.");
  out.push("");
  out.push("One of them cannot actually be built on Monday morning.");

  out.push(writeRule("1/3  demo/broken-project  --  cli/axiom.mjs validate -Gate Handoff"));
  const brokenExit = invokeGate(broken);
  out.push("");
  out.push(`Exit code: ${brokenExit}`);

  out.push(writeRule("What those failures mean"));
  out.push("  HANDOFF-004  The shared schema every other item reads from is");
  out.push("               scheduled last. Two engineers would spend day one");
  out.push("               building against a table that does not exist yet.");
  out.push("");
  out.push("  HANDOFF-012  The scan flow needs the rear camera and nobody decided");
  out.push("               how the page is served. A browser will not open a");
  out.push("               camera over plain HTTP, so this build works on the");
  out.push("               developer laptop and fails on the demo tablet.");
  out.push("");
  out.push("  HANDOFF-011  A data element the author marked sensitive has no");
  out.push("               classification decision attached.");
  out.push("");
  out.push("  HANDOFF-007  An acceptance case has no seed data, so it cannot be");
  out.push("               reached from the demo dataset.");
  out.push("");
  out.push("  HANDOFF-003  A work item is owned by 'Dev Team'.");
  out.push("");
  out.push("None of these are style violations. Each one costs days.");

  out.push(writeRule("2/3  demo/fixed-project  --  same command"));
  const fixedExit = invokeGate(fixed, true);
  out.push("");
  out.push(`Exit code: ${fixedExit}`);

  out.push(writeRule("3/3  Readiness is not one boolean"));
  out.push("The fixed project passes every deterministic check. That is not the");
  out.push("same as being ready to demonstrate:");
  out.push("");
  invokeAssess(fixed);

  out.push(writeRule("Try it on your own project"));
  out.push("  node cli/axiom.mjs handoff --project <path> --mode Standard");
  out.push("  node cli/axiom.mjs check");
  out.push("");
  out.push("Docs: docs/concepts/handoff-readiness.md");
  out.push("Rules: docs/rules/");
  out.push("");

  if (brokenExit === 0) {
    out.push("DEMO SELF-CHECK FAILED: the broken project was expected to fail the gate.");
    return { output: out.join("\n") + "\n", exitCode: 1 };
  }
  if (fixedExit !== 0) {
    out.push("DEMO SELF-CHECK FAILED: the fixed project was expected to pass the gate.");
    return { output: out.join("\n") + "\n", exitCode: 1 };
  }
  return { output: out.join("\n") + "\n", exitCode: 0 };
}
