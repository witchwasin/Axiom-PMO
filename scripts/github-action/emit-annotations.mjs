// Turn structured diagnostics into GitHub workflow-command annotations.
//
// SAFETY BOUNDARY -- read this before adding a field.
//
// This module never opens a project file, a source document, or an approval
// record. Every character it prints comes from a field the *validator* authored
// and the diagnostics contract already publishes:
//
//   rule_id, message, artifact, item_id, field, suggestion, documentation_url
//
// That is the whole allowlist. It is deliberately a whitelist and not a
// blacklist: a blacklist would have to guess which prose is confidential, and
// it would guess wrong the first time somebody put a customer name in a
// requirement title. Anything outside the list -- requirement prose, source
// excerpts, approval evidence, file contents -- is never read here, so it
// cannot leak here.
//
// See docs/reference/diagnostics-contract.md for the field definitions.

import { isAbsolute, relative, resolve } from "node:path";

// FAIL and WARN become annotations. PASS and INFO do not: a green run would
// otherwise bury the pull request in notices, and reviewers stop reading
// annotations that are mostly noise.
const ANNOTATION_LEVELS = { FAIL: "error", WARN: "warning" };

// GitHub renders at most ten annotations per level per step. Emitting more
// does not surface more -- it just drops them silently, which looks like the
// rule never fired. Cap on purpose and say so, so the reader knows to open the
// full report.
const PER_LEVEL_LIMIT = 10;

// A diagnostic message is one sentence by contract. A multi-KB one means a
// rule is echoing content it should have summarised; clamp rather than
// forward it verbatim.
const MAX_FIELD_CHARS = 500;

// Workflow-command escaping. `%` has to go first or it would re-escape the
// `%0D`/`%0A` introduced by the later replacements.
// https://docs.github.com/actions/reference/workflow-commands-for-github-actions
function escapeData(value) {
  return String(value).replace(/%/g, "%25").replace(/\r/g, "%0D").replace(/\n/g, "%0A");
}

// Property values live inside a `key=value,key=value` list, so `:` and `,`
// need escaping too or a message containing either would truncate the command.
function escapeProperty(value) {
  return escapeData(value).replace(/:/g, "%3A").replace(/,/g, "%2C");
}

function clamp(value) {
  const text = String(value);
  if (text.length <= MAX_FIELD_CHARS) return text;
  return `${text.slice(0, MAX_FIELD_CHARS - 1)}…`;
}

// A file-targeted annotation is only useful if GitHub can resolve the path
// inside the checked-out workspace. An artifact that escapes the workspace
// (`../`, an absolute path from another machine, a symlinked temp dir) would
// either render nothing or point at an unrelated file, so those degrade to a
// locationless annotation instead -- still visible in the run log, just not
// pinned to a line.
//
// `artifact` is project-relative for every rule except SCOPE-DIFF's, which is
// the one documented exception in the diagnostics contract: its paths are
// repo-root-relative, because a changed file it reports (from `git diff`)
// routinely lives outside the project folder entirely (the project's own
// PROJECT.md/DELIVERY.md tree and the application source tree it governs are
// frequently in different parts of the repository -- see
// docs/reference/scope-declaration.md). Resolving a SCOPE-DIFF artifact
// against `projectPath` the same way as every other rule either doubles the
// project prefix (when the changed file happens to sit inside the project
// folder) or silently points at the wrong file entirely (when it does not,
// which is the documented common case) -- caught by inspecting a real
// annotation GitHub rendered from this repository's own dogfood CI run, not
// by local testing alone.
function safeWorkspacePath(artifact, { workspace, projectPath, repoRootRelative = false }) {
  if (!artifact || typeof artifact !== "string") return null;
  if (!workspace) return null;

  const base = repoRootRelative ? workspace : (projectPath ?? workspace);
  const absolute = isAbsolute(artifact) ? artifact : resolve(base, artifact);
  const rel = relative(resolve(workspace), absolute);
  if (!rel || rel.startsWith("..") || isAbsolute(rel)) return null;

  // Workflow commands are POSIX-path oriented even on Windows runners.
  return rel.split(/[\\/]/).join("/");
}

// The one rule-id family whose `artifact` field is repo-root-relative
// instead of project-relative -- see safeWorkspacePath's comment above.
function isRepoRootRelativeRule(ruleId) {
  return typeof ruleId === "string" && ruleId.startsWith("SCOPE-DIFF-");
}

// The human-readable half of an annotation: what is wrong, then what to do.
// `documentation_url` is appended rather than made a property because GitHub
// does not linkify annotation properties, only the body.
function buildBody(result) {
  const parts = [clamp(result.message ?? "")];
  if (result.suggestion) parts.push(clamp(result.suggestion));
  if (result.documentation_url) parts.push(clamp(result.documentation_url));
  return parts.filter(Boolean).join("\n\n");
}

// `title` is what shows in the collapsed annotation row, so it carries the
// identifiers a reviewer scans for: which rule, which item, which field.
function buildTitle(result) {
  const location = [result.item_id, result.field].filter(Boolean).join(" · ");
  const ruleId = result.rule_id ?? "AXIOM";
  return location ? `${ruleId}: ${location}` : ruleId;
}

/**
 * Build the workflow-command strings for a result set.
 *
 * Returned rather than printed so the escaping and the location fallbacks can
 * be asserted in tests without capturing stdout.
 */
export function buildAnnotations(results, { workspace, projectPath, mode = "safe" } = {}) {
  if (mode === "off") return [];
  if (!Array.isArray(results)) return [];

  const lines = [];
  const emitted = { error: 0, warning: 0 };
  const suppressed = { error: 0, warning: 0 };

  for (const result of results) {
    const level = ANNOTATION_LEVELS[result?.level];
    if (!level) continue;

    if (emitted[level] >= PER_LEVEL_LIMIT) {
      suppressed[level] += 1;
      continue;
    }
    emitted[level] += 1;

    const properties = [`title=${escapeProperty(buildTitle(result))}`];
    const file = safeWorkspacePath(result.artifact, {
      workspace,
      projectPath,
      repoRootRelative: isRepoRootRelativeRule(result.rule_id),
    });
    if (file) properties.push(`file=${escapeProperty(file)}`);

    lines.push(`::${level} ${properties.join(",")}::${escapeData(buildBody(result))}`);
  }

  // Say what was withheld. A silent cap is indistinguishable from a rule that
  // did not fire, and that is exactly the kind of ambiguity this project exists
  // to remove.
  for (const [level, count] of Object.entries(suppressed)) {
    if (count === 0) continue;
    lines.push(
      `::notice::${escapeData(
        `${count} further ${level} diagnostic(s) were not annotated (GitHub shows at most ${PER_LEVEL_LIMIT} per level). The full set is in the JSON/Markdown report.`,
      )}`,
    );
  }

  return lines;
}

export function emitAnnotations(results, options = {}) {
  const lines = buildAnnotations(results, options);
  const write = options.write ?? ((line) => process.stdout.write(`${line}\n`));
  for (const line of lines) write(line);
  return lines.length;
}

export const __testing = { escapeData, escapeProperty, safeWorkspacePath, isRepoRootRelativeRule, buildTitle, buildBody, clamp, PER_LEVEL_LIMIT, MAX_FIELD_CHARS };
