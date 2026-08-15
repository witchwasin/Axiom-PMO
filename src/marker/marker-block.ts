// Fenced, namespaced block management for files Axiom-PMO does not own.
// Ported from scripts/lib/marker-block.ps1. Pure string-transform functions are
// here (deterministic, golden-comparable); filesystem I/O and backup are handled
// by the stateful layer (§8.6 fresh-tree methodology), not here.

import { createHash } from "node:crypto";

const AXIOM_MARKER_BEGIN = "AXIOM-PMO:BEGIN";
const AXIOM_MARKER_END = "AXIOM-PMO:END";

// v1 -- Milestone 6.3. Frozen literal; never replace, only append on new versions.
const KNOWN_BODY_DIGESTS = ["b3af36639b1077269108f6719c53630ecdf6c3c517f410589a599686194c626b"];

// Canonical body, byte-for-byte identical to Get-AxiomCanonicalBody -Version 1.
export function getAxiomCanonicalBody(version = "1"): string | null {
  if (version !== "1") return null;
  return [
    "## Axiom-PMO",
    "",
    "This repository is governed by [Axiom-PMO](https://github.com/witchwasin/Axiom-PMO),",
    "a governance and development-handoff framework. This block is generated -- edit",
    "it by re-running the setup command, not by hand.",
    "",
    "**Before implementing anything**, read the governed context for the work item",
    "you were given: `PROJECT.md` for scope, `DELIVERY.md` for the work item and its",
    "acceptance criteria, `SCOPE.json` for the approved implementation scope, and",
    "`.execution/<work-item>/EXECUTION-CONTRACT.json` if one was exported for you.",
    "",
    "**Stay inside the approved scope.** Changing files outside `SCOPE.json`'s",
    "`implementation_scope` is a scope deviation and will be reported.",
    "",
    "**You may not approve your own work.** Report `implementation-complete` and",
    "nothing more. Release, QA, security, scope-change, risk-downgrade and",
    "test-evidence acceptance are human-only authority claims; each needs a decision",
    "recorded in `decision-log.md` by a person. Writing `\"actor\": \"human\"` in a file",
    "you authored does not make one.",
    "",
    "**Evidence, not assertion.** A required test is satisfied by evidence from a",
    "source you cannot impersonate -- a CI check -- or by a human accepting a",
    "specific artifact on the record. Your own report that a test passed is not",
    "evidence of it.",
    "",
    "**Verification is after the fact.** Run",
    "`axiom verify --project . --result .execution/<work-item>/EXECUTION-RESULT.json`",
    "when you are done. This block gives you the approved scope and authority as",
    "context; it does not enforce them, and nothing here prevents an out-of-scope",
    "edit. Axiom-PMO checks afterwards whether the implementation stayed inside them.",
  ].join("\n");
}

export function getAxiomBlockDigest(content: string): string {
  const normalized = content.replace(/\r\n/g, "\n").trim();
  return createHash("sha256").update(normalized, "utf8").digest("hex").toLowerCase();
}

export type BlockStatus = "absent" | "present" | "malformed";

export interface AxiomBlock {
  status: BlockStatus;
  content?: string;
  digest?: string | null;
  startIndex?: number;
  endIndex?: number;
  reason?: string;
}

export function findAxiomBlock(text: string): AxiomBlock {
  const beginPattern = new RegExp(`<!--\\s*${AXIOM_MARKER_BEGIN}([^>]*?)-->`, "g");
  const endPattern = new RegExp(`<!--\\s*${AXIOM_MARKER_END}\\s*-->`, "g");

  const begins = [...text.matchAll(beginPattern)];
  const ends = [...text.matchAll(endPattern)];

  if (begins.length === 0 && ends.length === 0) return { status: "absent" };
  if (begins.length > 1) return { status: "malformed", reason: `the file contains ${begins.length} Axiom-PMO BEGIN markers; exactly one is expected` };
  if (ends.length > 1) return { status: "malformed", reason: `the file contains ${ends.length} Axiom-PMO END markers; exactly one is expected` };
  if (begins.length === 1 && ends.length === 0) return { status: "malformed", reason: "an Axiom-PMO BEGIN marker has no matching END marker" };
  if (begins.length === 0 && ends.length === 1) return { status: "malformed", reason: "an Axiom-PMO END marker has no matching BEGIN marker" };
  if (ends[0]!.index! < begins[0]!.index!) return { status: "malformed", reason: "the Axiom-PMO END marker appears before its BEGIN marker" };

  const attributes = begins[0]![1] ?? "";
  const digestMatch = /sha256\s*=\s*([0-9a-f]{64})/i.exec(attributes);
  const digest = digestMatch ? digestMatch[1]!.toLowerCase() : null;

  const contentStart = begins[0]!.index! + begins[0]![0].length;
  const content = text.substring(contentStart, ends[0]!.index!);

  return {
    status: "present",
    content,
    digest,
    startIndex: begins[0]!.index!,
    endIndex: ends[0]!.index! + ends[0]![0].length,
  };
}

