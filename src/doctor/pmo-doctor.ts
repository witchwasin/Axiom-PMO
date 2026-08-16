// pmo-doctor, ported from scripts/pmo-doctor.ps1. Framework self-audit:
// DOCTOR-* (rule catalog, versions, skills) and PERMISSION-* (.claude/settings,
// .gitignore). Output is Text (level/rule_id/message rows).

import { readFileSync, existsSync, statSync, readdirSync } from "node:fs";
import { join, dirname, basename } from "node:path";
import { getMarkdownFiles, readMarkdownText, testMarkdownLocalLinkPath } from "../markdown/files.js";
import { sortOrdinal } from "../core/ordinal-sort.js";
import { testFrameworkCheckout, frameworkCheckoutFailureMessage } from "../core/framework-checkout.js";

interface DoctorRow { level: "PASS" | "WARN" | "FAIL"; rule_id: string; message: string; }

export interface DoctorResult {
  rows: DoctorRow[];
  pass: number;
  warn: number;
  fail: number;
  frameworkCheckoutFailure?: string;
}

function loadJson(repo: string, rel: string): Record<string, unknown> | null {
  const path = join(repo, rel);
  if (!existsSync(path)) return null;
  try {
    let raw = readFileSync(path, "utf8");
    if (raw.charCodeAt(0) === 0xfeff) raw = raw.slice(1); // strip BOM (CR-019)
    return JSON.parse(raw) as Record<string, unknown>;
  } catch { return null; }
}

