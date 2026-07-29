// Turn a captured validator JSON envelope into the Action's report surfaces:
// axiom-report.json, axiom-report.md, and the GitHub Job Summary body.
//
// This module renders. It does not decide pass/fail and does not touch the
// filesystem outside the paths it is explicitly given -- run-action.mjs owns
// I/O and exit codes, this file owns formatting.

const OUTCOME_BY_EXIT_CODE = {
  0: "success",
  1: "failure",
  2: "warning",
  127: "runtime-missing",
};

export function outcomeForExitCode(exitCode) {
  return OUTCOME_BY_EXIT_CODE[exitCode] ?? "failure";
}

// axiom-report.json preserves the validator's own JSON untouched -- same
// field names, same nesting -- and adds a small, clearly-namespaced `action`
// object next to it. Nothing from the validator is renamed or removed: a
// consumer already parsing the diagnostics contract keeps working unchanged.
export function buildReportJson(validatorResult, meta) {
  return {
    ...validatorResult,
    action: {
      outcome: meta.outcome,
      exit_code: meta.exitCode,
      enforce: meta.enforce,
      fail_on_warning: meta.failOnWarning,
      annotation_mode: meta.annotationMode,
      generated_at: meta.generatedAt,
    },
  };
}

function levelRows(results, level) {
  return (results ?? []).filter((r) => r.level === level);
}

function formatRow(result) {
  const location = [result.artifact, result.item_id, result.field].filter(Boolean).join(" / ");
  const locationText = location ? ` (${location})` : "";
  const lines = [`- **${result.rule_id}**${locationText}: ${result.message}`];
  if (result.suggestion) lines.push(`  - Suggestion: ${result.suggestion}`);
  return lines.join("\n");
}

// `limit` caps how many FAIL/WARN rows are inlined -- unlimited for the
// on-disk Markdown report, capped for the Job Summary (which GitHub also caps
// at 1 MiB, and which nobody reads as a scrolling wall of text).
function renderBody(validatorResult, meta, { limit } = {}) {
  const { project, requested_mode, effective_mode, gate, summary, results } = validatorResult;
  const lines = [];

  lines.push(`# Axiom-PMO Governance Report`, "");
  lines.push(`| | |`, `|---|---|`);
  lines.push(`| Project | \`${project ?? "-"}\` |`);
  lines.push(`| Mode | ${requested_mode ?? "-"}${effective_mode && effective_mode !== requested_mode ? ` (effective: ${effective_mode})` : ""} |`);
  lines.push(`| Gate | ${gate ?? "-"} |`);
  lines.push(`| Outcome | **${meta.outcome.toUpperCase()}** |`);
  lines.push(`| Exit code | \`${meta.exitCode}\` |`);
  if (meta.enforce === false) {
    lines.push(`| Mode | report-only (this run cannot fail the workflow) |`);
  }
  lines.push("");

  if (summary) {
    lines.push(
      `PASS ${summary.pass ?? 0} · WARN ${summary.warn ?? 0} (${summary.warn_blocking ?? 0} blocking) · FAIL ${summary.fail ?? 0}`,
      "",
    );
  }

  const fails = levelRows(results, "FAIL");
  const warns = levelRows(results, "WARN");

  const renderSection = (title, rows) => {
    if (rows.length === 0) return;
    lines.push(`## ${title} (${rows.length})`, "");
    const shown = limit ? rows.slice(0, limit) : rows;
    for (const row of shown) lines.push(formatRow(row), "");
    if (limit && rows.length > limit) {
      lines.push(`_...and ${rows.length - limit} more. See the full JSON/Markdown report artifact._`, "");
    }
  };

  renderSection("FAIL", fails);
  renderSection("WARN (blocking)", warns.filter((r) => r.blocking));
  renderSection("WARN (non-blocking)", warns.filter((r) => !r.blocking));

  if (fails.length === 0 && warns.length === 0) {
    lines.push("No FAIL or WARN diagnostics.", "");
  }

  return lines.join("\n");
}

export function buildReportMarkdown(validatorResult, meta) {
  return renderBody(validatorResult, meta, { limit: null });
}

export function buildJobSummary(validatorResult, meta) {
  return renderBody(validatorResult, meta, { limit: 10 });
}
