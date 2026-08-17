// Marker-block regression probe: compare the pure string transforms
// (find/ownership/render/set/remove) against a golden fixture frozen from the
// PowerShell reference on the same inputs (Phase 9: the reference no longer
// exists to compare against live). Stateful filesystem I/O (backup, atomic
// write) is verified by the §8.6 fresh-tree methodology, not here.

import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { getAxiomCanonicalBody, getAxiomBlockDigest, findAxiomBlock, newAxiomBlockText, setAxiomBlock, removeAxiomBlock, testAxiomBlockOwnership } from "../marker/marker-block.js";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const FIXTURE = resolve(REPO_ROOT, "tests/golden/probes/marker-probe.json");
const golden = JSON.parse(readFileSync(FIXTURE, "utf8")) as {
  digest: string;
  render: string;
  find_absent: { status: string };
  find_present: { status: string; content: string; digest: string; startindex: number; endindex: number };
};

const body = getAxiomCanonicalBody("1")!;
let pass = 0;
let fail = 0;

function check(name: string, actual: unknown, expected: unknown): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a === e) {
    pass++;
    console.log(`[PASS] ${name}`);
  } else {
    fail++;
    console.log(`[FAIL] ${name}\n  expected: ${e}\n  actual:   ${a}`);
  }
}

// 1. canonical body digest matches golden
check("canonical digest", getAxiomBlockDigest(body), golden.digest);
check("canonical body known", testAxiomBlockOwnership({ status: "present", content: body, digest: getAxiomBlockDigest(body) }), "owned");

// 2. render round-trips: set then remove on a fresh file returns original bytes
const rendered = newAxiomBlockText(body, "\n");
const installed = setAxiomBlock("some user content\n", body, "\n").text;
const removed = removeAxiomBlock(installed).text;
check("set+remove round-trip", removed, "some user content\n");

// 3. golden render matches TS render
check("render", newAxiomBlockText(body, "\n"), golden.render);

// 4. find absent / present / malformed
check("find absent", findAxiomBlock("no markers here"), golden.find_absent);
const tsFound = findAxiomBlock(installed);
check("find present status", tsFound.status, golden.find_present.status);
check("find present digest", tsFound.digest, golden.find_present.digest);
check("find present startIndex", tsFound.startIndex, golden.find_present.startindex);
check("find present endIndex", tsFound.endIndex, golden.find_present.endindex);
check("find present content", tsFound.content, golden.find_present.content);

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
if (fail > 0) process.exitCode = 1;