export function runPmoDoctor(repo: string, skillRootOverride = "", templateRootOverride = ""): DoctorResult {
  if (!testFrameworkCheckout(repo)) {
    return { rows: [], pass: 0, warn: 0, fail: 1, frameworkCheckoutFailure: frameworkCheckoutFailureMessage(repo, "pmo-doctor") };
  }
  const rows: DoctorRow[] = [];
  let pass = 0, warn = 0, fail = 0;
  const add = (level: "PASS" | "WARN" | "FAIL", message: string, ruleId = "DOCTOR-000") => {
    rows.push({ level, rule_id: ruleId, message });
    if (level === "PASS") pass++; else if (level === "WARN") warn++; else fail++;
  };

  const policy = loadJson(repo, "pmo-config/policy.json");
  const skillManifest = loadJson(repo, "pmo-config/skill-manifest.json");
  const validationRules = loadJson(repo, "pmo-config/validation-rules.json");
  const handoffPolicy = loadJson(repo, "pmo-config/handoff-policy.json");
  const orchestrationPolicy = loadJson(repo, "pmo-config/orchestration-policy.json");
  const diagnosticsSchema = loadJson(repo, "pmo-config/diagnostics-schema.json");
  const onboardingQuestions = loadJson(repo, "pmo-config/onboarding-questions.json");
  const contextMapConfig = loadJson(repo, "pmo-config/context-map.json");

  const requireFile = (rel: string) => {
    if (existsSync(join(repo, rel))) add("PASS", `Found ${rel}`, "DOCTOR-STRUCT");
    else add("FAIL", `Missing ${rel}`, "DOCTOR-STRUCT");
  };

  for (const f of ["AGENTS.md", "CLAUDE.md", "VERSION", "CHANGELOG.md", "README.md", "TESTING.md", "SECURITY.md", "MIGRATION.md", "CONTEXT-ROUTER.md",
    "pmo-config/context-map.json", "pmo-config/policy.json", "pmo-config/skill-manifest.json", "pmo-config/validation-rules.json",
    "pmo-config/artifact-policy.json", "pmo-config/reference-types.json", "pmo-config/orchestration-policy.json",
    "scripts/validate-project.ps1", "scripts/pmo-doctor.ps1", "scripts/run-validation-tests.ps1", "scripts/run-all-checks.ps1",
    "scripts/new-project.ps1", "scripts/update-source-snapshot.ps1", "scripts/measure-context.ps1"]) {
    requireFile(f);
  }
  for (const name of ["PROJECT.md", "DELIVERY.md", "RELEASE.md", "RAID-log.md", "decision-log.md", "RTM.json", "WIREFRAME.md"]) {
    requireFile(join("templates", name));
  }
  for (const name of ["LITE-BUGFIX", "STANDARD-FEATURE", "STRICT-HIGH-RISK", "P01-DEMO"]) {
    const examplePath = join("examples", name);
    if (existsSync(join(repo, examplePath)) && statSync(join(repo, examplePath)).isDirectory()) add("PASS", `Found ${examplePath}`, "DOCTOR-EXAMPLE");
    else add("FAIL", `Missing ${examplePath}`, "DOCTOR-EXAMPLE");
  }

  const activeSkills = ((skillManifest?.["active_skills"] as Array<Record<string, unknown>>) ?? []).map((s) => String(s["id"]));
  if (activeSkills.length === 0) add("FAIL", "No active skills declared in pmo-config/skill-manifest.json", "DOCTOR-001");
  const skillsRoot = skillRootOverride ? skillRootOverride : join(repo, ".claude/skills");
  let actualSkills: string[] = [];
  if (existsSync(skillsRoot) && statSync(skillsRoot).isDirectory()) {
    actualSkills = readdirSync(skillsRoot).filter((e) => statSync(join(skillsRoot, e)).isDirectory());
  }

  const missingActive = activeSkills.filter((s) => !actualSkills.includes(s));
  const extraActive = actualSkills.filter((s) => !activeSkills.includes(s));
  if (missingActive.length === 0 && extraActive.length === 0) add("PASS", "Active skill runtime contains exactly 7 skills", "DOCTOR-001");
  else {
    if (missingActive.length > 0) add("FAIL", `Missing active skills: ${missingActive.join(", ")}`, "DOCTOR-001");
    if (extraActive.length > 0) add("FAIL", `Unexpected active skills: ${extraActive.join(", ")}`, "DOCTOR-001");
  }

  // Test-SkillFrontmatter (DOCTOR-SKILL-001)
  {
    const problems: string[] = [];
    for (const skill of activeSkills) {
      const skillFile = join(skillsRoot, skill, "SKILL.md");
      if (!existsSync(skillFile)) { problems.push(`${skill} missing SKILL.md`); continue; }
      const text = readFileSync(skillFile, "utf8");
      const fmMatch = /^---\s*\r?\n([\s\S]*?)\r?\n---/.exec(text);
      if (!fmMatch) { problems.push(`${skill} missing YAML frontmatter`); continue; }
      const frontmatter = fmMatch[1]!;
      const nameMatch = /^\s*name:\s*(.+?)\s*$/m.exec(frontmatter);
      const descriptionMatch = /^\s*description:\s*(.+?)\s*$/m.exec(frontmatter);
      if (!nameMatch) problems.push(`${skill} missing frontmatter name`);
      else if (nameMatch[1]!.trim() !== skill) problems.push(`${skill} frontmatter name does not match folder`);
      if (!descriptionMatch || descriptionMatch[1]!.trim().length < 12) problems.push(`${skill} missing useful frontmatter description`);
    }
    if (problems.length === 0) add("PASS", "Active skill frontmatter is valid", "DOCTOR-SKILL-001");
    else add("FAIL", `Active skill frontmatter problems: ${problems.slice(0, 8).join("; ")}`, "DOCTOR-SKILL-001");
  }

  // TABLE-001
  {
    const templateRoot = templateRootOverride ? templateRootOverride : join(repo, "templates");
    const problems: string[] = [];
    if (existsSync(templateRoot)) {
      for (const file of getMarkdownFiles(templateRoot)) {
        const lines = readFileSync(file, "utf8").split(/\r?\n/);
        let tableStart = -1;
        let tableLines: string[] = [];
        for (let i = 0; i <= lines.length; i++) {
          const line = i < lines.length ? lines[i]! : "";
          if (/^\s*\|/.test(line)) {
            if (tableStart < 0) tableStart = i + 1;
            tableLines.push(line);
            continue;
          }
          if (tableLines.length > 0) {
            if (tableLines.length >= 2) {
              const headerCount = tableLines[0]!.split("|").length - 2;
              for (let j = 1; j < tableLines.length; j++) {
                const cellCount = tableLines[j]!.split("|").length - 2;
                if (cellCount !== headerCount) problems.push(`${file} line ${tableStart + j}: expected ${headerCount} columns, got ${cellCount}`);
              }
            }
            tableStart = -1;
            tableLines = [];
          }
        }
      }
    }
    if (problems.length === 0) add("PASS", "Markdown table column counts are consistent", "TABLE-001");
    else add("FAIL", `Markdown table column mismatch: ${problems.slice(0, 8).join("; ")}`, "TABLE-001");
  }

  // DOCTOR-003 context map
  const cr = contextMapConfig?.["config_refs"] as Record<string, unknown> | undefined;
  if (contextMapConfig && cr && cr["policy"] === "pmo-config/policy.json" && cr["skill_manifest"] === "pmo-config/skill-manifest.json" && cr["validation_rules"] === "pmo-config/validation-rules.json" && cr["orchestration_policy"] === "pmo-config/orchestration-policy.json") {
    add("PASS", "Context map references central policy and skill manifest", "DOCTOR-003");
  } else {
    add("FAIL", "Context map must reference JSON runtime config files", "DOCTOR-003");
  }
  const rulesObj = (validationRules?.["rules"] as Record<string, unknown>) ?? {};
  if (rulesObj["STRUCT-001"] && rulesObj["ENUM-001"] && rulesObj["DOCTOR-001"]) add("PASS", "Validation rule catalog parses from JSON runtime config", "DOCTOR-003");
  else add("FAIL", "Validation rule catalog is missing required runtime rules", "DOCTOR-003");
  const research = (orchestrationPolicy?.["research"] as Record<string, unknown>) ?? {};
  const uiDelivery = (orchestrationPolicy?.["ui_delivery"] as Record<string, unknown>) ?? {};
  const externalization = (orchestrationPolicy?.["externalization"] as Record<string, unknown>) ?? {};
  const changeControl = (orchestrationPolicy?.["change_control"] as Record<string, unknown>) ?? {};
  if (orchestrationPolicy && ((research["modes"] as unknown[]) ?? []).length > 0 && ((research["depths"] as unknown[]) ?? []).length > 0 && ((research["providers"] as unknown[]) ?? []).length > 0 && ((uiDelivery["values"] as unknown[]) ?? []).length > 0 && ((externalization["classifications"] as unknown[]) ?? []).length > 0 && ((changeControl["classifications"] as unknown[]) ?? []).length > 0) {
    add("PASS", "Orchestration policy exposes the required optional-workflow enums", "DOCTOR-003");
  } else {
    add("FAIL", "Orchestration policy is missing required optional-workflow enums", "DOCTOR-003");
  }

  // DOCTOR-005 version
  const versionText = readFileSync(join(repo, "VERSION"), "utf8").trim();
  const changelogText = readFileSync(join(repo, "CHANGELOG.md"), "utf8");
  const changelogFirstVersion = /^##\s+([^\s]+)\s+-/m.exec(changelogText)?.[1] ?? "";
  const configVersions = [policy?.["version"], skillManifest?.["version"], validationRules?.["version"], contextMapConfig?.["version"], handoffPolicy?.["version"], orchestrationPolicy?.["version"], diagnosticsSchema?.["version"]].filter(Boolean).map(String);
  if (versionText === changelogFirstVersion && configVersions.every((v) => v === versionText)) {
    add("PASS", "VERSION, CHANGELOG, and JSON config versions match", "DOCTOR-005");
  } else {
    add("FAIL", `Version drift: VERSION=${versionText} CHANGELOG=${changelogFirstVersion} CONFIG=${configVersions.join(",")}`, "DOCTOR-005");
  }

  // DOCTOR-006 schema_version
  const supportedSchemaVersion = "1.0";
  const schemaVersionConfigs: Record<string, Record<string, unknown> | null> = {
    "policy.json": policy, "artifact-policy.json": loadJson(repo, "pmo-config/artifact-policy.json"), "reference-types.json": loadJson(repo, "pmo-config/reference-types.json"),
    "skill-manifest.json": skillManifest, "validation-rules.json": validationRules, "context-map.json": contextMapConfig,
    "handoff-policy.json": handoffPolicy, "diagnostics-schema.json": diagnosticsSchema, "onboarding-questions.json": onboardingQuestions, "orchestration-policy.json": orchestrationPolicy,
  };
  const schemaVersionProblems: string[] = [];
  for (const [name, cfg] of Object.entries(schemaVersionConfigs)) {
    if (!cfg) continue;
    if (!cfg["schema_version"]) schemaVersionProblems.push(`${name} is missing schema_version`);
    else if (cfg["schema_version"] !== supportedSchemaVersion) schemaVersionProblems.push(`${name} has unsupported schema_version ${cfg["schema_version"]} (expected ${supportedSchemaVersion})`);
  }
  if (schemaVersionProblems.length === 0) add("PASS", `All pmo-config/*.json carry a supported schema_version (${supportedSchemaVersion})`, "DOCTOR-006");
  else add("FAIL", `Config schema_version problems: ${schemaVersionProblems.join("; ")}`, "DOCTOR-006");

  // DOCTOR-007 rule catalog reconciliation
  const emitterFiles = [join(repo, "scripts/validate-project.ps1"), join(repo, "scripts/pmo-doctor.ps1")];
  const libDir = join(repo, "scripts/lib");
  if (existsSync(libDir) && statSync(libDir).isDirectory()) {
    for (const f of readdirSync(libDir)) {
      if (f.endsWith(".ps1")) emitterFiles.push(join(libDir, f));
    }
  }
  const emittedRuleIds = new Set<string>();
  for (const file of emitterFiles) {
    if (!existsSync(file)) continue;
    for (const line of readFileSync(file, "utf8").split(/\r?\n/)) {
      if (!/Add-Result|Test-ReviewRow|\$RuleId\s*=/.test(line)) continue;
      for (const m of line.matchAll(/"([A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+)"/g)) emittedRuleIds.add(m[1]!);
    }
  }
  const catalogRuleIds = Object.keys(rulesObj);
  const missingFromCatalog = [...emittedRuleIds].filter((id) => !catalogRuleIds.includes(id)).sort();
  const deadCatalogEntries = catalogRuleIds.filter((id) => !emittedRuleIds.has(id)).sort();
  if (missingFromCatalog.length === 0 && deadCatalogEntries.length === 0) add("PASS", "Validation rule catalog matches the rule ids emitted by the scripts", "DOCTOR-007");
  else {
    if (missingFromCatalog.length > 0) add("FAIL", `Rule ids emitted but missing from validation-rules.json: ${missingFromCatalog.join(", ")}`, "DOCTOR-007");
    if (deadCatalogEntries.length > 0) add("FAIL", `Dead catalog entries (in validation-rules.json but never emitted): ${deadCatalogEntries.join(", ")}`, "DOCTOR-007");
  }

  // DOCTOR-008 suggestion
  const actionableSeverities = ["fail", "fail_release", "warn"];
  const rulesWithoutSuggestion: string[] = [];
  for (const [name, entry] of Object.entries(rulesObj)) {
    const e = entry as Record<string, unknown>;
    if (!actionableSeverities.includes(String(e["severity"] ?? ""))) continue;
    if (String(e["suggestion"] ?? "").trim() === "") rulesWithoutSuggestion.push(name);
  }
  if (rulesWithoutSuggestion.length === 0) add("PASS", "Every fail/warn rule in the catalog carries a suggestion", "DOCTOR-008");
  else add("FAIL", `Rules missing a suggestion: ${sortOrdinal(rulesWithoutSuggestion).join(", ")}`, "DOCTOR-008");

  // DOCTOR-009 documentation
  const rulesWithBrokenDocs: string[] = [];
  for (const [name, entry] of Object.entries(rulesObj)) {
    const docPath = String((entry as Record<string, unknown>)["documentation"] ?? "");
    if (!docPath.trim()) continue;
    if (!existsSync(join(repo, docPath))) rulesWithBrokenDocs.push(`${name} -> ${docPath}`);
  }
  if (rulesWithBrokenDocs.length === 0) add("PASS", "Every rule documentation path resolves to a file", "DOCTOR-009");
  else add("FAIL", `Rules with unresolvable documentation: ${sortOrdinal(rulesWithBrokenDocs).join(", ")}`, "DOCTOR-009");

  // DOCTOR-013 onboarding questions
  if (policy && onboardingQuestions) {
    const declaredTriggers = ((policy["enums"] as Record<string, unknown>)?.["strict_triggers"] as string[]) ?? [];
    const questionKeys = Object.keys((onboardingQuestions["questions"] as Record<string, unknown>) ?? {});
    const triggersWithoutQuestion = declaredTriggers.filter((t) => !questionKeys.includes(t));
    const questionsWithoutTrigger = questionKeys.filter((q) => !declaredTriggers.includes(q));
    if (triggersWithoutQuestion.length === 0 && questionsWithoutTrigger.length === 0) add("PASS", `onboarding-questions.json covers exactly the declared strict triggers (${declaredTriggers.length})`, "DOCTOR-013");
    else {
      if (triggersWithoutQuestion.length > 0) add("FAIL", `Strict triggers with no onboarding question: ${sortOrdinal(triggersWithoutQuestion).join(", ")}`, "DOCTOR-013");
      if (questionsWithoutTrigger.length > 0) add("FAIL", `onboarding-questions.json entries for triggers no longer declared: ${sortOrdinal(questionsWithoutTrigger).join(", ")}`, "DOCTOR-013");
    }
  } else {
    add("FAIL", "policy.json or onboarding-questions.json could not be loaded", "DOCTOR-013");
  }

  // DOCTOR-014 lifecycle
  const blockingSeverities = ["fail", "fail_release"];
  const experimentalBlocking: string[] = [];
  for (const [name, entry] of Object.entries(rulesObj)) {
    const e = entry as Record<string, unknown>;
    if (e["lifecycle"] === undefined) continue;
    if (String(e["lifecycle"]) !== "experimental") continue;
    if (blockingSeverities.includes(String(e["severity"] ?? ""))) experimentalBlocking.push(name);
  }
  if (experimentalBlocking.length === 0) add("PASS", "No experimental rule carries a blocking severity", "DOCTOR-014");
  else add("FAIL", `Experimental rules with a blocking severity (promotion to enforced requires a DEC-### and a ROADMAP.md entry first): ${sortOrdinal(experimentalBlocking).join(", ")}`, "DOCTOR-014");

  // PERMISSION-* from .claude/settings.json
  const settingsPath = join(repo, ".claude/settings.json");
  if (existsSync(settingsPath)) {
    const settings = readFileSync(settingsPath, "utf8");
    let settingsJson: Record<string, unknown> | null = null;
    try { settingsJson = JSON.parse(settings); add("PASS", ".claude/settings.json parses as JSON", "PERMISSION-000"); }
    catch { add("FAIL", ".claude/settings.json is not valid JSON", "PERMISSION-000"); }

    const permissions = (settingsJson?.["permissions"] as Record<string, unknown>) ?? {};
    const allowEntries = (permissions["allow"] as unknown[] ?? []).map(String);
    const askEntries = (permissions["ask"] as unknown[] ?? []).map(String);
    const denyEntries = (permissions["deny"] as unknown[] ?? []).map(String);

    const allowText = allowEntries.join("\n");
    if (/git push|git commit|git tag/.test(allowText)) add("FAIL", ".claude/settings.json still allows git push/commit/tag", "PERMISSION-001");
    else add("PASS", ".claude/settings.json does not allow git push/commit/tag by default", "PERMISSION-001");

    const askText = askEntries.join("\n");
    if (/git push/.test(askText) && /git commit/.test(askText) && /git tag/.test(askText)) add("PASS", ".claude/settings.json asks before git commit/push/tag", "PERMISSION-003");
    else add("FAIL", ".claude/settings.json should ask before git commit/push/tag", "PERMISSION-003");

    const denyText = denyEntries.join("\n");
    if (/\.env/.test(denyText) && /\.pem/.test(denyText) && /\.pfx/.test(denyText) && /id_rsa/.test(denyText) && /id_ed25519/.test(denyText)) add("PASS", ".claude/settings.json denies common secret and private key paths", "PERMISSION-004");
    else add("FAIL", ".claude/settings.json should deny common secret and private key paths", "PERMISSION-004");

    if (settingsJson && settingsJson["disableBypassPermissionsMode"] === "disable") add("PASS", ".claude/settings.json disables bypass permissions mode", "PERMISSION-005");
    else add("FAIL", ".claude/settings.json should disable bypass permissions mode", "PERMISSION-005");

    if (/scripts\/pmo-doctor\.ps1/.test(allowText)) add("PASS", ".claude/settings.json allows the framework doctor command", "PERMISSION-002");
    else add("FAIL", ".claude/settings.json does not allow scripts/pmo-doctor.ps1", "PERMISSION-002");
    if (/scripts\/run-validation-tests\.ps1/.test(allowText)) add("PASS", ".claude/settings.json allows the validation fixture test command", "PERMISSION-002");
    else add("FAIL", ".claude/settings.json does not allow scripts/run-validation-tests.ps1", "PERMISSION-002");

    if (/\bWebSearch\b/.test(allowText)) add("FAIL", ".claude/settings.json allows WebSearch without approval", "PERMISSION-006");
    else if (/\bWebSearch\b/.test(askText)) add("PASS", ".claude/settings.json asks before WebSearch", "PERMISSION-006");
    else add("WARN", ".claude/settings.json does not mention WebSearch", "PERMISSION-006");

    if (settings.includes("echo 'PMO-")) add("FAIL", "Fake PMO echo hooks still exist", "DOCTOR-HOOK");
    else add("PASS", "No fake PMO echo hooks found in settings", "DOCTOR-HOOK");
  } else {
    add("WARN", ".claude/settings.json not found", "PERMISSION-002");
  }

  // PERMISSION-007 gitignore
  const gitignorePath = join(repo, ".gitignore");
  if (existsSync(gitignorePath)) {
    const gitignore = readFileSync(gitignorePath, "utf8");
    const requiredIgnorePatterns = [".env", ".env.*", "*.pem", "*.key", "*.pfx", "*.p12", "id_rsa", "id_ed25519"];
    const missingIgnores = requiredIgnorePatterns.filter((p) => !new RegExp(`^${p.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\r?$`, "m").test(gitignore));
    const staleIgnores = ["P13-RR-EWALLET/Others/Figma Flow/", "P*/SystemFlow/PDF_*/"].filter((s) => gitignore.includes(s));
    if (missingIgnores.length === 0 && staleIgnores.length === 0 && !/\*\*\/\*secret\*|\*\*\/\*credential\*/.test(gitignore)) add("PASS", ".gitignore uses precise sensitive-file patterns", "PERMISSION-007");
    else add("FAIL", `.gitignore sensitive patterns need cleanup: missing=${missingIgnores.join(",")} stale=${staleIgnores.join(",")}`, "PERMISSION-007");
  }

  // DOCTOR-002 legacy skills
  const claude = readMarkdownText(join(repo, "CLAUDE.md"));
  const agent = readMarkdownText(join(repo, "AGENTS.md"));
  const legacySkillNames = ["pmo-analyze-new-mom", "pmo-gap-analysis", "pmo-activity-diagram", "pmo-dev-handoff", "pmo-qa-report", "pmo-git-push", "pmo-task-breakdown", "pmo-wireframe-design", "pmo-workflow-architect", "pmo-use-case-diagram"];
  for (const skill of legacySkillNames) {
    if (claude.includes(skill) || agent.includes(skill)) add("FAIL", `Router or core rules reference archived legacy skill: ${skill}`, "DOCTOR-002");
  }

  // DOCTOR-004 legacy patterns in active skills
  const legacyPatterns = ["SystemFlow", "UserFlow", "TaskBreakdown"];
  const loggingEveryPattern = /Logging every|log every/;
  for (const skill of actualSkills) {
    const skillPath = join(skillsRoot, skill);
    const hits: string[] = [];
    for (const file of getMarkdownFiles(skillPath)) {
      const content = readFileSync(file, "utf8");
      for (const pattern of legacyPatterns) {
        if (content.includes(pattern)) hits.push(`${skill}/${basename(file)}:${pattern}`);
      }
      const loggingLines = content.split(/\r?\n/).filter((l) => loggingEveryPattern.test(l));
      const unprohibited = loggingLines.filter((l) => !/\b(do not|never|avoid|without)\b/i.test(l));
      if (unprohibited.length > 0) hits.push(`${skill}/${basename(file)}:log every`);
    }
    if (hits.length > 0) add("FAIL", `Active skill has legacy rule references: ${hits.slice(0, 5).join(", ")}`, "DOCTOR-004");
  }

  // Broken links (DOCTOR-000 default)
  const links: string[] = [];
  for (const file of getMarkdownFiles(repo)) {
    const relFile = file.substring(repo.length).replace(/^[/\\]/, "");
    if (/^tests[\\/]fixtures[\\/]invalid-/.test(relFile)) continue;
    if (/(^|[\\/])(source|MOM|REQ|Transcript)[\\/]/.test(relFile)) continue;
    const content = readFileSync(file, "utf8");
    for (const m of content.matchAll(/\[[^\]]+\]\((?!https?:\/\/)([^)#]+)(?:#[^)]+)?\)/g)) {
      const target = m[1]!;
      if (/^\s*$|^mailto:|^</.test(target)) continue;
      const base = dirname(file);
      const pathResult = testMarkdownLocalLinkPath(base, target);
      if (!pathResult.validPath) {
        const lineNumber = 1 + content.substring(0, m.index).split(/\r\n|\n|\r/).length - 1;
        links.push(`${relFile} line ${lineNumber} -> invalid local link target`);
      } else if (!pathResult.exists) {
        links.push(`${relFile} -> ${target}`);
      }
    }
  }
  if (links.length === 0) add("PASS", "No broken local markdown links found");
  else add("WARN", `Broken local links: ${links.slice(0, 8).join(", ")}`);

  return { rows, pass, warn, fail };
}

export function formatDoctorText(repo: string, result: DoctorResult): string {
  const lines: string[] = [];
  lines.push(`Axiom-PMO Framework Doctor: ${repo}`);
  lines.push("");
  if (result.frameworkCheckoutFailure) {
    lines.push(result.frameworkCheckoutFailure);
    return lines.join("\n");
  }
  for (const row of result.rows) lines.push(`[${row.level}] ${row.rule_id} ${row.message}`);
  lines.push("");
  lines.push(`Summary: PASS=${result.pass} WARN=${result.warn} FAIL=${result.fail}`);
  return lines.join("\n");
}