export type Ownership = "owned" | "edited" | "foreign" | "unknown" | "absent";

export function testAxiomBlockOwnership(block: AxiomBlock): Ownership {
  if (block.status !== "present") return "absent";
  const actual = getAxiomBlockDigest(block.content ?? "");
  if (KNOWN_BODY_DIGESTS.includes(actual)) return "owned";
  if (!block.digest) return "unknown";
  if (block.digest === actual) return "foreign";
  return "edited";
}

export function getAxiomOwnershipReason(ownership: Ownership, verb = "modify"): string {
  switch (ownership) {
    case "edited":
      return `the block's content is not one Axiom-PMO generates, and it no longer matches the digest recorded when it was written -- it has been edited by hand since. ${verb}ing it would discard those edits`;
    case "foreign":
      return `the block's content is not one Axiom-PMO generates. Its recorded digest matches its content, but that digest is unkeyed and anyone can compute one -- a matching digest shows the content is internally consistent, not that Axiom-PMO wrote it. ${verb}ing it would discard content the framework never created`;
    case "unknown":
      return "the block's content is not one Axiom-PMO generates and carries no recorded digest, so it cannot be shown to be framework-generated";
    default:
      return "the block cannot be shown to be framework-generated";
  }
}

export function newAxiomBlockText(body: string, newline = "\n"): string {
  const normalizedBody = body.replace(/\r\n/g, "\n").trim();
  const digest = getAxiomBlockDigest(normalizedBody);
  const lines = [
    `<!-- ${AXIOM_MARKER_BEGIN} v2 sha256=${digest} -->`,
    "",
    normalizedBody,
    "",
    `<!-- ${AXIOM_MARKER_END} -->`,
  ];
  return lines.join("\n").replace(/\n/g, newline);
}

export interface BlockOpResult {
  action: "inserted" | "replaced" | "unchanged" | "blocked" | "removed" | "absent";
  text: string;
  reason?: string | undefined;
}

export function setAxiomBlock(text: string, body: string, newline = "\n", force = false): BlockOpResult {
  const block = findAxiomBlock(text);
  const rendered = newAxiomBlockText(body, newline);

  if (block.status === "malformed") {
    return { action: "blocked", reason: block.reason, text };
  }
  if (block.status === "absent") {
    return { action: "inserted", text: text + rendered };
  }

  const ownership = testAxiomBlockOwnership(block);
  if (ownership !== "owned" && !force) {
    return { action: "blocked", reason: getAxiomOwnershipReason(ownership, "replac"), text };
  }

  const existing = text.substring(block.startIndex!, block.endIndex!);
  if (existing === rendered) return { action: "unchanged", text };

  const updated = text.substring(0, block.startIndex!) + rendered + text.substring(block.endIndex!);
  return { action: "replaced", text: updated };
}

export function removeAxiomBlock(text: string, _newline = "\n", force = false): BlockOpResult {
  const block = findAxiomBlock(text);
  if (block.status === "absent") return { action: "absent", text };
  if (block.status === "malformed") return { action: "blocked", reason: block.reason, text };

  const ownership = testAxiomBlockOwnership(block);
  if (ownership !== "owned" && !force) {
    return { action: "blocked", reason: getAxiomOwnershipReason(ownership, "remov"), text };
  }

  return { action: "removed", text: text.substring(0, block.startIndex!) + text.substring(block.endIndex!) };
}
