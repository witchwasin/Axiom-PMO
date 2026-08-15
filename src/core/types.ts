// Core shared types for the Node/TypeScript interpreter.
//
// Field order in the diagnostic row and envelope mirrors result-writer.ps1
// exactly: JSON.stringify preserves insertion order, and the golden masters
// compare JSON bytes canonically, so a reordered object is a golden diff.

export type Level = "PASS" | "WARN" | "FAIL" | "INFO";
export type Mode = "Lite" | "Standard" | "Strict";
export type Gate = "Draft" | "Scope" | "Design" | "Handoff" | "Release";

export const DIAGNOSTICS_SCHEMA_VERSION = "1.1";

/** A single diagnostic row (diagnostics-schema.json §diagnostic). */
export interface Diagnostic {
  schema_version: string;
  level: Level;
  rule_id: string;
  message: string;
  blocking: boolean;
  artifact: string | null;
  item_id: string | null;
  field: string | null;
  suggestion: string | null;
  documentation_url: string | null;
}

export interface Summary {
  pass: number;
  warn: number;
  warn_blocking: number;
  fail: number;
  exit_code: number;
}

export interface ScopeDiffResult {
  base_sha: string;
  head_sha: string;
  approved_include: string[];
  approved_exclude: string[];
  changed_in_scope: string[];
  changed_out_of_scope: string[];
  changed_excluded: string[];
  exempt: Array<{ path: string; reason: string }>;
  renames: Array<{
    status: string;
    old_path: string;
    new_path: string;
    old_verdict: "excluded" | "out_of_scope" | "exempt" | "in_scope";
    new_verdict: "excluded" | "out_of_scope" | "exempt" | "in_scope";
  }>;
  verdict: "pass" | "fail" | "scope_missing" | "invalid_scope" | "git_error";
}

/** The full JSON envelope written by the validator (diagnostics-schema.json §envelope). */
export interface Envelope {
  schema_version: string;
  project: string;
  requested_mode: Mode;
  effective_mode: Mode;
  gate: Gate;
  summary: Summary;
  results: Diagnostic[];
  scope_diff?: ScopeDiffResult;
}
