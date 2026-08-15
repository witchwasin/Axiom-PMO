// File/directory presence checks and the Mode x Gate artifact matrix, ported
// from scripts/lib/artifact-policy.ps1.

import { readFileSync, existsSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { addResult } from "./result-writer.js";
import type { ResultAccumulator, ValidationRules } from "./context.js";
import type { Mode, Gate } from "./types.js";

function testFile(acc: ResultAccumulator, catalog: ValidationRules | undefined, project: string, relativePath: string, requirement: "required" | "optional"): boolean {
  const path = join(project, relativePath);
  if (existsSync(path) && statSync(path).isFile()) {
    addResult(acc, catalog, "PASS", `Found ${relativePath}`, { ruleId: "STRUCT-001" });
    return true;
  }
  if (requirement === "required") {
    addResult(acc, catalog, "FAIL", `Missing ${relativePath}`, { ruleId: "STRUCT-001" });
  } else {
    addResult(acc, catalog, "INFO", `Missing optional file ${relativePath}`, { ruleId: "STRUCT-001" });
  }
  return false;
}

function testDir(acc: ResultAccumulator, catalog: ValidationRules | undefined, project: string, relativePath: string, requirement: "required" | "optional"): boolean {
  const path = join(project, relativePath);
  if (existsSync(path) && statSync(path).isDirectory()) {
    addResult(acc, catalog, "PASS", `Found ${relativePath}/`, { ruleId: "STRUCT-001" });
    return true;
  }
  if (requirement === "required") {
    addResult(acc, catalog, "FAIL", `Missing ${relativePath}/`, { ruleId: "STRUCT-001" });
  } else {
    addResult(acc, catalog, "INFO", `Missing optional directory ${relativePath}/`, { ruleId: "STRUCT-001" });
  }
  return false;
}

export function getProjectText(project: string): string {
  const path = join(project, "PROJECT.md");
  if (existsSync(path)) return readFileSync(path, "utf8");
  return "";
}

function isUserSourcePath(relativePath: string): boolean {
  // Port of Test-UserSourcePath's core: source/, MOM/, REQ/, Transcript/, Others/.
  return /(^|[\\/])(source|MOM|REQ|Transcript|Others)[\\/]/.test(relativePath);
}

export interface ProjectFileSets {
  allProjectFiles: string[];
  allTextFiles: string[];
  governedFiles: string[];
  userSourceFiles: string[];
}

const TEXT_EXTENSIONS = [".md", ".yaml", ".yml", ".puml", ".html"];

export function getProjectFileSets(project: string): ProjectFileSets {
  const allProjectFiles: string[] = [];
  const walk = (dir: string) => {
    for (const entry of readdirSync(dir)) {
      const full = join(dir, entry);
      let st;
      try {
        st = statSync(full);
      } catch {
        continue;
      }
      if (st.isDirectory()) walk(full);
      else if (st.isFile()) allProjectFiles.push(full);
    }
  };
  walk(project);

  const allTextFiles = allProjectFiles.filter((f) => TEXT_EXTENSIONS.some((e) => f.toLowerCase().endsWith(e)));
  const governedFiles: string[] = [];
  const userSourceFiles: string[] = [];
  for (const f of allTextFiles) {
    const rel = relative(project, f);
    if (isUserSourcePath(rel)) userSourceFiles.push(f);
    else governedFiles.push(f);
  }
  return { allProjectFiles, allTextFiles, governedFiles, userSourceFiles };
}

export function testRequiredArtifacts(
  acc: ResultAccumulator,
  catalog: ValidationRules | undefined,
  project: string,
  mode: Mode,
  gate: Gate,
  artifactPolicy: Record<string, unknown>,
  taskSourceIsGithub: boolean,
): void {
  testFile(acc, catalog, project, "PROJECT.md", "required");

  const matrixRequired: string[] = [];
  const modeMatrix = (artifactPolicy["artifact_matrix"] as Record<string, unknown> | undefined)?.[mode] as Record<string, unknown> | undefined;
  if (modeMatrix?.[gate]) {
    matrixRequired.push(...(modeMatrix[gate] as string[]));
  }

  const deliveryOptionalViaGithub = taskSourceIsGithub && matrixRequired.includes("DELIVERY.md");

  const allTrackedArtifacts = ["DELIVERY.md", "RELEASE.md", "RAID-log.md", "decision-log.md", "DESIGN", "RTM.json", "HANDOFF.md", "DESIGN/BUILD-SPEC.md"];
  for (const artifact of allTrackedArtifacts) {
    let requirement: "required" | "optional" = matrixRequired.includes(artifact) ? "required" : "optional";
    if (artifact === "DELIVERY.md" && deliveryOptionalViaGithub) requirement = "optional";
    if ((artifact === "HANDOFF.md" || artifact === "DESIGN/BUILD-SPEC.md") && requirement === "optional") continue;
    if (artifact === "DESIGN") {
      testDir(acc, catalog, project, "DESIGN", requirement);
    } else {
      testFile(acc, catalog, project, artifact, requirement);
    }
  }
  testDir(acc, catalog, project, "source", "optional");

  if (deliveryOptionalViaGithub && !existsSync(join(project, "DELIVERY.md"))) {
    addResult(acc, catalog, "WARN", "Task source is GitHub Issues; DELIVERY.md is absent, so work-item completion cannot be verified offline (check the GitHub board / CI)", { ruleId: "TASK-003", blocking: false });
  }
}

export function testGithubTaskSource(project: string): boolean {
  const path = join(project, "PROJECT.md");
  if (!existsSync(path)) return false;
  const text = readFileSync(path, "utf8");
  const isGithub = /^[ \t]*>?[ \t]*Task source:[ \t]*github[ \t]*\r?$/m.test(text);
  const hasRepo = /^[ \t]*github_repository:[ \t]*\S+/m.test(text);
  return isGithub && hasRepo;
}
