#!/usr/bin/env node
// CLI wrapper for ci-profile.ts, ported from scripts/ci-profile.ps1's own
// command-line surface (Phase 9: replaces that script as the CI workflow's
// profile-resolution step). Prints a single-line JSON object on stdout,
// matching the reference exactly, and optionally appends
// profile/suite/hosts/reason/matrix lines to $GITHUB_OUTPUT.
import { readFileSync, existsSync, appendFileSync } from "node:fs";
import { resolveCiProfile, resolveDispatchProfile, getCiMatrixJson } from "./ci-profile.js";
function takeOption(args, name) {
    const index = args.indexOf(`-${name}`);
    if (index === -1 || index + 1 >= args.length)
        return null;
    return args[index + 1];
}
function takeFlag(args, name) {
    return args.includes(`-${name}`);
}
function main() {
    const args = process.argv.slice(2);
    const profileArg = takeOption(args, "Profile");
    const targetHost = takeOption(args, "TargetHost") ?? "";
    const suite = takeOption(args, "Suite") ?? "";
    const changedPathsPath = takeOption(args, "ChangedPathsPath");
    const githubOutput = takeFlag(args, "GithubOutput");
    let result;
    if (profileArg) {
        if (profileArg !== "fast" && profileArg !== "targeted" && profileArg !== "full") {
            throw new Error(`Invalid -Profile '${profileArg}'. Expected fast, targeted, or full.`);
        }
        result = resolveDispatchProfile(profileArg, targetHost, suite);
    }
    else {
        let paths = [];
        if (changedPathsPath && existsSync(changedPathsPath)) {
            paths = readFileSync(changedPathsPath, "utf8").split("\n").filter((l) => l.trim());
        }
        result = resolveCiProfile(paths);
    }
    process.stdout.write(JSON.stringify(result) + "\n");
    const outputPath = process.env["GITHUB_OUTPUT"];
    if (githubOutput && outputPath) {
        const hostList = result.hosts.split(",").filter(Boolean);
        const lines = [
            `profile=${result.profile}`,
            `suite=${result.suite}`,
            `hosts=${result.hosts}`,
            `reason=${result.reason}`,
            `matrix=${getCiMatrixJson(hostList)}`,
        ];
        appendFileSync(outputPath, lines.join("\n") + "\n", "utf8");
    }
}
main();
