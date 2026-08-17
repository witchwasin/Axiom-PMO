#!/usr/bin/env node
// Interpreter-migration canary baseline.
//
// The canary measures the validation surface, not the CLI or the CI plumbing
// itself. The manifest is exactly this path set:
//
//   - src/**/*.ts
//   - scripts/**/*.ps1 (empty since the PowerShell reference was deleted in
//     Phase 9; kept so a reintroduced .ps1 script is caught, not silently
//     unwatched)
//   - pmo-config/*.json
//   - .ci/canary/compatibility-case-manifest.md
//   - tests/golden/**
//
// plus the git SHA the baseline was captured at. The hashing mechanism is the
// same one the migration's differential-proof work used (SHA-256 per file,
// committed manifest) -- same mechanism, continuous use. State lives under
// .ci/canary/ because it is CI-runtime state, not planning material; the
// internal migration planning records this used to cite (Fixed_plan/) were
// retired once the migration closed (see CHANGELOG.md).
//
// Commands:
//   --check   Recompute and diff against .ci/canary/canary-baseline.json.
//             Exit 0 if clean, 1 if the surface moved (prints the changed list).
//   --update  Re-capture the baseline at the current git SHA.
//   --record  Canary-run bookkeeping: compute the verdict, append the run line
//             (or the N RESET line + re-captured baseline) to canary-log.md,
//             and print the verdict with the consecutive-clean count. Exit 1 on
//             reset. A run counts toward N only when it is a qualifying run
//             (push-to-main full profile); pass the event name via the
//             CANARY_EVENT env var (CI sets it to github.event_name).
//             RESETs are logged and the baseline re-captured on ANY full run:
//             drift is drift, whatever event surfaced it.

import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, relative, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const BASELINE_PATH = join(ROOT, ".ci/canary/canary-baseline.json");
const LOG_PATH = join(ROOT, ".ci/canary/canary-log.md");
const MANIFEST_HOSTS = "windows-ps51,windows-ps7,linux,macos";

function walkFiles(dir) {
  const out = [];
  const walk = (d) => {
    for (const entry of readdirSync(d)) {
      const full = join(d, entry);
      if (statSync(full).isDirectory()) walk(full);
      else out.push(full);
    }
  };
  if (existsSync(dir)) walk(dir);
  return out;
}

function manifestPaths() {
  const paths = [];
  for (const f of walkFiles(join(ROOT, "src"))) {
    if (f.endsWith(".ts")) paths.push(relative(ROOT, f).replace(/\\/g, "/"));
  }
  for (const f of walkFiles(join(ROOT, "scripts"))) {
    if (f.endsWith(".ps1")) paths.push(relative(ROOT, f).replace(/\\/g, "/"));
  }
  const pmoConfig = join(ROOT, "pmo-config");
  if (existsSync(pmoConfig)) {
    for (const f of readdirSync(pmoConfig)) {
      if (f.endsWith(".json")) paths.push(`pmo-config/${f}`);
    }
  }
  paths.push(".ci/canary/compatibility-case-manifest.md");
  for (const f of walkFiles(join(ROOT, "tests/golden"))) {
    paths.push(relative(ROOT, f).replace(/\\/g, "/"));
  }
  return [...new Set(paths)].sort();
}

function sha256File(p) {
  return createHash("sha256").update(readFileSync(p)).digest("hex");
}

function computeHashes() {
  const files = {};
  for (const rel of manifestPaths()) files[rel] = sha256File(join(ROOT, rel));
  return files;
}

function gitSha() {
  const r = spawnSync("git", ["rev-parse", "HEAD"], { cwd: ROOT, encoding: "utf8" });
  return r.status === 0 ? r.stdout.trim() : "unknown";
}

function nodeVersion() {
  const r = spawnSync(process.execPath, ["--version"], { encoding: "utf8" });
  return r.status === 0 ? r.stdout.trim() : "unknown";
}

function readBaseline() {
  return JSON.parse(readFileSync(BASELINE_PATH, "utf8"));
}

function writeBaseline() {
  const baseline = {
    git_sha: gitSha(),
    captured_at: new Date().toISOString(),
    files: computeHashes(),
  };
  writeFileSync(BASELINE_PATH, JSON.stringify(baseline, null, 2) + "\n", "utf8");
  return baseline;
}

