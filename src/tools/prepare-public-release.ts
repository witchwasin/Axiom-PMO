// `prepare-public-release`, ported from scripts/prepare-public-release.ps1.
// Non-destructive release readiness check; NEVER commits/pushes/tags.

import { readFileSync, existsSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { checkPublicHygiene } from "./check-public-hygiene.js";

export interface ReleaseResult {
  output: string;
  exitCode: number;
}

export function preparePublicRelease(repoRoot: string, runSuite: boolean): ReleaseResult {
  const repo = resolve(repoRoot);
  const releaseVersion = readFileSync(join(repo, "VERSION"), "utf8").trim();
  const expectedTag = `v${releaseVersion}`;

  const problems: string[] = [];
  const notes: string[] = [];
  const out: string[] = [];
  const section = (t: string) => { out.push("", `== ${t} ==`); };
  out.push(`Axiom-PMO public-release readiness (non-destructive): ${repo}`);

  section("Version consistency");
  const versionText = readFileSync(join(repo, "VERSION"), "utf8").trim();
  const changelogText = readFileSync(join(repo, "CHANGELOG.md"), "utf8");
  const changelogVersion = /^##\s+([^\s]+)\s+-/m.exec(changelogText)?.[1] ?? "";
  const configVersions: string[] = [];
  const pmoConfigDir = join(repo, "pmo-config");
  if (existsSync(pmoConfigDir)) {
    for (const f of readdirSync(pmoConfigDir).filter((f) => f.endsWith(".json")).sort()) {
      try {
        let raw = readFileSync(join(pmoConfigDir, f), "utf8");
        if (raw.charCodeAt(0) === 0xfeff) raw = raw.slice(1);
        const cfg = JSON.parse(raw);
        if (cfg["version"] !== undefined && cfg["version"] !== null) configVersions.push(String(cfg["version"]));
      } catch {}
    }
  }
  let pluginVersion = "";
  const pluginManifest = join(repo, ".claude-plugin/plugin.json");
  if (existsSync(pluginManifest)) {
    try { pluginVersion = String(JSON.parse(readFileSync(pluginManifest, "utf8"))["version"] ?? ""); } catch {}
  }
  const allVersions = [versionText, changelogVersion, ...configVersions, ...(pluginVersion ? [pluginVersion] : [])];
  // The reference sorts its distinct-version and config lists, so the drift
  // report line order is stable regardless of config file ordering.
  const distinctVersions = [...new Set(allVersions)].sort();
  if (distinctVersions.length === 1) {
    out.push(`OK: all version fields = ${versionText} (VERSION, CHANGELOG, ${configVersions.length} config file(s), plugin manifest)`);
  } else {
    problems.push(`Version drift: VERSION=${versionText} CHANGELOG=${changelogVersion} PLUGIN=${pluginVersion} CONFIG=${[...new Set(configVersions)].sort().join(",")}`);
    out.push(`FAIL: version drift (${distinctVersions.join(" / ")})`);
  }

  section("Public hygiene");
  const hygiene = checkPublicHygiene(repo);
  if (hygiene.exitCode !== 0) problems.push(`Public hygiene check failed (exit ${hygiene.exitCode})`);
  // The reference runs the hygiene check as a child whose report streams into
  // its own stdout; a port that swallowed that report would silently hide the
  // check it is reporting on. trimEnd so the join below contributes exactly the
  // one blank line the reference's trailing Write-Host "" produces.
  out.push(hygiene.output.trimEnd());

  section("Working tree");
  const status = spawnSync("git", ["-C", repo, "-c", "core.excludesFile=", "status", "--porcelain"], { encoding: "utf8" }).stdout ?? "";
  if (!status.trim()) out.push("Clean working tree.");
  else {
    notes.push("Working tree has uncommitted changes (expected during the overhaul).");
    out.push("Note: uncommitted changes present:");
    // The reference captures the child's stdout as PowerShell lines, which
    // never include a trailing empty element after the final newline; the raw
    // string here does, so drop it before printing (otherwise every dirty-tree
    // run carries a stray "  " line the reference does not have).
    const statusLines = status.split("\n");
    if (statusLines.length > 0 && statusLines[statusLines.length - 1] === "") statusLines.pop();
    for (const line of statusLines.slice(0, 20)) out.push(`  ${line}`);
  }

  if (runSuite) {
    section("Check suite");
    const suite = [
      { n: "doctor", f: "scripts/pmo-doctor.ps1", a: [] },
      { n: "fixtures", f: "scripts/run-validation-tests.ps1", a: ["-RepoPath", repo, "-VerifyGolden"] },
      { n: "example-goldens", f: "tests/golden/capture-examples.ps1", a: ["-Verify"] },
    ];
    for (const s of suite) {
      const r = spawnSync(process.env.AXIOM_PWSH ?? "pwsh", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", join(repo, s.f), ...s.a], { encoding: "utf8" });
      const code = r.status ?? 1;
      if (code !== 0) problems.push(`Check '${s.n}' failed (exit ${code})`);
      out.push(`${s.n}: exit ${code}`);
    }
  }

  section("Verdict");
  if (problems.length > 0) {
    out.push("NOT READY. Resolve the following before releasing:");
    for (const p of problems) out.push(`  - ${p}`);
  } else {
    out.push("Readiness checks passed.");
  }
  for (const n of notes) out.push(`  note: ${n}`);

  section("Release commands (review and run manually -- this script runs none of them)");
  out.push("git status");
  out.push("git diff --check");
  out.push("git add .");
  out.push(`git commit -m "release: publish Axiom-PMO ${releaseVersion}"`);
  out.push(`git tag -a ${expectedTag} -m "Axiom-PMO ${releaseVersion}"`);
  out.push("git push origin <release-branch>");
  out.push(`git push origin ${expectedTag}`);

  return { output: out.join("\n") + "\n", exitCode: problems.length > 0 ? 1 : 0 };
}
