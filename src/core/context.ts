// Typed, per-run ValidationContext (CR-012). The PowerShell implementation used
// `$script:` module globals to share state across dot-sourced modules; the port
// must not. Every run gets its own context object threaded through every
// validator call, so sequential and concurrent multi-project runs cannot leak
// state or caches into each other.

import type { Diagnostic, Envelope, Gate, Mode, ScopeDiffResult } from "./types.js";

export interface Config {
  policy: Record<string, unknown>;
  policyEnums: Record<string, unknown>;
  sentinelRules: Record<string, unknown>;
  artifactPolicy: Record<string, unknown>;
  referenceTypesConfig: Record<string, unknown>;
  validationRules: ValidationRules;
  handoffPolicy: Record<string, unknown>;
  orchestrationPolicy: Record<string, unknown>;
}

export interface ValidationRules {
  version?: string;
  documentation_base_url?: string | null;
  rules: Record<string, RuleCatalogEntry>;
}

export interface RuleCatalogEntry {
  severity?: string;
  description?: string;
  suggestion?: string;
  documentation?: string;
  lifecycle?: string;
}

export interface ResultAccumulator {
  messages: Diagnostic[];
  pass: number;
  warn: number;
  warnBlocking: number;
  fail: number;
}

export interface ValidationContext {
  readonly repoRoot: string;
  readonly project: string;
  readonly config: Config;
  readonly accumulator: ResultAccumulator;
  scopeDiff: ScopeDiffResult | null;
}

export interface RunOptions {
  project: string;
  mode: Mode;
  gate: Gate;
  format: "Text" | "Json";
  failOnWarning: boolean;
  scopeDiffBase: string | null;
  scopeDiffHead: string | null;
  scopeDiffRepoRoot: string | null;
  releaseDiffBase: string | null;
  releaseDiffHead: string | null;
  release: boolean;
}

export function createAccumulator(): ResultAccumulator {
  return { messages: [], pass: 0, warn: 0, warnBlocking: 0, fail: 0 };
}

export function createEnvelope(
  ctx: ValidationContext,
  requestedMode: Mode,
  effectiveMode: Mode,
  gate: Gate,
  exitCode: number,
): Envelope {
  const a = ctx.accumulator;
  const envelope: Envelope = {
    schema_version: "1.1",
    project: ctx.project,
    requested_mode: requestedMode,
    effective_mode: effectiveMode,
    gate,
    summary: {
      pass: a.pass,
      warn: a.warn,
      warn_blocking: a.warnBlocking,
      fail: a.fail,
      exit_code: exitCode,
    },
    results: a.messages,
  };
  if (ctx.scopeDiff !== null) {
    envelope.scope_diff = ctx.scopeDiff;
  }
  return envelope;
}