function check() {
  const baseline = readBaseline();
  const current = computeHashes();
  const changed = [];
  const allPaths = new Set([...Object.keys(baseline.files), ...Object.keys(current)]);
  for (const p of allPaths) {
    if (baseline.files[p] !== current[p]) changed.push(p);
  }
  return { changed, baselineSha: baseline.git_sha, currentSha: gitSha() };
}

function isQualifyingRun() {
  // CI passes github.event_name via CANARY_EVENT. Only push-to-main full runs
  // qualify; locally (no CANARY_EVENT) a record is treated as a
  // qualifying run so the mechanism is usable by hand.
  const event = process.env.CANARY_EVENT;
  if (!event) return true;
  return event === "push";
}

function trailingCleanRuns(logLines) {
  let n = 0;
  for (let i = logLines.length - 1; i >= 0; i--) {
    const m = /run clean N=(\d+)/.exec(logLines[i]);
    if (m && Number(m[1]) === n + 1) n = Number(m[1]);
    else break;
  }
  return n;
}

function appendLog(line) {
  const header = [
    "# Phase 7 Canary Log",
    "",
    "Qualifying run: a push-to-main CI run of the full profile with",
    "AXIOM_ROLLBACK_PWSH unset. N = consecutive clean qualifying",
    "runs; any validation-surface drift (canary-baseline.json mismatch) logs a",
    "RESET and restarts N at 0. Every qualifying run appends a line",
    "below; the appended lines are committed from the phase7-canary artifact by",
    "the maintainer -- this is a committed file. No external state store.",
    "",
  ].join("\n");
  const existing = existsSync(LOG_PATH) ? readFileSync(LOG_PATH, "utf8") : "";
  const body = existing.trim() === "" ? "" : existing.endsWith("\n") ? existing : existing + "\n";
  writeFileSync(LOG_PATH, (body === "" ? header : body) + line + "\n", "utf8");
}

function doRecord() {
  const { changed, baselineSha, currentSha } = check();
  const existing = existsSync(LOG_PATH) ? readFileSync(LOG_PATH, "utf8") : "";
  const logLines = existing.split("\n").filter((l) => l.trim() !== "");
  const n = trailingCleanRuns(logLines);
  const ts = new Date().toISOString();
  const sha7 = currentSha.slice(0, 7);

  if (changed.length === 0) {
    if (isQualifyingRun()) {
      const line = `${ts} run clean N=${n + 1} sha=${sha7} node=${nodeVersion()} hosts=${MANIFEST_HOSTS}`;
      appendLog(line);
      console.log(`CANARY CLEAN: consecutive clean qualifying runs N=${n + 1} (sha ${sha7})`);
    } else {
      console.log(`CANARY CLEAN (non-qualifying run, not counted): surface matches baseline ${baselineSha.slice(0, 7)}`);
    }
    return 0;
  }

  const line = `${ts} RESET N=${n}->0 sha=${sha7} changed=${changed.join(",")}`;
  appendLog(line);
  // Re-capture so the NEXT run has a correct comparison point.
  const baseline = writeBaseline();
  console.log(`CANARY RESET: N ${n}->0; validation surface changed since baseline ${baselineSha.slice(0, 7)} (HEAD ${sha7}):`);
  for (const c of changed) console.log(`  - ${c}`);
  console.log(`baseline re-captured at ${baseline.git_sha.slice(0, 7)} -- commit .ci/canary/canary-baseline.json + canary-log.md`);
  return 1;
}

const args = process.argv.slice(2);

if (args.includes("--check")) {
  const { changed, baselineSha, currentSha } = check();
  if (changed.length === 0) {
    console.log(`CANARY CLEAN: surface matches baseline ${baselineSha.slice(0, 7)} (HEAD ${currentSha.slice(0, 7)})`);
    process.exitCode = 0;
  } else {
    console.log(`CANARY RESET: surface differs from baseline ${baselineSha.slice(0, 7)} (HEAD ${currentSha.slice(0, 7)}):`);
    for (const c of changed) console.log(`  - ${c}`);
    process.exitCode = 1;
  }
} else if (args.includes("--update")) {
  const baseline = writeBaseline();
  console.log(`canary baseline re-captured at ${baseline.git_sha.slice(0, 7)}: ${Object.keys(baseline.files).length} files hashed`);
} else if (args.includes("--record")) {
  process.exitCode = doRecord();
} else {
  console.error("usage: node scripts/canary-baseline.mjs --check | --update | --record");
  process.exitCode = 64;
}
