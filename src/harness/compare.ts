// Differential comparison: canonical-form equality via the golden normalizer,
// plus an exit-code assertion. The harness fails on any real diff and — proven
// by the mutant self-tests — only on real diffs, never on host noise.

import { getCanonicalGoldenText, getGoldenDiffReport } from "../output/canonical-normalizer.js";
import type { RunResult } from "./runner.js";

export interface CompareResult {
  equivalent: boolean;
  exitMatch: boolean;
  report: string[];
}

export function compareOutputs(reference: RunResult, candidate: RunResult): CompareResult {
  const refCanon = getCanonicalGoldenText(reference.stdout);
  const candCanon = getCanonicalGoldenText(candidate.stdout);
  const equivalent = refCanon === candCanon;
  const exitMatch = (reference.exitCode ?? 1) === (candidate.exitCode ?? 1);

  const report: string[] = [];
  if (!equivalent) {
    report.push("canonical output differs:");
    report.push(...getGoldenDiffReport(refCanon, candCanon));
  }
  if (!exitMatch) {
    report.push(`exit code differs: reference=${reference.exitCode} candidate=${candidate.exitCode}`);
  }
  return { equivalent, exitMatch, report };
}
