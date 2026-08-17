#!/usr/bin/env node
// Executes one named CI suite for the risk-based `targeted` profile (Phase 9:
// replaces scripts/run-ci-suite.ps1, which is being deleted). A targeted CI
// dispatch narrows a run to one check instead of paying for the full
// `axiom check` pass. Each suite maps to the same in-process ported function
// run-all-checks.ts itself uses, or to spawning the one relevant *.test.js
// file directly.
//
// "golden" (tests/golden/capture-examples.ps1) is intentionally not a valid
// suite here, unlike src/tools/run-ci-suite.ts's resolveCiSuite (which still
// maps it for -ResolveOnly, the differential-proof artifact frozen against
// the PS reference) -- its coverage is carried forward by
// differential-probe.ts and validation-fixtures.ts, same as run-all-checks.ts
// already decided.
import { spawnSync } from "node:child_process";
import { resolve, join } from "node:path";
import { runPmoDoctor, formatDoctorText } from "../doctor/pmo-doctor.js";
import { checkPublicHygiene } from "./check-public-hygiene.js";
import { runValidationFixtures } from "./validation-fixtures.js";
import { buildPluginPackage } from "./build-plugin-package.js";
import { runAllChecks } from "./run-all-checks.js";
function takeOption(args, name) {
    const index = args.indexOf(`-${name}`);
    if (index === -1 || index + 1 >= args.length)
        return null;
    return args[index + 1];
}
function spawnTest(repo, relFile) {
    const r = spawnSync(process.execPath, ["--test", join(repo, relFile)], { stdio: "inherit" });
    return r.status ?? 1;
}
function spawnNode(repo, relFile) {
    const r = spawnSync(process.execPath, [join(repo, relFile)], { stdio: "inherit" });
    return r.status ?? 1;
}
function main() {
    const args = process.argv.slice(2);
    const suite = takeOption(args, "Suite");
    const repo = resolve(takeOption(args, "RepoPath") ?? ".");
    if (!suite) {
        console.log("[FAIL] CI-SUITE-001 Missing -Suite.");
        process.exit(1);
    }
    switch (suite) {
        case "doctor": {
            const r = runPmoDoctor(repo);
            console.log(formatDoctorText(repo, r));
            process.exit(r.fail > 0 ? 1 : 0);
            break;
        }
        case "hygiene": {
            const r = checkPublicHygiene(repo);
            console.log(r.output);
            process.exit(r.exitCode);
            break;
        }
        case "validation-fixtures": {
            const r = runValidationFixtures(repo, true);
            console.log(r.output);
            process.exit(r.exitCode);
            break;
        }
        case "plugin-drift": {
            const r = buildPluginPackage(repo, true);
            console.log(r.output);
            process.exit(r.exitCode);
            break;
        }
        case "config-mutation":
            process.exit(spawnTest(repo, "dist/tools/config-mutation.test.js"));
            break;
        case "line-ending":
            process.exit(spawnTest(repo, "dist/output/line-ending.test.js"));
            break;
        case "cli":
            process.exit(spawnNode(repo, "tests/helpers/cli-tests.mjs"));
            break;
        case "github-action":
            process.exit(spawnNode(repo, "tests/helpers/github-action-tests.mjs"));
            break;
        case "all": {
            const r = runAllChecks(repo, "");
            console.log(r.output);
            process.exit(r.exitCode);
            break;
        }
        default:
            console.log(`[FAIL] CI-SUITE-001 Unknown suite '${suite}'. Expected one of: all, cli, config-mutation, doctor, github-action, hygiene, line-ending, plugin-drift, validation-fixtures.`);
            process.exit(1);
    }
}
main();
