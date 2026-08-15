// Marker-block differential probe: compare the pure string transforms
// (find/ownership/render/set/remove) against the PowerShell reference on the
// same inputs. Stateful filesystem I/O (backup, atomic write) is verified by
// the §8.6 fresh-tree methodology, not here.
import { spawnSync } from "node:child_process";
import { getAxiomCanonicalBody, getAxiomBlockDigest, findAxiomBlock, newAxiomBlockText, setAxiomBlock, removeAxiomBlock, testAxiomBlockOwnership } from "../marker/marker-block.js";
const PWSH = process.env.AXIOM_PWSH ?? "/Users/arm/tools/pwsh/pwsh";
// Run a PS function with a JSON hashtable of named args, using the harness
// file (marker-harness.ps1) which decodes to a hashtable, splats it, and
// lowercases the result keys for field-level comparison.
import { writeFileSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
const HARNESS = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "src", "probe", "marker-harness.ps1");
function runPs(fn, args) {
    const argsPath = join(tmpdir(), `marker-args-${process.pid}-${Math.random().toString(36).slice(2)}.json`);
    writeFileSync(argsPath, JSON.stringify(args), "utf8");
    try {
        const r = spawnSync(PWSH, ["-NoProfile", "-File", HARNESS, "-Fn", fn, "-ArgsPath", argsPath], { encoding: "utf8" });
        if (r.status !== 0)
            throw new Error(`ps ${fn} failed: ${r.stderr}`);
        const out = r.stdout.trim();
        return out === "null" ? null : JSON.parse(out);
    }
    finally {
        unlinkSync(argsPath);
    }
}
const body = getAxiomCanonicalBody("1");
let pass = 0;
let fail = 0;
function check(name, actual, expected) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) {
        pass++;
        console.log(`[PASS] ${name}`);
    }
    else {
        fail++;
        console.log(`[FAIL] ${name}\n  expected: ${e}\n  actual:   ${a}`);
    }
}
// 1. canonical body digest matches PS
check("canonical digest", getAxiomBlockDigest(body), runPs("Get-AxiomBlockDigest", { Content: body }));
check("canonical body known", testAxiomBlockOwnership({ status: "present", content: body, digest: getAxiomBlockDigest(body) }), "owned");
// 2. render round-trips: set then remove on a fresh file returns original bytes
const rendered = newAxiomBlockText(body, "\n");
const installed = setAxiomBlock("some user content\n", body, "\n").text;
const removed = removeAxiomBlock(installed).text;
check("set+remove round-trip", removed, "some user content\n");
// 3. PS render matches TS render
check("render", newAxiomBlockText(body, "\n"), runPs("New-AxiomBlockText", { Body: body, Newline: "\n" }));
// 4. find absent / present / malformed
check("find absent", findAxiomBlock("no markers here"), runPs("Find-AxiomBlock", { Text: "no markers here" }));
const psFound = runPs("Find-AxiomBlock", { Text: installed });
const tsFound = findAxiomBlock(installed);
check("find present status", tsFound.status, psFound["status"]);
check("find present digest", tsFound.digest, psFound["digest"]);
check("find present startIndex", tsFound.startIndex, psFound["startindex"]);
check("find present endIndex", tsFound.endIndex, psFound["endindex"]);
check("find present content", tsFound.content, psFound["content"]);
// 5. ownership states
const edited = installed.replace("You may not approve", "You CAN approve");
check("edited ownership", testAxiomBlockOwnership(findAxiomBlock(edited)), "edited");
const foreign = "<!-- AXIOM-PMO:BEGIN sha256=" + getAxiomBlockDigest("not canonical") + " -->\nnot canonical\n<!-- AXIOM-PMO:END -->";
check("foreign ownership", testAxiomBlockOwnership(findAxiomBlock(foreign)), "foreign");
const unknown = "<!-- AXIOM-PMO:BEGIN -->\nsomething else\n<!-- AXIOM-PMO:END -->";
check("unknown ownership", testAxiomBlockOwnership(findAxiomBlock(unknown)), "unknown");
// 6. set blocked on edited (no force) vs forced replace
check("set blocked on edited", setAxiomBlock(edited, body).action, "blocked");
check("set forced replace", setAxiomBlock(edited, body, "\n", true).action, "replaced");
// 7. remove blocked on foreign (no force)
check("remove blocked on foreign", removeAxiomBlock(foreign).action, "blocked");
console.log(`\nSummary: PASS=${pass} FAIL=${fail}`);
if (fail > 0)
    process.exitCode = 1;
