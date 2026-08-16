// `demo`, ported from scripts/demo.ps1. Three-minute proof: run the Handoff gate
// on broken + fixed demo projects. Spawns child validators via pwsh (the
// validate-project.ps1 reference), same as the original.
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { resolvePwsh } from "../probe/pwsh-resolver.js";
function writeRule(text) {
    const bar = "=".repeat(74);
    return `\n${bar}\n${text}\n${bar}\n\n`;
}
export function runDemo(repoRoot, plain, noPause) {
    const repo = resolve(repoRoot);
    const broken = join(repo, "demo/broken-project");
    const fixed = join(repo, "demo/fixed-project");
    for (const p of [broken, fixed]) {
        if (!existsSync(p))
            return { output: `Demo project not found: ${p}\n`, exitCode: 1 };
    }
    const out = [];
    const pwsh = resolvePwsh();
    function invokeChild(script, scriptArgs) {
        const r = spawnSync(pwsh, ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", join(repo, script), ...scriptArgs], { encoding: "utf8" });
        out.push(r.stdout ?? "");
        if (r.stderr)
            out.push(r.stderr);
        return r.status ?? 1;
    }
    const invokeGate = (projectPath, extra = []) => invokeChild("scripts/validate-project.ps1", ["-ProjectPath", projectPath, "-Mode", "Standard", "-Gate", "Handoff", ...extra]);
    const invokeAssess = (projectPath) => invokeChild("scripts/assess-handoff.ps1", ["-ProjectPath", projectPath, "-Mode", "Standard"]);
    out.push(writeRule("Axiom-PMO -- the Handoff gate in three minutes"));
    out.push("Two synthetic projects. Both have a PROJECT.md, a design, a work-item");
    out.push("board, and an approved Design Ready gate. Both would pass every gate");
    out.push("Axiom-PMO 1.0 could run.");
    out.push("");
    out.push("One of them cannot actually be built on Monday morning.");
    out.push(writeRule("1/3  demo/broken-project  --  scripts/validate-project.ps1 -Gate Handoff"));
    const brokenExit = invokeGate(broken);
    out.push("");
    out.push(`Exit code: ${brokenExit}`);
    out.push(writeRule("What those failures mean"));
    out.push("  HANDOFF-004  The shared schema every other item reads from is");
    out.push("               scheduled last. Two engineers would spend day one");
    out.push("               building against a table that does not exist yet.");
    out.push("  HANDOFF-012  The scan flow needs the rear camera and nobody decided");
    out.push("               how the page is served.");
    out.push("  HANDOFF-011  A data element the author marked sensitive has no");
    out.push("               classification decision attached.");
    out.push("  HANDOFF-007  An acceptance case has no seed data.");
    out.push("  HANDOFF-003  A work item is owned by 'Dev Team'.");
    out.push("");
    out.push("None of these are style violations. Each one costs days.");
    out.push(writeRule("2/3  demo/fixed-project  --  same command"));
    const fixedExit = invokeGate(fixed, ["-FailOnWarning"]);
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
